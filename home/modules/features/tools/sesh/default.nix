{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.tools.sesh;
in
{
  options.cyberfighter.features.tools.sesh = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Sesh is a terminal session manager written in Rust.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.sesh = {
      enable = true;
      enableTmuxIntegration = false;  # We'll manually configure the keybind
      tmuxKey = "o";
    };
    programs.fzf.tmux.enableShellIntegration = true;
  };
}
