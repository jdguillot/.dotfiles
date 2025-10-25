{
  lib,
  inputs,
  ...
}:
{
  imports = [
    ./pkgs.nix
    ./flatpak.nix
    ../optional/graphics.nix
    ../optional/docker.nix
    ../optional/tailscale.nix
    ../optional/flatpak.nix
    inputs.nix-flatpak.nixosModules.nix-flatpak
  ];

  options.cyberfighter.features = {
    flatpak = {
      enable = lib.mkEnableOption "Add Flatpak support and Flathub";
      desktop = lib.mkEnableOption "Add typical Desktop Packages";
      browsers = lib.mkEnableOption "Add typical Browsers";
      cad = lib.mkEnableOption "Add CAD software";
      electronics = lib.mkEnableOption "Add software for electronics";
    };
    docker = {
      enable = lib.mkEnableOption "Docker container support";
      rootless = lib.mkEnableOption "Docker rootless mode";
    };
    tailscale = {
      enable = lib.mkEnableOption "Enable Tailcale with routing";
    };
    graphics = {
      enable = lib.mkEnableOption "Enable Hardware Graphics";
      nvidia = lib.mkEnableOption "Use Nvidia Drivers";
      amd = lib.mkEnableOption "Use AMD Drivers";
    };
  };

}
