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

        snapshot = {
          dir = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "/var/lib/immich";
            description = ''
              The project's state directory, snapshotted read-only before
              every start into `<dir>.snapshots/<timestamp>`. The step runs
              after `down`, so the data is quiescent, and it is the manual
              rollback for an image bump whose migration went wrong. Must
              be a btrfs subvolume: declare it with a `v` tmpfiles rule,
              and on a host where it already exists as a directory, convert
              it once with the unit stopped. Elsewhere the step logs and
              takes nothing.
            '';
          };

          days = lib.mkOption {
            type = lib.types.ints.positive;
            default = 14;
            description = "Snapshots older than this are deleted when a new one is taken. By the timestamp in the name: a snapshot's own mtime is the source's, not the time it was taken.";
          };
        };
      };
    };

  # Read-only snapshot of the state subvolume, before `up` and after the
  # previous `down`. Unconditional and time-expired rather than keyed on
  # "did the images change": no detection logic, and a few reboots cannot
  # push the pre-upgrade snapshot out. A snapshot of unchanged data costs
  # nothing. Non-fatal (`-` in ExecStartPre): a snapshot that cannot be
  # taken is logged, not a reason to keep the service down.
  snapshotScript =
    name: p:
    pkgs.writeShellScript "${name}-snapshot" ''
      set -euo pipefail
      dir=${lib.escapeShellArg p.snapshot.dir}
      snaps="$dir.snapshots"
      mkdir -p "$snaps"
      if ! btrfs subvolume show "$dir" >/dev/null 2>&1; then
        echo "${name}: $dir is not a btrfs subvolume; no snapshot taken" >&2
        exit 0
      fi
      btrfs subvolume snapshot -r "$dir" "$snaps/$(date -u +%Y%m%d-%H%M%S)"
      cutoff=$(date -u -d "${toString p.snapshot.days} days ago" +%Y%m%d-%H%M%S)
      for s in "$snaps"/*/; do
        s="''${s%/}"
        [ -e "$s" ] || continue
        [ "$(basename "$s")" \< "$cutoff" ] || continue
        btrfs subvolume delete "$s"
      done
    '';
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
        # Bounded: a project that is actually broken still lands in `failed`
        # instead of rebuilding every 30s forever.
        startLimitIntervalSec = 600;
        startLimitBurst = 5;
        after = [
          "docker.service"
          "docker.socket"
        ]
        ++ networkUnits;
        requires = [ "docker.service" ] ++ networkUnits;
        # Containers carry `restart: "no"`, so docker never starts a project
        # behind systemd's back -- ExecStartPre always wins the race to stage
        # secrets. PartOf is what then brings projects back with the daemon:
        # Requires propagates stop, not restart.
        partOf = [ "docker.service" ];
        wantedBy = [ "multi-user.target" ];
        path = [
          pkgs.coreutils
          pkgs.btrfs-progs
        ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          TimeoutStartSec = p.timeout;

          # A project that builds or pulls needs a registry, and no ordering
          # edge can express "the internet is up" -- network-online.target
          # only means links are configured. Boot loses that race routinely,
          # and the containers then run under docker's own restart policy
          # while the unit that owns them sits failed. Legal for oneshot:
          # only `always` and `on-success` are rejected.
          Restart = "on-failure";
          RestartSec = "30s";

          ExecStart = "${compose} up -d --remove-orphans${
            lib.optionalString (p.extraUpFlags != [ ]) " ${lib.concatStringsSep " " p.extraUpFlags}"
          }";
          ExecStop = "${compose} down";
        }
        // lib.optionalAttrs (p.prepare != null || p.snapshot.dir != null) {
          ExecStartPre =
            lib.optional (p.prepare != null) "${p.prepare}"
            ++ lib.optional (p.snapshot.dir != null) "-${snapshotScript name p}";
        }
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
