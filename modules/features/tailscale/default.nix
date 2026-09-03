{
  config,
  lib,
  ...
}:

let
  cfg = config.cyberfighter.features.tailscale;
in
{
  options.cyberfighter.features.tailscale = {
    enable = lib.mkEnableOption "Tailscale VPN";

    useRoutingFeatures = lib.mkOption {
      type = lib.types.str;
      default = "client";
      description = "Tailscale routing features mode";
    };

    acceptRoutes = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Accept routes advertised by other nodes";
    };

    acceptDns = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Let Tailscale manage /etc/resolv.conf (MagicDNS)";
    };

    extraUpFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra flags to pass to tailscale up";
    };

    secrets.authKey = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "tailscale-authkey";
      description = ''
        Name of the sops secret holding a Tailscale auth key; the module
        declares the secret itself. Without an auth key (this or
        authKeyFile), extraUpFlags/acceptRoutes/acceptDns are never applied
        automatically — someone must run `tailscale up` by hand. With one,
        tailscaled-autoconnect runs `tailscale up` with all configured flags
        on boot whenever the node is logged out or stopped.
      '';
    };

    authKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Escape hatch: explicit path to an auth key file, bypassing the sops declaration from `secrets.authKey`.";
    };

    serve = lib.mkOption {
      type = lib.types.submodule {
        options.enable = lib.mkEnableOption "Tailscale serve (expose local services over the tailnet)";
        options.services = lib.mkOption {
          type = lib.types.attrsOf (lib.types.submodule ({
            options.endpoints = lib.mkOption {
              type = lib.types.attrsOf lib.types.str;
              default = { };
              description = ''
                Local port to proxy target, e.g.
                endpoints."tcp:11434" = "tcp://127.0.0.1:11434".
              '';
            };
            options.advertised = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Advertise the service in the tailnet";
            };
          }));
          default = { };
          description = "Services to proxy through Tailscale";
        };
      };
      default = {
        enable = false;
        services = { };
      };
      description = "Tailscale serve options (expose local services over the tailnet)";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.secrets.authKey == null || (config.cyberfighter.features.sops.enable or false);
        message = "cyberfighter.features.tailscale.secrets.authKey needs cyberfighter.features.sops.enable = true; set authKeyFile to bypass sops.";
      }
    ];

    sops.secrets = lib.optionalAttrs (cfg.secrets.authKey != null && cfg.authKeyFile == null) {
      ${cfg.secrets.authKey}.mode = "0400";
    };

    services.tailscale = {
      enable = true;
      useRoutingFeatures = cfg.useRoutingFeatures;
      authKeyFile =
        if cfg.authKeyFile != null then
          cfg.authKeyFile
        else if cfg.secrets.authKey != null then
          config.sops.secrets.${cfg.secrets.authKey}.path
        else
          null;
      extraUpFlags =
        cfg.extraUpFlags
        ++ [
          # Always emitted, both values: prefs persist in tailscaled's state,
          # so omitting a flag leaves a stale pref in place forever. Explicit
          # values make the next `tailscale up` converge on the config.
          "--accept-routes=${lib.boolToString cfg.acceptRoutes}"
          "--accept-dns=${lib.boolToString cfg.acceptDns}"
        ];

      serve = {
        enable = cfg.serve.enable;
        services = cfg.serve.services;
      };
    };

    # Upstream's unit only *orders* after tailscaled-autoconnect (`after` is
    # not a dependency), so a rebuild can run it against a stopped backend and
    # fail. `requires` pulls autoconnect into the transaction -- it is
    # Type=notify and only reports ready once the backend reaches Running --
    # and the retry covers a backend that comes up late.
    systemd.services.tailscale-serve = lib.mkIf cfg.serve.enable {
      requires = [ "tailscaled-autoconnect.service" ];
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
