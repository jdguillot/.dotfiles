{
  config,
  lib,
  ...
}:

let
  cfg = config.cyberfighter.features.tools.zellij;
in
{
  options.cyberfighter.features.tools.zellij = {
    enable = lib.mkEnableOption "Zellij terminal multiplexer";

    theme = lib.mkOption {
      type = lib.types.str;
      default = "catppuccin_frappe";
      description = "Zellij color theme";
    };
  };

  config = lib.mkIf cfg.enable {

    programs.zellij = {
      enable = true;
      settings = {
        inherit (cfg) theme;
        font = "FiraCode Nerd Font";
        keybinds = {
          normal = { };
          pane = { };
        };
      };
    };

  };
}
