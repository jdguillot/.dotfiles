{ lib, hostMeta, ... }:

{
  # Defaults from the host's entry in hosts/default.nix; override per home
  # to break the host/home symmetry (same pattern as modules/core/traits).
  options.cyberfighter.profile = {
    enable = lib.mkOption {
      type = lib.types.enum [ "desktop" "minimal" "wsl" ];
      default = hostMeta.profile or "minimal";
      defaultText = lib.literalExpression "hostMeta.profile";
      description = "Profile to use for home configuration";
    };
  };
}
