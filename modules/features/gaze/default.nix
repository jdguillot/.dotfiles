# gaze -- face authentication (github:GunduLabs/gaze). Thin
# `cyberfighter.features.gaze` wrapper around the upstream module
# (`inputs.gaze.nixosModules.gaze`): the gazed daemon, CLI, PAM modules,
# and per-service `security.pam.services.<name>.gaze.*` options all come
# from upstream, which face-auths `sudo` and `polkit-1` by default with
# the password kept as fallback. Further tuning (hybrid policy, liveness
# level, ...) goes through `services.gaze.settings` directly.
{
  config,
  lib,
  inputs,
  ...
}:

let
  cfg = config.cyberfighter.features.gaze;
in
{
  imports = [ inputs.gaze.nixosModules.default ];

  options.cyberfighter.features.gaze = {
    enable = lib.mkEnableOption "Gaze face authentication";

    gui = lib.mkEnableOption "the Gaze GTK4 configuration GUI";

    rgbCamera = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/dev/video0";
      description = ''
        RGB camera node. The upstream default `"primary"` goes through
        PipeWire, which needs a user session to lend the root daemon a
        stream fd -- flaky for enrollment handoff and absent entirely at
        greeters/lock screens. A direct `/dev/video*` node avoids that.
        NOTE: with the upstream default `mutableConfig = true`, the config
        file is seeded once; changing this later needs a matching edit to
        /etc/gaze/config.toml (or set `services.gaze.mutableConfig = false`).
      '';
    };

    irCamera = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "usb:13d3:56d5";
      description = ''
        Infrared camera as `usb:VID:PID` (gaze picks the mono/IR node,
        stable across boots) or a `/dev/video*` path. When set, gaze
        captures RGB+IR hybrid templates and drives the IR emitter itself.
      '';
    };

    dmsLockScreen = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Provide `/etc/pam.d/dankshell` with the gaze rule ahead of the
        standard stack. The DMS lock screen authenticates against that
        service when it exists (falling back to `login` otherwise), so
        this scopes lock-screen face auth without touching `login`.
        Inert on hosts that don't run DMS.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.gaze = {
      enable = true;
      gui.enable = cfg.gui;
      settings.cameras =
        lib.optionalAttrs (cfg.rgbCamera != null) {
          rgb = cfg.rgbCamera;
        }
        // lib.optionalAttrs (cfg.irCamera != null) {
          ir = cfg.irCamera;
          emitter_enabled = true;
        };
    };

    security.pam.services.dankshell = lib.mkIf cfg.dmsLockScreen {
      gaze.enable = true;
    };
  };
}
