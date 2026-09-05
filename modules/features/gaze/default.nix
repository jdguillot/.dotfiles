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
      settings = lib.mkIf (cfg.irCamera != null) {
        cameras = {
          ir = cfg.irCamera;
          emitter_enabled = true;
        };
      };
    };

    security.pam.services.dankshell = lib.mkIf cfg.dmsLockScreen {
      gaze.enable = true;
    };
  };
}
