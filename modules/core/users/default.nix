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
