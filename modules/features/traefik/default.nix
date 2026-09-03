# Traefik -- TLS-terminating reverse proxy, as a docker compose project (the
# point is the label provider, not services.traefik).
#
# The config is native yaml/toml alongside this module, shared by every host
# that enables it; per-host values are @NAME@ placeholders that replaceVars
# fills from the options below (the build fails on a leftover or unused one),
# and host-specific routes come in through `dynamicFiles`. Beyond rendering,
# the module creates the docker network, stages SOPS secrets into
# /run/traefik, and runs compose up/down as a boot-time oneshot.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.traefik;

  runtimeDir = "/run/traefik";
  tokenPath = "${runtimeDir}/cf-token";
  usersPath = "${runtimeDir}/basic-auth-users";
  dataDir = "/var/lib/traefik";
  dynamicDir = "/etc/traefik/dynamic";

  # Derived from the host name; no per-host label block needed.
  dashboardHost = "${config.networking.hostName}-traefik.${cfg.dnsDomain}";

  # Complete TOML array; elements are validated by the assertion below.
  dnsResolversToml = "[${lib.concatMapStringsSep ", " (r: "\"${r}\"") cfg.dnsResolvers}]";

  # One store path per file, listing exactly the placeholders it contains.
  composeYaml = pkgs.replaceVars ./compose.yaml {
    EMAIL = cfg.email;
    NETWORK = cfg.network;
    DASHBOARD_HOST = dashboardHost;
  };
  traefikToml = pkgs.replaceVars ./traefik.toml {
    EMAIL = cfg.email;
    NETWORK = cfg.network;
    DNS_RESOLVERS = dnsResolversToml;
  };
  middlewaresToml = pkgs.replaceVars ./dynamic/middlewares.toml {
    RATE_LIMIT_AVERAGE = toString cfg.rateLimit.average;
    RATE_LIMIT_BURST = toString cfg.rateLimit.burst;
  };

  # The dynamic mount must be ONE symlink to a directory of REAL files:
  # docker resolves only the top-level mount source, so per-file /etc
  # symlinks (via /etc/static) dangle inside the container -- the file
  # provider then loads nothing, and every route referencing an @file
  # middleware dies to a 404 with the default cert.
  dynamicTree = pkgs.runCommand "traefik-dynamic" { } ''
    mkdir $out
    cp ${middlewaresToml} $out/middlewares.toml
    ${lib.concatStrings (
      lib.mapAttrsToList (name: path: "cp ${path} $out/${lib.escapeShellArg name}
") cfg.dynamicFiles
    )}
  '';

  # Stages credentials at the paths the native files hardcode.
  prepare = pkgs.writeShellScript "traefik-prepare" ''
    set -euo pipefail
    umask 077
    ${pkgs.coreutils}/bin/install -m 0400 ${cfg.tokenFile} ${tokenPath}
    ${pkgs.coreutils}/bin/install -m 0400 ${cfg.basicAuthUsersFile} ${usersPath}
  '';

in
{
  options.cyberfighter.features.traefik = {
    enable = lib.mkEnableOption "Traefik reverse proxy (docker compose)";

    dnsDomain = lib.mkOption {
      type = lib.types.str;
      example = "example.com";
      description = ''
        The DNS zone the proxy routes under. The dashboard hostname is
        derived as `<networking.hostName>-traefik.<dnsDomain>` and rendered
        into compose.yaml.
      '';
    };

    email = lib.mkOption {
      type = lib.types.str;
      example = "admin@example.com";
      description = ''
        The email recorded on the Let's Encrypt ACME account and passed to
        Cloudflare as `CF_API_EMAIL`. Rendered into both compose.yaml and
        traefik.toml.
      '';
    };

    network = lib.mkOption {
      type = lib.types.str;
      default = "web";
      description = ''
        The docker network containers attach to for routing through traefik.
        Created on boot by the docker module, and rendered into
        compose.yaml's external networks block and traefik.toml's
        providers.docker.network, so it is named in one place.
      '';
    };

    dnsResolvers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      # Public recursors on purpose: the split-horizon zone means the LAN
      # resolver knows no _acme-challenge TXT records (see traefik.toml).
      default = [ "1.1.1.1:53" "1.0.0.1:53" ];
      description = ''
        DNS resolvers lego's ACME DNS-01 challenge uses to verify the TXT
        record, as `host` or `host:port`. Rendered into traefik.toml's
        dnsChallenge resolvers.
      '';
    };

    rateLimit = lib.mkOption {
      type = lib.types.submodule {
        options = {
          average = lib.mkOption {
            type = lib.types.ints.unsigned;
            default = 500;
            description = "Requests per second per client IP the proxy tolerates, sustained. 0 disables the limit.";
          };
          burst = lib.mkOption {
            type = lib.types.ints.unsigned;
            default = 500;
            description = "Cap on requests arriving at once; size it above a whole page load, not a single request.";
          };
        };
      };
      default = { };
      description = ''
        The shared `middlewares-rate-limit` middleware every routed chain
        includes, rendered into dynamic/middlewares.toml.
      '';
    };

    dynamicFiles = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = { };
      example = lib.literalExpression ''{ "ollama.toml" = ./traefik/ollama.toml; }'';
      description = ''
        Host-specific file-provider fragments, deployed verbatim (no
        placeholder rendering) to ${dynamicDir}/<name> next to the shared
        middlewares.toml. This is how backends that cannot carry docker
        labels -- native systemd services, other hosts -- get routed. The
        provider only loads `.toml`/`.yml`/`.yaml`; any other suffix deploys
        but stays inert.
      '';
    };

    tokenFile = lib.mkOption {
      type = lib.types.str;
      example = lib.literalExpression ''config.sops.secrets."cloudflare-dns-token".path'';
      description = ''
        Path to a file holding the Cloudflare API token for the DNS-01
        challenge, needing Zone:Read and DNS:Edit on the zone. Staged to
        ${tokenPath} at start, where compose.yaml's CF_*_TOKEN_FILE point.
      '';
    };

    basicAuthUsersFile = lib.mkOption {
      type = lib.types.str;
      example = lib.literalExpression ''config.sops.secrets."traefik-basic-auth".path'';
      description = ''
        htpasswd file backing the `simpleAuth` middleware (and the dashboard).
        Staged to ${usersPath} at start, where dynamic/middlewares.toml's
        `usersFile` points. Generate a line with `htpasswd -nB <user>`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.dnsResolvers != [ ];
        message = "cyberfighter.features.traefik.dnsResolvers must not be empty: the ACME DNS-01 challenge cannot verify against no resolvers.";
      }
      {
        assertion = builtins.match "[a-zA-Z0-9._-]+" cfg.network != null;
        message = "cyberfighter.features.traefik.network must be a docker network name (letters, digits, '.', '_', '-')";
      }
      {
        # Rendered quoted into a toml array; keeps quotes/backslashes out.
        assertion = builtins.all (r: builtins.match "[][A-Za-z0-9.:-]+" r != null) cfg.dnsResolvers;
        message = "cyberfighter.features.traefik.dnsResolvers entries must be `host` or `host:port` (letters, digits, '.', ':', '-', '[', ']')";
      }
      {
        assertion = builtins.all (n: builtins.match "[^/]+" n != null && n != "middlewares.toml") (builtins.attrNames cfg.dynamicFiles);
        message = "cyberfighter.features.traefik.dynamicFiles names must be bare file names, and not middlewares.toml (which the module ships)";
      }
    ];

    # Appends, so a host may declare further networks of its own.
    cyberfighter.features.docker.networks = [ cfg.network ];

    # 0600 or traefik refuses acme.json; losing it re-issues every cert
    # against Let's Encrypt's rate limits.
    systemd.tmpfiles.rules = [
      "d ${dataDir} 0700 root root -"
      "f ${dataDir}/acme.json 0600 root root -"
    ];

    # Docker resolves these symlinks at container-create time, and
    # restartTriggers below recreate the container on a repoint. dynamic is
    # deliberately one directory symlink -- see dynamicTree above.
    environment.etc = {
      "traefik/compose.yaml".source = composeYaml;
      "traefik/traefik.toml".source = traefikToml;
      "traefik/dynamic".source = dynamicTree;
    };

    # No firewall rules: docker's DNAT publishes 80/443 past the INPUT chain;
    # access control for a routed service is its middlewares.
    cyberfighter.features.compose.projects.traefik = {
      description = "Traefik reverse proxy (docker compose)";
      files = [ "/etc/traefik/compose.yaml" ];
      networks = [ cfg.network ];
      inherit prepare;
      runtimeDirectory = "traefik";
      # The restart also refreshes the bind mounts.
      restartTriggers = [
        composeYaml
        traefikToml
        dynamicTree
      ];
    };
  };
}
