{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = [
    ../../modules
    inputs.nixos-wsl.nixosModules.default
    inputs.nix-index-database.nixosModules.nix-index
    inputs.vscode-server.nixosModules.default
  ];

  cyberfighter = {
    system = {
      extraGroups = [ "docker" ];
    };

    nix = {
      enableDevenv = true;
      trustedUsers = [
        "root"
        "jdguillot"
      ];
      # Ensure all nix clients (including sudo) use the work CA bundle
      extraOptions = "ssl-cert-file = /etc/ssl/certs/ca-bundle-with-work.crt";
    };

    packages = {
      extraPackages = with pkgs; [
        moonlight-qt
        nil
        zulu8
        gradle
      ];
    };

    features = {
      graphics = {
        enable = true;
        # nvidia.enable = true;
      };

      flatpak = {
        enable = true;
        browsers = true;
        cad = true;
        extraPackages = [
          "md.obsidian.Obsidian"
        ];
      };

      docker.enable = true;
      tailscale = {
        enable = true;
        # WSL shares one network namespace across all distros, so anything Tailscale
        # programs here breaks networking for every distro. Keep it off the shared
        # stack (routes AND resolv.conf — /etc/resolv.conf is literally an inode at
        # /mnt/wsl/resolv.conf visible from every WSL distro):
        useRoutingFeatures = "none"; # no subnet/exit-node route programming (table 52)
        acceptRoutes = true; # don't pull others' subnet routes into the shared stack
        acceptDns = false; # don't overwrite the shared /etc/resolv.conf
        # (WSL bypasses MagicDNS entirely — nameservers are set here, not via Tailscale)
        extraUpFlags = [ "--netfilter-mode=off" ]; # don't install iptables/nftables rules
        secrets.authKey = "tailscale-authkey";
      };

      vscode.enable = true;

      sops.enable = true;
      ssh.enable = true;
    };
  };

  services.vscode-server.enable = false;

  wsl = {
    enable = true;
    defaultUser = config.cyberfighter.system.username;
    docker-desktop.enable = true;
    useWindowsDriver = true;
    # WSL would otherwise re-point /etc/resolv.conf at /mnt/wsl/resolv.conf at boot,
    # clobbering the NixOS-managed one below.
    wslConf.network.generateResolvConf = false;
    # wslConf.automount.root = "/";
    wslConf.interop.appendWindowsPath = false;
    wslConf.interop.enabled = true; # Ensure Windows interop is enabled
  };

  # Home-lab DNS. In a WSL distro there is no running network manager/dhclient
  # to consume networking.nameservers (NixOS-WSL disables dhcpcd and WSL fixes
  # the netns), so that knob writes nothing — write the file directly instead.
  # /etc/resolv.conf is per-distro, so decoupling it from the shared
  # /mnt/wsl/resolv.conf (which we leave alone) keeps the sibling distro's DNS
  # intact. 192.168.101.1 = lab DNS (ryzn-server, *.cyberfighter.space);
  # 10.255.255.254 = WSL's fixed proxy to the Windows resolver (everything else).
  networking.resolvconf.enable = false; # so this file is ours, and the etc-file assertion passes
  environment.etc."resolv.conf".text = ''
    nameserver 192.168.101.1
    nameserver 10.255.255.254
    search cyberfighter.space
  '';

  sops.secrets."work-ca" = {
    sopsFile = ./100-PKROOTCA290-CA.yaml;
    key = "data";
    mode = "0444";
  };

  # Make nix-daemon use the custom bundle (must run after install-work-ca)
  systemd.services.nix-daemon = {
    after = [ "install-work-ca.service" ];
    requires = [ "install-work-ca.service" ];
    environment.CURL_CA_BUNDLE = lib.mkForce "/etc/ssl/certs/ca-bundle-with-work.crt";
    environment.NIX_SSL_CERT_FILE = lib.mkForce "/etc/ssl/certs/ca-bundle-with-work.crt";
  };

  # Create a systemd service to install the CA certificate after sops decrypts it
  systemd.services.install-work-ca = {
    description = "Install work CA certificate to system bundle";
    wantedBy = [
      "multi-user.target"
      "nix-daemon.service"
    ];
    after = [ "sops-nix.service" ];
    before = [
      "network-online.target"
      "nix-daemon.service"
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      # Wait for the secret to be available
      if [ -f ${config.sops.secrets."work-ca".path} ]; then
        # Create a combined CA bundle
        mkdir -p /etc/ssl/certs
        
        # Combine system CAs with work CA
        cat ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt > /etc/ssl/certs/ca-bundle-with-work.crt
        echo "" >> /etc/ssl/certs/ca-bundle-with-work.crt
        cat ${config.sops.secrets."work-ca".path} >> /etc/ssl/certs/ca-bundle-with-work.crt
        
        chmod 444 /etc/ssl/certs/ca-bundle-with-work.crt
        
        echo "Work CA certificate added to system bundle"
      else
        echo "Warning: Work CA certificate not found"
        exit 1
      fi
    '';
  };

  environment = {

    variables = {
      JAVA_HOME = "${pkgs.zulu8}";
      SSL_CERT_FILE = "/etc/ssl/certs/ca-bundle-with-work.crt";
      NIX_SSL_CERT_FILE = "/etc/ssl/certs/ca-bundle-with-work.crt";
    };

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
