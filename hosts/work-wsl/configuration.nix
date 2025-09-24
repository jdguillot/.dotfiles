# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

# NixOS-WSL specific options are documented on the NixOS-WSL repository:
# https://github.com/nix-community/NixOS-WSL

{ config, lib, pkgs, inputs, ... }:

{
#  imports = [
#     ./docker-desktop-fix.nix
# ];

  nix.extraOptions = ''
    extra-substituters = https://devenv.cachix.org
    extra-trusted-public-keys = devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=
    trusted-users = root jdguillot
    keep-outputs = true
    keep-derivations = true
  '';

  wsl.docker-desktop.enable = true;
  # fix.docker-desktop.enable = false;

  # security.sudo.enable = true;
  # # Allow members of the "wheel" group to sudo:
  # security.sudo.configFile = ''
  #   %wheel ALL=(ALL) ALL
  # '';

  ###### Docker
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
  };
  # virtualisation.docker.rootless = {
  #   enable = true;
  #   setSocketVariable = true;
  # };

  users.defaultUserShell = pkgs.zsh;

  users.users."jdguillot" = {
    extraGroups = [
      "wheel"
      "docker"
    ];
  };

  security.pki.certificateFiles = [ ../../secrets/100-PKROOTCA290-CA.crt  ];


  programs.zsh.enable =true;

  programs.nix-ld = {
    enable = true;
    package = pkgs.nix-ld-rs;
  };

  nixpkgs.config = {
    allowUnfree = true;
  };

  services.vscode-server.enable = true;

  environment.systemPackages = with pkgs; [
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    cifs-utils
    appimage-run
    xclip
    inputs.nixos-conf-editor.packages.${system}.nixos-conf-editor
    grc  
    nodejs
    # wineWowPackages.stable
    nvim-pkg
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "24.05"; # Did you read the comment?
}
