{
  config,
  lib,
  pkgs,
  ...
}:

let
  secretsFile = ../../../../secrets/secrets_common.yaml;
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

    # Ensure systemd units are linked and reloaded before sops-nix tries to
    # restart sops-nix.service, otherwise the unit won't be found.
    home.activation.reloadSystemdBeforeSops = lib.mkIf pkgs.stdenv.isLinux (
      lib.hm.dag.entryBetween [ "sops-nix" ] [ "reloadSystemd" ] ''
        # no-op: forces sops-nix to run after linkGeneration and reloadSystemd
      ''
    );

  };
}
