{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.sesh;
in
{
  options.cyberfighter.features.sesh = {
    enable = lib.mkEnableOption "Enable Sesh, a terminal multiplexer";

    useConfigFile = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use config file for Sesh. If false, Sesh will use default settings.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      sesh
    ];

    home.file."sesh.toml" = lib.mkIf cfg.useConfigFile {
      source = ./sesh.toml;
    };

  };
}
