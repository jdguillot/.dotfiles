{
  config,
  lib,
  ...
}:

let
  cfg = config.cyberfighter.features.ssh;
  systemUser = config.cyberfighter.system.username;
in
{
  options.cyberfighter.features.ssh = {
    enable = lib.mkEnableOption "OpenSSH server";

    ports = lib.mkOption {
      type = lib.types.listOf lib.types.int;
      default = [ 22 ];
      description = "SSH ports to listen on";
    };

    passwordAuth = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow password authentication";
    };

    permitRootLogin = lib.mkOption {
      type = lib.types.str;
      default = "prohibit-password";
      description = "Root login setting";
    };

    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBUyIMVw6JsHKA53g8WmxN5gkA0Qy/Gh1lmv8IqiXD5L cyberfighter@razer-nixos"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJq8jkRxEPluMdKOpipdV3Q3Xk7nVWCat22/viMon2C1"
      ];
      description = "SSH public keys authorized to log in as root and the primary system user";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.root.openssh.authorizedKeys.keys = cfg.authorizedKeys;
    users.users.${systemUser}.openssh.authorizedKeys.keys = cfg.authorizedKeys;

    services.openssh = {
      enable = true;
      ports = cfg.ports;
      settings = {
        PasswordAuthentication = cfg.passwordAuth;
        AllowUsers = null;
        UseDns = true;
        X11Forwarding = false;
        PermitRootLogin = cfg.permitRootLogin;
      };
    };
  };
}
