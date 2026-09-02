# Ollama -- local OpenAI-compatible inference server, and nothing else: the
# agents point their base_url here. One server, many clients. Upstream's
# `services.ollama.acceleration` no longer exists; `acceleration` below
# picks a package variant instead.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.ai.ollama;

  packages = {
    cuda = pkgs.ollama-cuda;
    rocm = pkgs.ollama-rocm;
    vulkan = pkgs.ollama-vulkan;
    cpu = pkgs.ollama-cpu;
  };

  # Off-loopback only for containerised clients; the firewall rule keeps it
  # scoped to the bridge.
  listenHost = if cfg.exposeToContainers then "0.0.0.0" else cfg.host;

  # "user/repo" without a prefix resolves against ollama.com, not HF -- the
  # easy mistake, surfacing only at runtime as "pull model manifest: file
  # does not exist".
  hasRegistryPrefix =
    m: lib.hasPrefix "hf.co/" m || lib.hasPrefix "huggingface.co/" m || !(lib.hasInfix "/" m);
  ambiguousModels = lib.filter (m: !hasRegistryPrefix m) cfg.models;
in
{
  options.cyberfighter.features.ai.ollama = {
    enable = lib.mkEnableOption "Ollama local inference server";

    acceleration = lib.mkOption {
      type = lib.types.enum [
        "cuda"
        "rocm"
        "vulkan"
        "cpu"
      ];
      default = "cuda";
      description = ''
        Hardware backend, selected by package variant.

        NOTE: `ollama-cuda` and `ollama-rocm` are not in cache.nixos.org --
        CUDA/ROCm are unfree, so Hydra does not build them. Without a
        substituter that has them, `nixos-rebuild` compiles Ollama locally.
        `cyberfighter.nix` ships the nixos-cuda cache for exactly this reason.
      '';
    };

    modelsDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/models";
      description = ''
        Where model weights are stored. The module creates this directory owned
        by the service user and, on btrfs, marks it nodatacow -- multi-gigabyte
        GGUF blobs fragment badly under copy-on-write.

        Put it on the fastest disk available: load time is paid on every cold
        session, not once.
      '';
    };

    models = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "qwen3-coder:30b-a3b-q4_K_M"
        "qwen3:4b"
      ];
      description = ''
        Models pulled once `ollama.service` is up, via
        `services.ollama.loadModels`. Tags must be exact -- a floating tag like
        `:30b` can silently change quantisation upstream, which moves your VRAM
        budget under you.
      '';
    };

    derivedModels = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = { };
      example = lib.literalExpression ''{ "team-small" = ./modelfiles/team-small.Modelfile; }'';
      description = ''
        Models created with `ollama create <name> -f <Modelfile>` (native
        format: https://docs.ollama.com/modelfile) once the server and the
        `models` pulls are up. The point is per-model overrides of
        server-wide settings, above all `PARAMETER num_ctx`. FROM a pulled
        model reuses its blobs. With `syncModels`, list derived names in
        `models` too or they are deleted on rebuild.
      '';
    };

    syncModels = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Delete any installed model not listed in `models`. Off by default: it
        makes a rebuild destructive toward anything pulled by hand, and these
        are large and slow to re-fetch.
      '';
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Bind address, when `exposeToContainers` is false.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 11434;
      description = "Listen port. The OpenAI-compatible surface is at /v1 on this port.";
    };

    exposeToContainers = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Bind 0.0.0.0 and open `port` on `containerBridge` only.

        Needed for any client that runs in a container: inside one, 127.0.0.1
        is the container's own loopback, not the host, so a loopback-bound
        server is unreachable no matter what the client config says.

        This is not the same as `networking.firewall.allowedTCPPorts` -- that
        would expose an unauthenticated inference server to the whole LAN.
      '';
    };

    containerBridge = lib.mkOption {
      type = lib.types.str;
      default = "docker0";
      example = "podman0";
      description = "Interface the container firewall hole is opened on.";
    };

    keepAlive = lib.mkOption {
      type = lib.types.str;
      default = "30m";
      example = "-1";
      description = ''
        How long an idle model stays resident (OLLAMA_KEEP_ALIVE). "-1" pins it
        forever, which is right for a headless box and wrong for one that also
        games -- a pinned 20GB model leaves nothing for the GPU's day job.
      '';
    };

    maxLoadedModels = lib.mkOption {
      type = lib.types.ints.positive;
      default = 2;
      description = ''
        Concurrently resident models (OLLAMA_MAX_LOADED_MODELS).

        2 is the useful default when agents use a small auxiliary model for
        side tasks (compression, title generation, tool-call judging): without
        the second slot, every side call evicts the primary model and pays a
        multi-gigabyte reload.
      '';
    };

    numParallel = lib.mkOption {
      type = lib.types.ints.positive;
      default = 1;
      description = ''
        Parallel request slots per model (OLLAMA_NUM_PARALLEL). KV cache scales
        with this, so raising it silently eats the VRAM you budgeted for
        context. Verify with `nvidia-smi` before trusting a higher value.
      '';
    };

    contextLength = lib.mkOption {
      type = lib.types.ints.positive;
      default = 32768;
      example = 65536;
      description = ''
        Context window every model is loaded with (OLLAMA_CONTEXT_LENGTH).
        The default matches upstream's, but set explicitly so it is typed and
        visible instead of an env var you have to remember exists.

        Server-wide, fixed at load time: Ollama never grows it to use spare
        VRAM, and the OpenAI-compatible /v1 endpoint has no way to request
        more per call -- a client sending a longer prompt just gets a 400.
        Models whose architecture supports less are clamped to their own max.

        KV cache cost scales with this times `numParallel`. Overshooting does
        not fail loudly: Ollama silently offloads layers to CPU and tokens/sec
        falls off a cliff. After raising it, check `ollama ps` still reports
        100% GPU for the big models.
      '';
    };

    flashAttention = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable flash attention (OLLAMA_FLASH_ATTENTION). Required for KV cache quantisation.";
    };

    kvCacheType = lib.mkOption {
      type = lib.types.enum [
        "f16"
        "q8_0"
        "q4_0"
      ];
      default = "q8_0";
      description = ''
        KV cache quantisation (OLLAMA_KV_CACHE_TYPE). q8_0 roughly halves cache
        size against f16 for no quality cost worth measuring, which buys back
        context on a card that is already full of weights.
      '';
    };

    groupMembers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "cyberfighter" ];
      example = [ "cyberfighter" ];
      description = ''
        Users added to the `ollama` group, so they can read and manage
        `modelsDir` without sudo.
      '';
    };

    environmentVariables = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Extra environment variables for the service, merged over the ones set above.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion =
              cfg.acceleration != "cuda" || (config.cyberfighter.features.graphics.nvidia.enable or false);
            message = ''
              cyberfighter.features.ai.ollama: acceleration = "cuda" needs
              cyberfighter.features.graphics.nvidia.enable = true, otherwise the
              NVIDIA userspace libraries are absent and Ollama silently falls
              back to CPU.
            '';
          }
          {
            assertion =
              cfg.acceleration != "rocm" || (config.cyberfighter.features.graphics.amd.enable or false);
            message = ''
              cyberfighter.features.ai.ollama: acceleration = "rocm" needs
              cyberfighter.features.graphics.amd.enable = true.
            '';
          }
        ];

        warnings = lib.optional (ambiguousModels != [ ]) ''
          cyberfighter.features.ai.ollama: these entries in `models` have a
          "user/repo" shape but no registry prefix, so Ollama will look them up
          in its own registry rather than on Hugging Face:

            ${lib.concatStringsSep "\n            " ambiguousModels}

          If they came from a Hugging Face URL, prefix them with "hf.co/".
          Note that only conversational LLMs belong here at all -- a diffusion
          text encoder or VAE is valid GGUF that Ollama can never execute.
        '';

        # A bad tag must not roll back the system: upstream pulls via xargs
        # (exit 123) with Restart=on-failure, so one failure would fail
        # activation AND the rollback, deadlocking deploys. 123 = success;
        # the error stays in the journal.
        systemd.services.ollama-model-loader.serviceConfig.SuccessExitStatus = [
          "0"
          "123"
        ];

        services.ollama = {
          enable = true;
          package = packages.${cfg.acceleration};

          # A fixed service user, not the module's DynamicUser default: the
          # model store outlives the unit and has to have a stable owner.
          user = "ollama";
          group = "ollama";

          inherit (cfg) modelsDir port syncModels;
          host = listenHost;
          loadModels = cfg.models;

          environmentVariables = {
            OLLAMA_KEEP_ALIVE = cfg.keepAlive;
            OLLAMA_MAX_LOADED_MODELS = toString cfg.maxLoadedModels;
            OLLAMA_NUM_PARALLEL = toString cfg.numParallel;
            OLLAMA_CONTEXT_LENGTH = toString cfg.contextLength;
            OLLAMA_FLASH_ATTENTION = if cfg.flashAttention then "1" else "0";
            OLLAMA_KV_CACHE_TYPE = cfg.kvCacheType;
          }
          // cfg.environmentVariables;
        };

        # modelsDir is usually its own mount, so own the mountpoint; `+C` is
        # inherited, hence applied while the directory is still empty.
        systemd.tmpfiles.rules = [
          "d ${cfg.modelsDir} 2770 ollama ollama -"
          "h ${cfg.modelsDir} - - - - +C"
        ];
      }

      (lib.mkIf (cfg.derivedModels != { }) {
        systemd.services.ollama-derived-models = {
          description = "Create derived Ollama models from Modelfiles";
          # After the loader so FROM can reference pulled models; a pull
          # failure must not block this unit.
          after = [
            "ollama.service"
            "ollama-model-loader.service"
          ];
          requires = [ "ollama.service" ];
          wantedBy = [ "multi-user.target" ];

          # A Modelfile edit re-runs the creates (replace in place).
          restartTriggers = lib.attrValues cfg.derivedModels;

          environment.OLLAMA_HOST = "127.0.0.1:${toString cfg.port}";
          path = [
            packages.${cfg.acceleration}
            pkgs.coreutils
          ];

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            User = "ollama";
            Group = "ollama";
          };

          # Failures log but never fail the unit: a bad Modelfile must not
          # roll back a deploy (same trade as the loader's SuccessExitStatus).
          script = ''
            for _ in $(seq 60); do
              ollama list >/dev/null 2>&1 && break
              sleep 1
            done
            ${lib.concatStrings (
              lib.mapAttrsToList (name: modelfile: ''
                ollama create ${lib.escapeShellArg name} -f ${modelfile} \
                  || echo "ollama create ${name}: FAILED, see above" >&2
              '') cfg.derivedModels
            )}
          '';
        };
      })

      (lib.mkIf (cfg.groupMembers != [ ]) {
        users.users = lib.genAttrs cfg.groupMembers (_: {
          extraGroups = [ "ollama" ];
        });
      })

      (lib.mkIf cfg.exposeToContainers {
        networking.firewall.interfaces.${cfg.containerBridge}.allowedTCPPorts = [ cfg.port ];
      })
    ]
  );
}
