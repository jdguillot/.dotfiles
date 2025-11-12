{ config, lib, pkgs, ... }:

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
        gitmux
      ];
    })

    {
      home.packages = cfg.extraPackages;
    }
  ];
}