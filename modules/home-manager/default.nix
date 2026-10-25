{pkgs, ...}: {
  imports = [
    ./opencode-notifier-plugin
    ./openspec
    ./superpowers-opencode-plugin
  ];

  _module.args.auxera = import ../../pkgs {
    inherit pkgs;
    bun2nix = pkgs.bun2nix;
  };
}
