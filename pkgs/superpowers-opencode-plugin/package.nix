{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  nix-update-script,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "superpowers-opencode-plugin";
  version = "6.3.0";

  src = fetchFromGitHub {
    owner = "obra";
    repo = "superpowers";
    rev = "v${finalAttrs.version}";
    hash = "sha256-EsGNO0dULWf5Bx6bGrCv2kI2Z8aKH0kRvGiuN23wChQ=";
  };

  installPhase = ''
    runHook preInstall

    install -Dm644 .opencode/plugins/superpowers.js "$out/superpowers.js"
    cp -r skills "$out/skills"

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--flake"
    ];
  };

  meta = {
    description = "Superpowers OpenCode plugin and skills from source";
    homepage = "https://github.com/obra/superpowers";
    changelog = "https://github.com/obra/superpowers/releases/tag/v${finalAttrs.version}";
    license = [lib.licenses.mit];
    platforms = lib.platforms.unix;
  };
})
