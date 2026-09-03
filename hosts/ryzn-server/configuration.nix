# ryzn-server: gaming desktop + local inference host, dual-booting Windows.
{
  inputs,
  lib,
  pkgs,
  config,
  ...
}:
{
  imports = [
    ../../modules
    inputs.nix-index-database.nixosModules.nix-index

    ./hardware-configuration.nix
    ./disk-config.nix
  ];

  cyberfighter = {
    system = {
      userDescription = "Jonathan Guillot";
      extraGroups = [ "docker" ];

      bootloader = {
        efiCanTouchVariables = true;
        # Secure Boot stays on for the Windows dual-boot; implies secureBoot.
        type = "lanzaboote";
      };
    };

    packages = {
      extraPackages = [
        # `hf`, for gated GGUF repos `ollama pull` cannot reach (separate
        # auth): `hf download` then `ollama create -f Modelfile`.
        pkgs.python3Packages.huggingface-hub
        pkgs.mcp-nixos
      ];
    };

    nix.trustedUsers = [
      "root"
      "cyberfighter"
    ];

    features = {
      desktop = {
        environment = "plasma6";
        firefox = true;
      };

      ssh = {
        enable = true;
        passwordAuth = true;
        permitRootLogin = "no";
      };

      graphics = {
        enable = true;
        nvidia = {
          enable = true;
          # Suspend units + NVreg_PreserveVideoMemoryAllocations: without
          # them a resume kills UVM and Ollama silently degrades to CPU.
          # Sleep is also refused outright below.
          powerManagement = true;
        };
      };

      sound.enable = true;
      fonts.enable = true;
      bluetooth.enable = true;

      gaming.enable = true;

      flatpak = {
        enable = true;
        browsers = true;
        extraPackages = [
          "com.discordapp.Discord"
          "com.heroicgameslauncher.hgl"
          "com.moonlight_stream.Moonlight"
        ];
      };

      # Game streaming to Moonlight clients. Native package with KMS capture:
      # no portal consent dialog, so it works unattended (see autoLogin below).
      sunshine = {
        enable = true;
        csrfAllowedOrigins = [
          "https://ryzn-server:47990"
        ];
      };

      # Web UI on the LAN (http://192.168.101.94:8384), login from sops.
      syncthing = {
        enable = true;
        guiAddress = "0.0.0.0:8384";
        openGuiFirewall = true;
        guiUserFile = config.sops.secrets."syncthing-username".path;
        guiPasswordFile = config.sops.secrets."syncthing-password".path;
      };

      # Decrypts secrets/secrets.yaml with the host SSH key. Every
      # config.sops.secrets."..." reference below depends on this.
      sops.enable = true;

      tailscale = {
        enable = true;
        authKeyFile = config.sops.secrets."tailscale-authkey".path;
        acceptRoutes = false;
        extraUpFlags = [
          "--ssh"
          # Control silently drops svc adverts from untagged nodes; the tag
          # needs tagOwners plus a Tailscale SSH rule (not autogroup:self).
          "--advertise-tags=tag:server"
        ];

        # Ollama over the tailnet. Also patches the serve unit, which
        # otherwise races a stopped backend on rebuild.
        serve = {
          enable = true;
          services.ollama = {
            endpoints."tcp:11434" = "tcp://127.0.0.1:11434";
            advertised = true;
          };
        };
      };

      ai.ollama = {
        enable = true;
        acceleration = "cuda";

        # Own SSD subvolume: load time is paid on every cold session.
        modelsDir = "/var/lib/models";

        models = [
          "qwen3.6:27b"
          "qwen3.6:35b"
          # Shared primary (hermes + litellm's team-coder): dense VLM, 256K
          # native. :27b-mtp-q4_K_M is the speculative-decoding variant,
          # worth benchmarking.
          "qwen3.8:27b-q4_K_M"
          # Base of the team-small derived model below.
          "qwen3.5:4b-q4_K_M"
        ];

        # Aux for hermes and litellm's team-small; context-capped so it
        # coexists with the 27B primary (see the Modelfile).
        derivedModels."team-small" = ./modelfiles/team-small.Modelfile;

        # Without a second slot, every auxiliary call evicts the large
        # primary and pays a full reload.
        maxLoadedModels = 2;

        # 32K bounced opencode (exceed_context_size_error). qwen3.5+ KV
        # caches are tiny (~2.1GiB/64K on the 27B), so 256K fits in ~24.4GiB
        # -- but that budgets ONE large model at a time.
        contextLength = 262144;

        # "-1" would pin ~21GB forever and starve Steam. 30m stays warm across
        # an agent session, then hands the card back.
        keepAlive = "30m";

        # Containers cannot reach 127.0.0.1 on the host. Binds 0.0.0.0 but
        # opens the port on docker0 only, never the LAN.
        exposeToContainers = true;

        groupMembers = [ "cyberfighter" ];
      };

      # Team gateway for Ollama: per-user keys and model allowlist
      # (litellm-config.yaml), minted with `litellm-keys`. The hostname is
      # private -- compose interpolates it from the litellm-env dotenv at up
      # time. The DNS-01 token must cover the team zone too.
      ai.litellm = {
        enable = true;
        configFile = ./litellm-config.yaml;
        publicHost = "\${LITELLM_PUBLIC_HOST}";
      };

      ai.hermes = {
        enable = true;

        configFile = ./hermes-config.yaml;

        # Cloud fallback for vision and for anything the local model cannot
        # handle. Dotenv blob in secrets/secrets.yaml.
        secrets.envSecret = "hermes-env";

        addToSystemPackages = true;
        groupMembers = [ "cyberfighter" ];
      };

      # Loopback publish for the openai-api shim; browser access goes through
      # traefik with basic auth. State under /var/lib/comfyui.
      ai.comfyui.server = {
        enable = true;
        publicHost = "comfyui.cyberfighter.space";
      };

      # Checkpoints, reproducible; hashes cross-checked against HF LFS oids.
      ai.comfyui = {
        enable = true;
        user = "cyberfighter";
        group = "users";

        # Needed by the gated text encoder below. Add `hf-token` to
        # secrets/secrets.yaml and declare sops.secrets."hf-token" first.
        # hfTokenFile = config.sops.secrets."hf-token".path;

        models = [
          {
            path = "checkpoints/flux1-schnell-fp8.safetensors";
            url = "https://huggingface.co/Comfy-Org/flux1-schnell/resolve/main/flux1-schnell-fp8.safetensors";
            sha256 = "ead426278b49030e9da5df862994f25ce94ab2ee4df38b556ddddb3db093bf72";
          }
          {
            path = "diffusion_models/flux-2-klein-9b-Q6_K.gguf";
            url = "https://huggingface.co/unsloth/FLUX.2-klein-9B-GGUF/resolve/main/flux-2-klein-9b-Q6_K.gguf";
            sha256 = "1cd667293607431e79c9e7e01ecf5c602bd00539c2c0f49d4817a62998b5fe98";
          }
          {
            path = "diffusion_models/flux1-schnell-Q4_K_S.gguf";
            url = "https://huggingface.co/city96/FLUX.1-schnell-gguf/resolve/main/flux1-schnell-Q4_K_S.gguf";
            sha256 = "4fd16477b3a5296d0cf722c4b92a9fd7f30d09ac7495826e4465d8de9c9fd973";
          }
          {
            # Gated repo -- needs hfTokenFile above.
            path = "text_encoders/flux2-klein-9b-uncensored-q4_k_m.gguf";
            url = "https://huggingface.co/ponpoke/flux2-klein-9b-uncensored-text-encoder/resolve/main/flux2-klein-9b-uncensored-q4_k_m.gguf";
            sha256 = "df33c8bef6f75c00dd282cd9850e2bf40afb363c6bbe464e977b225882550a14";
          }
          {
            path = "vae/flux2-vae.safetensors";
            url = "https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/vae/flux2-vae.safetensors";
            sha256 = "d64f3a68e1cc4f9f4e29b6e0da38a0204fe9a49f2d4053f0ec1fa1ca02f9c4b5";
          }
        ];
      };

      # Image generation for Odysseus through the ComfyUI already here;
      # reachable from the compose bridge only.
      ai.comfyui.openaiApi.enable = true;

      # A service in its own right: LAN at :8080, published by traefik at
      # search.cyberfighter.space, and it survives odysseus restarts --
      # Odysseus points here instead of running its bundled container.
      searxng = {
        enable = true;
        openFirewall = true;
        # Stamped into the OpenSearch descriptor and image-proxy links.
        baseUrl = "https://search.cyberfighter.space/";
      };

      ai.odysseus = {
        enable = true;

        # Use searxng above rather than the bundled container. searxngInstance
        # derives from it; the module opens 8080 on the compose bridge.
        bundledSearxng = false;

        # Loopback only: all access goes through traefik over HTTPS, so the
        # login and session cookie never cross the LAN in cleartext.
        bind = "127.0.0.1";
        allowedOrigins = [
          # LAN URL (split-horizon) and the tunnel-forwarded team URL; the
          # private team values interpolate from the odysseus-env dotenv.
          "https://odysseus.cyberfighter.space"
          "\${ODYSSEUS_TEAM_ORIGIN}"
        ];
        extraEnv.SECURE_COOKIES = "true";

        # ODYSSEUS_TEAM_HOST / ODYSSEUS_TEAM_ORIGIN.
        secrets.envSecret = "odysseus-env";

        # Traefik reaches the container directly over this network.
        extraNetworks = [ "web" ];

        # Rendered from the traefik.routes.odysseus declaration below.
        labels = config.cyberfighter.features.traefik.routeLabels.odysseus;

        # ollamaBaseUrl derives from ai.ollama (exposeToContainers is on).

        # Container drops to this id; stateDir is owned by it.
        puid = 1000;
        pgid = 100;
      };

      # HTTPS in front of the containers: the shared module config rendered
      # from these options; dashboard at ryzn-server-traefik.cyberfighter.space.
      # DNS-01 issuance, but every routed subdomain still needs a DNS record
      # pointing at 192.168.101.94 -- traefik does not create those.
      traefik = {
        enable = true;
        dnsDomain = "cyberfighter.space";
        email = "cyberfighter@gmail.com";
        tokenFile = config.sops.secrets."cloudflare-dns-token".path;
        basicAuthUsersFile = config.sops.secrets."traefik-basic-auth".path;

        routes = {
          # SearXNG runs natively (no labels), so it routes as a file-provider
          # fragment reaching the host. chain-no-auth: the instance is already
          # LAN-open, and basic auth would break adding it as a browser search
          # engine.
          searxng = {
            host = "search.cyberfighter.space";
            port = config.cyberfighter.features.searxng.port;
            auth = "none";
            backend = "host";
          };

          # The LAN URL (split-horizon) and the tunnel-forwarded team URL;
          # each name gets its own DNS-01 cert. chain-no-auth: Odysseus has
          # its own login, no second password prompt. Rendered into the
          # container's labels via ai.odysseus.labels above.
          odysseus = {
            host = "odysseus.cyberfighter.space";
            extraHosts = [ "\${ODYSSEUS_TEAM_HOST}" ];
            port = 7000;
            auth = "none";
            # On two networks -- pin the one traefik connects over.
            network = "web";
          };
        };

        # No raw ollama route: it has no auth. Team access goes through the
        # litellm container's labels; tailscale serve is the personal path.
      };

      # Outbound-only tunnel: the Zero Trust dashboard routes the published
      # hostnames down to traefik :443, with Cloudflare Access in front at
      # the edge. No inbound ports.
      cloudflared = {
        enable = true;
        tokenFile = config.sops.secrets."cloudflared-tunnel-token".path;
      };

      docker = {
        enable = true;
        enableOnBoot = true;
      };

      graphics.nvidia.containerToolkit = true;

    };
  };

  # Not declared by the tailscale module itself -- the host opts in to
  # decrypting this key from the default SOPS file.
  sops.secrets."tailscale-authkey" = { };

  # Traefik's DNS-01 token (Zone:Read + DNS:Edit) and dashboard htpasswd,
  # shared with thkpd-pve1. The unit stages both at start (its restartTriggers
  # only cover config files), so a secrets-only deploy needs this restart.
  sops.secrets."cloudflare-dns-token".restartUnits = [ "traefik.service" ];
  sops.secrets."traefik-basic-auth".restartUnits = [ "traefik.service" ];

  # Tunnel token from the Zero Trust dashboard; runs the connector only,
  # grants no account access. LoadCredential reads it at unit start, so a
  # secrets-only deploy needs this restart.
  sops.secrets."cloudflared-tunnel-token".restartUnits = [ "cloudflared-tunnel.service" ];

  # Syncthing GUI login, applied over its REST API at boot.
  sops.secrets."syncthing-username" = { };
  sops.secrets."syncthing-password" = { };

  virtualisation.waydroid.enable = true; # For Android gaming

  # Never sleep: this box serves the tailnet, and a resume killed UVM once.
  # keepDisplayOn was not enough; refusing here makes logind report
  # CanSuspend=no, so Plasma stops offering the action.
  systemd.sleep.settings.Sleep = {
    AllowSuspend = false;
    AllowHibernation = false;
    AllowHybridSleep = false;
    AllowSuspendThenHibernate = false;
  };

  # Headless (HDMI dummy plug); Sunshine's user unit needs a graphical
  # session, so SDDM auto-logs-in whenever the session starts.
  services.displayManager = {
    autoLogin = {
      enable = true;
      user = config.cyberfighter.system.username;
    };
    defaultSession = "plasma"; # Wayland
  };

  # Session on demand, not at boot: the idle Plasma session holds ~4-5GiB of
  # VRAM the models need. Boot to multi-user (upstream graphical.target has a
  # baked-in Wants=display-manager, so a wantedBy override is not enough);
  # `systemctl start display-manager` brings up Sunshine, `stop` frees VRAM.
  systemd.defaultUnit = lib.mkForce "multi-user.target";

  # --------------------------------------------------------------- storage
  # btrfs mount options are per-filesystem, so per-directory exceptions go on
  # the inode instead: `h` sets chattr flags that new files underneath inherit.
  systemd.tmpfiles.rules = [
    # overlay2 fragments badly under CoW.
    "h /var/lib/docker - - - - +C"

    # Steam library and bulk data, owned by the interactive user.
    "d /mnt/bulk/games 0755 cyberfighter users -"
    "d /mnt/bulk/data 0755 cyberfighter users -"

    # /var/lib/models and the ComfyUI mounts are owned by their modules.

    # Snapshot source and target. btrbk reaches the contents through sudo, so
    # the group bit is only for listing. Not world-readable: these hold /home.
    "d /.snapshots 0750 root btrbk -"
    "d /mnt/bulk/snapshots 0750 root btrbk -"
  ];

  fileSystems = {
    "/mnt/windows" = {
      device = "/dev/disk/by-uuid/10181624181608FC";
      fsType = "ntfs3";
      options = [
        "nofail"
        "uid=1000"
        "gid=100"
        "windows_names"
      ];
    };
    "/mnt/puddlejumper" = {
      device = "/dev/disk/by-uuid/48F82300F822EC3E";
      fsType = "ntfs3";
      options = [
        "nofail"
        "uid=1000"
        "gid=100"
        "windows_names"
      ];
    };
  };

  # Snapshots: /home is the only thing a rebuild cannot recreate (ComfyUI
  # workflows included); everything else comes from git or upstream.
  services.btrbk = {
    # Keeps the nightly send off the disk holding the Steam library.
    ioSchedulingClass = "idle";
    niceness = 19;

    instances.ryzn = {
      onCalendar = "daily";
      settings = {
        timestamp_format = "long";
        snapshot_create = "onchange";

        # Shallow on SSD, deep on HDD (snapshots pin extents). `latest` is
        # the parent of the next incremental send -- load-bearing.
        snapshot_preserve_min = "latest";
        snapshot_preserve = "3d";

        target_preserve_min = "no";
        target_preserve = "14d 8w 6m";

        volume."/" = {
          snapshot_dir = ".snapshots";
          subvolume."home".target = "/mnt/bulk/snapshots";
        };
      };
    };
  };

  # btrfs only reports checksum errors it reads; the HDD sits idle for months.
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [
      "/"
      "/mnt/bulk/data"
    ];
  };

  # Absorbs spikes in RAM; the 16G swapfile stays as last-resort overflow.
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  # Aggressive on purpose: swapping to zram is cheap.
  boot.kernel.sysctl."vm.swappiness" = 180;

  # Windows drives; Fast Startup must stay DISABLED or the dirty NTFS
  # refuses read-write mounts (or corrupts).
  boot.supportedFilesystems.ntfs = true;
}
