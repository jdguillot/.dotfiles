# SearXNG -- self-hosted metasearch, run natively rather than in a container.
#
# A first-class service: a search engine in its own right AND the backend
# Odysseus queries (its bundled instance dies with the compose project; see
# ai.odysseus.bundledSearxng). One server, many clients, exposure scoped by
# who must reach it -- same shape as ai.ollama. Outside features/ai/ because
# the AI stack is just one client.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.searxng;
  odysseusCfg = config.cyberfighter.features.ai.odysseus;

  # Loopback unless something off-box must reach it; a container can never
  # use the host's loopback.
  listenHost = if (cfg.openFirewall || cfg.containerBridges != [ ]) then "0.0.0.0" else cfg.listen;

  # Not in the world-readable store: this key signs session cookies.
  generatedSecretFile = "/var/lib/searxng/secret-key.env";
  secretFile = if cfg.secretKeyFile != null then cfg.secretKeyFile else generatedSecretFile;

  baseSettings = {
    # Merge over upstream's settings.yml; the engine list is not ours to keep.
    use_default_settings = true;

    server = {
      bind_address = listenHost;
      inherit (cfg) port;
      # Expanded by envsubst in searx-init.service, out of `secretFile`.
      secret_key = "$SEARXNG_SECRET_KEY";
      limiter = cfg.limiter;
    }
    // lib.optionalAttrs (cfg.baseUrl != null) { base_url = cfg.baseUrl; };

    # json is what makes this an API; without it programmatic clients
    # (Odysseus included) get bare 403s.
    search.formats = [ "html" ] ++ lib.optional cfg.jsonApi "json";
  };
in
{
  options.cyberfighter.features.searxng = {
    enable = lib.mkEnableOption "SearXNG metasearch engine";

    package = lib.mkPackageOption pkgs "searxng" { };

    listen = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Bind address, when `openFirewall` is false and `containerBridges` is empty.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = ''
        Listen port. Both the web UI and, with `jsonApi`, the JSON search API
        are served here.

        Note the clash: Odysseus' bundled SearXNG publishes 127.0.0.1:8080. Set
        `ai.odysseus.bundledSearxng = false` -- which is the point of running
        this -- or move this port.
      '';
    };

    baseUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "http://ryzn-server:8080/";
      description = ''
        Absolute URL the instance is reached at (`server.base_url`).

        Worth setting for anything beyond loopback: it is what SearXNG stamps
        into the OpenSearch descriptor -- the thing that makes "add to browser
        search engines" work -- and into image-proxy links. Left null, those
        come out pointing at localhost and only work on the host itself.
      '';
    };

    jsonApi = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Serve `search.formats = [html, json]`.

        Required by every programmatic client, `ai.odysseus` included. Turning
        it off is the failure that looks like a broken search engine: the UI
        keeps working and API callers get 403 with no useful error.
      '';
    };

    limiter = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Rate limiting and bot detection (`server.limiter`), which pulls in a
        local Redis via `services.searx.redisCreateLocally`.

        Off by default, and deliberately so on a LAN instance: the bot
        detection is built to stop scrapers hitting a *public* instance, and it
        does not distinguish them from your own API clients. Enabling it
        without adding those clients to the limiter's pass list is the usual
        way JSON search starts returning 429 to Odysseus.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Open `port` to the whole LAN, and bind 0.0.0.0.

        SearXNG has no authentication. On a trusted LAN that is the normal way
        to run it; do not carry this to a network you do not control.
      '';
    };

    containerBridges = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = lib.optional odysseusCfg.enable odysseusCfg.bridgeName;
      defaultText = lib.literalExpression "the ai.odysseus compose bridge, when that is enabled";
      example = [ "docker0" ];
      description = ''
        Bridges to open `port` on, for containerised clients. Non-empty binds
        0.0.0.0.

        Unlike Docker's published ports, this direction *does* traverse INPUT:
        a container reaching the host through `host.docker.internal` arrives on
        its own compose bridge, so without a hole there the connection is
        dropped by the firewall. Same rule `ai.ollama.exposeToContainers`
        follows, for the same reason.
      '';
    };

    secretKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/secrets/searxng-secret-key";
      description = ''
        Environment file defining `SEARXNG_SECRET_KEY`, substituted into
        `server.secret_key`. Point this at a SOPS secret to make the key part
        of the deployment.

        Null generates one on first start under ${generatedSecretFile} and
        reuses it thereafter. That is fine for a single host -- the key only
        signs session cookies -- but it is host-local state, so a rebuilt
        machine gets a new one.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      example = {
        general.instance_name = "search";
        ui.default_theme = "simple";
      };
      description = ''
        Extra SearXNG settings, merged recursively over the ones set above.
        Passed through to `services.searx.settings`.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        services.searx = {
          enable = true;
          inherit (cfg) package openFirewall;

          # Built-in server; upstream calls uWSGI unnecessary below public
          # scale. Tradeoff: it logs every query.
          configureUwsgi = false;

          redisCreateLocally = cfg.limiter;
          environmentFile = secretFile;

          settings = lib.recursiveUpdate baseSettings cfg.settings;
        };
      }

      (lib.mkIf (cfg.containerBridges != [ ]) {
        networking.firewall.interfaces = lib.genAttrs cfg.containerBridges (_: {
          allowedTCPPorts = [ cfg.port ];
        });
      })

      # Must exist before searx-init.service reads it as an EnvironmentFile.
      (lib.mkIf (cfg.secretKeyFile == null) {
        systemd.services.searxng-secret-key = {
          description = "Generate the SearXNG secret key";
          before = [ "searx-init.service" ];
          requiredBy = [ "searx-init.service" ];

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            UMask = "0077";
            StateDirectory = "searxng";
            StateDirectoryMode = "0700";
          };

          script = ''
            if [ ! -s ${generatedSecretFile} ]; then
              printf 'SEARXNG_SECRET_KEY=%s\n' \
                "$(${pkgs.coreutils}/bin/head -c 48 /dev/urandom | ${pkgs.coreutils}/bin/base64 -w0)" \
                > ${generatedSecretFile}
            fi
          '';
        };
      })
    ]
  );
}
