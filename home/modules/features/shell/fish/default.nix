{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.shell.fish;
in
{
  options.cyberfighter.features.shell.fish = {
    enable = lib.mkEnableOption "Fish Shell configuration";
  };

  config = lib.mkIf cfg.enable {
    fish = {
      enable = true;
      plugins = [
        {
          name = "grc";
          inherit (pkgs.fishPlugins.grc) src;
        }
        {
          name = "done";
          src = pkgs.fishPlugins.done;
        }
        {
          name = "fzf-fish";
          src = pkgs.fishPlugins.fzf-fish;
        }
        {
          name = "forgit";
          src = pkgs.fishPlugins.forgit;
        }
      ];
    };
  };
}
