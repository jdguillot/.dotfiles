{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.tools.rofi;

  # Demo of rofi's dmenu scriptability: pick a niri style or noctalia preset
  # from one menu. niri-style / noctalia-preset come from their own modules.
  styleMenu = pkgs.writeShellApplication {
    name = "style-menu";
    runtimeInputs = [ pkgs.rofi ];
    text = ''
      choice=$(
        {
          for f in "$HOME/.config/niri/styles"/*.kdl; do
            echo "niri style: $(basename "$f" .kdl)"
          done
          noctalia-preset list | sed -n 's/^  /noctalia preset: /p'
        } | rofi -dmenu -i -p "󰏘 Style"
      ) || true

      case "$choice" in
        "niri style: "*) niri-style "''${choice#niri style: }" ;;
        "noctalia preset: "*) noctalia-preset "''${choice#noctalia preset: }" ;;
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
