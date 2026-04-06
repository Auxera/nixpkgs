{pkgs, ...}: {
  imports = [
    ./opencode-notifier-plugin
    ./plannotator-opencode-plugin
  ];

  _module.args.auxera = import ../../pkgs {inherit pkgs;};
}
