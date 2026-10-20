# Per-package pins. Every `pin` block in workarounds.nix becomes one
# attribute of this overlay, taken from the nixpkgs revision the block names
# -- the revision main's lock had when the package last built, so a host
# keeps the version it already runs while the rest of nixpkgs moves.
# `builtins.fetchTree` with the lock's own narHash is pure and needs no
# flake input; one import per distinct revision, with the host's nixpkgs
# config so unfree and platform settings carry over. Deleting the register
# entry deletes the pin.
let
  register = import ./workarounds.nix;
  pins = builtins.filter (e: e ? pin) (builtins.attrValues register);
  byRev = builtins.groupBy (e: e.pin.rev) pins;
in
final: prev:
let
  pkgsAt = builtins.mapAttrs (
    rev: entries:
    import
      (builtins.fetchTree {
        type = "github";
        owner = "NixOS";
        repo = "nixpkgs";
        inherit rev;
        inherit ((builtins.head entries).pin) narHash;
      })
      {
        inherit (prev.stdenv.hostPlatform) system;
        inherit (prev) config;
      }
  ) byRev;
in
builtins.listToAttrs (
  map (e: {
    name = e.pin.attr;
    value = pkgsAt.${e.pin.rev}.${e.pin.attr};
  }) pins
)
