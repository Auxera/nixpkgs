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
  version = "0.80.10";

  src = fetchFromGitHub {
    owner = "earendil-works";
    repo = "pi";
    rev = "v${finalAttrs.version}";
    hash = "sha256-Vs/ndHYzFyfN4CjPV2zMYblLXe9IuM13UrPJI1VsZEQ=";
  };

  npmDepsHash = "sha256-XGvDNH+eilsgc0Z7ITqbitB/9RVc+WuDfCcr1pibNqk=";

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
