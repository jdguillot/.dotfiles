# Shared scaffolding for docker compose projects run as boot-time systemd
# oneshots. Service modules declare what they run (files, networks, env,
# staging); this module owns the ordering and lifecycle invariants:
# docker.socket in `after` but not `requires`, RuntimeDirectoryPreserve so
# ExecStop still has its staged files at teardown, and a `<name>-compose`
# wrapper for day-2 ops (logs, exec, pull) against the exact same project.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.compose;

  composeCmd =
    name: p:
    lib.concatStringsSep " " (
      [ "${pkgs.docker}/bin/docker compose -p ${p.projectName}" ]
      ++ map (f: "-f ${f}") p.files
      ++ lib.optional (p.projectDirectory != null) "--project-directory ${p.projectDirectory}"
      ++ lib.optional (p.envFile != null) "--env-file ${p.envFile}"
    );

  projectModule =
    { name, ... }:
    {
      options = {
        description = lib.mkOption {
          type = lib.types.str;
          default = "${name} (docker compose)";
          description = "systemd unit description.";
        };

        projectName = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "Compose project name (-p). Explicit so a store-path project directory cannot rename the project and orphan its volumes.";
        };

        files = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          description = "Compose files (-f), in override order. Use /etc paths together with restartTriggers when the rendered file should be editable without a unit rewrite.";
        };

        projectDirectory = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "--project-directory, for projects whose compose file lives in a store path.";
        };

        envFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "--env-file compose interpolates \${VAR} references from; typically a runtime path the prepare script stages secrets into.";
        };

        networks = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "External docker networks the project attaches to; the unit orders after their docker-network-<name>.service units (compose fails outright if an external network is missing).";
        };

        prepare = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "ExecStartPre script, for staging secrets into the runtime directory before compose runs.";
        };

        runtimeDirectory = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "RuntimeDirectory under /run (0700, preserved across stop so ExecStop still sees staged files).";
        };

        timeout = lib.mkOption {
          type = lib.types.str;
          default = "10min";
          description = "TimeoutStartSec; size it to the project's cold-start image pull or build.";
        };

        extraUpFlags = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "--build" ];
          description = "Flags appended to `up -d --remove-orphans`.";
        };

        restartTriggers = lib.mkOption {
          type = lib.types.listOf lib.types.unspecified;
          default = [ ];
          description = "Restart the unit when these change. Needed whenever ExecStart only names /etc paths: without it an edit deploys but never takes effect.";
        };
      };
    };
in
{
  options.cyberfighter.features.compose.projects = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule projectModule);
    default = { };
    description = "Docker compose projects run as boot-time systemd oneshots.";
  };

  config = lib.mkIf (cfg.projects != { }) {
    assertions = [
      {
        assertion = config.cyberfighter.features.docker.enable;
        message = "cyberfighter.features.compose.projects (${lib.concatStringsSep ", " (lib.attrNames cfg.projects)}) needs cyberfighter.features.docker.enable = true.";
      }
    ];

    # Day-2 ops wrappers, one per project.
    environment.systemPackages = lib.mapAttrsToList (
      name: p:
      pkgs.writeShellScriptBin "${name}-compose" ''
        exec ${composeCmd name p} "$@"
      ''
    ) cfg.projects;

    systemd.services = lib.mapAttrs (
      name: p:
      let
        compose = composeCmd name p;
        networkUnits = map (n: "docker-network-${n}.service") p.networks;
      in
      {
        inherit (p) description restartTriggers;
        after = [
          "docker.service"
          "docker.socket"
        ]
        ++ networkUnits;
        requires = [ "docker.service" ] ++ networkUnits;
        wantedBy = [ "multi-user.target" ];
        path = [ pkgs.coreutils ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          TimeoutStartSec = p.timeout;

          ExecStart = "${compose} up -d --remove-orphans${
            lib.optionalString (p.extraUpFlags != [ ]) " ${lib.concatStringsSep " " p.extraUpFlags}"
          }";
          ExecStop = "${compose} down";
        }
        // lib.optionalAttrs (p.prepare != null) { ExecStartPre = "${p.prepare}"; }
        // lib.optionalAttrs (p.runtimeDirectory != null) {
          RuntimeDirectory = p.runtimeDirectory;
          RuntimeDirectoryMode = "0700";
          # ExecStop still needs the staged files at teardown.
          RuntimeDirectoryPreserve = "yes";
        };
      }
    ) cfg.projects;
  };
}
