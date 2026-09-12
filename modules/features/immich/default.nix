# Immich -- self-hosted photo/video library as a compose project. Two roles:
# `enable` runs the server stack (server, Postgres, Valkey, optional local
# ML container) behind traefik; `mlServer.enable` runs only the machine
# learning container for an Immich elsewhere (GPU host). The compose files,
# hwaccel fragments and system-settings file are native upstream formats
# next to this module; per-host values are @NAME@ placeholders.
#
# Storage model: /data is one NAS export (staging, profile, DB dumps), each
# user's originals are a separate mount bound at /data/library/<label>, and
# thumbnails, encoded video and the database stay on local disk. Immich
# copies across the mount boundary on upload (rename fails with EXDEV, it
# falls back to copy-verify-delete). Docs: https://docs.immich.app/
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.immich;
  traefikCfg = config.cyberfighter.features.traefik;
  sopsEnabled = config.cyberfighter.features.sops.enable or false;

  runtimeEnv = "/run/immich/env";
  etcDir = "/etc/immich";

  localMl = cfg.machineLearning.local;
  mlImageTag = device: cfg.version + lib.optionalString (device != "cpu") "-${device}";

  # The local container is the last resort after every remote URL.
  mlUrls =
    cfg.machineLearning.urls ++ lib.optional localMl.enable "http://immich-machine-learning:3003";

  # Upstream's transcoding fragment names the QSV service `quicksync`, but
  # the ffmpeg setting is `qsv`.
  ffmpegAccel =
    {
      cpu = "disabled";
      quicksync = "qsv";
      vaapi = "vaapi";
      nvenc = "nvenc";
    }
    .${cfg.transcoding};

  composeYaml = pkgs.replaceVars ./compose.yaml {
    VERSION = cfg.version;
    NETWORK = traefikCfg.network;
    DATA_DIR = cfg.dataDir;
    STATE_DIR = cfg.stateDir;
    TZ = config.time.timeZone;
    TRANSCODE_DEVICE = cfg.transcoding;
    SERVER_MEM = cfg.memory.server;
    DB_MEM = cfg.memory.database;
  };

  mlComposeYaml =
    {
      device,
      memory,
      cacheDir,
    }:
    pkgs.replaceVars ./compose-ml.yaml {
      ML_IMAGE_TAG = mlImageTag device;
      ML_DEVICE = device;
      ML_MEM = memory;
      ML_CACHE_DIR = cacheDir;
      ML_MODEL_TTL = toString cfg.machineLearning.modelTtl;
    };

  localMlComposeYaml = mlComposeYaml {
    inherit (localMl) device memory;
    cacheDir = "${cfg.stateDir}/model-cache";
  };
  mlServerComposeYaml = mlComposeYaml {
    inherit (cfg.mlServer) device memory;
    cacheDir = cfg.mlServer.stateDir;
  };

  configYaml = pkgs.replaceVars ./immich-config.yaml {
    PUBLIC_HOST = cfg.publicHost;
    STORAGE_TEMPLATE = cfg.storageTemplate;
    ML_URLS = builtins.toJSON mlUrls;
    OCR_ENABLED = lib.boolToString cfg.machineLearning.ocr;
    FFMPEG_ACCEL = ffmpegAccel;
    FFMPEG_ACCEL_DECODE = lib.boolToString (cfg.transcoding != "cpu");
    FFMPEG_HW_DEVICE = if cfg.transcodingDevice == null then "auto" else cfg.transcodingDevice;
    JOB_CONCURRENCY = builtins.toJSON (
      lib.mapAttrs (_: concurrency: { inherit concurrency; }) cfg.jobConcurrency
    );
  };

  # Compose override adding the per-user library binds; compose merges the
  # volume lists by container path. YAML is a JSON superset.
  librariesOverride = pkgs.writeText "immich-libraries.yaml" (
    builtins.toJSON {
      services.immich-server.volumes = lib.mapAttrsToList (
        label: path: "${path}:/data/library/${label}"
      ) cfg.libraries;
    }
  );

  # Override publishing the ML port for the standalone role.
  mlPublishOverride = pkgs.writeText "immich-ml-publish.yaml" (
    builtins.toJSON {
      services.immich-machine-learning.ports = [
        "${cfg.mlServer.bind}:${toString cfg.mlServer.port}:3003"
      ];
    }
  );

  secretPath = lib.optionalString sopsEnabled config.sops.secrets.${cfg.secrets.envSecret}.path;

  # Staged for compose's --env-file; ${VAR} in compose.yaml interpolates
  # the secrets from it.
  prepare = pkgs.writeShellScript "immich-prepare" ''
    set -euo pipefail
    umask 077
    ${pkgs.coreutils}/bin/install -m 0400 ${secretPath} ${runtimeEnv}
  '';

  # Published ports bypass the NixOS INPUT chain (docker DNATs in
  # PREROUTING), so the client allowlist lives in DOCKER-USER, which docker
  # consults first in FORWARD. --ctorigdstport matches the pre-DNAT port;
  # --ctdir ORIGINAL keeps replies (container -> client) out of the check.
  mlAclChain = "immich-ml-acl";
  mlAclRule = "-p tcp -m conntrack --ctdir ORIGINAL --ctorigdstport ${toString cfg.mlServer.port} -j ${mlAclChain}";
