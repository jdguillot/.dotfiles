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
      description = "Show a dad joke on shell startup";
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
      enableCompletion = cfg.enableCompletion;
      autosuggestion.enable = cfg.enableAutosuggestions;
      syntaxHighlighting.enable = cfg.enableSyntaxHighlighting;

      history = {
        size = cfg.historySize;
      };

      initContent = ''
        eval "$(starship init zsh)"
        eval "$(zoxide init zsh)"
        ${lib.optionalString cfg.enableStartupJoke ''
          curl -s -H "Accept: text/plain" https://icanhazdadjoke.com | cowsay -f sus | lolcat
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
