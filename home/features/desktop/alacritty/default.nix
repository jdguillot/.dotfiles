{ config, pkgs, ... }:
{
  programs.alacritty = {
    enable = true;
    settings = {
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
        args = [
          "-l"
          "-c"
          "tmux new-session -A -s new-session"
        ];
      };
    };
    theme = "catppuccin_frappe";
  };
}
