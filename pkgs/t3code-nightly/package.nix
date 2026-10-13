# T3 Code nightly: CLI (`t3-nightly`) plus the Electron desktop app
# (`t3code-nightly-desktop`) and the resource-monitor sidecar, built from
# source. Structurally identical to ../t3code/package.nix, pinned to a
# nightly tag instead of a stable release.
#
# Differences from the stable package:
# - Binaries, the macOS app, and the Linux desktop entry are suffixed so
#   both channels are co-installable. The desktop still pairs with its own
#   bundled server (resolved relative to the app tree, never via PATH), and
#   names its bundled CLI by absolute path through T3CODE_CLI_PATH.
# - No shell completions: the generated scripts hardcode `t3` in function
#   names (`_t3_service_install`, ...), so a blanket rename would produce
#   invalid identifiers. Nightly users can still run
#   `t3-nightly --completions <shell>` and adjust the registration line.
{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpm_11,
  pnpmConfigHook,
  nodejs,
  node-gyp,
  python3,
  pkg-config,
  libsecret,
  spdx-license-list-data,
  cacert,
  git,
  gh,
  cctools,
  xcbuild,
  electron_44,
  copyDesktopItems,
  makeDesktopItem,
  libicns,
  writeDarwinBundle,
  makeBinaryWrapper,
  versionCheckHook,
  writableTmpDirAsHomeHook,
  nix-update-script,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "t3code-nightly";
  version = "0.0.46-nightly.20261011.2967";

  src = fetchFromGitHub {
    owner = "pingdotgg";
    repo = "t3code";
    tag = "v${finalAttrs.version}";
    hash = "sha256-1TUSFoLJIBXfr8ZvOdArI07NjNdLU9W7hPXlrPm9CHQ=";
  };

  pnpmWorkspaces = [
    # `...` suffix also pulls in workspace deps of the listed packages.
    "@t3tools/monorepo"
    "t3..."
    "@t3tools/web..."
    "@t3tools/desktop..."
    "@t3tools/scripts..."
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src pnpmWorkspaces;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-reXWayWahyOJKTDp6GyOq9n5TsS4BpAMclWycpIxygo=";
  };

  resourceMonitor = rustPlatform.buildRustPackage {
    pname = "${finalAttrs.pname}-resource-monitor";
    inherit (finalAttrs) version src;

    sourceRoot = "${finalAttrs.src.name}/native/resource-monitor";

    # NOTE: cargoLock.lockFile would read Cargo.lock at eval time, forcing
    # the src to realize while evaluating for other systems (breaks
    # `nix flake check`). cargoHash only changes when Cargo.lock does.
    cargoHash = "sha256-5cmG2daM1bVOA23gjjoalbx0fEL1hmqV6WZov0sUZp8=";
  };

  nativeBuildInputs =
    [
      makeBinaryWrapper
      node-gyp
      nodejs
      python3
      git # `vp config` needs git
      pnpmConfigHook
      pnpm_11
      cacert
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      copyDesktopItems
      pkg-config
    ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
      cctools
      libicns
      writeDarwinBundle
      xcbuild
    ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    libsecret
  ];

  postPatch = ''
    substituteInPlace apps/web/vite.config.ts \
      --replace-fail 'const host = explicitHost || "localhost";' \
                     'const host = explicitHost || "127.0.0.1";'

    mkdir -p .generated/third-party-licenses/spdx/v3.28.0
    cp ${spdx-license-list-data.json}/json/details/*.json \
      .generated/third-party-licenses/spdx/v3.28.0
  '';

  preBuild = ''
    # pnpm 11 otherwise detects dependency drift and reinstalls, including
    # lifecycle scripts.
    export pnpm_config_verify_deps_before_run=false
    # Our pnpm (11.8.0) is older than the upstream pin (11.10.0); keep it from
    # trying to self-switch to the pinned version (no network in build phase).
    export npm_config_manage_package_manager_versions=false
    export pnpm_config_manage_package_manager_versions=false

    node scripts/update-release-package-versions.ts ${finalAttrs.version}

    export npm_config_nodedir=${nodejs}
    export ELECTRON_SKIP_BINARY_DOWNLOAD=1
    pnpm rebuild --pending "''${pnpmInstallFlags[@]}" --filter '!@t3tools/monorepo'
  '';

  buildPhase = ''
    runHook preBuild

    # Builds the t3 server bundle + web client first (desktop depends on it),
    # then the desktop bundle, the preview CSS, and the Linux
    # browser-secret helper (a no-op on other systems).
    pnpm exec vp run --filter @t3tools/desktop build
    pnpm vp cache clean

    runHook postBuild
  '';

  # Many dependencies vendor prebuilt native artifacts for non-host platforms.
  # Let fixup handle wrappers and shebangs, but skip ELF patching and the
  # tmpdir audit scan of the vendored tree.
  dontPatchELF = true;
  noAuditTmpdir = true;

  installPhase =
    ''
      runHook preInstall

      mkdir --parents "$out"/libexec/t3code-nightly/apps/desktop "$out"/libexec/t3code-nightly/apps/server
      cp --recursive --no-preserve=mode node_modules "$out"/libexec/t3code-nightly
      cp --recursive --no-preserve=mode apps/server/{node_modules,dist} "$out"/libexec/t3code-nightly/apps/server
      cp --recursive --no-preserve=mode \
        apps/desktop/{package.json,node_modules,dist-electron} \
        "$out"/libexec/t3code-nightly/apps/desktop

      mkdir --parents "$out"/libexec/t3code-nightly/apps/desktop/prod-resources
      install --mode=444 ${
        if stdenv.hostPlatform.isDarwin
        then "assets/prod/black-macos-1024.png"
        else "assets/prod/black-universal-1024.png"
      } "$out"/libexec/t3code-nightly/apps/desktop/prod-resources/icon.png
    ''
    + lib.optionalString stdenv.hostPlatform.isLinux ''
      install -Dm755 \
        native/browser-secret/build/${stdenv.hostPlatform.node.arch}/t3-browser-secret \
        "$out"/libexec/t3code-nightly/apps/desktop/prod-resources/browser-secret/t3-browser-secret
    ''
    + ''

      find "$out"/libexec/t3code-nightly -xtype l -delete

      install -Dm755 ${finalAttrs.resourceMonitor}/bin/t3-resource-monitor \
        "$out"/libexec/t3code-nightly/resource-monitor/t3-resource-monitor

      makeWrapper ${lib.getExe nodejs} "$out"/bin/t3-nightly \
        --add-flags "$out"/libexec/t3code-nightly/apps/server/dist/bin.mjs \
        --prefix PATH : ${lib.makeBinPath [git gh]} \
        --set-default T3CODE_RESOURCE_MONITOR_PATH "$out"/libexec/t3code-nightly/resource-monitor/t3-resource-monitor

      makeWrapper ${lib.getExe electron_44} "$out"/bin/t3code-nightly-desktop \
        --add-flags "$out"/libexec/t3code-nightly/apps/desktop \
        --prefix PATH : ${lib.makeBinPath [git gh]} \
        --set-default T3CODE_RESOURCE_MONITOR_PATH "$out"/libexec/t3code-nightly/resource-monitor/t3-resource-monitor \
        --inherit-argv0
    ''
    + lib.optionalString stdenv.hostPlatform.isDarwin ''
      # node-pty tries to chmod this helper at runtime, but the Nix store is
      # immutable by then.
      find "$out"/libexec/t3code-nightly \
        -path '*/node-pty/prebuilds/darwin-*/spawn-helper' \
        -exec chmod 755 {} +

      mkdir --parents "$out/Applications/T3 Code Nightly (Alpha).app/Contents/"{MacOS,Resources}
      png2icns \
        "$out/Applications/T3 Code Nightly (Alpha).app/Contents/Resources/t3code-nightly.icns" \
        assets/prod/black-macos-1024.png

      # writeDarwinBundle is a shebangless bash script; run it explicitly via
      # stdenv.shell to avoid Darwin's intermittent ENOEXEC fallback issues.
      ${stdenv.shell} ${lib.getExe writeDarwinBundle} \
        "$out" "T3 Code Nightly (Alpha)" t3code-nightly-desktop t3code-nightly
    ''
    + ''
      mkdir --parents \
        "$out"/share/icons/hicolor/{1024x1024,scalable}/apps
      install --mode=444 ${
        if stdenv.hostPlatform.isDarwin
        then "assets/prod/black-macos-1024.png"
        else "assets/prod/black-universal-1024.png"
      } "$out"/share/icons/hicolor/1024x1024/apps/t3code-nightly.png
      install --mode=444 assets/prod/logo.svg \
        "$out"/share/icons/hicolor/scalable/apps/t3code-nightly.svg

      runHook postInstall
    '';

  desktopItems = [
    (makeDesktopItem {
      name = "t3code-nightly";
      desktopName = "T3 Code Nightly (Alpha)";
      comment = "Nightly desktop control surface for local coding agents";
      exec = "t3code-nightly-desktop %U";
      terminal = false;
      icon = "t3code-nightly";
      startupWMClass = "t3code";
      categories = ["Development"];
    })
  ];

  nativeInstallCheckInputs = [
    versionCheckHook
    writableTmpDirAsHomeHook
  ];
  doInstallCheck = true;
  versionCheckProgram = "${placeholder "out"}/bin/t3-nightly";
  versionCheckProgramArg = "--version";

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--flake"
      "--use-github-releases"
      "--version-regex"
      "v(.*-nightly.*)"
      "--subpackage"
      "pnpmDeps"
    ];
  };

  meta = {
    description = "Minimal web GUI for coding agents (nightly build)";
    homepage = "https://t3.codes";
    downloadPage = "https://t3.codes/download";
    changelog = "https://github.com/pingdotgg/t3code/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "t3code-nightly-desktop";
    platforms = lib.platforms.unix;
  };
})
