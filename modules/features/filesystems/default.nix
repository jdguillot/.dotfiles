{
  config,
  lib,
  ...
}:

let
  cfg = config.cyberfighter.filesystems;

  mkCifsMount = name: device: {
    device = device;
    fsType = "cifs";
    options =
      let
        automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
      in
      [ "${automount_opts},credentials=${cfg.smbCredentials}" ];
  };
in
{
  options.cyberfighter.filesystems = {
    truenas = {
      enable = lib.mkEnableOption "TrueNAS CIFS mounts";

      server = lib.mkOption {
        type = lib.types.str;
        default = "truenas.cyberfighter.space";
        description = "TrueNAS server hostname";
      };

      mounts = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              share = lib.mkOption {
                type = lib.types.str;
                description = "Share path on the server";
              };
              mountPoint = lib.mkOption {
                type = lib.types.str;
                description = "Local mount point";
              };
            };
          }
        );
        default = { };
        description = "TrueNAS shares to mount";
        example = lib.literalExpression ''
          {
            home = {
              share = "userdata/Jonny";
              mountPoint = "/mnt/truenas-home";
            };
          }
        '';
      };
    };

    smbCredentials = lib.mkOption {
      type = lib.types.str;
      default = "/etc/nixos/smb-secrets";
      description = "Path to SMB credentials file";
    };

    extraMounts = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Additional filesystem mounts";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.truenas.enable && builtins.pathExists ../../../secrets/secrets.yaml) {
      sops.secrets = {
        smb-username = {
          sopsFile = lib.mkDefault ../../../secrets/secrets.yaml;
        };
        smb-password = {
          sopsFile = lib.mkDefault ../../../secrets/secrets.yaml;
        };
      };

      # Create the combined credentials file using a template
      sops.templates."smb-credentials" = {
        content = ''
          username=${config.sops.placeholder.smb-username}
          domain=WORKGROUP
          password=${config.sops.placeholder.smb-password}
        '';
        mode = "0600";
        path = "/etc/nixos/smb-secrets";
      };

      fileSystems = lib.mapAttrs' (
        name: mount:
        lib.nameValuePair mount.mountPoint (
          mkCifsMount mount.mountPoint "//${cfg.truenas.server}/${mount.share}"
        )
      ) cfg.truenas.mounts;
    })

    {
      fileSystems = cfg.extraMounts;
    }
  ];
}
