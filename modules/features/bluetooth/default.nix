{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.bluetooth;
in
{
  options.cyberfighter.features.bluetooth = {
    enable = lib.mkEnableOption "Bluetooth support";

    powerOnBoot = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Power on Bluetooth controller on boot";
    };

    blueman = lib.mkOption {
      type = lib.types.bool;
      default =
        !(
          config.cyberfighter.features.desktop.enable
          && config.cyberfighter.features.desktop.environment == "niri"
        );
      defaultText = lib.literalExpression ''off under features.desktop.environment == "niri"'';
      description = ''
        blueman and its tray applet. Off under niri, where both desktop
        shells drive bluez themselves (DMS's control centre, noctalia's), so
        the applet only adds a redundant tray icon. bluez and bluez-tools are
        installed either way, so bluetoothctl still works.
      '';
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional Bluetooth packages";
      example = lib.literalExpression "[ pkgs.bluez-tools ]";
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.bluetooth = {
      enable = true;
      inherit (cfg) powerOnBoot;
      settings = {
        General = {
          Enable = "Source,Sink,Media,Socket";
          Experimental = true;
        };
      };
    };

    services.blueman.enable = lib.mkDefault cfg.blueman;

    environment.systemPackages =
      with pkgs;
      [
        bluez
        bluez-tools
      ]
      ++ cfg.extraPackages;
  };
}
