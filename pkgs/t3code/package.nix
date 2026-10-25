# T3 Code: CLI (`t3`) plus the Electron desktop app (`t3code-desktop`) and
# the resource-monitor sidecar, built from source.
#
# Mirrors the upstream build paths (`vp run --filter @t3tools/desktop build`
# for the server bundle + web client + desktop bundle, `cargo build` for
# native/resource-monitor) and the install layout of nixpkgs' t3code, with
# two deliberate differences:
# - electron_44 comes from the nixpkgs-electron flake input, which tracks
#   nixos-unstable independently: the main nixpkgs pin does not provide
#   electron_44 yet (max electron_42). Drop the input once the pin catches
#   up.
# - The resource monitor uses cargoHash instead of a separate derivation
#   with cargoLock.lockFile: lockFile is read at eval time, forcing the src
#   to realize while evaluating for other systems (breaks `nix flake
#   check`). cargoHash only changes when Cargo.lock does.
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
  installShellFiles,
  versionCheckHook,
  writableTmpDirAsHomeHook,
  nix-update-script,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "t3code";
  version = "0.0.45";

  src = fetchFromGitHub {
    owner = "pingdotgg";
    repo = "t3code";
    tag = "v${finalAttrs.version}";
    hash = "sha256-8drTHjFqa2vJ96jhpRZXmNbtbXtKk1q40jOEp9dohNc=";
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
    hash = "sha256-2dGEHOQrnidTei54NlZTJh5u5/i810hb2LddK4XfUNQ=";
  };

  resourceMonitor = rustPlatform.buildRustPackage {
    pname = "${finalAttrs.pname}-resource-monitor";
    inherit (finalAttrs) version src;

    sourceRoot = "${finalAttrs.src.name}/native/resource-monitor";

    cargoHash = "sha256-5cmG2daM1bVOA23gjjoalbx0fEL1hmqV6WZov0sUZp8=";
  };

  nativeBuildInputs =
    [
      installShellFiles
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
    # Keep pnpm from trying to self-switch to the upstream-pinned version
    # (no network in build phase). pnpm itself comes from the
    # nixpkgs-electron overlay, which tracks upstream's 11.10.0 pin.
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

      mkdir --parents "$out"/libexec/t3code/apps/desktop "$out"/libexec/t3code/apps/server
      cp --recursive --no-preserve=mode node_modules "$out"/libexec/t3code
      cp --recursive --no-preserve=mode apps/server/{node_modules,dist} "$out"/libexec/t3code/apps/server
      cp --recursive --no-preserve=mode \
        apps/desktop/{package.json,node_modules,dist-electron} \
        "$out"/libexec/t3code/apps/desktop

      mkdir --parents "$out"/libexec/t3code/apps/desktop/prod-resources
      install --mode=444 ${
        if stdenv.hostPlatform.isDarwin
        then "assets/prod/black-macos-1024.png"
        else "assets/prod/black-universal-1024.png"
      } "$out"/libexec/t3code/apps/desktop/prod-resources/icon.png
    ''
    + lib.optionalString stdenv.hostPlatform.isLinux ''
      install -Dm755 \
        native/browser-secret/build/${stdenv.hostPlatform.node.arch}/t3-browser-secret \
        "$out"/libexec/t3code/apps/desktop/prod-resources/browser-secret/t3-browser-secret
    ''
    + ''

      find "$out"/libexec/t3code -xtype l -delete

      makeWrapper ${lib.getExe nodejs} "$out"/bin/t3 \
        --add-flags "$out"/libexec/t3code/apps/server/dist/bin.mjs \
        --prefix PATH : ${lib.makeBinPath [git gh]} \
        --set-default T3CODE_RESOURCE_MONITOR_PATH "$out"/libexec/t3code/resource-monitor/t3-resource-monitor

      install -Dm755 ${finalAttrs.resourceMonitor}/bin/t3-resource-monitor \
        "$out"/libexec/t3code/resource-monitor/t3-resource-monitor

      # The store is immutable, so in-app updates could never apply;
      # disable them instead of failing mid-download (user-overridable).
      makeWrapper ${lib.getExe electron_44} "$out"/bin/t3code-desktop \
        --add-flags "$out"/libexec/t3code/apps/desktop \
        --prefix PATH : ${lib.makeBinPath [git gh]} \
        --set-default T3CODE_RESOURCE_MONITOR_PATH "$out"/libexec/t3code/resource-monitor/t3-resource-monitor \
        --set-default T3CODE_DISABLE_AUTO_UPDATE true \
        --inherit-argv0
    ''
    + lib.optionalString stdenv.hostPlatform.isDarwin ''
      # node-pty tries to chmod this helper at runtime, but the Nix store is
      # immutable by then.
      find "$out"/libexec/t3code \
        -path '*/node-pty/prebuilds/darwin-*/spawn-helper' \
        -exec chmod 755 {} +

      mkdir --parents "$out/Applications/T3 Code (Alpha).app/Contents/"{MacOS,Resources}
      png2icns \
        "$out/Applications/T3 Code (Alpha).app/Contents/Resources/t3code.icns" \
        assets/prod/black-macos-1024.png

      # writeDarwinBundle is a shebangless bash script; run it explicitly via
      # stdenv.shell to avoid Darwin's intermittent ENOEXEC fallback issues.
      ${stdenv.shell} ${lib.getExe writeDarwinBundle} \
        "$out" "T3 Code (Alpha)" t3code-desktop t3code
    ''
    + ''
      mkdir --parents \
        "$out"/share/icons/hicolor/{1024x1024,scalable}/apps
      install --mode=444 ${
        if stdenv.hostPlatform.isDarwin
        then "assets/prod/black-macos-1024.png"
        else "assets/prod/black-universal-1024.png"
      } "$out"/share/icons/hicolor/1024x1024/apps/t3code.png
      install --mode=444 assets/prod/logo.svg \
        "$out"/share/icons/hicolor/scalable/apps/t3code.svg

      runHook postInstall
    '';

  postInstall = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    for shell in bash fish zsh; do
      installShellCompletion --cmd t3 --"$shell" <("$out/bin/t3" --completions "$shell")
    done
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "t3code";
      desktopName = "T3 Code (Alpha)";
      comment = "Minimal web GUI for coding agents";
      exec = "t3code-desktop %U";
      terminal = false;
      icon = "t3code";
      startupWMClass = "t3code";
      categories = ["Development"];
    })
  ];

  nativeInstallCheckInputs = [
    versionCheckHook
    writableTmpDirAsHomeHook
  ];
  doInstallCheck = true;
  versionCheckProgram = "${placeholder "out"}/bin/t3";
  versionCheckProgramArg = "--version";

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--flake"
      "--use-github-releases"
      # Plain vX.Y.Z tags only. Nightlies and previews are newer GitHub
      # releases, and scheduled updates in this repo are auto-merged.
      "--version-regex"
      "v([0-9]+\\.[0-9]+\\.[0-9]+)$"
      "--subpackage"
      "pnpmDeps"
    ];
  };

  meta = {
    description = "Minimal web GUI for coding agents";
    homepage = "https://t3.codes";
    downloadPage = "https://t3.codes/download";
    changelog = "https://github.com/pingdotgg/t3code/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "t3code-desktop";
    platforms = lib.platforms.unix;
  };
})
