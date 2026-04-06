{
  config,
  lib,
  auxera,
  ...
}: let
  cfg = config.programs.hello-custom;
in {
  options.programs.hello-custom = {
    enable = lib.mkEnableOption "hello-custom helper";

    name = lib.mkOption {
      type = lib.types.str;
      default = "mini-nixpkgs";
      example = "aske";
      description = "Name printed by the hello-custom command.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [auxera.hello-custom];

    xdg.configFile."hello-custom/config.toml".text = ''
      name = ${builtins.toJSON cfg.name}
    '';

    home.sessionVariables.HELLO_CUSTOM_NAME = cfg.name;
  };
}
