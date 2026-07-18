{
  config,
  inputs,
  lib,
  ...
}:

let
  cfg = config.cyberfighter.features.tools.skills;

  # Pinned in flake.lock; update with `nix flake update anthropic-skills`.
  anthropicSkills = inputs.anthropic-skills;

  # Local skills live in ./skills, one directory per skill (each with a SKILL.md).
  localSkills = lib.mapAttrs (name: _: ./skills + "/${name}") (
    lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./skills)
  );

  skills =
    localSkills
    // (lib.optionalAttrs cfg.enableWebappTesting {
      webapp-testing = "${anthropicSkills}/skills/webapp-testing";
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
