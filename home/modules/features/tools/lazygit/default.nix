{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.tools.lazygit;
in
{
  options.cyberfighter.features.tools.lazygit = {
    enable = lib.mkEnableOption "lazygit terminal UI for git";

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = {
        gui = {
          nerdFontsVersion = "3";
        };
        git = {
          parseEmoji = true;
        };
        confirmOnQuit = false;
      };
      description = "lazygit configuration settings";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.lazygit = {
      enable = true;
      inherit (cfg) settings;
    };
  };
}
