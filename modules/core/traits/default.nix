{
  lib,
  hostMeta,
  ...
}:

let
  # Adding a trait = add its name here, declare it on hosts in
  # hosts/default.nix, and gate module defaults on
  # config.cyberfighter.traits.<name>.
  knownTraits = [ "dev" ];
in
{
  # Imported by BOTH module trees (modules/default.nix and
  # home/modules/default.nix): system and home each get their own copy
  # of these options, both defaulting from the host's declared traits,
  # so either side can override independently.
  options.cyberfighter.traits = lib.genAttrs knownTraits (
    name:
    lib.mkOption {
      type = lib.types.bool;
      default = builtins.elem name (hostMeta.traits or [ ]);
      defaultText = lib.literalExpression ''builtins.elem "${name}" hostMeta.traits'';
      description = "Whether this host carries the ${name} trait (declared in hosts/default.nix; override per system or home to break the host/user symmetry).";
    }
  );
}
