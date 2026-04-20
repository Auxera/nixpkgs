{
  lib,
  stdenvNoCC,
  bun,
  fetchFromGitHub,
  makeBinaryWrapper,
  models-dev,
  nodejs,
  ripgrep,
  sysctl,
}: let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash;

  outputHash =
    if versionData ? outputHash
    then versionData.outputHash
    else lib.fakeHash;
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "opencode";
    inherit version;

    src = fetchFromGitHub {
      owner = "anomalyco";
      repo = "opencode";
      rev = "v${version}";
      inherit hash;
    };

    node_modules = stdenvNoCC.mkDerivation {
      pname = "${finalAttrs.pname}-node_modules";
      inherit version;
      src = finalAttrs.src;

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

        export HOME="$TMPDIR/home"
        mkdir -p "$HOME"
        export BUN_INSTALL_CACHE_DIR="$TMPDIR/bun-cache"

        bun install \
          --filter '!./' \
          --cpu="*" \
          --frozen-lockfile \
          --filter ./packages/app \
          --filter ./packages/desktop \
          --filter ./packages/opencode \
          --ignore-scripts \
          --no-progress \
          --os="*"

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

      dontFixup = true;

      outputHashAlgo = "sha256";
      outputHashMode = "recursive";
      inherit outputHash;
    };

    nativeBuildInputs = [
      bun
      nodejs
      makeBinaryWrapper
      models-dev
    ];

    env.MODELS_DEV_API_JSON = "${models-dev}/dist/_api.json";
    env.OPENCODE_DISABLE_MODELS_FETCH = true;

    configurePhase = ''
      runHook preConfigure

      cp -R ${finalAttrs.node_modules}/. .
      patchShebangs node_modules
      patchShebangs packages/*/node_modules

      runHook postConfigure
    '';

    buildPhase = ''
      runHook preBuild

      export HOME="$TMPDIR/home"
      mkdir -p "$HOME"
      export OPENCODE_VERSION="${version}"
      export OPENCODE_CHANNEL="stable"

      cd ./packages/opencode
      bun --bun ./script/build.ts --single --skip-install
      bun --bun ./script/schema.ts config.json tui.json

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      install -Dm755 dist/opencode-*/bin/opencode $out/bin/opencode
      wrapProgram $out/bin/opencode \
        --prefix PATH : ${
        lib.makeBinPath (
          [
            ripgrep
          ]
          ++ lib.optionals stdenvNoCC.hostPlatform.isDarwin [
            sysctl
          ]
        )
      }

      install -Dm644 config.json $out/share/opencode/config.json
      install -Dm644 tui.json $out/share/opencode/tui.json

      runHook postInstall
    '';

    meta = {
      description = "AI coding agent built for the terminal";
      homepage = "https://github.com/anomalyco/opencode";
      license = [lib.licenses.mit];
      sourceProvenance = with lib.sourceTypes; [fromSource];
      platforms = [
        "aarch64-linux"
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      mainProgram = "opencode";
    };
  })
