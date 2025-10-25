{
  config,
  lib,
  ...
}:

let
  cfg = config.cyberfighter.features.docker;
in
{
  config = lib.mkMerge [
    # Basic Docker setup
    (lib.mkIf cfg.enable {
      virtualisation.docker = {
        enable = true;
        enableOnBoot = true;
      };
    })

    # Rootless Docker (only if both enable and rootless are true)
    (lib.mkIf (cfg.enable && cfg.rootless) {
      virtualisation.docker.rootless = {
        enable = true;
        setSocketVariable = true;
      };
    })
  ];
}
