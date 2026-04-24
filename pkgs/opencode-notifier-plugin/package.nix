{
  lib,
  stdenvNoCC,
  bun2nix,
  bun,
  fetchFromGitHub,
  pkgs,
  alejandra,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "opencode-notifier-plugin";
  version = "0.2.3";

  src = fetchFromGitHub {
    owner = "mohak34";
    repo = "opencode-notifier";
    rev = "v${finalAttrs.version}";
    hash = "sha256-Pji4jbFewkhD88SilwJAWzmkA+z3/u54KXN74aXjtHk=";
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

  passthru.updateScript = pkgs.writeScript "update" ''
    set -e

    nix-update ${finalAttrs.pname} --flake

    tmpdir=$(mktemp -d)

    NEW_VERSION=$(nix eval .#${finalAttrs.pname}.version --raw)

    curl -sL "https://raw.githubusercontent.com/${finalAttrs.src.owner}/${finalAttrs.src.repo}/v$NEW_VERSION/bun.lock" -o "$tmpdir/bun.lock"

    ${bun2nix}/bin/bun2nix -l $tmpdir/bun.lock -o ./pkgs/${finalAttrs.pname}/bun.nix

    ${alejandra}/bin/alejandra ./pkgs/${finalAttrs.pname}/bun.nix

    rm -rf "$tmpdir"
  '';

  meta = {
    description = "OpenCode notifier plugin built from source";
    homepage = "https://github.com/mohak34/opencode-notifier";
    changelog = "https://github.com/mohak34/opencode-notifier/releases/tag/v${finalAttrs.version}";
    license = [lib.licenses.mit];
    platforms = lib.platforms.unix;
  };
})
