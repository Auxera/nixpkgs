{
  lib,
  stdenvNoCC,
  bun2nix,
  bun,
  fetchFromGitHub,
}: let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash;
in
  stdenvNoCC.mkDerivation {
    pname = "opencode-notifier-plugin";
    inherit version;

    src = fetchFromGitHub {
      owner = "mohak34";
      repo = "opencode-notifier";
      rev = "v${version}";
      inherit hash;
    };

    nativeBuildInputs = [
      bun2nix.hook
      bun
    ];

    bunDeps = bun2nix.fetchBunDeps {
      bunNix = ./bun.nix;
    };

    dontRunLifecycleScripts = true;
    dontUseBunBuild = true;
    dontUseBunInstall = true;

    buildPhase = ''
      runHook preBuild

      bun build src/index.ts --outfile dist/index.js --target bun --packages=bundle

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      install -Dm644 dist/index.js "$out/plugins/opencode-notifier.js"
      cp -r logos "$out/"
      cp -r sounds "$out/"

      runHook postInstall
    '';

    meta = {
      description = "OpenCode notifier plugin built from source";
      homepage = "https://github.com/mohak34/opencode-notifier";
      changelog = "https://github.com/mohak34/opencode-notifier/releases/tag/v${version}";
      license = [lib.licenses.mit];
      platforms = lib.platforms.unix;
    };
  }
