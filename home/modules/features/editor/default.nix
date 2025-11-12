{ config, lib, pkgs, ... }:

let
  cfg = config.cyberfighter.features.editor;
in
{
  options.cyberfighter.features.editor = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Editor configuration";
    };

    vim = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Vim editor";
      };

      plugins = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs.vimPlugins; [ vim-airline ];
        description = "Vim plugins to install";
      };
    };

    neovim = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Neovim editor";
      };
    };

    vscode = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable VSCode configuration";
      };

      extensions = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "VSCode extensions to install";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.enable && cfg.vim.enable) {
      programs.vim = {
        enable = true;
        plugins = cfg.vim.plugins;
        settings = {
          ignorecase = true;
        };
        extraConfig = ''
          set mouse=a
          set cursorline
        '';
      };
    })

    (lib.mkIf (cfg.enable && cfg.neovim.enable) {
      programs.neovim = {
        enable = true;
        viAlias = true;
        vimAlias = true;
      };
    })

    (lib.mkIf (cfg.enable && cfg.vscode.enable) {
      programs.vscode = {
        enable = true;
        extensions = cfg.vscode.extensions;
      };
    })
  ];
}