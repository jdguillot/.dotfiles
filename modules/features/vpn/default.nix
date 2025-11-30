{
  config,
  lib,
  ...
}:

let
  cfg = config.cyberfighter.features.vpn;
in
{
  options.cyberfighter.features.vpn = {
    pia = {
      enable = lib.mkEnableOption "Private Internet Access VPN";

      autoStart = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Automatically start VPN on boot";
      };

      server = lib.mkOption {
        type = lib.types.str;
        default = "us-newjersey.privacy.network";
        description = "PIA server hostname";
      };

      port = lib.mkOption {
        type = lib.types.int;
        default = 1198;
        description = "PIA server port";
      };

      credentialsFile = lib.mkOption {
        type = lib.types.str;
        default = "/run/secrets/pia-credentials";
        description = "Path to PIA credentials file (managed by SOPS)";
      };
    };
  };

  config = lib.mkIf (cfg.pia.enable && builtins.pathExists ../../../secrets/secrets.yaml) {
    assertions = [
      {
        assertion = config.cyberfighter.features.sops.enable or false;
        message = "VPN module requires SOPS to be enabled for managing credentials";
      }
    ];

    sops.secrets.pia-credentials = { };

    services.openvpn.servers.pia = {
      autoStart = cfg.pia.autoStart;

      config = ''
        client
        dev tun
        proto udp
        remote ${cfg.pia.server} ${toString cfg.pia.port}
        resolv-retry infinite
        nobind
        persist-key
        persist-tun
        cipher aes-128-cbc
        auth sha1
        tls-client
        remote-cert-tls server

        auth-user-pass
        compress
        verb 1
        reneg-sec 0

        ca ${./ca.pem}

        disable-occ

        auth-user-pass ${cfg.pia.credentialsFile}
      '';
    };
  };
}
