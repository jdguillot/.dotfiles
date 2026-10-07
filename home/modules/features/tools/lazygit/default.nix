{
  config,
  lib,
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
          # gui.theme must be a color map, not a file path, so the palette
          # from the active theme identity is mapped to lazygit's shape here.
          theme =
            let
              p = config.cyberfighter.features.themes.activeTheme;
            in
            {
              activeBorderColor = [ p.blue "bold" ];
              inactiveBorderColor = [ p.overlay1 ];
              searchingActiveBorderColor = [ p.peach ];
              optionsTextColor = [ p.blue ];
              selectedLineBgColor = [ p.surface1 ];
              inactiveViewSelectedLineBgColor = [ p.overlay0 ];
              cherryPickedCommitFgColor = [ p.blue ];
              cherryPickedCommitBgColor = [ p.surface0 ];
              markedBaseCommitFgColor = [ p.blue ];
              markedBaseCommitBgColor = [ p.peach ];
              unstagedChangesColor = [ p.red ];
              defaultFgColor = [ p.text ];
              authorColors = { "*" = p.lavender; };
            };
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
    # The catppuccin module points LG_CONFIG_FILE at its read-only nix store
    # theme file; lazygit's config migration tries to write back to it and
    # fails. We ship the theme ourselves (features.themes.activeTheme)
    # instead.
    catppuccin.lazygit.enable = false;
    programs.lazygit = {
      enable = true;
      inherit (cfg) settings;
    };
  };
}
