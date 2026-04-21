final: _prev: let
  auxeraLib = {
    readPackageHashes = import ./lib/read-package-hashes.nix;
  };
in {
  inherit auxeraLib;
  auxera = import ./pkgs {
    pkgs = final;
    inherit auxeraLib;
  };
}
