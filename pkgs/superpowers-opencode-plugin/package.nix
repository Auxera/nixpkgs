{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}: let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash;
in
  stdenvNoCC.mkDerivation {
    pname = "superpowers-opencode-plugin";
    inherit version;

    src = fetchFromGitHub {
      owner = "obra";
      repo = "superpowers";
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
  }
