# WSL-specific configurations module
# This module handles Windows path integration, auto-detection, and caching
# for fast shell startup in WSL environments.
#
# Key features:
# - Auto-detects Windows username and caches it (adds ~140ms once)
# - Subsequent shells use cache (~0.5ms overhead)
# - No username stored in git (cached in ~/.cache/wsl-paths)
# - Shell functions in: home/modules/features/shell/shell-functions.{sh,fish}
{
  config,
  lib,
  pkgs,
  hostProfile,
  ...
}:

let
  cfg = config.cyberfighter.wsl;
  isWsl = hostProfile == "wsl";
  # Bridge the Windows 1Password named pipe to ~/.1password/agent.sock via
  # npiperelay.exe (Windows) + socat (Linux). Starts once per shell session.
  npiperelayBridge = ''
    export SSH_AUTH_SOCK="$HOME/.1password/agent.sock"
    if ! ss -xlp 2>/dev/null | grep -qF "$SSH_AUTH_SOCK"; then
      rm -f "$SSH_AUTH_SOCK"
      (setsid nohup socat \
        UNIX-LISTEN:"$SSH_AUTH_SOCK",fork \
        EXEC:"npiperelay.exe -ei -s //./pipe/openssh-ssh-agent",nofork \
        </dev/null >/dev/null 2>&1 &)
    fi
  '';
