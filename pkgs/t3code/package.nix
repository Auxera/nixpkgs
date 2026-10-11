# T3 Code CLI (`t3`) plus the resource-monitor sidecar, built from source.
#
# Mirrors the upstream build paths (`vp run --filter t3 build` for the server
# bundle + web client, `cargo build` for native/resource-monitor) and the
# install layout of nixpkgs' t3code, with two deliberate differences:
# - The Electron desktop app is omitted: it needs electron_44, which the
#   pinned nixpkgs does not provide yet (max electron_42). Re-add it (see
#   nixpkgs pkgs/by-name/t3/t3code/{package,unwrapped}.nix) once the pin
#   catches up.
# - The resource monitor's cargoHash only needs a refresh when upstream's
#   Cargo.lock changes.
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
    # The desktop workspace is excluded on purpose (see file header).
    "@t3tools/monorepo"
    "t3..."
    "@t3tools/web..."
    "@t3tools/scripts..."
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src pnpmWorkspaces;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-nCEZcB5r3xzN/CSWED0IBRhsu3iGd0B88/Lv1v/YaUU=";
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

    mkdir --parents "$out"/libexec/t3code/apps/server
    cp --recursive --no-preserve=mode node_modules "$out"/libexec/t3code
    cp --recursive --no-preserve=mode apps/server/{node_modules,dist} "$out"/libexec/t3code/apps/server

    find "$out"/libexec/t3code -xtype l -delete

    install -Dm755 ${finalAttrs.resourceMonitor}/bin/t3-resource-monitor \
      "$out"/libexec/t3code/resource-monitor/t3-resource-monitor

    # The resource monitor sidecar is only built in the electron-builder
    # pipeline upstream, so the server checks this variable before any
    # bundled location.
    makeWrapper ${lib.getExe nodejs} "$out"/bin/t3 \
      --add-flags "$out"/libexec/t3code/apps/server/dist/bin.mjs \
      --prefix PATH : ${lib.makeBinPath [git gh]} \
      --set-default T3CODE_RESOURCE_MONITOR_PATH "$out"/libexec/t3code/resource-monitor/t3-resource-monitor

    runHook postInstall
  '';

  postInstall = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    for shell in bash fish zsh; do
      installShellCompletion --cmd t3 --"$shell" <("$out/bin/t3" --completions "$shell")
    done
  '';

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
    mainProgram = "t3";
    platforms = lib.platforms.unix;
  };
})
