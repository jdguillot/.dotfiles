{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.tools.skills;

  # Skill repos are pinned in npins/sources.json, not flake.lock; update
  # with `npins update <name>` from the repo root.
  sources = import ../../../../../npins;

  anthropicSkills = sources.anthropic-skills;
  autoskillsRegistry = "${sources.autoskills}/packages/autoskills/skills-registry";
  nixSkills = sources.nix-skills;
  cceSkills = "${sources.claude-code-extensions}/.claude/skills";
  mattpocockSkills = "${sources.mattpocock-skills}/skills";
  hyperSkills = "${sources.hyperskills}/skills";
  nixosManaging = "${sources.nixos-management-skill}/nixos-managing";

  # One catalog drives everything: adding a vendored skill is one line here.
  # `requires` names catalog entries that must ship alongside this one.
  catalog = {
    webapp-testing = "${anthropicSkills}/skills/webapp-testing";
    rust-best-practices = "${autoskillsRegistry}/rust-best-practices";
    tauri-v2 = "${cceSkills}/tauri-v2";
    golang-patterns = "${autoskillsRegistry}/golang-patterns";
    golang-testing = "${autoskillsRegistry}/golang-testing";
    nix-flakes = "${nixSkills}/skills/nix-flakes";
    # grill-me is only the /grill-me slash trigger; the interview logic
    # lives in grilling, so both must ship together.
    grill-me = {
      path = "${mattpocockSkills}/productivity/grill-me";
      requires = [ "grilling" ];
    };
    grilling = "${mattpocockSkills}/productivity/grilling";
    diagnosing-bugs = "${mattpocockSkills}/engineering/diagnosing-bugs";
    tdd = "${mattpocockSkills}/engineering/tdd";
    to-spec = "${mattpocockSkills}/engineering/to-spec";
    improve-codebase-architecture = "${mattpocockSkills}/engineering/improve-codebase-architecture";
    codebase-design = "${mattpocockSkills}/engineering/codebase-design";
    tui-design = "${hyperSkills}/tui-design";
    # NixOS-side reference for this repo's own subject matter: flakes,
    # modules, secrets and the anti-patterns page. Its LUKS/impermanence
    # pages are dead weight here, but they only load on demand.
    nixos-managing = nixosManaging;
  };

  # Normalize plain-path entries, then close over `requires` so a shipped
  # skill always brings its companions.
  entryOf =
    name: if lib.isAttrs catalog.${name} then catalog.${name} else { path = catalog.${name}; };
  closure = names: lib.unique (lib.concatMap (n: [ n ] ++ (entryOf n).requires or [ ]) names);
  catalogSkills = lib.genAttrs (closure (lib.attrNames catalog)) (n: (entryOf n).path);

  # Local skills live in ./skills, one directory per skill (each with a SKILL.md).
  localSkills = lib.mapAttrs (name: _: ./skills + "/${name}") (
    lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./skills)
  );

  # Shared with ci/agent-skills.nix, which ships a subset to the weekly
  # bump's fix agent and needs the same clamp applied to its copies.
  clampDescription = import ../../../../../lib/clamp-skill-description.nix { inherit pkgs; };

  skills = lib.mapAttrs clampDescription (localSkills // catalogSkills // cfg.extraSkills);
in
{
  options.cyberfighter.features.tools.skills = {
    enable = lib.mkEnableOption "shared agent skills for AI coding assistants" // {
      default = config.cyberfighter.traits.dev;
      defaultText = lib.literalExpression "config.cyberfighter.traits.dev";
    };

    extraSkills = lib.mkOption {
      type = lib.types.attrsOf (lib.types.either lib.types.path lib.types.str);
      default = { };
      example = lib.literalExpression "{ my-skill = ./my-skill; }";
      description = "Extra skills (name → skill directory), merged over the local and vendored catalog.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Claude Code binary is installed system-wide (cyberfighter.packages);
    # this only manages ~/.claude/skills.
    programs.claude-code = {
      enable = true;
      package = null;
      inherit skills;
    };

    programs.opencode = {
      inherit skills;
    };

    # Crush's own module places these under ~/.config/crush/skills.
    programs.crush = {
      inherit skills;
    };

    # TmuxAI has no home-manager module; it reads the same SKILL.md format
    # from ~/.config/tmuxai/skills/<name>/ (enabled in its config.yaml).
    xdg.configFile = lib.mkIf config.cyberfighter.features.tools.tmuxai.enable (
      lib.mapAttrs' (name: src: lib.nameValuePair "tmuxai/skills/${name}" { source = src; }) skills
    );
  };
}
