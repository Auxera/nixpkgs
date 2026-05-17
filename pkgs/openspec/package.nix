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
  pname = "openspec";
  version = "1.3.1";

  src = fetchFromGitHub {
    owner = "Fission-AI";
    repo = "OpenSpec";
    rev = "v${finalAttrs.version}";
    hash = "sha256-L4LBHVVtgMhSJm+IzZSYOR0UXPbvIRg4xiEV5urYxdI=";
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

    outputHash = "sha256-3I/bQG/PzjGW5Si9yxpdcQ91P5yUG4fonLgk5dLIPk0=";
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

    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild

    node build.js

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/openspec
    cp -r dist $out/lib/openspec/
    cp -r bin $out/lib/openspec/
    cp -r schemas $out/lib/openspec/
    cp -r node_modules $out/lib/openspec/
    install -Dm644 package.json $out/lib/openspec/package.json

    mkdir -p $out/bin
    ln -s $out/lib/openspec/bin/openspec.js $out/bin/openspec
    patchShebangs $out/lib/openspec/bin/openspec.js

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
    description = "AI-native system for spec-driven development";
    homepage = "https://openspec.dev";
    changelog = "https://github.com/Fission-AI/OpenSpec/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "openspec";
    platforms = lib.platforms.unix;
  };
})
