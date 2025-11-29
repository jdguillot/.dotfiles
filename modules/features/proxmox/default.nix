{
  config,
  lib,
  proxmox-nixos,
  system,
  ...
}:

let
  cfg = config.cyberfighter.features.proxmox;
in
{
  options.cyberfighter.features.proxmox = {
    enable = lib.mkEnableOption "Proxmox support";

    ipAddress = lib.mkOption {
      type = lib.types.str;
      default = "192.168.0.1";
      description = "IP Address for the Proxmox Host";
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [
      proxmox-nixos.overlays.${system}
    ];

    services.proxmox-ve = {
      enable = true;
      inherit (cfg) ipAddress;
    };
  };

}
