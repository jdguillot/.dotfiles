{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.niri;
  styles = [
    "minimal"
    "rounded"
    "showcase"
  ];
  capitalize = s: lib.toUpper (builtins.substring 0 1 s) + builtins.substring 1 (-1) s;

  # Swap the style-current.kdl symlink and reload niri — no rebuild needed.
  styleScript = pkgs.writeShellApplication {
    name = "niri-style";
    text = ''
      styles_dir="$HOME/.config/niri/styles"
      current="$HOME/.config/niri/style-current.kdl"

      case "''${1:-list}" in
        list|-l|--list)
          echo "Usage: niri-style <name>"
          if [[ -L "$current" ]]; then
            echo "Current: $(basename "$(readlink "$current")" .kdl)"
          fi
          echo "Available styles:"
          for f in "$styles_dir"/*.kdl; do
            basename "$f" .kdl | sed 's/^/  /'
          done
          ;;
        *)
          style="$styles_dir/$1.kdl"
          if [[ ! -e "$style" ]]; then
            echo "Unknown style: $1 (try 'niri-style list')" >&2
            exit 1
          fi
          ln -sf "$style" "$current"
          niri msg action load-config-file || true
          echo "Switched niri style to '$1'."
          ;;
      esac
    '';
  };
in
{
  options.cyberfighter.features.niri = {
    enable = lib.mkEnableOption "Niri compositor config";
    style = lib.mkOption {
      type = lib.types.enum styles;
      default = "rounded";
      description = ''
        Initial visual style variant for niri. Shared config lives in
        base.kdl; the active style is included at runtime from
        ~/.config/niri/style-current.kdl and can be switched without a
        rebuild via the niri-style command (or the launcher entries).
        - minimal: tight gaps, thin solid ring, no shadows (previous look)
        - rounded: rounded corners, shadows, gradient focus ring, snappy springs
        - showcase: bigger gaps, rainbow gradient, blur, translucent terminals
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # niri the compositor is installed at the NixOS level (desktop.environment
    # = "niri"); this module just deploys the user config.
    xdg.configFile = {
      "niri/config.kdl".text = ''
        ${builtins.readFile ./base.kdl}
        // Active visual style, switched at runtime via `niri-style <name>`.
        include "~/.config/niri/style-current.kdl" optional=true
      '';
    }
    // builtins.listToAttrs (
      map (s: {
        name = "niri/styles/${s}.kdl";
        value.source = ./styles + "/${s}.kdl";
      }) styles
    );

    home.packages = [ styleScript ];

    # Seed the style symlink on first activation; runtime choice wins after.
    home.activation.niriStyleDefault = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      current="$HOME/.config/niri/style-current.kdl"
      if [ ! -e "$current" ]; then
        run ln -sf "$HOME/.config/niri/styles/${cfg.style}.kdl" "$current"
      fi
    '';

    # Make styles switchable from the noctalia launcher (Mod+Space).
    xdg.desktopEntries = builtins.listToAttrs (
      map (s: {
        name = "niri-style-${s}";
        value = {
          name = "Niri Style: ${capitalize s}";
          comment = "Switch niri visual style to ${s}";
          exec = "niri-style ${s}";
          icon = "preferences-desktop-theme";
          terminal = false;
          categories = [ "Settings" ];
        };
      }) styles
    );
  };
}
