{
  lib,
  stdenvNoCC,
  readPackageHashes,
  fetchFromGitHub,
}: let
  versionData = readPackageHashes {
    inherit lib stdenvNoCC;
    packageDir = ./.;
    needsOutputHash = false;
  };
  inherit (versionData) version hash;
  sourceInfo = {
    owner = "obra";
    repo = "superpowers";
  };
in
  stdenvNoCC.mkDerivation {
    pname = "superpowers-opencode-plugin";
    inherit version;

    src = fetchFromGitHub {
      inherit (sourceInfo) owner repo;
      rev = "v${version}";
      inherit hash;
    };

    installPhase = ''
      runHook preInstall

      install -Dm644 .opencode/plugins/superpowers.js "$out/.opencode/plugins/superpowers.js"
      cp -r skills "$out/skills"

      runHook postInstall
    '';

    meta = {
      description = "Superpowers OpenCode plugin and skills from source";
      homepage = "https://github.com/obra/superpowers";
      changelog = "https://github.com/obra/superpowers/releases/tag/v${version}";
      license = [lib.licenses.mit];
      platforms = lib.platforms.unix;
    };

    passthru.sourceInfo = sourceInfo;
  }
