{
  lib,
  config,
  pkgs,
  hostProfile,
  hostMeta,
  ...
}@inputs:
{
  imports = [
    ../../modules
    inputs.inputs.nixos-wsl.nixosModules.default
    inputs.inputs.nix-index-database.nixosModules.nix-index
    inputs.inputs.vscode-server.nixosModules.default
  ];

  cyberfighter = {
    profile.enable = hostProfile;

    system = hostMeta.system // {
      stateVersion = "25.05";
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
      includeDev = true;
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
      tailscale.enable = true;

      vscode.enable = true;

      sops.enable = true;
      ssh.enable = true;
    };
  };

  services.vscode-server.enable = true;

  wsl = {
    enable = true;
    defaultUser = "jdguillot";
    docker-desktop.enable = true;
    useWindowsDriver = true;
    # wslConf.automount.root = "/";
    wslConf.interop.appendWindowsPath = false;
  };
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
