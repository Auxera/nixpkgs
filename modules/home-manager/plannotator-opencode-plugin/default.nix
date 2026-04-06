{
  config,
  lib,
  auxera,
  ...
}: let
  cfg = config.programs.plannotator-opencode-plugin;
in {
  options.programs.plannotator-opencode-plugin = {
    enable = lib.mkEnableOption "plannotator opencode plugin";

    env = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Environment variables exported for Plannotator.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [auxera.plannotator-opencode-plugin];

    xdg.configFile."opencode/plugins/plannotator.js".source = "${auxera.plannotator-opencode-plugin}/plugins/plannotator.js";
    xdg.configFile."opencode/command/plannotator-review.md".source = "${auxera.plannotator-opencode-plugin}/commands/plannotator-review.md";
    xdg.configFile."opencode/command/plannotator-annotate.md".source = "${auxera.plannotator-opencode-plugin}/commands/plannotator-annotate.md";
    xdg.configFile."opencode/command/plannotator-archive.md".source = "${auxera.plannotator-opencode-plugin}/commands/plannotator-archive.md";
    xdg.configFile."opencode/command/plannotator-last.md".source = "${auxera.plannotator-opencode-plugin}/commands/plannotator-last.md";

    home.sessionVariables = cfg.env;
  };
}
