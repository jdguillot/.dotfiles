{ config, lib, pkgs, ... }:
let
  cfg = config.services.playit;
  playitPkg = pkgs.callPackage ./playit-agent.nix { };
in
{
  options.services.playit = {
    enable = lib.mkEnableOption "playit.gg tunnel agent";

    package = lib.mkOption {
      type = lib.types.package;
      default = playitPkg;
      description = "playit-cli package to use";
    };

    secretPath = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to the TOML file containing the playit.gg agent secret.
        When null, the playit-cli binary is installed but the service is not started.
        Run `playit-cli claim` to obtain the secret, then set this to the encrypted path.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    systemd.services.playit = lib.mkIf (cfg.secretPath != null) {
      description = "playit.gg agent";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];

      environment.SECRET_PATH = "%d/secret";

      serviceConfig = {
        ExecStart = ''${lib.getExe cfg.package} --stdout --secret_wait --secret_path "''${SECRET_PATH}" start'';
        Restart = "on-failure";
        StateDirectory = "playit";
        LoadCredential = [ "secret:${cfg.secretPath}" ];

        DynamicUser = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        NoNewPrivileges = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
        ];
        CapabilityBoundingSet = [ ];
      };
    };
  };
}