in
{
  options.cyberfighter.features.immich = {
    enable = lib.mkEnableOption "Immich photo library server (docker compose)";

    version = lib.mkOption {
      type = lib.types.str;
      default = "v3.2.0";
      description = ''
        Immich image tag, shared by the server and every ML container so a
        remote ML host renders the same version. Exact tags only: Immich
        ships breaking changes on minor versions and the mobile app tracks
        the server, so bump deliberately with the release notes.
      '';
    };

    publicHost = lib.mkOption {
      type = lib.types.str;
      example = "photos.example.com";
      description = "Hostname traefik routes to the server; also Immich's external domain for share links. The DNS record is yours to create.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      example = "/mnt/immich/data";
      description = ''
        Bound at /data: upload/ (staging), profile/, backups/ (nightly DB
        dumps) and the empty library/ root. Meant to be a NAS mount; the
        unit orders after it via RequiresMountsFor.
      '';
    };

    libraries = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        alice = "/mnt/immich/library/alice";
      };
      description = ''
        Storage label -> host path, bound read-write at
        /data/library/<label>. Set the same label on the Immich user
        (admin UI, "storage label"); the storage template then writes that
        user's originals into their own mount, and a per-export NFS
        `mapall` on the NAS gives the files that user's uid. The label is
        part of every stored path, so it cannot change afterwards.
      '';
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/immich";
      description = "Local disk for postgres/ (unsupported on NFS upstream), thumbs/, encoded-video/ and the ML model cache. Only postgres/ is state a rebuild cannot recreate; the nightly dump in dataDir/backups covers it.";
    };

    storageTemplate = lib.mkOption {
      type = lib.types.str;
      default = "{{y}}/{{y}}-{{MM}}/{{filename}}";
      description = "Path template under library/<label>/ (https://docs.immich.app/administration/storage-template). Changing it later needs the Storage Template Migration job.";
    };

    transcoding = lib.mkOption {
      type = lib.types.enum [
        "cpu"
        "quicksync"
        "vaapi"
        "nvenc"
      ];
      default = "cpu";
      description = "Hardware transcoding backend: a service name from the vendored hwaccel.transcoding.yml. quicksync/vaapi pass /dev/dri; nvenc needs graphics.nvidia.containerToolkit.";
    };

    transcodingDevice = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "renderD128";
      description = ''
        Render node under /dev/dri handed to ffmpeg for quicksync/vaapi.
        Null lets Immich pick, which on a host with more than one GPU is
        the highest-numbered node, not the one with the video driver;
        `ls -l /dev/dri/by-path` maps nodes to PCI devices.
      '';
    };

    jobConcurrency = lib.mkOption {
      type = lib.types.attrsOf lib.types.ints.positive;
      default = { };
      example = {
        metadataExtraction = 2;
        thumbnailGeneration = 2;
      };
      description = "Per-queue worker counts (Immich `job.<queue>.concurrency`) overriding upstream defaults; queues not listed keep theirs. videoConversion above 1 is not supported upstream.";
    };

    machineLearning = {
      urls = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "http://192.168.1.20:3003" ];
        description = "Remote ML servers (an `mlServer` host elsewhere), tried in order; the local container, if enabled, comes after them. Remote ML covers smart search, face detection and OCR; facial recognition always runs in the server.";
      };

      modelTtl = lib.mkOption {
        type = lib.types.int;
        default = 300;
        description = "Seconds an idle ML model stays in memory before unloading (MACHINE_LEARNING_MODEL_TTL), for every ML container this module runs.";
      };

      ocr = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Queue OCR (text-in-image search) jobs to the ML servers. Off skips the queue entirely; existing OCR results stay searchable.";
      };

      local = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Run the ML container next to the server. Off only when every job may fail while the remote servers are down.";
        };

        device = lib.mkOption {
          type = lib.types.enum [
            "cpu"
            "openvino"
            "cuda"
            "rocm"
          ];
          default = "cpu";
          description = "Accelerator: selects the image tag suffix and the service in the vendored hwaccel.ml.yml. openvino passes /dev/dri; cuda needs graphics.nvidia.containerToolkit.";
        };

        memory = lib.mkOption {
          type = lib.types.str;
          default = "3g";
          description = "cgroup memory limit for the local ML container; models load on demand and unload after `modelTtl`.";
        };
      };
    };

    memory = {
      server = lib.mkOption {
        type = lib.types.str;
        default = "2g";
        description = "cgroup memory limit for the server container.";
      };

      database = lib.mkOption {
        type = lib.types.str;
        default = "1g";
        description = "cgroup memory limit for Postgres.";
      };
    };

    secrets = {
      envSecret = lib.mkOption {
        type = lib.types.str;
        default = "immich-env";
        description = "Key in the SOPS file holding a dotenv blob with DB_PASSWORD (A-Za-z0-9 only, per upstream; `openssl rand -hex 32`). Set once: Postgres keeps the password it was initialised with.";
      };

      sopsFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "SOPS file holding the secret. Null uses sops.defaultSopsFile.";
      };
    };

    mlServer = {
      enable = lib.mkEnableOption "standalone Immich machine-learning container for an Immich server on another host";

      device = lib.mkOption {
        type = lib.types.enum [
          "cpu"
          "openvino"
          "cuda"
          "rocm"
        ];
        default = "cuda";
        description = "Accelerator, as for machineLearning.local.device.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 3003;
        description = "Published port; the server lists http://<this host>:<port> in machineLearning.urls.";
      };

      bind = lib.mkOption {
        type = lib.types.str;
        default = "0.0.0.0";
        description = "Address the port is published on. The ML API has no auth: leave the default only together with `allowedClients`.";
      };

      allowedClients = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "192.168.1.10" ];
        description = "Source addresses (or CIDRs) allowed to reach the published port; everything else is dropped in DOCKER-USER. Empty leaves the port open to whatever `bind` exposes.";
      };

      memory = lib.mkOption {
        type = lib.types.str;
        default = "8g";
        description = "cgroup memory limit for the ML container.";
      };

      stateDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/immich-ml";
        description = "Model cache; re-downloaded if lost.";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.enable || cfg.mlServer.enable) {
      assertions = [
        {
          assertion = !(cfg.enable && cfg.mlServer.enable);
          message = "cyberfighter.features.immich: `enable` already runs an ML container for this server; `mlServer` is for a host that serves another Immich.";
        }
        {
          assertion =
            !(
              (cfg.enable && localMl.enable && localMl.device == "cuda")
              || (cfg.enable && cfg.transcoding == "nvenc")
              || (cfg.mlServer.enable && cfg.mlServer.device == "cuda")
            )
            || config.cyberfighter.features.graphics.nvidia.containerToolkit;
          message = "cyberfighter.features.immich: cuda/nvenc need cyberfighter.features.graphics.nvidia.containerToolkit = true (the compose files use CDI).";
        }
      ];

      environment.etc = {
        "immich/hwaccel.ml.yml".source = ./hwaccel.ml.yml;
        "immich/hwaccel.transcoding.yml".source = ./hwaccel.transcoding.yml;
      };
    })

    (lib.mkIf cfg.enable {
      assertions = [
        {
          # The route, the network and the TLS edge all come from traefik.
          assertion = traefikCfg.enable;
          message = "cyberfighter.features.immich needs cyberfighter.features.traefik.enable = true.";
        }
        {
          assertion = sopsEnabled;
          message = "cyberfighter.features.immich: `secrets.envSecret` requires cyberfighter.features.sops.enable = true.";
        }
        {
          assertion = lib.all (l: builtins.match "[A-Za-z0-9_-]+" l != null) (lib.attrNames cfg.libraries);
          message = "cyberfighter.features.immich.libraries: labels must match [A-Za-z0-9_-]+ (they become path components and Immich storage labels).";
        }
      ];

      # Bulk importer for existing archives (Takeout, folders); runs on this
      # host against the mounted libraries.
      environment.systemPackages = [ pkgs.immich-go ];

      # The images chown their data dirs at init; `+C`: the database
      # fragments under CoW.
      systemd.tmpfiles.rules = [
        "d ${cfg.stateDir} 0750 root root -"
        "d ${cfg.stateDir}/postgres 0700 root root -"
        "h ${cfg.stateDir}/postgres - - - - +C"
        "d ${cfg.stateDir}/thumbs 0755 root root -"
        "d ${cfg.stateDir}/encoded-video 0755 root root -"
        "d ${cfg.stateDir}/model-cache 0755 root root -"
      ];

      # Store symlinks resolved at container-create; restartTriggers
      # recreate the containers on a repoint.
      environment.etc = {
        "immich/compose.yaml".source = composeYaml;
        "immich/immich-config.yaml".source = configYaml;
      }
      // lib.optionalAttrs localMl.enable {
        "immich/compose-ml.yaml".source = localMlComposeYaml;
      };

      # Immich carries its own login; basic auth would clobber the app's
      # Authorization header. Mobile backup is a burst of uploads.
      cyberfighter.features.traefik.routes.immich = {
        host = cfg.publicHost;
        service = "immich-server";
        port = 2283;
        auth = "none";
        rateLimit = false;
      };
      cyberfighter.features.traefik.claimedRoutes = [ "immich" ];

      cyberfighter.features.compose.projects.immich = {
        description = "Immich photo library (docker compose)";
        files = [
          "${etcDir}/compose.yaml"
        ]
        ++ lib.optional localMl.enable "${etcDir}/compose-ml.yaml"
        ++ [
          "${librariesOverride}"
          "${traefikCfg.routeLabelFiles.immich}"
        ];
        envFile = runtimeEnv;
        networks = [ traefikCfg.network ];
        inherit prepare;
        runtimeDirectory = "immich";
        # First start pulls four images, the ML one being ~2 GB.
        timeout = "20min";
        restartTriggers = [
          composeYaml
          configYaml
        ];
      };

      # The NAS mounts must be there before compose binds them, and a
      # container must not outlive them; inert for local paths.
      systemd.services.immich.unitConfig.RequiresMountsFor = [
        cfg.dataDir
      ]
      ++ lib.attrValues cfg.libraries;

      sops.secrets.${cfg.secrets.envSecret} = {
        mode = "0400";
        sopsFile = lib.mkIf (cfg.secrets.sopsFile != null) cfg.secrets.sopsFile;
      };
    })

    (lib.mkIf cfg.mlServer.enable {
      assertions = [
        {
          assertion = config.cyberfighter.features.docker.enable;
          message = "cyberfighter.features.immich.mlServer needs cyberfighter.features.docker.enable = true.";
        }
      ];

      systemd.tmpfiles.rules = [
        "d ${cfg.mlServer.stateDir} 0755 root root -"
      ];

      environment.etc."immich/compose-ml.yaml".source = mlServerComposeYaml;

      cyberfighter.features.compose.projects.immich-ml = {
        description = "Immich machine learning server (docker compose)";
        files = [
          "${etcDir}/compose-ml.yaml"
          "${mlPublishOverride}"
        ];
        timeout = "20min";
        restartTriggers = [ mlServerComposeYaml ];
      };

      networking.firewall = lib.mkIf (cfg.mlServer.allowedClients != [ ]) {
        extraCommands = ''
          iptables -N ${mlAclChain} 2>/dev/null || true
          iptables -F ${mlAclChain}
          ${lib.concatMapStringsSep "\n" (
            c: "iptables -A ${mlAclChain} -s ${c} -j RETURN"
          ) cfg.mlServer.allowedClients}
          iptables -A ${mlAclChain} -j DROP
          # Docker creates DOCKER-USER itself later in boot; pre-creating
          # it is fine, docker keeps existing rules.
          iptables -N DOCKER-USER 2>/dev/null || true
          iptables -C DOCKER-USER ${mlAclRule} 2>/dev/null || iptables -I DOCKER-USER ${mlAclRule}
        '';
        extraStopCommands = ''
          iptables -D DOCKER-USER ${mlAclRule} 2>/dev/null || true
          iptables -F ${mlAclChain} 2>/dev/null || true
          iptables -X ${mlAclChain} 2>/dev/null || true
        '';
      };
    })
  ];
}
