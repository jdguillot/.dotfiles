# Odysseus -- self-hosted AI workspace. https://github.com/odysseus-dev/odysseus
#
# Docker compose off a pinned source tree (upstream ships no image or release
# tags); a systemd oneshot drives it, so a bad commit never blocks a rebuild.
# Consumes the shared ai.ollama server. Compose also brings up ChromaDB
# (8100), SearXNG (8080; optional, see bundledSearxng) and ntfy (8091).
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.ai.odysseus;
  ollamaCfg = config.cyberfighter.features.ai.ollama;
  searxngCfg = config.cyberfighter.features.searxng;

  # `host.docker.internal` is pinned to host-gateway by upstream's compose.
  usesHostOllama = ollamaCfg.enable && ollamaCfg.exposeToContainers;
  defaultOllamaUrl =
    if usesHostOllama then "http://host.docker.internal:${toString ollamaCfg.port}/v1" else "";

  # Only meaningful once the bundled container is gone.
  defaultSearxngInstance =
    if searxngCfg.enable then "http://host.docker.internal:${toString searxngCfg.port}" else null;

  searxngInstance =
    if cfg.searxngInstance != null then
      cfg.searxngInstance
    else if !cfg.bundledSearxng then
      defaultSearxngInstance
    else
      null;

  env = {
    APP_BIND = cfg.bind;
    APP_PORT = toString cfg.port;
    APP_DATA_DIR = "${cfg.stateDir}/data";
    APP_LOGS_DIR = "${cfg.stateDir}/logs";

    # Model discovery scans this host for serve ports (11434 included), and
    # EMBEDDING_URL defaults to http://$LLM_HOST:11434/v1/embeddings.
    LLM_HOST = cfg.llmHost;
    OLLAMA_BASE_URL = if cfg.ollamaBaseUrl == null then defaultOllamaUrl else cfg.ollamaBaseUrl;

    AUTH_ENABLED = if cfg.auth then "true" else "false";
    LOCALHOST_BYPASS = "false";

    # Read by patches/research-probe-timeout.patch; inert without it.
    ODYSSEUS_RESEARCH_PROBE_TIMEOUT = toString cfg.researchProbeTimeout;

    PUID = toString cfg.puid;
    PGID = toString cfg.pgid;
  }
  // lib.optionalAttrs (cfg.allowedOrigins != [ ]) {
    ALLOWED_ORIGINS = lib.concatStringsSep "," cfg.allowedOrigins;
  }
  // lib.optionalAttrs (searxngInstance != null) {
    SEARXNG_INSTANCE = searxngInstance;
  }
  // cfg.extraEnv;

  envFile = pkgs.writeText "odysseus.env" (
    lib.concatStrings (lib.mapAttrsToList (k: v: "${k}=${v}\n") env)
  );

  # These four exist only to interpolate upstream's ports/volumes; the
  # container has no use for them. Everything else has to reach the process.
  composeOnlyKeys = [
    "APP_BIND"
    "APP_PORT"
    "APP_DATA_DIR"
    "APP_LOGS_DIR"
  ];
  containerEnv = removeAttrs env composeOnlyKeys;

  # Override upstream's compose, never replace it (it bind-mounts out of its
  # own tree). Two things must come from here: the bridge interface name
  # (compose otherwise picks br-<random>, and the ollama firewall hole is
  # per-interface), and the service environment (--env-file only feeds
  # interpolation; re-declaring here is what reaches the container).
  overrideLines = [
    "services:"
    "  odysseus:"
    "    environment:"
  ]
  ++ lib.mapAttrsToList (k: v: "      ${k}: ${builtins.toJSON v}") containerEnv

  # Dropping bundled SearXNG needs BOTH `!override` on depends_on (compose
  # merges it, and odysseus gates on the searxng healthcheck) and `!reset` on
  # the service below. The replacement depends_on is spelled out, so check it
  # against docker-compose.yml when bumping `src`.
  ++ lib.optionals (!cfg.bundledSearxng) [
    "    depends_on: !override"
    "      chromadb:"
    "        condition: service_started"
  ]

  # Traefik routing metadata; inert without a proxy.
  ++ lib.optionals (cfg.labels != { }) (
    [ "    labels:" ] ++ lib.mapAttrsToList (k: v: "      ${k}: ${builtins.toJSON v}") cfg.labels
  )

  # `default` must be restated: naming any network replaces the implicit
  # one, cutting odysseus off from chromadb.
  ++ lib.optionals (cfg.extraNetworks != [ ]) (
    [
      "    networks:"
      "      - default"
    ]
    ++ map (n: "      - ${n}") cfg.extraNetworks
  )

  # Must come after every odysseus-scoped key: this line closes that block.
  ++ lib.optionals (!cfg.bundledSearxng) [ "  searxng: !reset null" ]

  ++ [
    ""
    "networks:"
    "  default:"
    "    driver: bridge"
    "    driver_opts:"
    "      com.docker.network.bridge.name: ${cfg.bridgeName}"
  ]

  # External: whoever owns the network creates it; compose must not race it.
  ++ lib.concatMap (n: [
    "  ${n}:"
    "    external: true"
  ]) cfg.extraNetworks;

  overrideFile = pkgs.writeText "odysseus-compose-override.yaml" (
    lib.concatStringsSep "\n" overrideLines + "\n"
  );

  # On top of `src`, so pointing src at a working clone keeps them.
  patchedSrc =
    if cfg.patches == [ ] then
      cfg.src
    else
      pkgs.applyPatches {
        name = "odysseus-patched-source";
        inherit (cfg) src patches;
      };

  runtimeEnv = "/run/odysseus/env";

  # -p, not the directory basename: the project directory is a store path, so
  # without this every source bump renames the project and orphans its volumes.
  composeArgs = lib.concatStringsSep " " [
    "-p ${cfg.projectName}"
    "-f ${patchedSrc}/docker-compose.yml"
    "-f ${overrideFile}"
    "--project-directory ${patchedSrc}"
    "--env-file ${runtimeEnv}"
  ];

  compose = "${pkgs.docker}/bin/docker compose ${composeArgs}";

  # Matches the unit names `cyberfighter.features.docker.networks` generates.
  networkUnits = map (n: "docker-network-${n}.service") cfg.extraNetworks;

  # Day-2 ops (logs, exec, pull) against the exact same project.
  composeWrapper = pkgs.writeShellScriptBin "odysseus-compose" ''
    exec ${compose} "$@"
  '';

  secretPath = lib.optionalString (
    cfg.secrets.envSecret != null && (config.cyberfighter.features.sops.enable or false)
  ) config.sops.secrets.${cfg.secrets.envSecret}.path;

  # The secret is a dotenv blob, appended so its keys win over the Nix ones.
  writeRuntimeEnv = pkgs.writeShellScript "odysseus-write-env" ''
    set -euo pipefail
    umask 077
    cat ${envFile} > ${runtimeEnv}
    ${lib.optionalString (secretPath != "") ''
      printf '\n' >> ${runtimeEnv}
      cat ${secretPath} >> ${runtimeEnv}
    ''}
  '';
