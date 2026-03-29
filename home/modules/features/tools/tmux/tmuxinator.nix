{
  config,
  lib,
  hostMeta,
  hostProfile,
  ...
}:

let
  cfg = config.cyberfighter.features.tmuxinator;
  tmux = config.programs.tmux.enable;
  tmuxinatorFiles = {
    razer-nixos = {
      "tmuxinator/dotfiles.yml".source = ./tmuxinator-configs/dotfiles_razer-nixos.yml;
    };
  };
  tmuxinatorConfigs =
    tmuxinatorFiles.${hostMeta.system.hostname} or {
      "tmuxinator/dotfiles.yml".source = ./tmuxinator-configs/dotfiles.yml;
    };

in
{
  options.cyberfighter.features.tmuxinator = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Tmuxinator Tmux session manager";
    };
  };

  config = lib.mkIf (cfg.enable && tmux) {
    programs.tmux.tmuxinator.enable = true;

    xdg.configFile = tmuxinatorConfigs;
  };
}
