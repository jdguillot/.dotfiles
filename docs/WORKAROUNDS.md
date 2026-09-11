# Workarounds

`workarounds.nix` at the repo root is the register of temporary fixes this
tree carries while waiting on something upstream: an override, a patch, a
mount, a version pinned in code, or a setting on a machine this repo does
not manage. Each entry says what it works around, where the code is, what
upstream event ends it, and what removing it takes. The weekly bump
(`docs/CI.md`, "The workaround register") probes every entry against
upstream and retires the ones it can; the rest it keeps reporting until a
person deletes them.

Held *inputs* are a different mechanism. A flake input or npins pin that
cannot move this week is a hold, kept in the hold ledger by the weekly
workflow itself. The register is for code: something written into this
repository, or done to a host, that would not exist if upstream were fixed.

## Why a register

A workaround is written once, with the reason fresh in mind, and then
outlives the reason. Nobody re-reads a `fileSystems` block to check whether
the WSL release that made it necessary is still the one installed. The
register turns "remember to remove this" into a probe that runs every week,
and the marker comments turn removal into deleting a line range instead of
re-deriving what the fix touched.

## Recording one

1. Fence every block the workaround adds with a marker pair, in whatever
   comment syntax the file uses:

   ```nix
   # WORKAROUND(<id>)
   fileSystems."/mnt/shared_memory" = { ... };
   # END WORKAROUND(<id>)
   ```

   The markers are literal text; `retire-workaround.sh` matches them as
   fixed strings and deletes from the start line through the end line,
   inclusive, so the block has to be a contiguous, self-contained range
   whose removal leaves valid code behind. A workaround that is a changed
   value, or a fix woven through a module, cannot be fenced that way — it
   is a `manual` entry (below) and the markers only need to say where it
   is.

2. Add the entry to `workarounds.nix`, fenced by the same pair so the
   retirer can remove it along with the code:

   ```nix
   # WORKAROUND(<id>)
   <id> = {
     title = "one line, what it is";
     added = "YYYY-MM-DD";
     hosts = [ "work-nix-wsl" ];   # affected hosts; [ ] means all
     problem = ''what breaks, and why upstream is at fault'';
     workaround = ''what was put in place, and where'';
     files = [ "hosts/work-nix-wsl/configuration.nix" ];   # each carries the marker pair
     upstream = {
       issue = "https://github.com/owner/repo/issues/N";   # optional
       fix = "https://github.com/owner/repo/pull/N";       # optional
     };
     resolved = { ... };   # the probe, see below
     retire = "auto";      # or "manual"
     removal = ''what removing it takes, for a person'';
   };
   # END WORKAROUND(<id>)
   ```

   Upstream URLs are fine here. Files on a branch raise no cross-reference
   events; the weekly pull request body is passed through
   `sanitize-refs.sh` before those URLs reach it.

3. `git add` the register and the files, as with any new tracked content.

The id is a short kebab-case slug, used in the markers and the reports.
Prose fields are for the person reading the weekly report months later and
for whoever has to remove the thing; write them for someone who has not
seen the original failure.

## The `resolved` probe

What the weekly run checks, deterministically, to decide the fix has
shipped. One of:

| `kind` | Fields | Resolved when |
|---|---|---|
| `release` | `repo`, `minVersion`, `prerelease` (default `false`) | `owner/repo` has a non-draft release with a tag at or past `minVersion`. With `prerelease = false`, only stable releases count. |
| `pr` | `url` | the pull request is merged |
| `issue` | `url` | the issue is closed |
| `commit` | `input`, `sha` | the flake input named `input` is pinned, after this week's bump, to a revision that contains `sha` |
| `package` | `attr`, `minVersion` | `pkgs.<attr>.version` evaluates, on the entry's first host, to `minVersion` or later |

`commit` is the one to reach for when a nixpkgs or module fix has merged
and the question is whether it has reached the branch this repo tracks.
`pr` alone answers "is it merged", which is usually weeks earlier than
"is it in my pin".

A probe that cannot answer — a rate limit, an attribute that does not
evaluate — is reported as `unknown`, never as still waiting. Version
comparison strips a leading `v` and compares numerically, component by
component.

## `retire`

- `auto`: when the probe resolves, `retire-workaround.sh` deletes every
  fenced block in `files` and the entry's own block in the register, then
  evaluates each host in `hosts` (every host, when the list is empty). If
  anything fails to evaluate the files are put back exactly as they were
  and the report says so. What survives evaluation is built by the same
  gate as the bump, and lands in the weekly pull request with a
  "Workarounds" section explaining the removal.
- `manual`: the run reports the entry as fixed upstream, prints `removal`,
  and raises a warning annotation, every week until the entry is deleted.
  For a fix that the markers cannot capture, and for anything outside this
  repository — the first entry, a WSL channel switch on a Windows host, is
  one of those.

## Doing it by hand

```bash
# what the weekly run would see, without changing anything
.github/scripts/check-workarounds.sh && cat workarounds-report.md

# remove one auto entry now, with the same checks the run applies
.github/scripts/retire-workaround.sh <id>
```

Both need `gh` authenticated for the GitHub probes. `check-workarounds.sh`
does retire `auto` entries whose probe resolves, so read the report from
a run before relying on it as a dry run; `git checkout -- .` puts back
anything it removed.
