{ pkgs, ... }:
{
  ## Tmux
  programs.tmux = {
    enable = true;
    shell = "${pkgs.zsh}/bin/zsh";
    historyLimit = 100000;
    escapeTime = 300;
    plugins = with pkgs.tmuxPlugins; [
      catppuccin
      # nord
      resurrect
      continuum
      tmux-floax
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
