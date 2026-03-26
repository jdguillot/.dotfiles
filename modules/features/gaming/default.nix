{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.gaming;
in
{
  options.cyberfighter.features.gaming = {
    enable = lib.mkEnableOption "Gaming support with Steam and related tools";

    steam = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Steam";
      };

      remotePlay = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Steam Remote Play";
      };

      localNetworkGameTransfers = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Steam Local Network Game Transfers";
      };

      gamescopeSession = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable gamescope session";
      };
    };

    gamemode = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Feral GameMode for performance optimization";
    };

    mangohud = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable MangoHud for performance overlay";
    };

    protonup = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable ProtonUp-Qt for managing Proton versions";
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional gaming-related packages";
      example = lib.literalExpression "[ pkgs.lutris pkgs.heroic ]";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      programs.steam = lib.mkIf cfg.steam.enable {
        enable = true;
        remotePlay.openFirewall = cfg.steam.remotePlay;
        localNetworkGameTransfers.openFirewall = cfg.steam.localNetworkGameTransfers;
        gamescopeSession.enable = cfg.steam.gamescopeSession;
      };

      programs.gamemode.enable = cfg.gamemode;

      environment.systemPackages = with pkgs;
        (lib.optionals cfg.mangohud [ mangohud ])
        ++ (lib.optionals cfg.protonup [ protonup-ng ])
        ++ cfg.extraPackages;
    }

    (lib.mkIf cfg.steam.enable {
      environment.sessionVariables = {
        STEAM_EXTRA_COMPAT_TOOLS_PATHS = "\${HOME}/.steam/root/compatibilitytools.d";
      };
    })
  ]);
}
