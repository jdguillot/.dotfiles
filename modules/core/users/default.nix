{
  config,
  lib,
  ...
}:

let
  cfg = config.cyberfighter.system;
in
{
  options.cyberfighter.system.extraGroups = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Extra groups for the primary user";
    example = [
      "docker"
      "libvirtd"
    ];
  };

  config = {

    sops.secrets."temp-pass" = {
      neededForUsers = true;
    };

    users.users.${cfg.username} = {
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBUyIMVw6JsHKA53g8WmxN5gkA0Qy/Gh1lmv8IqiXD5L cyberfighter@razer-nixos"
      ];
      extraGroups = [
        "networkmanager"
        "wheel"
      ]
      ++ cfg.extraGroups;
      initialHashedPassword = "$y$j9T$ee5r38mtIKQ.eA.TimY7g0$6DUlYVVIus9SD0mPDWDrDeovBmlaVqIJ4/4TKruS1hD";

    };

    security.sudo.wheelNeedsPassword = false;

  };
}
