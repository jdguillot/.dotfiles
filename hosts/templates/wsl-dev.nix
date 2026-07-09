# Template for WSL development environment
{
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
{
  imports = [
    ../../modules
    inputs.nixos-wsl.nixosModules.default
    inputs.nix-index-database.nixosModules.nix-index
    inputs.vscode-server.nixosModules.default  # Optional
  ];

  cyberfighter = {
    profile.enable = "wsl";

    system = {
      hostname = "my-wsl";
      username = "myuser";
      userDescription = "My Full Name";
      stateVersion = "25.05";
      extraGroups = [ "docker" ];
    };

    nix = {
      enableDevenv = true;
      trustedUsers = [ "root" "myuser" ];
    };

    packages = {
      includeDev = true;
      extraPackages = with pkgs; [
        # Add WSL-specific packages
      ];
    };

    features = {
      graphics.enable = true;  # For GUI apps
      docker.enable = true;
      tailscale.enable = true;

      vscode = {
        enable = true;
        enableServer = true;
        syncSettings = false;  # Use VSCode Settings Sync instead
      };
    };
  };

  wsl = {
    enable = true;
    defaultUser = "myuser";
    useWindowsDriver = true;
    wslConf.automount.root = "/";
    wslConf.interop.appendWindowsPath = false;
    wslConf.interop.enabled = true; # Ensure Windows interop is enabled
  };

  # Ensure binfmt_misc is properly set up for .exe files
  boot.binfmt.registrations = lib.mkIf config.wsl.enable {
    WSLInterop = {
      magicOrExtension = "MZ";
      interpreter = "/init";
      preserveArgvZero = false;
    };
  };

  programs.nix-ld.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
    config.common.default = "*";
  };
}
