{
  config,
  lib,
  ...
}:

let
  cfg = config.cyberfighter.features.docker;
in
{
  options.cyberfighter.features.docker = {
    enable = lib.mkEnableOption "Docker container support";

    rootless = lib.mkEnableOption "Docker rootless mode";

    enableOnBoot = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start Docker daemon on boot";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      virtualisation.docker = {
        enable = true;
        enableOnBoot = cfg.enableOnBoot;
      };
    }

    (lib.mkIf cfg.rootless {
      virtualisation.docker.rootless = {
        enable = true;
        setSocketVariable = true;
      };
    })
  ]);
}
