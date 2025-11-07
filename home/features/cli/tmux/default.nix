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

          # Configure left look and feel
          set -g status-left-length 100
          set -g status-left ""
          set -ga status-left "#{?client_prefix,#{#[bg=#{@thm_red},fg=#{@thm_bg},bold]  #S },#{#[bg=#{@thm_bg},fg=#{@thm_green}]  #S }}"
          set -ga status-left "#[bg=#{@thm_bg},fg=#{@thm_overlay_0},none]│"
          set -ga status-left "#[bg=#{@thm_bg},fg=#{@thm_maroon}]  #{pane_current_command} "
          set -ga status-left "#[bg=#{@thm_bg},fg=#{@thm_overlay_0},none]│"
          set -ga status-left "#[bg=#{@thm_bg},fg=#{@thm_blue}]  #{=/-32/...:#{s|$USER|~|:#{b:pane_current_path}}} "
          set -ga status-left "#[bg=#{@thm_bg},fg=#{@thm_overlay_0},none]#{?window_zoomed_flag,│,}"
          set -ga status-left "#[bg=#{@thm_bg},fg=#{@thm_yellow}]#{?window_zoomed_flag,  zoom ,}"

          # status right look and feel
          set -g status-right-length 100
          set -g status-right ""
          set -ga status-right "#[bg=#{@thm_bg},fg=#{@thm_green}] #{weather} "
          set -ga status-right "#[bg=#{@thm_bg},fg=#{@thm_overlay_0}, none]│"
          set -ga status-right "#[bg=#{@thm_bg},fg=#{@thm_blue}] 󰭦 %Y-%m-%d 󰅐 %H:%M "
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
