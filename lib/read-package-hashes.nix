{
  lib,
  stdenvNoCC,
  packageDir,
  needsOutputHash ? false,
}: let
  system = stdenvNoCC.hostPlatform.system;
  source = builtins.fromJSON (builtins.readFile (packageDir + "/source.json"));

  sourceHash =
    if builtins.isAttrs source.hash
    then source.hash.${system}
    else source.hash;

  outputHashPath = packageDir + "/output-hashes/${system}.txt";
  outputHash =
    if needsOutputHash
    then
      if builtins.pathExists outputHashPath
      then lib.strings.removeSuffix "\n" (builtins.readFile outputHashPath)
      else lib.fakeHash
    else null;
in {
  version = source.version;
  hash = sourceHash;
  inherit outputHash;
}
