{
  config,
  lib,
  pkgs,
  hostProfile,
  ...
}:

let
  cfg = config.cyberfighter.packages;
in
{
  options.cyberfighter.packages = {
    includeDev = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Include development packages";
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Extra packages to install";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.includeDev {
      home.packages = with pkgs; [
        python3
        python3Packages.pip-tools
        gitmux
        lsof
      ];
    })

    (lib.mkIf (hostProfile == "wsl") {
      home.packages = with pkgs; [
        wslu
      ];
    })

    {
      home.packages = cfg.extraPackages;
    }
  ];
}
