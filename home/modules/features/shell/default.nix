{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.shell;
in
{
  imports = [
    ./zsh/default.nix
    ./starship/default.nix
  ];

  options.cyberfighter.features.shell = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Shell configuration";
    };

    fish = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Fish shell";
      };

      plugins = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [ ];
        description = "Fish plugins to install";
      };
    };

    bash = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Bash shell";
      };
    };

    extraSessionVariables = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Extra session variables";
    };

    extraAliases = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Extra shell aliases";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.enable && cfg.fish.enable) {
      programs.fish = {
        enable = true;
        interactiveShellInit = ''
          set fish_greeting # Disable greeting
        '';
        shellInit = ''
          zoxide init fish | source
          fzf --fish | source
        '';
        inherit (cfg.fish) plugins;
      };
    })

    (lib.mkIf (cfg.enable && cfg.bash.enable) {
      programs.bash = {
        enable = true;
      };
    })

    (lib.mkIf cfg.enable {
      home = {
        sessionVariables = {
          ## Editor
          EDITOR = "nvim";

          ## Python
          PIP_REQUIRE_VIRTUALENV = "true";

          ## fzf
          FZF_DEFAULT_COMMAND = "fd --type f --strip-cwd-prefix";
        }
        // cfg.extraSessionVariables;

        shellAliases = {
          ## Overriding default operations
          ls = "eza --icons -F -H -g -h -o --group-directories-first --git -1  --tree --level=1 --ignore-glob='node_modules*'";
          ll = "ls -la";

          ## Command Presets
          pysrc = ". .venv/bin/activate";
          pynew = "python -m venv .venv && pysrc && pip install -r requirements";

          ns = "sudo nixos-rebuild switch --flake ~/.dotfiles && home-manager switch --flake ~/.dotfiles#$USER@$(hostname -s)";
          hs = "home-manager switch --flake ~/.dotfiles#$USER@$(hostname -s)";
          nu = "nix flake update --flake ~/.dotfiles";
          nb = "sudo nixos-rebuild boot --flake ~/.dotfiles && home-manager switch --flake ~/.dotfiles#$USER@$(hostname -s)";

          myip = "curl http://ip-api.com/json/ -s | jq";

          dadjoke = "curl -s -H \"Accept: text/plain\" https://icanhazdadjoke.com | cowsay -f sus | lolcat";

          bwu = "export BW_SESSION=$(bw unlock --raw)";
        }
        // cfg.extraAliases;
      };
    })
  ];
}

