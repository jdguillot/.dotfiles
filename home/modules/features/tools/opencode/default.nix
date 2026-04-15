{
  config,
  lib,
  ...
}:

let
  cfg = config.cyberfighter.features.tools.opencode;
in
{
  options.cyberfighter.features.tools.opencode = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable OpenCode, a code editor for developers.";
    };

    theme = lib.mkOption {
      type = lib.types.str;
      # Default theme has to be this custom one for now because the system theme isn't working in my tmux
      default = "catppuccin-frappe-term";
      description = "OpenCode color theme (optional).";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.opencode = {
      enable = true;
      themes = ./themes;
      tui = {
        inherit (cfg) theme;
      };
    };
  };
}
