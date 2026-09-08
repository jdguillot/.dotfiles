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
    inputs.vscode-server.nixosModules.default # Optional
  ];

  cyberfighter = {
    system = {
      userDescription = "Jonathan Guillot";
      extraGroups = [ "docker" ];
    };

    nix = {
      enableDevenv = true;
      trustedUsers = [
        "root"
        "cyberfighter"
      ];
    };

    # Dev packages come from `traits = [ "dev" ]` on the host's entry in
    # hosts/default.nix, not from a per-host includeDev line.
    packages = {
      extraPackages = with pkgs; [
        # Add WSL-specific packages
      ];
    };

    features = {
      graphics.enable = true; # For GUI apps
      docker.enable = true;
      tailscale = {
        enable = true;
        # WSL shares one network namespace across all distros, so anything Tailscale
        # programs here breaks networking for every distro. Keep it off the shared stack:
        useRoutingFeatures = "none"; # no subnet/exit-node route programming (table 52)
        acceptRoutes = false; # don't pull others' subnet routes into the shared stack
        acceptDns = true; # manage /etc/resolv.conf here (WSL writes the file, so
                         # tailscaled's writes work); enables MagicDNS + split DNS
        extraUpFlags = [ "--netfilter-mode=off" ]; # don't install iptables/nftables rules
      };

      vscode = {
        enable = true;
        enableServer = true;
        syncSettings = false; # Use VSCode Settings Sync instead
      };
    };
  };

  wsl = {
    enable = true;
    defaultUser = config.cyberfighter.system.username;
    useWindowsDriver = true;
    # Don't let WSL regenerate /etc/resolv.conf — it would wipe the file
    # tailscaled manages for MagicDNS / split DNS.
    wslConf.network.generateResolvConf = false;
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
