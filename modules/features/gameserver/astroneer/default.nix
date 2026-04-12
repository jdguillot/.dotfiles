{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.gameserver.astroneer;
  stateDir = "/var/lib/astroneer";
  # AstroTuxLauncher runs the Windows binary under Wine; config path uses WindowsServer
  configDir = "${stateDir}/AstroneerServer/Astro/Saved/Config/WindowsServer";
in
{
  options.cyberfighter.features.gameserver.astroneer = {
    enable = lib.mkEnableOption "Astroneer dedicated server via AstroTuxLauncher";

    serverName = lib.mkOption {
      type = lib.types.str;
      default = "Astroneer Server";
      description = "Server name shown in the server browser";
    };

    gamePort = lib.mkOption {
      type = lib.types.port;
      default = 7777;
      description = "Game port (UDP) — must match the playit.gg tunnel's local port";
    };

    maxPlayers = lib.mkOption {
      type = lib.types.ints.between 1 8;
      default = 8;
      description = "Maximum concurrent players (max 8)";
    };

    autoSaveInterval = lib.mkOption {
      type = lib.types.int;
      default = 900;
      description = "Auto-save interval in seconds";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall ports for the game port (UDP)";
    };

    publicIpFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to a file whose contents are the public IP for Playfab registration.
        When set, overrides the launcher's WAN IP auto-detection on every start.
        Intended to be set to a sops secret path containing the playit.gg tunnel IP.
      '';
    };

    serverPasswordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to a file containing the server password.
        When null, the server is passwordless.
        Intended to be set to a sops secret path.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    let
      astroTuxLauncher = pkgs.callPackage ./astrotuxlauncher.nix { };
      mergeConfigPython = pkgs.python3;
      mergeConfigScript = ./merge-config.py;

      astroneerSettingsIni = pkgs.replaceVars ./AstroServerSettings.ini {
        serverName = cfg.serverName;
        maxPlayers = toString cfg.maxPlayers;
        autoSaveInterval = toString cfg.autoSaveInterval;
      };

      engineIni = pkgs.replaceVars ./Engine.ini {
        gamePort = toString cfg.gamePort;
      };
    in
    {
      # AstroTuxLauncher runs the Windows Astroneer server binary under Wine
      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };

      users.users.astroneer = {
        isSystemUser = true;
        group = "astroneer";
        home = stateDir;
        description = "Astroneer dedicated server user";
      };

      users.groups.astroneer = { };

      cyberfighter.features.gameserver.ludusavi = {
        games = [ "Astroneer" ];

        roots = [
          {
            path = stateDir;
            store = "other";
          }
        ];

        customGames = [
          {
            name = "Astroneer";
            integration = "extend";
            installDir = [ "AstroneerServer" ];
            files = [
              "${stateDir}/launcher.toml"
              "<base>/Astro/Saved/Config/WindowsServer"
              "<base>/Astro/Saved/SaveGames"
            ];
          }
        ];
      };

      systemd.services.astroneer-server = {
        description = "Astroneer Dedicated Server via AstroTuxLauncher";
        wantedBy = [ "multi-user.target" ];
        after = [
          "network-online.target"
          "nss-lookup.target"
        ];
        wants = [ "network-online.target" ];

        preStart =
          ''
            mkdir -p "${configDir}"

            # Merge template-managed values into live config files while preserving
            # any extra options the launcher or game may have added at runtime.
            ${mergeConfigPython}/bin/python ${mergeConfigScript} toml ${./launcher.toml} "${stateDir}/launcher.toml"
            ${mergeConfigPython}/bin/python ${mergeConfigScript} ini ${astroneerSettingsIni} "${configDir}/AstroServerSettings.ini"
            ${mergeConfigPython}/bin/python ${mergeConfigScript} ini ${engineIni} "${configDir}/Engine.ini"
            chmod 0644 "${stateDir}/launcher.toml" "${configDir}/AstroServerSettings.ini" "${configDir}/Engine.ini"
          ''
          + lib.optionalString (cfg.publicIpFile != null) ''
            TUNNEL_IP=$(cat ${toString cfg.publicIpFile})
            sed -i "s|^PublicIP=.*|PublicIP=$TUNNEL_IP|" "${configDir}/AstroServerSettings.ini"
          ''
          + lib.optionalString (cfg.serverPasswordFile != null) ''
            SERVER_PASS=$(cat ${toString cfg.serverPasswordFile})
            sed -i "s|^ServerPassword=.*|ServerPassword=$SERVER_PASS|" "${configDir}/AstroServerSettings.ini"
          '';

        serviceConfig = {
          Type = "simple";
          User = "astroneer";
          Group = "astroneer";
          StateDirectory = "astroneer";
          WorkingDirectory = stateDir;
          ExecStart = "${astroTuxLauncher}/bin/AstroTuxLauncher start";
          Restart = "on-failure";
          RestartSec = "30s";
        };

        environment.HOME = stateDir;
      };

      networking.firewall = lib.mkIf cfg.openFirewall {
        allowedUDPPorts = [ cfg.gamePort ];
      };
    }
  );
}
