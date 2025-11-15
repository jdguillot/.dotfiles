{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.shell.starship;
in
{
  options.cyberfighter.features.shell.starship = {
    enable = lib.mkEnableOption "Starship cross-shell prompt";

    useDefaultConfig = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use the default starship.toml configuration file";
    };

    extraSettings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Extra settings to merge with the default configuration";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.starship = {
      enable = true;
      settings =
        if cfg.useDefaultConfig then
          (with builtins; fromTOML (readFile ./starship.toml)) // cfg.extraSettings
        else
          cfg.extraSettings;
    };
  };
}
