{
  config,
  lib,
  auxera,
  ...
}: let
  cfg = config.programs.openspec;
in {
  options.programs.openspec = {
    enable = lib.mkEnableOption "OpenSpec - AI-native spec-driven development tool";

    disableTelemetry = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Disable OpenSpec telemetry";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [auxera.openspec];

    home.sessionVariables = lib.mkIf cfg.disableTelemetry {
      OPENSPEC_TELEMETRY = "0";
    };
  };
}
