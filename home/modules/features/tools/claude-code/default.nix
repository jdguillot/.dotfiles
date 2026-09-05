# Claude Code user settings that should hold on every install.
#
# The settings land in the mutable ~/.claude/settings.json rather than
# through `programs.claude-code.settings`, which writes that file as a
# read-only store symlink -- and Claude Code writes to it itself, so `/config`
# would have nowhere to save the model, theme, effort level or editor mode.
# Declared keys win, anything set by hand survives. Same trade-off, and the
# same activation-merge shape, as the MCP servers in ../mcp.
#
# Skills and LSP servers are configured elsewhere (../skills, ../lsp); this
# module only owns settings.json.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.tools.claude-code;

  settings =
    lib.optionalAttrs (!cfg.remoteControl) {
      # The hard switch: claude.ai/code, `claude remote-control`, --rc, the
      # auto-start and the in-session toggle. `remoteControlAtStartup = false`
      # alone would only stop it starting on its own.
      disableRemoteControl = true;
    }
    // lib.optionalAttrs (!cfg.feedback) {
      # Two separate features: the periodic session survey, and the tool that
      # lets the model queue feedback drafts.
      feedbackSurveyRate = 0;
      feedbackDrafts = "off";
    }
    // cfg.extraSettings;

  settingsFile = (pkgs.formats.json { }).generate "claude-code-settings.json" settings;
in
{
  options.cyberfighter.features.tools.claude-code = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.cyberfighter.traits.dev;
      defaultText = lib.literalExpression "config.cyberfighter.traits.dev";
      description = "Manage Claude Code's user settings. Defaults to the host's dev trait.";
    };

    remoteControl = lib.mkEnableOption "Claude Code Remote Control -- driving this session from claude.ai/code";

    feedback = lib.mkEnableOption "Claude Code feedback -- the session quality survey and the model's feedback-draft tool";

    extraSettings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      example = lib.literalExpression ''{ autoCompactEnabled = false; }'';
      description = ''
        Further keys merged into ~/.claude/settings.json, overriding the ones
        derived from the options above.

        Only for settings that should hold on every install. Anything you
        would rather change with `/config` should be left out -- a key
        declared here is reasserted on the next activation.
      '';
    };
  };

  config = lib.mkIf (cfg.enable && settings != { }) {
    home.activation.claudeCodeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      claudeSettings="${config.home.homeDirectory}/.claude/settings.json"
      if [ -v DRY_RUN ]; then
        verboseEcho "Would merge Claude Code settings into $claudeSettings"
      elif [ ! -f "$claudeSettings" ]; then
        $DRY_RUN_CMD mkdir -p "$(dirname "$claudeSettings")"
        $DRY_RUN_CMD cp ${settingsFile} "$claudeSettings"
        $DRY_RUN_CMD chmod 644 "$claudeSettings"
      else
        # `*` deep-merges with the declared side winning, so a nested key set
        # by hand is kept unless it is one this module declares. A settings.json
        # that is not valid JSON is left alone rather than clobbered.
        tmp=$(mktemp)
        if ${pkgs.jq}/bin/jq --slurpfile declared ${settingsFile} \
             '. * $declared[0]' "$claudeSettings" > "$tmp" 2>/dev/null; then
          $DRY_RUN_CMD mv "$tmp" "$claudeSettings"
        else
          rm -f "$tmp"
          errorEcho "$claudeSettings is not valid JSON; leaving it untouched"
        fi
      fi
    '';
  };
}
