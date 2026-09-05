# The Agent Skills spec caps `description` at 1024 chars. Crush enforces it and
# refuses to load violators (red in the skill list, "Skill validation failed" in
# the logs), and opencode reads the same directory, so the clamp has to apply to
# every consumer's copy rather than one client's. Vendored nix-flakes trips it;
# the others pass through unchanged.
{ pkgs }:
name: src:
pkgs.runCommandLocal "skill-${name}" { } ''
  cp -rL ${src} $out
  chmod -R u+w $out
  awk -v max=1024 '
    NR > 1 && /^---$/ { infm = 0 }
    infm && /^description:/ {
      val = substr($0, index($0, ":") + 2)
      if (length(val) > max) $0 = "description: " substr(val, 1, max - 3) "..."
    }
    NR == 1 && /^---$/ { infm = 1 }
    { print }
  ' $out/SKILL.md > SKILL.md.tmp && mv SKILL.md.tmp $out/SKILL.md
''
