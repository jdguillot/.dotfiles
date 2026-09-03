{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.cyberfighter.features.tools.agentBrowser;

  # agent-browser ships no browser, and its own `agent-browser install`
  # downloads a Chrome-for-Testing binary that cannot run on NixOS. Wrap
  # the CLI to default to a nixpkgs chromium instead; --set-default keeps
  # AGENT_BROWSER_EXECUTABLE_PATH overridable from the environment.
  wrapped = pkgs.symlinkJoin {
    name = "agent-browser-wrapped";
    paths = [ pkgs.agent-browser ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/agent-browser \
        --set-default AGENT_BROWSER_EXECUTABLE_PATH ${lib.getExe cfg.browserPackage}
    '';
  };
in
{
  options.cyberfighter.features.tools.agentBrowser = {
    enable = lib.mkEnableOption "agent-browser CLI for AI-agent browser automation" // {
      default = true;
    };

    browserPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.chromium;
      defaultText = lib.literalExpression "pkgs.chromium";
      description = "Browser driven by agent-browser over CDP.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ wrapped ];
  };
}
