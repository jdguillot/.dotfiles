{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.shell.zsh;
in
{
  options.cyberfighter.features.shell.zsh = {
    enable = lib.mkEnableOption "Zsh shell";

    enableCompletion = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable zsh completion";
    };

    lazyLoadCompletion = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Lazy load completions on first use (faster startup)";
    };

    enableAutosuggestions = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable zsh autosuggestions";
    };

    enableSyntaxHighlighting = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable zsh syntax highlighting";
    };

    historySize = lib.mkOption {
      type = lib.types.int;
      default = 10000;
      description = "Number of commands to keep in history";
    };

    enableOhMyZsh = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Oh My Zsh";
    };

    ohMyZshPlugins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "git"
        "fzf"
        "gh"
      ];
      description = "Oh My Zsh plugins to enable";
    };

    enableStartupJoke = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Show a dad joke on shell startup (uses cached jokes, refreshes daily)";
    };

    extraInitContent = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra content to add to zsh init";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.zsh = {
      enable = true;
      # Disable home-manager's completion management when using lazy loading
      enableCompletion = cfg.enableCompletion && !cfg.lazyLoadCompletion;
      autosuggestion.enable = cfg.enableAutosuggestions;
      syntaxHighlighting.enable = cfg.enableSyntaxHighlighting;

      history = {
        size = cfg.historySize;
      };

      initContent = ''
        # Skip compinit security checks (speeds up startup significantly)
        # compinit is handled by oh-my-zsh, but we can optimize it
        ${lib.optionalString cfg.enableOhMyZsh ''
          # Skip insecure directory checks for compinit
          ZSH_DISABLE_COMPFIX=true
        ''}

        ${lib.optionalString (cfg.enableCompletion && cfg.lazyLoadCompletion) ''
          # Lazy load completions - only initialize when first tab completion is used
          # This dramatically speeds up shell startup
          autoload -Uz compinit

          # Only regenerate compdump once a day
          if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
            compinit -i -C
          else
            compinit -i
          fi
        ''}

        # Source shell functions first (needed for startup joke)
        source ${../shell-functions.sh}

        eval "$(starship init zsh)"
        eval "$(zoxide init zsh)"
        ${lib.optionalString cfg.enableStartupJoke ''
          show-startup-joke
        ''}

        if command -v nix-your-shell > /dev/null; then
          nix-your-shell zsh | source /dev/stdin
        fi

        ${cfg.extraInitContent}

      '';

      oh-my-zsh = lib.mkIf cfg.enableOhMyZsh {
        enable = true;
        plugins = cfg.ohMyZshPlugins;
      };
    };
  };
}
