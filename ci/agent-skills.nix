# Skills for the weekly bump's fix agent, materialised into one directory that
# opencode reads as $XDG_CONFIG_HOME/opencode/skills. Separate from the home
# catalog on purpose: the agent runs on an ephemeral runner with no home
# configuration, and a broken bump is a narrow problem -- everything here has
# to bear on reading a Nix failure and adapting a module to it.
{ pkgs }:
let
  sources = import ../npins;
  clamp = import ../lib/clamp-skill-description.nix { inherit pkgs; };

  skills = {
    # What the repo itself is made of: flakes, modules, secrets, anti-patterns.
    nixos-managing = "${sources.nixos-management-skill}/nixos-managing";
    nix-flakes = "${sources.nix-skills}/skills/nix-flakes";
    # The discipline the agent most needs and least has: form a hypothesis,
    # test it, and do not conclude from a command whose stderr you discarded.
    diagnosing-bugs = "${sources.mattpocock-skills}/skills/engineering/diagnosing-bugs";
  };
in
pkgs.linkFarm "ci-agent-skills" (builtins.mapAttrs clamp skills)