in
{
  options.cyberfighter.wsl = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = isWsl;
      description = "Enable WSL-specific configurations";
    };

    includeWindowsPaths = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Include Windows paths in WSL PATH using slow wslpath/wslvar (adds 4+ seconds to shell startup)";
    };

    windowsUsername = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Windows username for fast path resolution (skips auto-detection)";
      example = "cyberfighter";
    };

    extraWindowsPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional Windows paths to include (relative to Windows user home)";
      example = [ "AppData/Local/Programs/SomeApp" ];
    };

    includeSystemPaths = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include Windows system paths (System32, PowerShell, etc). Warning: Very slow!";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        home = {
          # Install WSL utilities
          packages = with pkgs; [
            wslu # WSL utilities (wslpath, wslvar, etc)
          ];

          # Set WSL-specific environment variables
          sessionVariables = {
            # Use Windows Chrome as default browser in WSL
            BROWSER = "/mnt/c/Program Files/Google/Chrome/Application/chrome.exe --new-tab";
          };

          # Windows system paths (very slow, only add if explicitly requested)
          sessionPath = lib.mkIf cfg.includeSystemPaths [
            "/mnt/c/Windows/System32"
            "/mnt/c/Windows/System32/OpenSSH"
            "/mnt/c/Windows/System32/WindowsPowerShell/v1.0"
            "/mnt/c/Program Files/Docker/Docker/resources/bin"
          ];
        };

        # WSL-specific shell initialization
        programs = {
          bash.initExtra = lib.mkIf isWsl (
            if cfg.windowsUsername != null then
              # Fast path: username provided explicitly in config
              let
                winHome = "/mnt/c/Users/${cfg.windowsUsername}";
                basePaths = [
                  "${winHome}/AppData/Local/Programs/Microsoft VS Code/bin"
                  "${winHome}/AppData/Local/Microsoft/WindowsApps"
                  "${winHome}/AppData/Local/Microsoft/WinGet/Links"
                  "${winHome}/AppData/Local/Microsoft/WinGet/Packages/equalsraf.win32yank_Microsoft.Winget.Source_8wekyb3d8bbwe"
                ];
                extraPaths = map (p: "${winHome}/${p}") cfg.extraWindowsPaths;
                allPaths = basePaths ++ extraPaths;
              in
              ''
                # Fast Windows paths (username provided, no detection needed)
                ${lib.concatMapStringsSep "\n" (p: ''[ -d "${p}" ] && export PATH="${p}:$PATH"'') allPaths}
              ''
            else if cfg.includeWindowsPaths then
              # Legacy slow path: use wslvar/wslpath (adds 4s startup time)
              ''
                _win_home=$(wslpath "$(wslvar USERPROFILE 2>/dev/null)")
                if [ -n "$_win_home" ]; then
                  export PATH="$_win_home/AppData/Local/Programs/Microsoft VS Code/bin:$_win_home/AppData/Local/Microsoft/WindowsApps:$_win_home/AppData/Local/Microsoft/WinGet/Links:$_win_home/AppData/Local/Microsoft/WinGet/Packages/equalsraf.win32yank_Microsoft.Winget.Source_8wekyb3d8bbwe:$PATH"
                fi
              ''
            else
              # Default: Call shell function for auto-detection with caching
              "setup-wsl-windows-paths"
          );

          zsh.initContent = lib.mkIf isWsl (
            ''
              # Deduplicate PATH entries to reduce overhead
              typeset -U path
            ''
            + (
              if cfg.windowsUsername != null then
                let
                  winHome = "/mnt/c/Users/${cfg.windowsUsername}";
                  basePaths = [
                    "${winHome}/AppData/Local/Programs/Microsoft VS Code/bin"
                    "${winHome}/AppData/Local/Microsoft/WindowsApps"
                    "${winHome}/AppData/Local/Microsoft/WinGet/Links"
                    "${winHome}/AppData/Local/Microsoft/WinGet/Packages/equalsraf.win32yank_Microsoft.Winget.Source_8wekyb3d8bbwe"
                  ];
                  extraPaths = map (p: "${winHome}/${p}") cfg.extraWindowsPaths;
                  allPaths = basePaths ++ extraPaths;
                in
                ''
                  # Fast Windows paths (username provided, no detection needed)
                  ${lib.concatMapStringsSep "\n" (p: ''[ -d "${p}" ] && export PATH="${p}:$PATH"'') allPaths}
                ''
              else if cfg.includeWindowsPaths then
                ''
                  _win_home=$(wslpath "$(wslvar USERPROFILE 2>/dev/null)")
                  if [ -n "$_win_home" ]; then
                    export PATH="$_win_home/AppData/Local/Programs/Microsoft VS Code/bin:$_win_home/AppData/Local/Microsoft/WindowsApps:$_win_home/AppData/Local/Microsoft/WinGet/Links:$_win_home/AppData/Local/Microsoft/WinGet/Packages/equalsraf.win32yank_Microsoft.Winget.Source_8wekyb3d8bbwe:$PATH"
                  fi
                ''
              else
                "setup-wsl-windows-paths"
            )
          );

          fish.interactiveShellInit = lib.mkIf isWsl (
            ''
              # Source fish functions for WSL helpers
              source ${../../features/shell/shell-functions.fish}
            ''
            + (
              if cfg.windowsUsername != null then
                let
                  winHome = "/mnt/c/Users/${cfg.windowsUsername}";
                  basePaths = [
                    "${winHome}/AppData/Local/Programs/Microsoft VS Code/bin"
                    "${winHome}/AppData/Local/Microsoft/WindowsApps"
                    "${winHome}/AppData/Local/Microsoft/WinGet/Links"
                    "${winHome}/AppData/Local/Microsoft/WinGet/Packages/equalsraf.win32yank_Microsoft.Winget.Source_8wekyb3d8bbwe"
                  ];
                  extraPaths = map (p: "${winHome}/${p}") cfg.extraWindowsPaths;
                  allPaths = basePaths ++ extraPaths;
                in
                lib.concatMapStringsSep "\n" (p: ''
                  if test -d "${p}"
                    fish_add_path "${p}"
                  end
                '') allPaths
              else if cfg.includeWindowsPaths then
                ''
                  set _win_home (wslpath (wslvar USERPROFILE 2>/dev/null) 2>/dev/null)
                  if test -n "$_win_home"
                    fish_add_path "$_win_home/AppData/Local/Programs/Microsoft VS Code/bin"
                    fish_add_path "$_win_home/AppData/Local/Microsoft/WindowsApps"
                    fish_add_path "$_win_home/AppData/Local/Microsoft/WinGet/Links"
                    fish_add_path "$_win_home/AppData/Local/Microsoft/WinGet/Packages/equalsraf.win32yank_Microsoft.Winget.Source_8wekyb3d8bbwe"
                  end
                ''
              else
                "setup-wsl-windows-paths"
            )
          );
        };
      }

      (lib.mkIf (config.cyberfighter.features.ssh.enable && config.cyberfighter.features.ssh.onepass) {
        home.packages = [ pkgs.socat ];

        home.activation.ensureNpiperelay = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          _win_profile=$(/mnt/c/Windows/System32/cmd.exe /c "echo %USERPROFILE%" 2>/dev/null | tr -d '\r\n')
          if [ -n "$_win_profile" ]; then
            _win_home=$(/sbin/wslpath "$_win_profile")
            _winget="$_win_home/AppData/Local/Microsoft/WindowsApps/winget.exe"
            _links="$_win_home/AppData/Local/Microsoft/WinGet/Links"
            _npiperelay="$_links/npiperelay.exe"
            if [ ! -f "$_npiperelay" ]; then
              # Check if it's already installed in WinGet Packages (but not linked yet)
              _pkg_exe=$(find "$_win_home/AppData/Local/Microsoft/WinGet/Packages" \
                -name "npiperelay.exe" 2>/dev/null | head -1)
              if [ -n "$_pkg_exe" ]; then
                echo "npiperelay.exe found in packages, linking to WinGet Links..."
                $DRY_RUN_CMD cp "$_pkg_exe" "$_npiperelay"
              elif [ -x "$_winget" ]; then
                echo "npiperelay.exe not found — installing via winget..."
                "$_winget" install --id jstarks.npiperelay \
                  --accept-package-agreements --accept-source-agreements --silent || true
                # After install, link from packages to links
                _pkg_exe=$(find "$_win_home/AppData/Local/Microsoft/WinGet/Packages" \
                  -name "npiperelay.exe" 2>/dev/null | head -1)
                [ -n "$_pkg_exe" ] && $DRY_RUN_CMD cp "$_pkg_exe" "$_npiperelay"
              else
                echo "warning: npiperelay.exe not found and winget.exe not available" >&2
              fi
            fi
          fi
        '';
        programs = {

          bash.initExtra = npiperelayBridge;
          zsh.initContent = lib.mkAfter npiperelayBridge;
          fish.interactiveShellInit = lib.mkAfter ''
            set -x SSH_AUTH_SOCK "$HOME/.1password/agent.sock"
            if not ss -xlp 2>/dev/null | grep -qF "$SSH_AUTH_SOCK"
              rm -f "$SSH_AUTH_SOCK"
              setsid nohup socat \
                UNIX-LISTEN:"$SSH_AUTH_SOCK",fork \
                EXEC:"npiperelay.exe -ei -s //./pipe/openssh-ssh-agent",nofork \
                </dev/null >/dev/null 2>&1 &
            end
          '';
        };
      })
    ]
  );
}
