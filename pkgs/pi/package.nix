{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  makeBinaryWrapper,
  ripgrep,
  fd,
  writableTmpDirAsHomeHook,
  versionCheckHook,
  nix-update-script,
}:
buildNpmPackage (finalAttrs: {
  pname = "pi";
  version = "0.79.7";

  src = fetchFromGitHub {
    owner = "earendil-works";
    repo = "pi";
    rev = "v${finalAttrs.version}";
    hash = "sha256-NgBSmUF0Ikp4tUxzp9/2RD4I2k9aepn3MVEmVN/NlFQ=";
  };

  npmDepsHash = "sha256-2B4VE1V8rOKfGiLM5527DuXv4zI/fp7O0VeWd/14/d4=";

  npmWorkspace = "packages/coding-agent";
  npmRebuildFlags = ["--ignore-scripts"];

  nativeBuildInputs = [
    makeBinaryWrapper
  ];

  buildPhase = ''
    runHook preBuild

    npx tsgo -p packages/ai/tsconfig.build.json
    npx tsgo -p packages/tui/tsconfig.build.json
    npx tsgo -p packages/agent/tsconfig.build.json
    npm run build --workspace=packages/coding-agent

    runHook postBuild
  '';

  postInstall = ''
    local nm="$out/lib/node_modules/pi-monorepo/node_modules"

    for ws in @earendil-works/pi-ai:packages/ai \
              @earendil-works/pi-agent-core:packages/agent \
              @earendil-works/pi-tui:packages/tui; do
      IFS=: read -r pkg src <<< "$ws"
      rm "$nm/$pkg"
      cp -r "$src" "$nm/$pkg"
    done

    find "$nm" -type l -lname '*/packages/*' -delete

    find "$nm/.bin" -xtype l -delete
  '';

  postFixup = "wrapProgram $out/bin/pi --prefix PATH : ${
    lib.makeBinPath [
      ripgrep
      fd
    ]
  }";

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    writableTmpDirAsHomeHook
    versionCheckHook
  ];

  versionCheckKeepEnvironment = ["HOME"];
  versionCheckProgram = "${placeholder "out"}/bin/pi";
  versionCheckProgramArg = "--version";

  passthru.updateScript = nix-update-script {
    extraArgs = ["--flake"];
  };

  meta = {
    description = "Pi coding agent";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
})
