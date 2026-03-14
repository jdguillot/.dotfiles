{
  config,
  lib,
  ...
}:

let
  secretsFile = ../../../../secrets/secrets.yaml;
  secretsAvailable = builtins.pathExists secretsFile;
in
{
  config = lib.mkIf secretsAvailable {
    sops = {
      defaultSopsFile = secretsFile;
      validateSopsFiles = false;
      age = {
        # sshKeyPaths = [ "${config.home.homeDirectory}/.ssh/id_ed25519" ];
        keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
        generateKey = true;
      };

      secrets = {
        "personal-info/fullname" = { };
        "personal-info/email" = { };
        "personal-info/github" = { };
        "personal-info/work-email" = { };
        "personal-info/work-github" = { };
      };
    };

  };
}
