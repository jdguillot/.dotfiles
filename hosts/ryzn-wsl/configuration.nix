{
  lib,
  pkgs,
  config,
  hostProfile,
  hostMeta,
  ...
}@inputs:
{
  imports = [
    ../../modules
    inputs.inputs.nixos-wsl.nixosModules.default
    inputs.inputs.nix-index-database.nixosModules.nix-index
  ];

  cyberfighter = {
    profile.enable = hostProfile;

    system = hostMeta.system // {
      extraGroups = [ "docker" ];
    };

    nix = {
      enableDevenv = true;
      trustedUsers = [
        "root"
        "cyberfighter"
      ];
    };

    packages = {
      includeDev = true;
      extraPackages = with pkgs; [
        moonlight-qt
        nil
        zulu8
        gradle
      ];
    };

    features = {
      graphics.enable = true;
      flatpak.enable = true;
      docker.enable = true;
      ssh.enable = true;
      sops.enable = true;
      cachix.enable = true;
    };
  };

  wsl = {
    enable = true;
    defaultUser = "cyberfighter";
    useWindowsDriver = true;
    wslConf.automount.root = "/";
    wslConf.interop.enabled = true; # Ensure Windows interop is enabled
  };

  # Do NOT register WSLInterop (or any binfmt) here: binfmt_misc is kernel-global
  # across all WSL distros. With no registrations, NixOS never starts
  # systemd-binfmt.service, so it can't wipe the shared table on boot/shutdown and
  # WSL's own /init-registered WSLInterop handler keeps working for every distro.

  environment.variables = {
    JAVA_HOME = "${pkgs.zulu8}";
    WAYLAND_DISPLAY = "";
  };

  programs.nix-ld.enable = true;

  xdg = {
    portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
      ];
      config.common.default = "*";
    };
  };
}
