{ config, lib, pkgs, ... }:

let
  cfg = config.cyberfighter.features.terminal;
in
{
  options.cyberfighter.features.terminal = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Terminal configuration";
    };

    alacritty = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Alacritty terminal";
      };
    };

    ghostty = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Ghostty terminal";
      };
    };

    tmux = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Tmux terminal multiplexer";
      };
    };

    zellij = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Zellij terminal multiplexer";
      };

      theme = lib.mkOption {
        type = lib.types.str;
        default = "nord";
        description = "Zellij theme";
      };

      font = lib.mkOption {
        type = lib.types.str;
        default = "FiraCode Nerd Font";
        description = "Zellij font";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.enable && cfg.alacritty.enable) {
      programs.alacritty = {
        enable = true;
      };
    })

    (lib.mkIf (cfg.enable && cfg.ghostty.enable) {
      home.packages = with pkgs; [ ghostty ];
    })

    (lib.mkIf (cfg.enable && cfg.tmux.enable) {
      programs.tmux = {
        enable = true;
      };
    })

    (lib.mkIf (cfg.enable && cfg.zellij.enable) {
      programs.zellij = {
        enable = true;
        settings = {
          theme = cfg.zellij.theme;
          font = cfg.zellij.font;
          keybinds = {
            normal = { };
            pane = { };
          };
        };
      };
    })
  ];
}