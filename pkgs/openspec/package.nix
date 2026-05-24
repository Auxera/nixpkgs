{
  lib,
  stdenvNoCC,
  nodejs,
  fetchFromGitHub,
  nix-update-script,
  fetchPnpmDeps,
  pnpmConfigHook,
  pnpm_9,
}: let
  pnpm = pnpm_9;
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "openspec";
    version = "1.3.1";

    src = fetchFromGitHub {
      owner = "Fission-AI";
      repo = "OpenSpec";
      rev = "v${finalAttrs.version}";
      hash = "sha256-L4LBHVVtgMhSJm+IzZSYOR0UXPbvIRg4xiEV5urYxdI=";
    };

    pnpmDeps = fetchPnpmDeps {
      inherit (finalAttrs) pname version src;
      fetcherVersion = 3;
      hash = "sha256-9s2kdvd7svK4hofnD66HkDc86WTQeayfF5y7L2dmjNg=";
      pnpm = pnpm;
    };

    nativeBuildInputs = [
      nodejs
      pnpmConfigHook
      pnpm
    ];

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
