{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.helixnotes;
  syncthingCfg = config.cyberfighter.features.syncthing;
  knownDevices = builtins.attrNames config.services.syncthing.settings.devices;
  unknownDevices = lib.subtractLists knownDevices cfg.syncthing.devices;
in
{
  options.cyberfighter.features.helixnotes = {
    enable = lib.mkEnableOption "HelixNotes, a local Markdown notes app";

    package = lib.mkPackageOption pkgs "helixnotes" { };

    syncthing = {
      enable = lib.mkEnableOption ''
        syncing the vault as a declared folder of the Syncthing module
        (`cyberfighter.features.syncthing`), with HelixNotes' per-device
        state ignored
      '';

      path = lib.mkOption {
        type = lib.types.str;
        default = "${syncthingCfg.dataDir}/HelixNotes";
        defaultText = lib.literalExpression ''"''${config.cyberfighter.features.syncthing.dataDir}/HelixNotes"'';
        description = "Vault directory; open this folder as the vault in HelixNotes.";
      };

      id = lib.mkOption {
        type = lib.types.str;
        default = "helixnotes";
        description = "Syncthing folder ID; must be the same on every device sharing the vault.";
      };

      label = lib.mkOption {
        type = lib.types.str;
        default = "HelixNotes";
        description = "Folder label shown in the Syncthing UI.";
      };

      devices = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [
          "phone"
          "ryzn-server"
        ];
        description = ''
          Names of devices in `services.syncthing.settings.devices` to share
          the vault with. Declared, not UI-managed: syncthing-init re-posts
          the folder on every start, replacing shares added in the web UI.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      { environment.systemPackages = [ cfg.package ]; }

      (lib.mkIf cfg.syncthing.enable {
        assertions = [
          {
            assertion = syncthingCfg.enable;
            message = "cyberfighter.features.helixnotes.syncthing needs cyberfighter.features.syncthing.enable = true.";
          }
          {
            assertion = cfg.syncthing.devices != [ ];
            message = "cyberfighter.features.helixnotes.syncthing.devices is empty: a folder shared with no device syncs nothing, and shares added in the web UI are reset on the next syncthing-init run.";
          }
          {
            assertion = unknownDevices == [ ];
            message = "cyberfighter.features.helixnotes.syncthing.devices names devices missing from services.syncthing.settings.devices: ${lib.concatStringsSep ", " unknownDevices}.";
          }
        ];

        services.syncthing.settings.folders.${cfg.syncthing.id} = {
          inherit (cfg.syncthing)
            path
            id
            label
            devices
            ;
          # Applied over REST to the folder, replacing patterns set in the UI.
          ignorePatterns = lib.filter (l: l != "") (lib.splitString "\n" (builtins.readFile ./stignore));
        };

        # Owned by the daemon's user so syncthing and the app can both write it.
        systemd.tmpfiles.rules = [
          "d ${cfg.syncthing.path} 0700 ${syncthingCfg.user} users -"
        ];
      })
    ]
  );
}
