{
  config,
  lib,
  ...
}:

let
  cfg = config.cyberfighter.features.noctalia;
in
{
  options.cyberfighter.features.noctalia = {
    enable = lib.mkEnableOption "Noctalia shell (v5)";
  };

  config = lib.mkIf cfg.enable {
    # Home Manager's own module with nixpkgs' package. v5 reads ~/.config
    # read-only and writes GUI changes to ~/.local/state/noctalia, so a
    # declarative config no longer blocks the settings GUI.
    programs.noctalia = {
      enable = true;
      settings = ./config.toml;
    };

    services.udiskie = {
      enable = true;
      automount = true;
      notify = true;
      tray = "never";
    };
  };
}
