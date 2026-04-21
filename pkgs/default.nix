{
  pkgs,
  auxeraLib ? pkgs.auxeraLib or {},
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
        && name != "__pycache__"
        && pathExists (./. + "/${name}/default.nix")
    )
    dirEntries
  );

  callPackage = pkgs.lib.callPackageWith (pkgs // self // auxeraLib // {inherit callPackage;});

  autoPackages = genAttrs packageDirs (name: callPackage (./. + "/${name}") {});

  self = autoPackages;
in
  self
