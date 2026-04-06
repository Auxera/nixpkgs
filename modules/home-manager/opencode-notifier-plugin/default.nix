{
  config,
  lib,
  auxera,
  ...
}: let
  cfg = config.programs.opencode-notifier-plugin;

  defaultSettings = {
    sound = true;
    notification = true;
    timeout = 5;
    showProjectName = true;
    showSessionTitle = false;
    showIcon = true;
    suppressWhenFocused = true;
    enableOnDesktop = false;
    notificationSystem = "osascript";
    linux.grouping = false;

    volumes = {
      permission = 1;
      complete = 1;
      subagent_complete = 1;
      error = 1;
      question = 1;
    };
  };
in {
  options.programs.opencode-notifier-plugin = {
    enable = lib.mkEnableOption "opencode notifier plugin";

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Additional notifier settings merged into defaults.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [auxera.opencode-notifier-plugin];

    xdg.configFile."opencode/plugins/opencode-notifier.js".source = "${auxera.opencode-notifier-plugin}/plugins/opencode-notifier.js";
    xdg.configFile."opencode/logos".source = "${auxera.opencode-notifier-plugin}/logos";
    xdg.configFile."opencode/sounds".source = "${auxera.opencode-notifier-plugin}/sounds";

    xdg.configFile."opencode/opencode-notifier.json".text =
      builtins.toJSON (lib.recursiveUpdate defaultSettings cfg.settings);
  };
}
