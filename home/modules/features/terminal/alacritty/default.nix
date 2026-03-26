{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.terminal.alacritty;
in
{
  options.cyberfighter.features.terminal.alacritty = {
    enable = lib.mkEnableOption "Alacritty terminal emulator";

    opacity = lib.mkOption {
      type = lib.types.float;
      default = 0.9;
      description = "Window opacity";
    };

    theme = lib.mkOption {
      type = lib.types.str;
      default = "catppuccin_frappe";
      description = "Alacritty color theme";
    };

    font = lib.mkOption {
      type = lib.types.str;
      default = "FiraCode Nerd Font Mono";
      description = "Font family";
    };

    shell = lib.mkOption {
      type = lib.types.str;
      default = "${pkgs.zsh}/bin/zsh";
      description = "Default shell";
    };

    startupMode = lib.mkOption {
      type = lib.types.str;
      default = "Fullscreen";
      description = "Window startup mode";
    };

    launchTmux = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Launch tmux on startup";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.alacritty = {
      enable = true;
      settings = {
        general.working_directory = "${config.home.homeDirectory}";
        window = {
          inherit (cfg) opacity;
          startup_mode = cfg.startupMode;
        };
        font.normal.family = cfg.font;
        selection.save_to_clipboard = true;
        env.term = "xterm-256color";
        terminal.shell = {
          program = cfg.shell;
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
      inherit (cfg) theme;
    };
  };
}
