{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.tools.lazygit;
in
{
  options.cyberfighter.features.tools.lazygit = {
    enable = lib.mkEnableOption "lazygit terminal UI for git";

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = {
        gui = {
          nerdFontsVersion = "3";
        };
        git = {
          # Renamed in lazygit: git.pagers -> git.diffRenderers, and the
          # per-entry `pager` field -> `command`.
          diffRenderers = [
            {
              command = "delta --dark --paging=never --line-numbers --hyperlinks --hyperlinks-file-link-format=\"lazygit-edit://{path}:{line}\"";
              colorArg = "always";
            }
          ];
          parseEmoji = true;
          tag = {
            forceAnnotated = true;
          };
        };
        confirmOnQuit = false;
      };
      description = "lazygit configuration settings";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.lazygit = {
      enable = true;
      inherit (cfg) settings;
    };
  };
}
