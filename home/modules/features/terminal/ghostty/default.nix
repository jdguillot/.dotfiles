{
  config,
  lib,
  ...
}:

let
  cfg = config.cyberfighter.features.terminal.ghostty;

  defaultSettings = {
    theme = "catppuccin-frappe.conf";
    fullscreen = "true";
    command = if cfg.launchTmux then "tmux new-session -A -s new-session" else null;
    confirm-close-surface = "false";
    background-opacity = 0.9;
  };
in
{
  options.cyberfighter.features.terminal.ghostty = {
    enable = lib.mkEnableOption "Ghostty terminal emulator";

    launchTmux = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Launch tmux on startup (attach-or-create, so every window joins one session).";
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      example = {
        fullscreen = "false";
      };
      description = "Ghostty settings merged over the module defaults; the full upstream surface, no renames.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.file = {
      ".config/ghostty/themes/catppuccin-frappe.conf".source = ./catppuccin-frappe.conf;
    };

    programs.ghostty = {
      enable = true;
      enableZshIntegration = lib.mkDefault true;
      settings = lib.recursiveUpdate defaultSettings cfg.settings;
    };
  };
}
