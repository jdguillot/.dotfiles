{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.gameserver;
  ludusaviStateDir = "/var/lib/gameserver-ludusavi";
  ludusaviConfigFile =
    (pkgs.formats.yaml { }).generate "gameserver-ludusavi-config.yaml" {
      manifest.enable = true;
      backup.path = cfg.ludusavi.path;
      restore.path = cfg.ludusavi.path;
      roots = cfg.ludusavi.roots;
      customGames = cfg.ludusavi.customGames;
    };
  ludusaviGamesArgs = lib.escapeShellArgs cfg.ludusavi.games;
in
{
  imports = [
    ./astroneer
    ./playit
  ];

  options.cyberfighter.features.gameserver = {
    enable = lib.mkEnableOption "Game server host infrastructure";

    ludusavi = {
      enable = lib.mkEnableOption "scheduled Ludusavi backups for game servers";

      schedule = lib.mkOption {
        type = lib.types.str;
        default = "*-*-* 00,12:00:00";
        description = "systemd OnCalendar schedule for Ludusavi backups";
      };

      path = lib.mkOption {
        type = lib.types.str;
        default = "${ludusaviStateDir}/backup";
        description = "Directory in which Ludusavi stores game server backups";
      };

      games = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Specific Ludusavi game names to back up; empty means all detected games";
      };

      roots = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [ ];
        description = "Additional Ludusavi root entries to include in the generated config";
      };

      customGames = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [ ];
        description = "Custom Ludusavi game entries to include in the generated config";
      };
    };
  };

  # Gate all sub-modules behind the top-level enable flag
  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.mkIf cfg.ludusavi.enable {
        systemd.services.gameserver-ludusavi-backup = {
          description = "Back up game server saves with Ludusavi";

          preStart = ''
            mkdir -p "${ludusaviStateDir}" "${cfg.ludusavi.path}"
            install -m 0644 ${ludusaviConfigFile} "${ludusaviStateDir}/config.yaml"
          '';

          serviceConfig = {
            Type = "oneshot";
            StateDirectory = "gameserver-ludusavi";
            WorkingDirectory = ludusaviStateDir;
            ExecStart = "${pkgs.ludusavi}/bin/ludusavi --config ${ludusaviStateDir} --no-manifest-update backup --force${lib.optionalString (cfg.ludusavi.games != [ ]) " ${ludusaviGamesArgs}"}";
          };
        };

        systemd.timers.gameserver-ludusavi-backup = {
          description = "Run game server Ludusavi backups on a schedule";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = cfg.ludusavi.schedule;
            Persistent = true;
          };
        };
      })
    ]
  );
}
