{
  imports = [
    ./common/default.nix
    ./profiles/default.nix
    # Shared with the NixOS module tree -- see the file's header comment.
    ../../../modules/core/traits/default.nix
    ./system/default.nix
    ./users/default.nix
    ./packages/default.nix
    ./wsl/default.nix
  ];
}
