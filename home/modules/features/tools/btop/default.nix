{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.tools.btop;
in
{
  options.cyberfighter.features.tools.btop = {
    enable = lib.mkEnableOption "btop system monitor";

    theme = lib.mkOption {
      type = lib.types.str;
      default = "catppuccin_frappe";
      description = "btop color theme";
    };
  };

  config = lib.mkIf cfg.enable {
    home.file = {
      ".config/btop/themes/nord-cold.theme".source = ./nord-cold.theme;
      ".config/btop/themes/catppuccin_frappe.theme".source = ./catppuccin_frappe.theme;
    };

    programs.btop = {
      enable = true;
      settings = {
        color_theme = cfg.theme;
      };
    };
  };
}
