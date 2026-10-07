{
  lib,
  config,
  ...
}:

let
  cfg = config.cyberfighter.features.themes;

  # Each theme identity is its own file in this directory; add a new
  # identity by dropping a file here and registering it below.
  themes = {
    catppuccin-frappe-blue = import ./catppuccin-frappe-blue.nix;
  };
in
{
  options.cyberfighter.features.themes = {
    # The active theme identity; apps read colors from activeTheme.
    active = lib.mkOption {
      type = lib.types.enum (builtins.attrNames themes);
      default = "catppuccin-frappe-blue";
      description = "Theme identity name";
    };

    # The resolved palette (the active identity file's contents).
    activeTheme = lib.mkOption {
      type = lib.types.attrs;
      default = themes.${cfg.active};
      description = "Color palette of the active theme identity";
    };
  };
}
