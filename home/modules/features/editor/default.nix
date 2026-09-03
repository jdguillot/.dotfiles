{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.editor;
in
{
  imports = [
    ./lazyvim/default.nix
    ./micro/default.nix
    ./zed/default.nix
  ];

  options.cyberfighter.features.editor = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Editor configuration";
    };

    # Selectors only; deeper configuration goes straight to the upstream
    # programs.* options (everything here is mkDefault).
    vim.enable = lib.mkEnableOption "Vim editor";
    neovim.enable = lib.mkEnableOption "Neovim editor";
    vscode.enable = lib.mkEnableOption "VSCode configuration";
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.enable && cfg.vim.enable) {
      programs.vim = {
        enable = true;
        plugins = lib.mkDefault [ pkgs.vimPlugins.vim-airline ];
        settings = {
          ignorecase = lib.mkDefault true;
        };
        extraConfig = lib.mkDefault ''
          set mouse=a
          set cursorline
        '';
      };
    })

    (lib.mkIf (cfg.enable && cfg.neovim.enable) {
      # All mkDefault: the lazyvim module writes programs.neovim too, and
      # its definitions must win when both are enabled.
      programs.neovim = {
        enable = true;
        viAlias = lib.mkDefault true;
        vimAlias = lib.mkDefault true;
        # No legacy pynvim/ruby-host plugins in use; opt into the new
        # upstream defaults (false) and drop the provider wrappers.
        withRuby = lib.mkDefault false;
        withPython3 = lib.mkDefault false;
      };
    })

    (lib.mkIf (cfg.enable && cfg.vscode.enable) {
      programs.vscode.enable = true;
    })
  ];
}
