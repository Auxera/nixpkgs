{
  lib,
  stdenvNoCC,
  bun,
  fetchFromGitHub,
  makeBinaryWrapper,
  models-dev,
  nodejs,
  nix-update-script,
  ripgrep,
  sysctl,
  wayland,
  installShellFiles,
  versionCheckHook,
  writableTmpDirAsHomeHook,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "opencode";
  version = "2.0.25";

  src = fetchFromGitHub {
    owner = "anomalyco";
    repo = "opencode";
    tag = "v${finalAttrs.version}";
    hash = "sha256-1q90OvTRg0Jdf46L1M2YY2CwGRC3ypJ3O5JF4WqYqvY=";
  };

  # Mirrors upstream nix/node_modules.nix (same bun filters/flags and
  # canonicalize scripts). Two deliberate differences:
  # - src/version are inherited here instead of a fileset checkout.
  # - outputHash is per-system, computed with our nixpkgs bun (currently
  #   1.3.x; upstream uses 1.4.x, so upstream nix/hashes.json does not match
  #   our closure). NOTE: `nix-update --subpackage node_modules` (linux
  #   runner) only refreshes the linux hash; refresh the darwin hash locally
  #   via `nix build .#packages.aarch64-darwin.opencode` on a hash mismatch.
  node_modules = let
    platform = stdenvNoCC.hostPlatform;
    bunCpu =
      if platform.isAarch64
      then "arm64"
      else "x64";
    bunOs =
      if platform.isLinux
      then "linux"
      else "darwin";
  in
    stdenvNoCC.mkDerivation {
      pname = "${finalAttrs.pname}-node_modules";
      inherit (finalAttrs) version src;

      impureEnvVars =
        lib.fetchers.proxyImpureEnvVars
        ++ [
          "GIT_PROXY_COMMAND"
          "SOCKS_SERVER"
        ];

      nativeBuildInputs = [
        bun
      ];

      dontConfigure = true;

      buildPhase = ''
        runHook preBuild
        export BUN_INSTALL_CACHE_DIR=$(mktemp -d)
        bun install \
          --cpu="${bunCpu}" \
          --os="${bunOs}" \
          --filter '!./' \
          --filter './packages/cli' \
          --filter './packages/desktop' \
          --filter './packages/app' \
          --frozen-lockfile \
          --ignore-scripts \
          --no-progress
        bun --bun ./nix/scripts/canonicalize-node-modules.ts
        bun --bun ./nix/scripts/normalize-bun-binaries.ts
        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall
        mkdir -p $out
        find . -type d -name node_modules -exec cp -R --parents {} $out \;
        runHook postInstall
      '';

      # NOTE: Required else we get errors that our fixed-output derivation references store paths
      dontFixup = true;

      outputHashAlgo = "sha256";
      outputHashMode = "recursive";
      outputHash =
        if stdenvNoCC.hostPlatform.system == "x86_64-linux"
        then "sha256-jTkP2Y1E9CHl/HChpAmdTovdOTBEkotuY2B2GARDdEA="
        else if stdenvNoCC.hostPlatform.system == "aarch64-darwin"
        then "sha256-H4BK/EtvtT1Tj1yBt7xS9XSPtK4LT4s2vfXOkXCK5zc="
        else throw "unsupported system ${stdenvNoCC.hostPlatform.system} (see upstream nix/hashes.json)";

      meta.platforms = [
        "aarch64-linux"
        "x86_64-linux"
        "aarch64-darwin"
      ];
    };

  nativeBuildInputs = [
    bun
    nodejs # for patchShebangs node_modules
    installShellFiles
    makeBinaryWrapper
    models-dev
    writableTmpDirAsHomeHook
  ];

  postPatch = ''
    # NOTE: Relax Bun version check to be a warning instead of an error
    substituteInPlace packages/script/src/index.ts \
      --replace-fail 'throw new Error(`This script requires bun@''${expectedBunVersionRange}' \
                     'console.warn(`Warning: This script requires bun@''${expectedBunVersionRange}'
  '';

  configurePhase = ''
    runHook preConfigure

    cp -R ${finalAttrs.node_modules}/. .
    patchShebangs node_modules
    patchShebangs packages/*/node_modules

    runHook postConfigure
  '';

  env.MODELS_DEV_API_JSON = "${models-dev}/dist/_api.json";
  env.OPENCODE_DISABLE_MODELS_FETCH = true;
  env.OPENCODE_VERSION = finalAttrs.version;
  env.OPENCODE_CHANNEL = "prod";
  env.NODE_OPTIONS = "--max-old-space-size=4096";

  buildPhase = ''
    runHook preBuild

    cd ./packages/cli
    bun --bun ./script/build.ts --single --skip-install

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 dist/cli-*/bin/opencode $out/bin/opencode

    # OpenTUI dlopens Wayland for clipboard images.
    wrapProgram $out/bin/opencode \
      --prefix PATH : ${
      lib.makeBinPath (
        [
          ripgrep
        ]
        # bun runs sysctl to detect if running on rosetta2
        ++ lib.optional stdenvNoCC.hostPlatform.isDarwin sysctl
      )
    } ${lib.optionalString stdenvNoCC.hostPlatform.isLinux ''
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [wayland]}
    ''}

    ln -s opencode $out/bin/opencode2

    runHook postInstall
  '';

  postInstall = lib.optionalString (stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform) ''
    # v2 dropped the `completion` subcommand; --completions is the global flag.
    # --completions also accepts sh, which emits the same script as bash.
    # staged to files, substitute below rejects anything that is not a regular file
    $out/bin/opencode --completions bash > opencode.bash
    $out/bin/opencode --completions zsh > _opencode
    $out/bin/opencode --completions fish > opencode.fish

    installShellCompletion --cmd opencode \
      --bash opencode.bash \
      --fish opencode.fish \
      --zsh _opencode

    # OPENCODE_CLI_NAME is a build-time define, so the opencode2 copies are
    # renamed rather than regenerated. --replace-fail is a global literal
    # substitution, so any lowercase opencode that later appears in a
    # description or help text ships as opencode2 in the opencode2 copy.
    substitute opencode.bash opencode2.bash --replace-fail opencode opencode2
    substitute _opencode _opencode2 --replace-fail opencode opencode2
    substitute opencode.fish opencode2.fish --replace-fail opencode opencode2

    installShellCompletion --cmd opencode2 \
      --bash opencode2.bash \
      --fish opencode2.fish \
      --zsh _opencode2
  '';

  nativeInstallCheckInputs = [
    versionCheckHook
    writableTmpDirAsHomeHook
  ];
  doInstallCheck = true;
  versionCheckKeepEnvironment = ["HOME" "OPENCODE_DISABLE_MODELS_FETCH"];
  versionCheckProgramArg = "--version";

  passthru = {
    env = finalAttrs.env;
    updateScript = nix-update-script {
      extraArgs = [
        "--subpackage"
        "node_modules"
        "--flake"
      ];
    };
  };

  meta = {
    description = "The open source coding agent";
    homepage = "https://opencode.ai";
    license = lib.licenses.mit;
    mainProgram = "opencode";
    inherit (finalAttrs.node_modules.meta) platforms;
  };
})
