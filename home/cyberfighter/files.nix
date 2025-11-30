{
  lib,
  ...
}:
{
  home.file = lib.mkIf (builtins.pathExists ../../secrets) {
    ".ssh/config".source = ../../secrets/.ssh_config_work;
    ".config/nix/nix.conf".source = ../../secrets/nix.conf;
  };
}
