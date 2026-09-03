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

    containerBridges = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Registry of bridge interface names containers reach the host through.
        Compose modules publish their fixed bridge here; host services with an
        `exposeToContainers` option open their port on every registered bridge.
        Unlike Docker's published ports, container-to-host traffic *does*
        traverse INPUT -- a container using `host.docker.internal` arrives on
        its own bridge, so without a hole there the firewall drops it.
        The default docker0 bridge is always registered.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            # Kernel interface name limit; a longer name is silently invalid.
            assertion = lib.all (b: lib.stringLength b <= 15 && builtins.match "[A-Za-z0-9-]+" b != null) cfg.containerBridges;
            message = "cyberfighter.features.docker.containerBridges entries must be interface names of at most 15 characters.";
          }
        ];

        # Where plain `docker run` containers land.
        cyberfighter.features.docker.containerBridges = [ "docker0" ];

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
