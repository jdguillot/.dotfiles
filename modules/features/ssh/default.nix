{
  config,
  lib,
  ...
}:

let
  cfg = config.cyberfighter.features.ssh;
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
  };

  config = lib.mkIf cfg.enable {
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
