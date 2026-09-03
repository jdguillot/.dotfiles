{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.syncthing;
  configDir = "${cfg.dataDir}/.config/syncthing";
  guiPort = lib.last (lib.splitString ":" cfg.guiAddress);
  # Name-style secrets by default; the *File options bypass sops entirely.
  effectiveGuiUserFile =
    if cfg.guiUserFile != null then
      cfg.guiUserFile
    else if cfg.secrets.guiUser != null then
      config.sops.secrets.${cfg.secrets.guiUser}.path
    else
      null;
  effectiveGuiPasswordFile =
    if cfg.guiPasswordFile != null then
      cfg.guiPasswordFile
    else if cfg.secrets.guiPassword != null then
      config.sops.secrets.${cfg.secrets.guiPassword}.path
    else
      null;
  guiAuthConfigured = effectiveGuiUserFile != null && effectiveGuiPasswordFile != null;
in
{
  options.cyberfighter.features.syncthing = {
    enable = lib.mkEnableOption "Syncthing file synchronisation (system service, runs as the main user)";

    user = lib.mkOption {
      type = lib.types.str;
      default = config.cyberfighter.system.username;
      defaultText = lib.literalExpression "config.cyberfighter.system.username";
      description = "User the daemon runs as; synced folders are owned by this user.";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/home/${cfg.user}";
      defaultText = lib.literalExpression ''"/home/''${cfg.user}"'';
      description = "Default parent directory for synced folders.";
    };

    guiAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1:8384";
      description = ''
        Address of the web UI. Binding `0.0.0.0` makes it reachable over
        Tailscale (ts-input accepts before nixos-fw); LAN access additionally
        needs `openGuiFirewall`.
      '';
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open TCP/UDP 22000 (transfers) and UDP 21027 (local discovery).";
    };

    openGuiFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Open the web UI port to the LAN. Requires `guiUserFile` and
        `guiPasswordFile`: the UI is otherwise an unauthenticated admin
        surface for the daemon's user.
      '';
    };

    secrets = {
      guiUser = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "syncthing-username";
        description = "Name of the sops secret holding the GUI username, applied over the REST API at boot; the module declares the secret itself.";
      };

      guiPassword = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "syncthing-password";
        description = "Name of the sops secret holding the GUI password (plaintext; syncthing bcrypts it on save).";
      };
    };

    guiUserFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Escape hatch: explicit path to the GUI username file, bypassing the sops declaration from `secrets.guiUser`.";
    };

    guiPasswordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Escape hatch: explicit path to the GUI password file, bypassing the sops declaration from `secrets.guiPassword`.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.openGuiFirewall || guiAuthConfigured;
        message = "cyberfighter.features.syncthing: refusing to open the GUI to the LAN without GUI credentials (secrets.guiUser/guiPassword or the *File options) -- it is an unauthenticated admin surface for the daemon's user.";
      }
      {
        assertion =
          (cfg.secrets.guiUser == null && cfg.secrets.guiPassword == null)
          || (config.cyberfighter.features.sops.enable or false);
        message = "cyberfighter.features.syncthing.secrets.* need cyberfighter.features.sops.enable = true; set the *File options to bypass sops.";
      }
    ];

    sops.secrets =
      lib.optionalAttrs (cfg.secrets.guiUser != null && cfg.guiUserFile == null) {
        ${cfg.secrets.guiUser}.mode = "0400";
      }
      // lib.optionalAttrs (cfg.secrets.guiPassword != null && cfg.guiPasswordFile == null) {
        ${cfg.secrets.guiPassword}.mode = "0400";
      };

    services.syncthing = {
      enable = true;
      inherit (cfg) user dataDir guiAddress;
      group = "users";
      inherit configDir;
      openDefaultPorts = cfg.openFirewall;
      # Devices/folders are managed from the web UI; don't wipe them on rebuild.
      overrideDevices = false;
      overrideFolders = false;
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openGuiFirewall [
      (lib.toInt guiPort)
    ];

    # Applied via REST (not settings.gui) so the credentials never enter the
    # store; syncthing hashes the plaintext password on save. Root: it must
    # read both the 0400 secrets and the user's config.xml.
    systemd.services.syncthing-gui-auth = lib.mkIf guiAuthConfigured {
      description = "Set Syncthing GUI credentials from secret files";
      after = [ "syncthing-init.service" ];
      wants = [ "syncthing-init.service" ];
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [
        curl
        jq
        gnused
        coreutils
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        key=$(sed -n 's:.*<apikey>\(.*\)</apikey>.*:\1:p' ${configDir}/config.xml)
        for _ in $(seq 30); do
          curl -fsS -H "X-API-Key: $key" \
            "http://127.0.0.1:${guiPort}/rest/system/ping" >/dev/null 2>&1 && break
          sleep 1
        done
        jq -n --rawfile u ${effectiveGuiUserFile} --rawfile p ${effectiveGuiPasswordFile} \
          '{ user: ($u | rtrimstr("\n")), password: ($p | rtrimstr("\n")) }' \
          | curl -fsS -X PATCH -H "X-API-Key: $key" -H 'Content-Type: application/json' \
              -d @- "http://127.0.0.1:${guiPort}/rest/config/gui" >/dev/null
      '';
    };
  };
}
