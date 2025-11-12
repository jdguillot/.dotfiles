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

    services.blueman.enable = lib.mkDefault true;

    environment.systemPackages =
      with pkgs;
      [
        bluez
        bluez-tools
      ]
      ++ cfg.extraPackages;
  };
}
