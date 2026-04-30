{
  pkgs,
  bun2nix ? null,
}: let
  inherit
    (pkgs.lib)
    attrNames
    filterAttrs
    genAttrs
    pathExists
    ;

  dirEntries = builtins.readDir ./.;

  packageDirs = attrNames (
    filterAttrs (
      name: kind:
        kind
        == "directory"
        && pathExists (./. + "/${name}/default.nix")
    )
    dirEntries
  );

  callPackage = pkgs.lib.callPackageWith (pkgs // self // {inherit callPackage bun2nix;});

  autoPackages = genAttrs packageDirs (name: callPackage (./. + "/${name}") {});

  self = autoPackages;
in
  self
