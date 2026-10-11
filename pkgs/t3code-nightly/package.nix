# T3 Code nightly CLI (`t3-nightly`) plus the resource-monitor sidecar, built
# from source. Structurally identical to ../t3code/package.nix, pinned to a
# nightly tag instead of a stable release.
#
# Differences from the stable package:
# - The binary is named `t3-nightly` so both channels are co-installable.
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
    # The desktop workspace is excluded on purpose (see ../t3code/package.nix).
    "@t3tools/monorepo"
    "t3..."
    "@t3tools/web..."
    "@t3tools/scripts..."
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src pnpmWorkspaces;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-3IUAvIxnz4Ewm1Yk9w5sCBhG+CACndhqJdafUJAf8mc=";
  };

  resourceMonitor = rustPlatform.buildRustPackage {
    pname = "${finalAttrs.pname}-resource-monitor";
    inherit (finalAttrs) version src;

    sourceRoot = "${finalAttrs.src.name}/native/resource-monitor";

    cargoLock = {
      lockFile = "${finalAttrs.src}/native/resource-monitor/Cargo.lock";
    };
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
      pkg-config
    ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
      cctools
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

    pnpm exec vp run --filter t3 build
    pnpm vp cache clean

    runHook postBuild
  '';

  # Many dependencies vendor prebuilt native artifacts for non-host platforms.
  # Let fixup handle wrappers and shebangs, but skip ELF patching and the
  # tmpdir audit scan of the vendored tree.
  dontPatchELF = true;
  noAuditTmpdir = true;

  installPhase = ''
    runHook preInstall

    mkdir --parents "$out"/libexec/t3code-nightly/apps/server
    cp --recursive --no-preserve=mode node_modules "$out"/libexec/t3code-nightly
    cp --recursive --no-preserve=mode apps/server/{node_modules,dist} "$out"/libexec/t3code-nightly/apps/server

    find "$out"/libexec/t3code-nightly -xtype l -delete

    install -Dm755 ${finalAttrs.resourceMonitor}/bin/t3-resource-monitor \
      "$out"/libexec/t3code-nightly/resource-monitor/t3-resource-monitor

    # The resource monitor sidecar is only built in the electron-builder
    # pipeline upstream, so the server checks this variable before any
    # bundled location.
    makeWrapper ${lib.getExe nodejs} "$out"/bin/t3-nightly \
      --add-flags "$out"/libexec/t3code-nightly/apps/server/dist/bin.mjs \
      --prefix PATH : ${lib.makeBinPath [git gh]} \
      --set-default T3CODE_RESOURCE_MONITOR_PATH "$out"/libexec/t3code-nightly/resource-monitor/t3-resource-monitor

    runHook postInstall
  '';

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
    mainProgram = "t3-nightly";
    platforms = lib.platforms.unix;
  };
})
