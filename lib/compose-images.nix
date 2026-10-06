# Compose images pinned by digest so a deploy copies them with the closure
# instead of pulling during activation. images.lock.json is the image
# counterpart of flake.lock; `nix run .#lock-images` writes it.
{ lib }:

let
  lock = lib.importJSON ../images.lock.json;

  # The tag is after the last `:` only when no `/` follows it, which keeps a
  # registry port (`host:5000/name`) out of the tag.
  parseRef =
    ref:
    let
      m = builtins.match "(.*):([^:/]+)" ref;
    in
    if m == null then
      throw "compose-images: '${ref}' has no tag; pin images by tag"
    else
      {
        name = builtins.elemAt m 0;
        tag = builtins.elemAt m 1;
      };
in
{
  # The literal `image:` refs in a compose file. Templated refs (`@TAG@`,
  # `${VAR}`) are skipped: they are only known once rendered.
  imagesIn =
    file:
    let
      lines = lib.splitString "\n" (builtins.readFile file);
      refOf = line: builtins.match "[[:space:]]*image:[[:space:]]*[\"']?([^\"'[:space:]#]+).*" line;
      refs = map (m: builtins.head m) (builtins.filter (m: m != null) (map refOf lines));
    in
    builtins.filter (r: !(lib.hasInfix "@" r) && !(lib.hasInfix "$" r)) refs;

  # The image tar for a locked ref, loaded under the same name:tag the
  # compose file uses.
  pull =
    pkgs: ref:
    let
      entry =
        lock.${ref}
          or (throw "compose-images: '${ref}' is not in images.lock.json; run `nix run .#lock-images` and commit the lock");
      parsed = parseRef ref;
    in
    pkgs.dockerTools.pullImage {
      inherit (entry) imageName imageDigest hash;
      finalImageName = parsed.name;
      finalImageTag = parsed.tag;
    };
}
