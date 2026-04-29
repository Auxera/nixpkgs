{
  config,
  lib,
  auxera,
  ...
}: let
  cfg = config.programs.superpowers-opencode-plugin;
in {
  options.programs.superpowers-opencode-plugin = {
    enable = lib.mkEnableOption "superpowers opencode plugin";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [auxera.superpowers-opencode-plugin];

    xdg.configFile."opencode/plugins/superpowers.js".source = "${auxera.superpowers-opencode-plugin}/superpowers.js";
    xdg.configFile."opencode/skills" = {
      source = "${auxera.superpowers-opencode-plugin}/skills";
      recursive = true;
    };
  };
}
