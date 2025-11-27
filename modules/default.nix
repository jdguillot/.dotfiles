{
  inputs,
  ...
}:
{
  imports = [
    ./core/profiles
    ./core/system
    ./core/users
    ./core/nix-settings

    ./features/desktop
    ./features/sound
    ./features/fonts
    ./features/networking
    ./features/printing
    ./features/ssh
    ./features/sops
    ./features/graphics
    ./features/docker
    ./features/tailscale
    ./features/flatpak
    ./features/packages
    ./features/filesystems
    ./features/bluetooth
    ./features/gaming
    ./features/vscode
    ./features/vpn
    ./features/security
    ./features/wine/default.nix

    inputs.nix-flatpak.nixosModules.nix-flatpak
  ];
}
