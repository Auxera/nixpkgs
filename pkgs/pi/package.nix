{
  lib,
  stdenvNoCC,
  buildNpmPackage,
  fetchurl,
  nodejs,
  makeWrapper,
  versionCheckHook,
  writableTmpDirAsHomeHook,
  fd,
  ripgrep,
  nix-update-script,
}:
buildNpmPackage rec {
  pname = "pi";
  version = "0.79.7";

  src = stdenvNoCC.mkDerivation {
    pname = "${pname}-src-with-lock";
    inherit version;

    src = fetchurl {
      url = "https://registry.npmjs.org/@earendil-works/pi-coding-agent/-/pi-coding-agent-${version}.tgz";
      hash = "sha256-LNob6zyA1FHOXbXauCdvIi2dHDw0stxG8q/ecccdSEE=";
    };

    buildCommand = ''
      mkdir -p $out
      tar -xzf $src -C $out --strip-components=1
      rm -f $out/npm-shrinkwrap.json
      cp ${./package-lock.json} $out/package-lock.json
    '';
  };

  npmDepsFetcherVersion = 2;
  npmDepsHash = "sha256-8zmJFSkP6Z7cZ3ijDLCN1LHQjj1od90UAeNZngVhNYk=";

  dontNpmBuild = true;
  makeCacheWritable = true;

  nativeBuildInputs = [
    makeWrapper
  ];

  nativeInstallCheckInputs = [
    versionCheckHook
    writableTmpDirAsHomeHook
  ];

  postInstall = ''
    wrapProgram $out/bin/pi \
      --prefix PATH : ${lib.makeBinPath [fd ripgrep]} \
      --set PI_SKIP_VERSION_CHECK 1 \
      --set PI_TELEMETRY 0
  '';

  doInstallCheck = true;
  versionCheckProgramArg = "--version";

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--subpackage"
      "node_modules"
      "--flake"
    ];
  };

  meta = {
    description = "Coding agent CLI with read, bash, edit, write tools and session management";
    homepage = "https://github.com/earendil-works/pi";
    license = lib.licenses.mit;
    mainProgram = "pi";
    platforms = lib.platforms.unix;
  };
}
