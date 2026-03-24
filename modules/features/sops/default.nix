{
  config,
  lib,
  pkgs,
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

    deployUserAgeKey = lib.mkEnableOption "derive an age key from the SSH host key and write it to the primary user's sops age key path during system activation";
  };

  config = lib.mkIf (cfg.enable && builtins.pathExists ../../../secrets/secrets.yaml) {
    sops = {
      inherit (cfg) defaultSopsFile;
      validateSopsFiles = false;
      age = {
        sshKeyPaths = [ cfg.sshKeyPath ];
        keyFile = "/var/lib/sops-nix/key.txt";
        generateKey = true;
      };
    };

    system.activationScripts.sopsUserAgeKey = lib.mkIf cfg.deployUserAgeKey (
      let
        username = config.cyberfighter.system.username;
        homeDir = "/home/${username}";
      in
      {
        deps = [ "users" ];
        text = ''
          mkdir -p ${homeDir}/.config/sops/age
          if [[ ! -f ${homeDir}/.config/sops/age/keys.txt ]]; then
            ${lib.getExe' pkgs.ssh-to-age "ssh-to-age"} \
              -private-key \
              -i ${cfg.sshKeyPath} \
              -o ${homeDir}/.config/sops/age/keys.txt
          fi
          chmod 700 ${homeDir}/.config/sops/age
          chmod 600 ${homeDir}/.config/sops/age/keys.txt
          chown -R ${username}: ${homeDir}/.config/sops
        '';
      }
    );
  };
}
