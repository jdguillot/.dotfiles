{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.gameserver;
in
{
  options.cyberfighter.features.gameserver = {
    enable = lib.mkEnableOption "Game server host infrastructure";

    user = lib.mkOption {
      type = lib.types.str;
      default = "gameserver";
      description = "User account to run game servers as";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "gameserver";
      description = "Group for the game server user";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/srv/gameserver";
      description = "Base directory for game server data";
    };

    astroneer = {
      enable = lib.mkEnableOption "Astroneer dedicated server via AstroTuxLauncher";

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
        users.users.${cfg.user} = {
          isNormalUser = true;
          group = cfg.group;
          home = cfg.dataDir;
          createHome = true;
          description = "Game server user";
        };

        users.groups.${cfg.group} = { };
      }

      (lib.mkIf cfg.astroneer.enable (
        let
          astroTuxLauncher = pkgs.callPackage ./astrotuxlauncher.nix { };

          launcherDir = "${cfg.dataDir}/astroneer-launcher";
          serverDir = "${launcherDir}/AstroneerServer";
          configDir = "${serverDir}/Astro/Saved/Config/LinuxServer";

          launcherToml = pkgs.writeText "launcher.toml" ''
            [launcher]
            AutoUpdateServer = true
            CheckNetwork = true
            OverwritePublicIP = false
            LogDebugMessages = false
            AstroServerPath = "AstroneerServer"
            WinePrefixPath = "winepfx"
            WineBootTimeout = 30
            LogPath = "logs"
            PlayfabAPIInterval = 2
            ServerStatusInterval = 3.0
            DisableEncryption = true

            [launcher.notifications]
            method = ""

            [launcher.status]
            SendStatus = false
            Interval = 120
            EndpointURL = ""
          '';

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

          preStartScript = pkgs.writeShellScript "astroneer-prestart" ''
            mkdir -p "${launcherDir}"
            mkdir -p "${configDir}"
            # Always sync launcher.toml from Nix config so declarative changes take effect on restart
            cp "${launcherToml}" "${launcherDir}/launcher.toml"
            # Only write AstroServerSettings.ini on first boot; the game server manages this file at runtime
            if [ ! -f "${configDir}/AstroServerSettings.ini" ]; then
              cp "${astroneerSettingsIni}" "${configDir}/AstroServerSettings.ini"
            fi
          '';
        in
        {
          # AstroTuxLauncher runs the Windows Astroneer server binary under Wine
          hardware.graphics = {
            enable = true;
            enable32Bit = true;
          };

          environment.systemPackages = [ astroTuxLauncher ];

          systemd.services.astroneer-server = {
            description = "Astroneer Dedicated Server via AstroTuxLauncher";
            wantedBy = [ "multi-user.target" ];
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            serviceConfig = {
              Type = "simple";
              User = cfg.user;
              WorkingDirectory = launcherDir;
              ExecStartPre = "${preStartScript}";
              ExecStart = "${astroTuxLauncher}/bin/AstroTuxLauncher start";
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
        }
      ))
    ]
  );
}
