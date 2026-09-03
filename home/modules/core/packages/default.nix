{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.packages;
in
{
  options.cyberfighter.packages = {
    includeDev = lib.mkOption {
      type = lib.types.bool;
      default = config.cyberfighter.traits.dev;
      defaultText = lib.literalExpression "config.cyberfighter.traits.dev";
      description = "Include development packages. Defaults to the host's dev trait.";
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

    {
      home.packages = cfg.extraPackages;
    }
  ];
}
