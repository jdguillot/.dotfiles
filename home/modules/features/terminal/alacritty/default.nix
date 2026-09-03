{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.terminal.alacritty;

  defaultSettings = {
    general.working_directory = "${config.home.homeDirectory}";
    window = {
      opacity = 0.9;
      startup_mode = "Fullscreen";
    };
    font.normal.family = "FiraCode Nerd Font Mono";
    selection.save_to_clipboard = true;
    env.term = "xterm-256color";
    terminal.shell = {
      program = "${pkgs.zsh}/bin/zsh";
      args =
        if cfg.launchTmux then
          [
            "-l"
            "-c"
            "tmux new-session -A -s new-session"
          ]
        else
          [ "-l" ];
    };
  };
in
{
  options.cyberfighter.features.terminal.alacritty = {
    enable = lib.mkEnableOption "Alacritty terminal emulator";

    launchTmux = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Launch tmux on startup (attach-or-create, so every window joins one session).";
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      example = {
        window.opacity = 1.0;
      };
      description = "Alacritty settings merged over the module defaults; the full upstream surface, no renames.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.alacritty = {
      enable = true;
      theme = lib.mkDefault "catppuccin_frappe";
      settings = lib.recursiveUpdate defaultSettings cfg.settings;
    };
  };
}
