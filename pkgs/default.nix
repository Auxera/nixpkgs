{pkgs}: let
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

  callPackage = pkgs.lib.callPackageWith (pkgs // self);

  autoPackages = genAttrs packageDirs (name: callPackage (./. + "/${name}") {});

  overrides = {};

  self = autoPackages // overrides;
in
  removeAttrs self ["default"]
