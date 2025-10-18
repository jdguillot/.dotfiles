{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  username = "cyberfighter";
in
{
  imports = [
    ./hardware-configuration.nix
    ./disko-btrfs-config.nix
    ../../modules/global/default.nix
    ../../services/docker/default.nix
    ../../services/tailscale/defualt.nix
    ../../services/flatpak/default.nix
  ];

  nix.extraOptions = ''
    extra-substituters = https://devenv.cachix.org
    extra-trusted-public-keys = devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=
    trusted-users = root ${username}
    keep-outputs = true
    keep-derivations = true
  '';

  # Shell Setup
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  users.users.${username} = {
    extraGroups = [
      "wheel"
      "docker"
    ];
  };

  # https://github.com/nix-community/nix-ld
  programs.nix-ld = {
    enable = true;
    package = pkgs.nix-ld-rs;
  };

  nixpkgs.config = {
    allowUnfree = true;
  };

  xdg.portal.enable = true;

  xdg.portal.extraPortals = with pkgs; [
    xdg-desktop-portal-gtk
  ];

  xdg.portal.config.common.default = "*";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  system.stateVersion = "25.05"; # Did you read the comment?
}
