{
  config,
  lib,
  ...
}:

let
  cfg = config.cyberfighter.features.networking;
in
{
  options.cyberfighter.features.networking = {
    networkmanager = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable NetworkManager";
    };
  };

  config = lib.mkIf cfg.networkmanager {
    networking.networkmanager.enable = true;
  };
}
