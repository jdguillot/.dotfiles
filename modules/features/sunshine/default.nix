{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.sunshine;
  nvidia = config.cyberfighter.features.graphics.nvidia.enable;

  # Sunshine's Linux NVENC encoder only exists when built with CUDA
  # (SUNSHINE_ENABLE_CUDA); nixpkgs defaults it off, which would leave an
  # NVIDIA host with software x264. Not in the binary cache -- builds locally.
  package = if nvidia then pkgs.sunshine.override { cudaSupport = true; } else pkgs.sunshine;
in
{
  options.cyberfighter.features.sunshine = {
    enable = lib.mkEnableOption "Sunshine game-stream host for Moonlight (native, KMS capture)";

    capture = lib.mkOption {
      type = lib.types.enum [
        "kms"
        "wlr"
        "x11"
        "portal"
        "kwin"
      ];
      default = "kms";
      description = ''
        Capture backend. `kms` reads the DRM framebuffer directly (needs
        CAP_SYS_ADMIN, granted below): no compositor consent dialog, no
        pipewire teardown races, and it can capture the lock screen -- the
        right choice for a headless host with a dummy plug.
      '';
    };

    encoder = lib.mkOption {
      type = lib.types.str;
      default = if nvidia then "nvenc" else "software";
      description = "Video encoder (`nvenc`, `vaapi`, `software`, ...).";
    };

    csrfAllowedOrigins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "https://192.168.1.10:47990" ];
      description = ''
        Extra origins allowed to use the web UI. Sunshine only trusts
        `https://localhost` by default, so browsing to it from another
        machine (LAN IP, hostname, Tailscale) is rejected as CSRF unless the
        exact `https://host:47990` origin is listed here.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open Sunshine's TCP/UDP ports (47984-48010 range) for LAN clients.";
    };

    keepDisplayOn = lib.mkOption {
      type = lib.types.bool;
      default = cfg.capture == "kms";
      defaultText = lib.literalExpression ''cfg.capture == "kms"'';
      description = ''
        Stop Plasma's power management from turning the display off (or
        suspending) when idle. KMS capture reads the scanout framebuffer, so
        a DPMS-off output has no CRTC and every Moonlight launch fails with
        "Failed to initialize video capture/encoding". Ships a system-wide
        `powerdevilrc` default; a per-user `~/.config/powerdevilrc` (written
        by System Settings > Power Management) still overrides it.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.oneOf [
          lib.types.bool
          lib.types.int
          lib.types.str
        ]
      );
      default = { };
      description = ''
        Extra `sunshine.conf` keys. Note the config is declarative: the web
        UI can still pair clients and manage apps, but settings changes made
        there do not persist.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.sunshine = {
      enable = true;
      inherit package;
      inherit (cfg) openFirewall;
      capSysAdmin = true;
      autoStart = true;
      settings = {
        inherit (cfg) capture encoder;
        csrf_allowed_origins = lib.concatStringsSep "," cfg.csrfAllowedOrigins;
      }
      // cfg.settings;
    };

    # hardware.uinput (enabled by services.sunshine) creates the group, but
    # nothing puts the streaming user in it -- without this the virtual
    # mouse/keyboard/gamepads fail with EACCES.
    cyberfighter.system.extraGroups = [ "uinput" ];

    # Plasma 6 powerdevil keys (libpowerdevilcore): the AC profile is the
    # only one that matters on a desktop.
    environment.etc."xdg/powerdevilrc" = lib.mkIf cfg.keepDisplayOn {
      text = ''
        [AC][Display]
        DimDisplayWhenIdle=false
        TurnOffDisplayWhenIdle=false

        [AC][SuspendAndShutdown]
        AutoSuspendAction=0
      '';
    };
  };
}
