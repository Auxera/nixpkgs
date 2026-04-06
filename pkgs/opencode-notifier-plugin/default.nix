{
  lib,
  stdenvNoCC,
  bun,
  nodejs,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "opencode-notifier-plugin";
  version = "0.1.36";

  src = fetchFromGitHub {
    owner = "mohak34";
    repo = "opencode-notifier";
    rev = "v0.1.36";
    hash = "sha256-tjxaqh9akN81MMToeGG1wNEiTp0/WEOmatmXewCThWU=";
  };

  strictDeps = true;

  nativeBuildInputs = [
    bun
    nodejs
  ];

  outputHashMode = "recursive";
  outputHashAlgo = "sha256";
  outputHash = "sha256-y1zpJDtn5VHRXWtGKSYhExzYD9qAqHnZ0pZOOlKjUFY=";

  dontFixup = true;

  buildPhase = ''
    runHook preBuild
    set -euo pipefail

    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    export BUN_INSTALL_CACHE_DIR="$TMPDIR/bun-cache"

    bun install --frozen-lockfile --ignore-scripts
    patchShebangs node_modules

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
    license = [lib.licenses.mit];
    platforms = lib.platforms.unix;
  };
}
