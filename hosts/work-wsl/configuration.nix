# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

# NixOS-WSL specific options are documented on the NixOS-WSL repository:
# https://github.com/nix-community/NixOS-WSL

{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    # ./docker-desktop-fix.nix
    ./flatpak.nix
  ];

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

  security.pki.certificateFiles = [ ../../secrets/100-PKROOTCA290-CA.crt ];

  programs.zsh.enable = true;

  programs.nix-ld = {
    enable = true;
    package = pkgs.nix-ld-rs;
  };

  nixpkgs.config = {
    allowUnfree = true;
  };

  services.vscode-server.enable = true;

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
    extraUpFlags = [ "--accept-routes=true" ];
  };

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
    # nvim-pkg
    vulkan-tools
    vulkan-loader
    lshw
    virtualgl
    moonlight-qt
    nil
  ];

  hardware.graphics = {
    enable = true;
    # extraPackages = with pkgs; [
    #   vulkan-tools
    #   vulkan-loader
    #   vulkan-validation-layers
    # ];
  };

  xdg.portal.enable = true;

  xdg.portal.extraPortals = with pkgs; [
    xdg-desktop-portal-gtk
  ];

  xdg.portal.config.common.default = "*";
  # services.xserver.videoDrivers = ["nvidia"];
  # hardware.nvidia.open = true;

  # environment.sessionVariables = {
  #     CUDA_PATH = "${pkgs.cudatoolkit}";
  #     EXTRA_LDFLAGS = "-L/lib -L${pkgs.linuxPackages.nvidia_x11}/lib";
  #     EXTRA_CCFLAGS = "-I/usr/include";
  #     LD_LIBRARY_PATH = [
  #         "/usr/lib/wsl/lib"
  #         "${pkgs.linuxPackages.nvidia_x11}/lib"
  #         "${pkgs.ncurses5}/lib"
  #         "/run/opengl-driver/lib"
  #     ];
  #     GALLIUM_DRIVER = "d3d12";
  #     MESA_D3D12_DEFAULT_ADAPTER_NAME = "Nvidia";
  # };

  # hardware.nvidia-container-toolkit = {
  #     enable = true;
  #     mount-nvidia-executables = false;
  # };

  # systemd.services = {
  #     nvidia-cdi-generator = {
  #         description = "Generate nvidia cdi";
  #         wantedBy = [ "docker.service" ];
  #         serviceConfig = {
  #         Type = "oneshot";
  #         ExecStart = "${pkgs.nvidia-docker}/bin/nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml --nvidia-ctk-path=${pkgs.nvidia-container-toolkit}/bin/nvidia-ctk";
  #         };
  #     };
  # };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  system.stateVersion = "25.05"; # Did you read the comment?
}
