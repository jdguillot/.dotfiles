{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.tools.sesh;
in
{
  options.cyberfighter.features.tools.sesh = {
    enable = lib.mkEnableOption "Enable Sesh, a terminal multiplexer";

    useConfigFile = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use config file for Sesh. If false, Sesh will use default settings.";
    };

    zshInitContent = lib.mkOption {
      type = lib.types.lines;
      readOnly = true;
      description = "Zsh init content for sesh integration (completion + sesh-sessions keybind).";
      default = ''
        mkdir -p "$HOME/.zsh/completions" && sesh completion zsh > "$HOME/.zsh/completions/_sesh"
        fpath=("$HOME/.zsh/completions" $fpath)

        function sesh-sessions() {
          {
            exec </dev/tty
            exec <&1
            local session
            session=$(sesh list -t -c | fzf --height 40% --reverse --border-label ' sesh ' --border --prompt '⚡  ')
            zle reset-prompt > /dev/null 2>&1 || true
            [[ -z "$session" ]] && return
            sesh connect $session
          }
        }

        zle     -N             sesh-sessions
        bindkey -M emacs '\es' sesh-sessions
        bindkey -M vicmd '\es' sesh-sessions
        bindkey -M viins '\es' sesh-sessions
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      sesh
    ];

    xdg.configFile."sesh/sesh.toml" = lib.mkIf cfg.useConfigFile {
      source = ./sesh.toml;
    };
  };
}
