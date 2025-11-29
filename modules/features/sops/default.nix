{
  config,
  lib,
  ...
}:

let
  cfg = config.cyberfighter.features.sops;
in
{
  options.cyberfighter.features.sops = {
    enable = lib.mkEnableOption "SOPS secrets management";

    defaultSopsFile = lib.mkOption {
      type = lib.types.path;
      default = ../../../secrets/secrets.yaml;
      description = "Default SOPS secrets file";
    };

    sshKeyPath = lib.mkOption {
      type = lib.types.str;
      default = "/etc/ssh/ssh_host_ed25519_key";
      description = "SSH key path for SOPS";
    };
  };

  config = lib.mkIf cfg.enable {
    sops = {
      defaultSopsFile = cfg.defaultSopsFile;
      age = {
        sshKeyPaths = [ cfg.sshKeyPath ];
        keyFile = "/var/lib/sops-nix/key.txt";
        generateKey = true;
      };
    };
  };
}
