{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.terminal.ghostty;
in
{
  options.cyberfighter.features.terminal.ghostty = {
    enable = lib.mkEnableOption "Ghostty terminal emulator";

    theme = lib.mkOption {
      type = lib.types.str;
      default = "catppuccin-frappe.conf";
      description = "Ghostty color theme";
    };

    fullscreen = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start in fullscreen mode";
    };

    enableZshIntegration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Zsh integration";
    };

    launchTmux = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Launch tmux on startup";
    };

    confirmClose = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Confirm before closing";
    };
  };

  config = lib.mkIf cfg.enable {
    home.file = {
      ".config/ghostty/themes/catppuccin-frappe.conf".source = ./catppuccin-frappe.conf;
    };

    programs.ghostty = {
      enable = true;
      enableZshIntegration = cfg.enableZshIntegration;
      settings = {
        theme = cfg.theme;
        fullscreen = if cfg.fullscreen then "true" else "false";
        command = if cfg.launchTmux then "tmux new-session -A -s new-session" else null;
        confirm-close-surface = if cfg.confirmClose then "true" else "false";
      };
    };
  };
}
