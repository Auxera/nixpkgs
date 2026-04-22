{
  lib,
  stdenvNoCC,
  readPackageHashes,
  bun,
  nodejs,
  fetchFromGitHub,
}: let
  versionData = readPackageHashes {
    inherit lib stdenvNoCC;
    packageDir = ./.;
    needsOutputHash = true;
  };
  inherit (versionData) version hash outputHash;
  sourceInfo = {
    owner = "backnotprop";
    repo = "plannotator";
  };
in
  stdenvNoCC.mkDerivation {
    pname = "plannotator-opencode-plugin";
    inherit version;

    src = fetchFromGitHub {
      inherit (sourceInfo) owner repo;
      rev = "v${version}";
      inherit hash;
    };

    strictDeps = true;

    nativeBuildInputs = [
      bun
      nodejs
    ];

    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    inherit outputHash;

    dontFixup = true;

    buildPhase = ''
      runHook preBuild
      set -euo pipefail

      export HOME="$TMPDIR/home"
      mkdir -p "$HOME"
      export BUN_INSTALL_CACHE_DIR="$TMPDIR/bun-cache"

      bun install --frozen-lockfile --ignore-scripts
      patchShebangs node_modules
      patchShebangs apps/hook/node_modules
      patchShebangs apps/review/node_modules
      patchShebangs apps/opencode-plugin/node_modules

      (
        cd apps/review
        bun x vite build
      )

      (
        cd apps/hook
        bun x vite build
        cp dist/index.html dist/redline.html
        cp ../review/dist/index.html dist/review.html
      )

      (
        cd apps/opencode-plugin
        cp ../hook/dist/index.html ./plannotator.html
        cp ../review/dist/index.html ./review-editor.html
        bun build index.ts --outfile dist/index.js --target bun --packages=bundle
      )

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      install -Dm644 apps/opencode-plugin/dist/index.js "$out/plugins/plannotator.js"
      install -Dm644 apps/opencode-plugin/plannotator.html "$out/plannotator.html"
      install -Dm644 apps/opencode-plugin/review-editor.html "$out/review-editor.html"
      install -Dm644 apps/opencode-plugin/commands/plannotator-annotate.md "$out/commands/plannotator-annotate.md"
      install -Dm644 apps/opencode-plugin/commands/plannotator-archive.md "$out/commands/plannotator-archive.md"
      install -Dm644 apps/opencode-plugin/commands/plannotator-last.md "$out/commands/plannotator-last.md"
      install -Dm644 apps/opencode-plugin/commands/plannotator-review.md "$out/commands/plannotator-review.md"

      runHook postInstall
    '';

    meta = {
      description = "Plannotator OpenCode plugin built from source";
      homepage = "https://github.com/backnotprop/plannotator";
      changelog = "https://github.com/backnotprop/plannotator/releases/tag/v${version}";
      license = [
        lib.licenses.mit
        lib.licenses.asl20
      ];
      platforms = lib.platforms.unix;
    };

    passthru.sourceInfo = sourceInfo;
    passthru.needsOutputHash = true;
  }
