{
  config,
  lib,
  ...
}:

let
  cfg = config.cyberfighter.features.tools.yazi;
in
{
  options.cyberfighter.features.tools.yazi = {
    enable = lib.mkEnableOption "Yazi File Exlporer";

    theme = lib.mkOption {
      type = lib.types.str;
      default = "catppuccin-frappe";
      description = "yazi color theme";
    };
  };

  config = lib.mkIf cfg.enable {
    home.file = {
      # ".config/yazi/theme.toml".source = ./catppuccin-frappe-blue.toml;
    };
    programs.yazi = {
      enable = true;
      settings = {
      };
    };
  };
}
