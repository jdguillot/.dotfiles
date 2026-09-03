{
  config,
  lib,
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

  # Local skills live in ./skills, one directory per skill (each with a SKILL.md).
  localSkills = lib.mapAttrs (name: _: ./skills + "/${name}") (
    lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./skills)
  );

  skills =
    localSkills
    // (lib.optionalAttrs cfg.enableWebappTesting {
      webapp-testing = "${anthropicSkills}/skills/webapp-testing";
    })
    // (lib.optionalAttrs cfg.enableRustSkill {
      rust-best-practices = "${autoskillsRegistry}/rust-best-practices";
    })
    // (lib.optionalAttrs cfg.enableTauriSkill {
      tauri-v2 = "${cceSkills}/tauri-v2";
    })
    // (lib.optionalAttrs cfg.enableGoSkills {
      golang-patterns = "${autoskillsRegistry}/golang-patterns";
      golang-testing = "${autoskillsRegistry}/golang-testing";
    })
    // (lib.optionalAttrs cfg.enableNixSkill {
      nix-flakes = "${nixSkills}/skills/nix-flakes";
    })
    // (lib.optionalAttrs cfg.enableGrillSkill {
      # grill-me is only the /grill-me slash trigger; the interview logic
      # lives in grilling, so both must ship together.
      grill-me = "${mattpocockSkills}/productivity/grill-me";
      grilling = "${mattpocockSkills}/productivity/grilling";
    });
in
{
  options.cyberfighter.features.tools.skills = {
    enable = lib.mkEnableOption "shared agent skills for AI coding assistants" // {
      default = true;
    };

    enableWebappTesting = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include the webapp-testing skill from anthropics/skills (Playwright-driven UI verification).";
    };

    enableRustSkill = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include the rust-best-practices skill from midudev/autoskills (Apollo GraphQL Rust handbook)";
    };

    enableTauriSkill = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include the tauri-v2 skill from nodnarbnitram/claude-code-extensions (Tauri commands, IPC, capabilities, plugins, plus reference docs)";
    };

    enableGoSkills = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include the golang-patterns and golang-testing skills from midudev/autoskills (idiomatic Go patterns, TDD, benchmarks)";
    };

    enableNixSkill = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include the nix-flakes skill from nhooey/nix-skills (flake conventions, input pinning, *2nix strategies)";
    };

    enableGrillSkill = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include the grill-me/grilling skills from mattpocock/skills (relentless interview to stress-test a plan or design; invoked via /grill-me)";
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
  };
}