in
{
  options.cyberfighter.features.ai.odysseus = {
    enable = lib.mkEnableOption "Odysseus self-hosted AI workspace";

    src = lib.mkOption {
      type = lib.types.path;
      # `dev` is upstream's default branch, where fixes land first; `main`
      # lags it by months (it shipped a broken mcp dep for six weeks, issue
      # #6209). npins tracks dev but only moves on an explicit
      # `npins update odysseus` -- on bump, re-check which patches upstream
      # has made redundant.
      default = (import ../../../../npins).odysseus;
      defaultText = lib.literalExpression "(import ../../../../npins).odysseus";
      description = ''
        Source tree holding docker-compose.yml and the Dockerfile. The image is
        built from this on first start, so a bump means a rebuild of the image,
        not just a pull. Can point at a working clone instead.
      '';
    };

    patches = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [
        ./patches/research-probe-timeout.patch
        ./patches/no-substring-mode-switch.patch
        ./patches/no-terminus-domain-clamp.patch
        ./patches/mcp-email-imap-maxline.patch
        ./patches/expose-search-emails-tool.patch
      ];
      defaultText = lib.literalExpression "[ ./patches/research-probe-timeout.patch ./patches/no-substring-mode-switch.patch ./patches/no-terminus-domain-clamp.patch ./patches/mcp-email-imap-maxline.patch ./patches/expose-search-emails-tool.patch ]";
      description = ''
        Patches applied to `src` before the image is built. Each one carries its
        upstream issue in a header comment -- drop it when that issue closes.

        research-probe-timeout fixes deep research against a local model:
        upstream probes the endpoint with a hardcoded 15s timeout and no retry,
        which a cold model load loses to, so research fails unless an earlier
        chat happened to warm the model. See `researchProbeTimeout`.

        no-substring-mode-switch stops the UI from silently flipping agent mode
        to chat mode (and persisting it) whenever an error message happens to
        contain "tool" or "auto".

        no-terminus-domain-clamp stops the local-machine heuristic ("from
        <word>" reads as a hostname) from replacing a detected email/calendar
        toolset with the shell/file one.

        mcp-email-imap-maxline mirrors the REST path's imaplib._MAXLINE bump
        into the MCP email server, whose UID SEARCH otherwise dies on large
        mailboxes.

        expose-search-emails-tool gives the MCP email server's search_emails a
        schema, index description, and email-domain slot; upstream wired only
        its security half, so tool selection could never offer it.
      '';
    };

    researchProbeTimeout = lib.mkOption {
      type = lib.types.ints.positive;
      default = 180;
      description = ''
        Seconds deep research waits for its liveness probe, via
        ODYSSEUS_RESEARCH_PROBE_TIMEOUT. Needs the patch of the same name;
        without it upstream's hardcoded 15 applies and this does nothing.

        Size it against a *cold* load of the research model, not a warm one:
        a 30B q4 takes ~40s to page into VRAM here, and a card already busy
        takes longer.
      '';
    };

    projectName = lib.mkOption {
      type = lib.types.str;
      default = "odysseus";
      description = "Compose project name. Owns the named volumes -- changing it abandons the old ones.";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/odysseus";
      description = ''
        Holds data/ (SQLite DB, settings, sessions, uploads, HF cache) and
        logs/. The only thing here a rebuild cannot recreate.
      '';
    };

    bind = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      example = "0.0.0.0";
      description = ''
        Host address the web UI is published on.

        NOT gated by `networking.firewall`: Docker publishes ports with its own
        DNAT rules, which forwarded traffic hits without traversing INPUT.
        This value is the whole access-control story, alongside `auth`.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 7000;
      description = "Host port for the web UI. The container always listens on 7000 internally.";
    };

    auth = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        AUTH_ENABLED. Leave on for anything reachable off loopback. The first
        admin password is printed once, in `journalctl -u odysseus`.
      '';
    };

    allowedOrigins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "http://ryzn-server:7000" ];
      description = ''
        CORS origins. Upstream defaults to localhost only, so reaching the UI
        by hostname needs that origin listed here.
      '';
    };

    ollamaBaseUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "http://host.docker.internal:11434/v1";
      description = ''
        OpenAI-compatible endpoint of the Ollama server, as seen from inside
        the container. Null derives it from `ai.ollama` when that server is
        enabled with `exposeToContainers`.

        The /v1 suffix is required -- the bare root 404s.
      '';
    };

    llmHost = lib.mkOption {
      type = lib.types.str;
      default = "host.docker.internal";
      description = ''
        Host that model discovery and the default embedding endpoint point at.
        Inside a container "localhost" is the container itself, so this is the
        host alias rather than upstream's default.
      '';
    };

    bundledSearxng = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Run the SearXNG container that upstream's compose bundles.

        Upstream offers no switch for this -- the service has no profile and
        odysseus waits on its healthcheck unconditionally -- so turning it off
        is done by overriding both, above.

        Set false when SearXNG is a service in its own right rather than an
        implementation detail of Odysseus. `cyberfighter.features.searxng`
        is the host-native one; with it enabled, `searxngInstance` points here
        by itself. Search then survives an `src` bump or a `systemctl stop
        odysseus`, and its settings live in this repo rather than in upstream's
        source tree plus a named volume.

        Nothing else in the compose project is affected -- ChromaDB and ntfy
        still come up.
      '';
    };

    searxngInstance = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "http://host.docker.internal:8080";
      description = ''
        SEARXNG_INSTANCE -- the search backend, as seen from inside the
        container. No /v1 or other suffix; Odysseus appends /search itself.

        Null derives it from `searxng` when `bundledSearxng` is false, and
        otherwise leaves upstream's `http://searxng:8080` alone.

        This is only the default. Odysseus stores a `search_url` in its own
        settings that wins over this whenever it is non-empty, so the UI can
        repoint search at any provider without a rebuild -- leave that field
        blank to defer to this value.
      '';
    };

    bridgeName = lib.mkOption {
      type = lib.types.str;
      default = "br-odysseus";
      description = ''
        Interface name for the compose network's bridge. Fixed so the Ollama
        firewall hole below has a stable interface to attach to. Max 15 chars.
      '';
    };

    extraNetworks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "web" ];
      description = ''
        Pre-existing docker networks to attach the odysseus container to, in
        addition to the project's own. Each is declared `external: true`, so it
        must already exist -- `cyberfighter.features.docker.networks` creates
        one per boot, and the unit below is ordered after that.

        This is how a reverse proxy on the same host reaches the container by
        its network address rather than through the published host port.
      '';
    };

    labels = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        "traefik.enable" = "true";
        "traefik.http.routers.odysseus.rule" = "Host(`odysseus.example.com`)";
      };
      description = ''
        Docker labels on the odysseus container. Intended for traefik routing;
        see `cyberfighter.features.traefik`, whose docker provider only sees
        containers on its own network with `traefik.enable=true`.
      '';
    };

    puid = lib.mkOption {
      type = lib.types.int;
      default = 1000;
      description = "UID the container drops to, and owner of stateDir. `id -u`.";
    };

    pgid = lib.mkOption {
      type = lib.types.int;
      default = 100;
      description = "GID the container drops to, and group of stateDir. `id -g`.";
    };

    extraEnv = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        COMPANION_BASE_URL = "http://192.168.1.50:7000";
      };
      description = ''
        Extra dotenv keys, merged over the ones set above. Lands in the
        world-readable Nix store -- use `secrets.envSecret` for credentials.
      '';
    };

    secrets = {
      envSecret = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "odysseus-env";
        description = ''
          Key in the SOPS file holding a dotenv blob of API keys, for example:

            odysseus-env: |
              OPENAI_API_KEY=sk-...
              TAVILY_API_KEY=tvly-...

          Appended to the generated env at start, so its keys win. Requires
          `cyberfighter.features.sops.enable`.
        '';
      };

      sopsFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "SOPS file holding the secret. Null uses sops.defaultSopsFile.";
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = config.cyberfighter.features.docker.enable;
            message = "cyberfighter.features.ai.odysseus needs cyberfighter.features.docker.enable = true.";
          }
          {
            assertion = cfg.secrets.envSecret == null || (config.cyberfighter.features.sops.enable or false);
            message = "cyberfighter.features.ai.odysseus: `secrets.envSecret` requires cyberfighter.features.sops.enable = true.";
          }
          {
            assertion = lib.stringLength cfg.bridgeName <= 15;
            message = "cyberfighter.features.ai.odysseus: `bridgeName` must be at most 15 characters (kernel interface name limit).";
          }
          {
            # Both want host 8080; whichever loses the race fails to start.
            assertion = !(cfg.bundledSearxng && searxngCfg.enable && searxngCfg.port == 8080);
            message = ''
              cyberfighter.features.ai.odysseus: the bundled SearXNG publishes
              127.0.0.1:8080, which collides with cyberfighter.features.searxng
              on the same port. Set `bundledSearxng = false` -- running both is
              two copies of the same service -- or move `searxng.port`.
            '';
          }
        ];

        warnings =
          lib.optional (cfg.ollamaBaseUrl == null && defaultOllamaUrl == "") ''
            cyberfighter.features.ai.odysseus: no Ollama endpoint. Either enable
            `ai.ollama` with `exposeToContainers = true`, or set `ollamaBaseUrl`.
            Without one, models have to be added by hand in Settings.
          ''
          ++ lib.optional (!cfg.auth && cfg.bind != "127.0.0.1") ''
            cyberfighter.features.ai.odysseus: `auth = false` with a non-loopback
            bind publishes an unauthenticated workspace with shell and file tools.
          ''
          ++ lib.optional (!cfg.bundledSearxng && searxngInstance == null) ''
            cyberfighter.features.ai.odysseus: `bundledSearxng = false` with no
            search backend. Either enable `searxng`, or set `searxngInstance`.
            Upstream's fallback is http://localhost:8080, which inside the
            container is the container itself, so SearXNG search will fail until
            a `search_url` is set in Settings.
          ''
          ++
            lib.optional
              (!cfg.bundledSearxng && searxngCfg.enable && !(lib.elem cfg.bridgeName searxngCfg.containerBridges))
              ''
                cyberfighter.features.ai.odysseus: `searxng.containerBridges` does
                not list "${cfg.bridgeName}", so the firewall drops this container's
                search requests to the host. Add it there.
              '';

        environment.systemPackages = [ composeWrapper ];

        # Bind-mount targets, owned by the id the container drops to. `+C`
        # because the HF cache under data/ fragments badly under CoW.
        systemd.tmpfiles.rules = [
          "d ${cfg.stateDir} 0750 ${toString cfg.puid} ${toString cfg.pgid} -"
          "h ${cfg.stateDir} - - - - +C"
          "d ${cfg.stateDir}/data 0750 ${toString cfg.puid} ${toString cfg.pgid} -"
          "d ${cfg.stateDir}/logs 0750 ${toString cfg.puid} ${toString cfg.pgid} -"
        ];

        systemd.services.odysseus = {
          description = "Odysseus AI workspace (docker compose)";
          after = [
            "docker.service"
            "docker.socket"
          ]
          ++ networkUnits;
          # Compose fails outright if an external network is missing.
          requires = [ "docker.service" ] ++ networkUnits;
          wantedBy = [ "multi-user.target" ];
          path = [ pkgs.coreutils ];

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            # First start builds the image from source, which is long.
            TimeoutStartSec = "60min";

            RuntimeDirectory = "odysseus";
            RuntimeDirectoryMode = "0700";
            # Kept across restarts so ExecStop still has the env file compose
            # needs for interpolation.
            RuntimeDirectoryPreserve = "yes";

            ExecStartPre = "${writeRuntimeEnv}";
            ExecStart = "${compose} up -d --build --remove-orphans";
            ExecStop = "${compose} down";
          };
        };
      }

      # Compose containers reach the host through their own bridge, so the
      # ollama hole must exist there too.
      (lib.mkIf usesHostOllama {
        networking.firewall.interfaces.${cfg.bridgeName}.allowedTCPPorts = [ ollamaCfg.port ];
      })

      (lib.mkIf (cfg.secrets.envSecret != null && (config.cyberfighter.features.sops.enable or false)) {
        sops.secrets.${cfg.secrets.envSecret} = {
          mode = "0400";
          sopsFile = lib.mkIf (cfg.secrets.sopsFile != null) cfg.secrets.sopsFile;
          # The unit stages the env at start (ExecStartPre), so a secrets-only
          # deploy needs this restart to reach the container.
          restartUnits = [ "odysseus.service" ];
        };
      })
    ]
  );
}
