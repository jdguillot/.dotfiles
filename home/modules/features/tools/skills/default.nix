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
    })
    // (lib.optionalAttrs cfg.enableDiagnosingBugs {
      diagnosing-bugs = "${mattpocockSkills}/engineering/diagnosing-bugs";
    })
    // (lib.optionalAttrs cfg.enableTdd {
      tdd = "${mattpocockSkills}/engineering/tdd";
    })
    // (lib.optionalAttrs cfg.enabletoSpec {
      to-spec = "${mattpocockSkills}/engineering/to-spec";
    })
    // (lib.optionalAttrs cfg.enableImproveCodebaseArchitecture {
      improve-codebase-architecture = "${mattpocockSkills}/engineering/improve-codebase-architecture";
    });
in
{
  options.cyberfighter.features.tools.skills = {
    enable = lib.mkEnableOption "shared agent skills for AI coding assistants" // {
      default = config.cyberfighter.traits.dev;
      defaultText = lib.literalExpression "config.cyberfighter.traits.dev";
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
    enableDiagnosingBugs = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include the diagnosing-bugs skill from mattpocock/skills (diagnose and fix a bug in a codebase; invoked via /diagnose-bug)";
    };
    enableTdd = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include the tdd skill from mattpocock/skills (test-driven development; invoked via /tdd)";
    };
    enabletoSpec = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include the to-spec skill from mattpocock/skills (convert a codebase to spec; invoked via /to-spec)";
    };
    enableImproveCodebaseArchitecture = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include the improve-codebase-architecture skill from mattpocock/skills (improve codebase architecture; invoked via /improve-codebase-architecture)";
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
