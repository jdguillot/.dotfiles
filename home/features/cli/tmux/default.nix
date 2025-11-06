{ pkgs, ... }:
{
  ## Tmux
  programs.tmux = {
    enable = true;
    shell = "${pkgs.zsh}/bin/zsh";
    historyLimit = 100000;
    escapeTime = 300;
    plugins = with pkgs.tmuxPlugins; [
      {
        plugin = catppuccin;
        extraConfig = ''
          set -g @catppuccin_flavor 'frappe'
          set -g @catppuccin_window_status_style "slant"
          set -g @catppuccin_status_background "none"
          set -g @catppuccin_window_status_style "none"
          set -g @catppuccin_pane_status_enabled "off"
          set -g @catppuccin_pane_border_status "off"
          set -g @catppuccin_directory_text "#{pane_current_path}"
          set -g @catppuccin_date_time_text "%H:%M:%S"
        '';
      }
      {
        plugin = weather;
        extraConfig = ''
          set -g @tmux-weather-units "u"
        '';
      }
      # nord
      resurrect
      continuum
      vim-tmux-navigator
      fpp
      {
        plugin = tmux-floax;
        extraConfig = ''
          unbind C-t
          set -g @floax-bind 't'
        '';
      }
    ];

    extraConfig = with builtins; (readFile ./tmux.conf);
  };
}
