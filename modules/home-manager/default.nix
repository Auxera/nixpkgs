{pkgs, ...}: {
  imports = [
    ./opencode-notifier-plugin
    ./plannotator-opencode-plugin
    ./superpowers-opencode-plugin
  ];

  _module.args.auxera = import ../../pkgs {inherit pkgs;};
}
