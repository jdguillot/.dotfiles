{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.tools.rofi;

  # Demo of rofi's dmenu scriptability: pick a niri style from a menu.
  # niri-style comes from the niri module.
  styleMenu = pkgs.writeShellApplication {
    name = "style-menu";
    runtimeInputs = [ pkgs.rofi ];
    text = ''
      choice=$(
        {
          for f in "$HOME/.config/niri/styles"/*.kdl; do
            echo "niri style: $(basename "$f" .kdl)"
          done
        } | rofi -dmenu -i -p "󰏘 Style"
      ) || true

      case "$choice" in
        "niri style: "*) niri-style "''${choice#niri style: }" ;;
      esac
    '';
  };
in
{
  options.cyberfighter.features.tools.rofi = {
    enable = lib.mkEnableOption "Rofi application launcher";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      rofi
      styleMenu
    ];

    xdg.configFile."rofi/".source = ./rofi-config;

  };
}
