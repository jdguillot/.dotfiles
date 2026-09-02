{
  config,
  lib,
  pkgs,
  inputs,
  hostMeta,
  ...
}:

let
  cfg = config.cyberfighter.features.noctalia;
  inherit (hostMeta.system) username;

  presets = [
    "floating-island"
    "framed-bento"
    "simple-top"
    "wallpaper-colors"
    "catppuccin-static"
  ];

  # Hot-swappable looks for noctalia. Settings stay runtime-managed (a
  # declarative settings.json would become a read-only symlink and break the
  # settings GUI), so presets are merged into the live file with jq instead;
  # noctalia watches settings.json and reloads automatically.
  presetScript = pkgs.writeShellApplication {
    name = "noctalia-preset";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      presets=${./presets}
      settings="$HOME/.config/noctalia/settings.json"

      case "''${1:-list}" in
        list|-l|--list)
          echo "Usage: noctalia-preset <name>"
          echo "Available presets:"
          for f in "$presets"/*.json; do
            basename "$f" .json | sed 's/^/  /'
          done
          ;;
        *)
          preset="$presets/$1.json"
          if [[ ! -f "$preset" ]]; then
            echo "Unknown preset: $1 (try 'noctalia-preset list')" >&2
            exit 1
          fi
          if [[ ! -f "$settings" ]]; then
            echo "No settings file at $settings — is noctalia running?" >&2
            exit 1
          fi
          jq -s '.[0] * .[1]' "$settings" "$preset" > "$settings.tmp"
          mv "$settings.tmp" "$settings"
          echo "Applied preset '$1' — noctalia reloads automatically."
          ;;
      esac
    '';
  };
in
{
  options.cyberfighter.features.noctalia = {
    enable = lib.mkEnableOption "Noctalia Shell Config";
  };

  config = lib.mkIf cfg.enable {
    # configure options
    programs.noctalia-shell = {
      enable = true;
    };
    # settings.json is intentionally NOT managed declaratively; use the
    # noctalia-preset command to switch between looks, or the settings GUI.
    # xdg.configFile."noctalia".source = ./configs;

    home.packages = [ presetScript ];

    # Make presets switchable from the noctalia launcher (Mod+Space).
    xdg.desktopEntries = builtins.listToAttrs (
      map (p: {
        name = "noctalia-preset-${p}";
        value = {
          name = "Noctalia Preset: ${p}";
          comment = "Apply the ${p} noctalia preset";
          exec = "noctalia-preset ${p}";
          icon = "preferences-desktop-theme";
          terminal = false;
          categories = [ "Settings" ];
        };
      }) presets
    );

    services.udiskie = {
      enable = true;
      automount = true;
      notify = true;
      tray = "never";
    };
  };
}
