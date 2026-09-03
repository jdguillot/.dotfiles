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
      lib.optionals cfg.enableDefault (
        (with pkgs; [
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
          television
          zoxide
          cht-sh
          pay-respects

          # Security & SSH
          ssh-agents
          gnupg
          pinentry-curses

          # Network tools
          dig

          # Data & text processing
          jq
          yq
          ripgrep

          # Fun & entertainment
          cmatrix
          cowsay
          lolcat
          fortune
          cbonsai
          fireplace
          asciiquarium
          pipes
        ])
        # Dev-trait CLIs; the zsh nix-your-shell hook already guards on
        # `command -v`, so dropping the binary is safe on non-dev homes.
        ++ lib.optionals config.cyberfighter.traits.dev (
          with pkgs;
          [
            # Version control & development
            gh
            git-crypt
            lazyssh

            # Container & system tools
            distrobox
            lazydocker
            lazysql
            rainfrog

            # Network tools
            mdns-scanner

            # Data & text processing
            fq
            fx
            csvlens

            # Nix tools
            nix-your-shell

            # Scripting & languages
            powershell
            tree-sitter

            # API & HTTP tools
            posting
          ]
        )
      )
      ++ cfg.extraPackages;
  };
}
