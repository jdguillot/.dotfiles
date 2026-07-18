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
      tailscale = {
        enable = true;
        # WSL shares one network namespace across all distros, so anything Tailscale
        # programs here breaks networking for every distro. Keep it off the shared stack:
        useRoutingFeatures = "none"; # no subnet/exit-node route programming (table 52)
        acceptRoutes = false; # don't pull others' subnet routes into the shared stack
        acceptDns = false; # don't overwrite the shared /etc/resolv.conf
        extraUpFlags = [ "--netfilter-mode=off" ]; # don't install iptables/nftables rules
      };

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

  # Do NOT register WSLInterop (or any binfmt) here: binfmt_misc is kernel-global
  # across all WSL distros. With no registrations, NixOS never starts
  # systemd-binfmt.service, so it can't wipe the shared table on boot/shutdown and
  # WSL's own /init-registered WSLInterop handler keeps working for every distro.

  programs.nix-ld.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
    config.common.default = "*";
  };
}
