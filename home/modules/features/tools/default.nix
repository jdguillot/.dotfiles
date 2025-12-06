{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.tools;
in
{
  options.cyberfighter.features.tools = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Development and utility tools";
    };

    enableDefault = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable default set of tools";
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Extra tools to install";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      with pkgs;
      lib.optionals cfg.enableDefault [
        # File management & navigation
        eza
        fd
        zip
        unzip
        mc
        duf
        tree
        dua
        bat

        # Shell utilities
        tldr
        fzf
        zoxide
        cht-sh
        pay-respects
        lazyssh

        # Version control & development
        gh
        git-crypt

        # Security & SSH
        ssh-agents
        gnupg
        pinentry-curses

        # Network tools
        dig
        mdns-scanner

        # Container & system tools
        distrobox
        lazydocker
        lazysql
        rainfrog

        # Data & text processing
        jq
        yq
        fq
        fx
        ripgrep
        csvlens

        # System monitoring & info
        neofetch

        # Nix tools
        nix-your-shell

        # Fun & entertainment
        cmatrix
        cowsay
        lolcat
        fortune
        cbonsai
        fireplace
        asciiquarium
        pipes

        # Scripting & languages
        powershell
        tree-sitter

        # API & HTTP tools
        posting
      ]
      ++ cfg.extraPackages;
  };
}
