{
  lib,
  stdenvNoCC,
  bun,
  nodejs,
  fetchFromGitHub,
  writableTmpDirAsHomeHook,
  nix-update-script,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "plannotator-opencode-plugin";
  version = "0.19.0";

  src = fetchFromGitHub {
    owner = "backnotprop";
    repo = "plannotator";
    rev = "v${finalAttrs.version}";
    hash = "sha256-+Z7sY9ImCi9wOE+4iLv2L+zk03fVuF237QPpzCTe8rg=";
  };

  node_modules = stdenvNoCC.mkDerivation {
    pname = "${finalAttrs.pname}-node_modules";
    inherit (finalAttrs) version src;

    nativeBuildInputs = [
      bun
      writableTmpDirAsHomeHook
    ];

    dontConfigure = true;

    buildPhase = ''
      runHook preBuild

      bun install \
        --cpu="*" \
        --frozen-lockfile \
        --ignore-scripts \
        --no-progress \
        --os="*"

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out
      find . -type d -name node_modules -exec cp -R --parents {} $out \;

      runHook postInstall
    '';

    dontFixup = true;

    outputHash = "sha256-eCe6AHWZPSDglm2ETI3n9iM8yFtjV1L1+Kxkv+WN07Y=";
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
  };

  nativeBuildInputs = [
    bun
    nodejs
    writableTmpDirAsHomeHook
  ];

  dontFixup = true;

  configurePhase = ''
     runHook preConfigure

    cp -R ${finalAttrs.node_modules}/. .
    patchShebangs node_modules
    patchShebangs apps/*/node_modules
    patchShebangs packages/*/node_modules

     runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild

    (
      cd ./apps/review
      bun vite build
    )

    (
      cd ./apps/hook
      bun vite build
      cp ./dist/index.html ./dist/redline.html
      cp ../review/dist/index.html ./dist/review.html
    )

    (
      cd ./apps/opencode-plugin
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

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--subpackage"
      "node_modules"
      "--flake"
    ];
  };

  meta = {
    description = "Plannotator OpenCode plugin built from source";
    homepage = "https://github.com/backnotprop/plannotator";
    changelog = "https://github.com/backnotprop/plannotator/releases/tag/v${finalAttrs.version}";
    license = [
      lib.licenses.mit
      lib.licenses.asl20
    ];
    platforms = lib.platforms.unix;
  };
})
