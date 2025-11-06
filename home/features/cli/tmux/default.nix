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
      # nord
      resurrect
      continuum
      {
        plugin = tmux-floax;
        extraConfig = ''
          unbind C-t
          set -g @floax-bind 't'
        '';
      }
      vim-tmux-navigator
      {
        plugin = tmux-which-key;
        extraConfig = ''
          set -g @tmux-which-key-xdg-enable 1
          set -g @tmux-which-key-disable-autobuild 1
        '';
      }
    ];

    extraConfig = with builtins; (readFile ./tmux.conf);
  };
}
