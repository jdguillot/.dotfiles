# The workaround register: temporary fixes this repo carries while waiting
# on something upstream. docs/WORKAROUNDS.md has the schema and the rules.
#
# Every entry is fenced by a `WORKAROUND(<id>)` / `END WORKAROUND(<id>)`
# comment pair, here and in each file it lists, so the weekly run can retire
# it by deleting those blocks once its `resolved` probe says the fix shipped.
{
  # WORKAROUND(wsl-prerelease-shared-memory)
  wsl-prerelease-shared-memory = {
    title = "WSL pre-release channel for the WSLg shared-memory fix";
    added = "2026-09-11";
    hosts = [ "work-nix-wsl" ];
    problem = ''
      WSL 2.7.x never mounts /mnt/shared_memory in the WSLg system distro, so
      weston's startup probe fails and the whole session runs in RAIL copy
      mode. Windows then intermittently never gets a first frame for a new
      window: the taskbar icon appears, the app is alive, nothing is drawn.
    '';
    workaround = ''
      The Windows host runs `wsl --update --pre-release` (2.9.11 at the time
      of writing). Nothing in this repo changes; the fix is in WSL's
      DeviceHost package, which the 2.7.x stable line has not picked up.
    '';
    files = [ ];
    upstream = {
      issue = "https://github.com/microsoft/WSL/issues/40618";
      fix = "https://github.com/microsoft/WSL/pull/41499";
    };
    resolved = {
      kind = "release";
      repo = "microsoft/WSL";
      minVersion = "2.9.10";
      prerelease = false;
    };
    retire = "manual";
    removal = ''
      On the Windows host run `wsl --update` (no `--pre-release`) to return to
      the stable channel, confirm `wsl --version` is at or past the release
      the probe named, then delete this entry.
    '';
  };
  # END WORKAROUND(wsl-prerelease-shared-memory)
}
