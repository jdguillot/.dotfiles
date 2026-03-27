{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.docker;
in
{
  options.cyberfighter.features.docker = {
    enable = lib.mkEnableOption "Docker container support";

    rootless = lib.mkEnableOption "Docker rootless mode";

    enableOnBoot = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start Docker daemon on boot";
    };

    networks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Docker networks to create on boot";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        virtualisation.docker = {
          enable = true;
          enableOnBoot = cfg.enableOnBoot;
        };

        environment.systemPackages = with pkgs; [
          dive # look into docker image layers
          docker-compose # start group of containers for dev
          lazydocker
        ];

        systemd.services = lib.mkIf (cfg.networks != []) (
          lib.listToAttrs (map (network: {
            name = "docker-network-${network}";
            value = {
              description = "Create docker network ${network}";
              after = [ "docker.service" ];
              requires = [ "docker.service" ];
              wantedBy = [ "multi-user.target" ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.docker}/bin/docker network inspect ${network} >/dev/null 2>&1 || ${pkgs.docker}/bin/docker network create ${network}'";
              };
            };
          }) cfg.networks)
        );

      }

      (lib.mkIf cfg.rootless {
        virtualisation.docker.rootless = {
          enable = true;
          setSocketVariable = true;
        };
      })
    ]
  );
}
