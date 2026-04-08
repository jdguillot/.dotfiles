{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.gameserver;
  installDir = "${cfg.dataDir}/astroneer";
  configDir = "${installDir}/Astro/Saved/Config/LinuxServer";

  astroneerSettingsIni = pkgs.writeText "AstroServerSettings.ini" ''
    [/Script/Astro.AstroServerSettings]
    MaxServerPlayers=${toString cfg.astroneer.maxPlayers}
    bLoadAutoSave=True
    ActiveSaveFileDescriptiveName=SAVE_1
    ServerName=${cfg.astroneer.serverName}
    ServerPassword=${cfg.astroneer.serverPassword}
    bDisableServerTravel=False
    DenyUnlisted=False
    VerbosePlayerProperties=True
    AutoSaveGameInterval=${toString cfg.astroneer.autoSaveInterval}
    BackupSaveGamesInterval=7200
    ServerGuid=
    ActivePlaylistName=Astro
    bIsCreativeMode=False
    bIsBuildAndSurvive=False
    GamePort=${toString cfg.astroneer.gamePort}
    HeartbeatInterval=55
  '';

  astroneerPreStartScript = pkgs.writeShellScript "astroneer-prestart" ''
    mkdir -p "${configDir}"
    if [ ! -f "${configDir}/AstroServerSettings.ini" ]; then
      cp "${astroneerSettingsIni}" "${configDir}/AstroServerSettings.ini"
    fi
  '';
in
{
  options.cyberfighter.features.gameserver = {
    enable = lib.mkEnableOption "Game server support with SteamCMD";

    user = lib.mkOption {
      type = lib.types.str;
      default = "steam";
      description = "User account to run game servers as";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "steam";
      description = "Group for the game server user";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/steam";
      description = "Base directory for game server data";
    };

    astroneer = {
      enable = lib.mkEnableOption "Astroneer dedicated server";

      serverName = lib.mkOption {
        type = lib.types.str;
        default = "Astroneer Server";
        description = "Display name shown in the server browser";
      };

      gamePort = lib.mkOption {
        type = lib.types.port;
        default = 8777;
        description = "Game port for the Astroneer server (TCP/UDP)";
      };

      queryPort = lib.mkOption {
        type = lib.types.port;
        default = 7777;
        description = "Query/beacon port for the Astroneer server (UDP)";
      };

      maxPlayers = lib.mkOption {
        type = lib.types.ints.between 1 8;
        default = 8;
        description = "Maximum number of concurrent players (max 8)";
      };

      serverPassword = lib.mkOption {
        type = lib.types.str;
        default = "";
        # NOTE: a non-empty password will be world-readable in the Nix store.
        # Use a SOPS secret + activation script to write the config file
        # if a private password is required.
        description = "Server password; leave empty for no password";
      };

      autoSaveInterval = lib.mkOption {
        type = lib.types.int;
        default = 900;
        description = "Auto-save interval in seconds";
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Open firewall ports for the Astroneer server";
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        # SteamCMD requires 32-bit graphics libraries
        hardware.graphics = {
          enable = true;
          enable32Bit = true;
        };

        users.users.${cfg.user} = {
          isNormalUser = true;
          group = cfg.group;
          home = cfg.dataDir;
          createHome = true;
          description = "Steam game server user";
        };

        users.groups.${cfg.group} = { };

        environment.systemPackages = [ pkgs.steamcmd ];
      }

      (lib.mkIf cfg.astroneer.enable {
        # Install/update the Astroneer dedicated server (App ID 728470)
        systemd.services.astroneer-update = {
          description = "Update Astroneer Dedicated Server via SteamCMD";
          wantedBy = [ "multi-user.target" ];
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          before = [ "astroneer-server.service" ];
          serviceConfig = {
            Type = "oneshot";
            User = cfg.user;
            ExecStart = "${pkgs.steamcmd}/bin/steamcmd +login anonymous +force_install_dir ${installDir} +app_update 728470 validate +quit";
            RemainAfterExit = true;
          };
        };

        systemd.services.astroneer-server = {
          description = "Astroneer Dedicated Server";
          wantedBy = [ "multi-user.target" ];
          after = [
            "network-online.target"
            "astroneer-update.service"
          ];
          requires = [ "astroneer-update.service" ];
          serviceConfig = {
            Type = "simple";
            User = cfg.user;
            WorkingDirectory = installDir;
            # Copy default config on first boot; the server may update it at runtime
            ExecStartPre = "${astroneerPreStartScript}";
            ExecStart = "${installDir}/AstroServer.sh -log";
            Restart = "on-failure";
            RestartSec = "30s";
          };
          environment = {
            HOME = cfg.dataDir;
          };
        };

        networking.firewall = lib.mkIf cfg.astroneer.openFirewall {
          allowedTCPPorts = [ cfg.astroneer.gamePort ];
          allowedUDPPorts = [
            cfg.astroneer.gamePort
            cfg.astroneer.queryPort
          ];
        };
      })
    ]
  );
}
