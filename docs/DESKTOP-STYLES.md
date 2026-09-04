# Desktop Styles: niri + noctalia

The niri and noctalia configs now have switchable looks, researched from
popular community setups (YaLTeR's own dotfiles, linkfrg, saatvik333,
snowarch/iNiR, nickjj) and omarchy's design conventions.

## niri visual styles

Styles switch **at runtime, no rebuild** — the config `include`s a mutable
symlink (`~/.config/niri/style-current.kdl`, omarchy-style) that the
`niri-style` command swaps before telling niri to reload:

```sh
niri-style list
niri-style rounded
```

Or open the noctalia launcher (`Mod+Space`) and type "niri style" — each
style has a launcher entry.

| Style      | Look                                                                 |
| ---------- | -------------------------------------------------------------------- |
| `minimal`  | Previous look: 4px gaps, thin solid ring, square corners, no shadows |
| `rounded`  | (default) 12px rounded corners, soft shadows, mauve→pink gradient    |
|            | focus ring spanning the workspace view, snappy springs               |
| `showcase` | Full rice: 12px gaps, oklch rainbow ring, blur behind translucent    |
|            | ghostty, inactive-window dimming, bouncy window-open                 |

The `cyberfighter.features.niri.style` option in `home/<user>/home.nix` only
seeds the initial symlink; after that the runtime choice wins. Shared
behavior lives in `home/modules/features/niri/base.kdl`; styles live in
`home/modules/features/niri/styles/<style>.kdl` and are deployed to
`~/.config/niri/styles/`. All variants are validated against niri 26.04
(`niri validate -c`).

## Desktop shells on niri: noctalia or DankMaterialShell

niri runs one Quickshell desktop on top of it, and both are installed side
by side so you can move between them. `base.kdl` holds the shell-agnostic
core (window motions, window rules); each shell's `spawn-at-startup` plus
its panel/media/lock binds live in
`home/modules/features/niri/shells/<shell>.kdl`, deployed to
`~/.config/niri/shells/` and `include`d through the mutable
`~/.config/niri/shell-current.kdl` symlink — the same trick the styles use.

The merge order in `config.kdl` is **base → style → shell**. The shell goes
last so a shell that manages niri settings itself (dank does; see below) wins
over the style's geometry. niri merges `binds` and `layout` later-wins, so
each layer only has to state what it changes.

| Shell      | What it is                                                         |
| ---------- | ------------------------------------------------------------------ |
| `noctalia` | The Noctalia shell (the previous, unchanged setup)                 |
| `dank`     | DankMaterialShell, from the `dms` flake input, on its stock keymap |

Two ways to switch:

- **At login**: the greeter lists `Niri (Noctalia)` and
  `Niri (DankMaterialShell)` next to the plain `Niri` session (which keeps
  whatever was last selected). The session entries are registered by the
  NixOS desktop module when `features.desktop.environment = "niri"`; each
  one points `shell-current.kdl` at its layer and then execs `niri-session`.
- **In a running session**: `niri-shell dank` / `niri-shell noctalia` swaps
  the symlink, reloads the config, stops the running shell, and starts the
  other one. `niri-shell list` shows what's current. Both also have launcher
  entries ("Niri Shell: …").

Neither path needs a rebuild. The choice persists through the symlink, so
the next login keeps it until a session entry or another `niri-shell` call
overrides it.

Because niri merges `binds` sections **later-wins** (a later section
replaces conflicting binds rather than erroring), the dank layer
deliberately takes over two `base.kdl` window motions to match DMS's
defaults: `Mod+V` → clipboard (was toggle-floating) and `Mod+Comma` →
settings (was consume-into-column). The vim-style workspace/column motions
(`Mod+H/J/K/L`, `Mod+Ctrl+…`) live in `base.kdl` and are untouched by either
shell.

Module wiring, for reference:

- `cyberfighter.features.niri.shells` — which layers get installed; both on
  `desktop` hosts, noctalia only elsewhere, so minimal hosts don't carry a
  second Quickshell closure. `"dank"` in this list is what enables
  `programs.dank-material-shell` (systemd unit off — niri spawns it, so a
  unit would double-spawn).
- `cyberfighter.features.niri.shell` — the layer seeded on first activation,
  before anything has picked one.
- `"noctalia"` still needs `cyberfighter.features.noctalia.enable`, which
  owns that package and its presets.

## The dank suite: apps, plugins, greeter

`cyberfighter.features.dank` (Home Manager) owns DankMaterialShell and the
rest of the suite, the way `features.noctalia` owns Noctalia. It is enabled
on desktop-profile hosts. `features.niri.shells` only deploys the niri-side
layer; the packages come from here. Upstream versions the whole suite
together — DMS, dgop, dsearch and dcal are all 1.6.0 — so each has its own
flake input rather than coming from nixpkgs.

| `apps.*`   | Binary    | What it is                                        |
| ---------- | --------- | ------------------------------------------------- |
| `monitor`  | `dgop`    | System monitor. **Not optional in practice**: the bar's cpuUsage/memUsage widgets and the `Mod+M` process list shell out to it, and the DMS module does not pull it in itself. On by default |
| `search`   | `dsearch` | Indexed filesystem search; runs a user service that keeps the index warm |
| `calendar` | `dcal`    | DankCalendar, with CalDAV sync and a reminder service |

### Plugin dependencies (`extraQtPackages`)

DMS bar plugins can need QML modules the shell wasn't built against — the
Home Assistant monitor plugin needs `QtWebSockets`, for example. Installing
the Qt package into the profile is not enough: Quickshell only sees modules
on the import path the `dms` wrapper pins, so a missing one shows up as

```
Blackholed import URL QUrl("qs:@/QtWebSockets/qmldir")
<Plugin>: Failed to load WebSocketClient. Dependency 'qt6-websockets' likely missing.
```

in `~/.cache/quickshell/`. Add the package to
`features.dank.extraQtPackages` instead; it goes through upstream's
`extraQtPackages` override, which folds it into both
`NIXPKGS_QT6_QML_IMPORT_PATH` and `QT_PLUGIN_PATH` on the wrapper. The cost
is that a non-empty list rebuilds `dms-shell` locally, which is why it
defaults to empty.

### Greeter

`features.desktop.greeter = "dms"` (the default) runs **dms-greeter** from
the `dank-greeter` flake input. It launches its own compositor —
`compositor.name` follows `features.desktop.environment` — and reads the
primary user's live DMS theme, wallpaper and settings through `configHome`,
so the login screen tracks the desktop instead of being themed by hand. The
other choices are `regreet` (GTK, themed in `modules/features/desktop/regreet/`)
and `tuigreet` (text, no compositor).

Either way the session list is the same one described above, so the greeter
is where you pick noctalia or DMS for the session you are about to start.

## Editing niri settings from the DMS GUI, without losing them

DMS's Settings GUI can drive niri itself. It does that by regenerating KDL
fragments into `~/.config/niri/dms/` (`layout`, `colors`, `input`, `cursor`,
`windowrules`, `alttab`, `wpblur`, …) and expecting your niri config to
include them. `shells/dank.kdl` does, as `include "dms/layout.kdl"` — the
relative form matters twice over: niri resolves includes against the path a
file was *included by* (never the symlink's store target, so `~/.config/niri`
stays the base), and DMS greps for exactly that string to decide whether a
fragment is wired up.

Because the dank layer comes after the style, DMS owns the knobs its GUI
exposes — gaps, border and focus-ring width, corner radius — and the style
keeps everything DMS never writes: shadows, blur, springs, the gradient focus
ring, column presets. Under `noctalia` the fragments are not included at all,
so the style is unchallenged. (Verified by feeding niri a deliberately broken
`dms/layout.kdl`: `dank` fails validation, `noctalia` doesn't.)

### Screenshots

DMS 1.6 has its own capture tool built into the `dms` binary — region select
with confirmation, window and output modes, and a scrolling capture that
stitches a tall image, which niri has no equivalent for. It is not wired to
anything by default (upstream's keymap leaves screenshots to the
compositor), and `base.kdl` binds `Print` to niri's built-in `screenshot`,
so it stayed invisible.

`shells/dank.kdl` now overrides those keys, which means DMS's tool under the
dank shell and niri's built-in under noctalia. Both write to
`~/Pictures/Screenshots`, so the two agree on where captures land.

| Key           | Action                                    |
| ------------- | ----------------------------------------- |
| `Print`       | region select                             |
| `Ctrl+Print`  | focused output                            |
| `Alt+Print`   | focused window                            |
| `Shift+Print` | scrolling region, stitched into one image |

`dms screenshot --help` lists the rest — `--stdout` for piping into an
editor, `last` to reuse the previous region, JPEG and quality flags.

`dms doctor` is the fastest way to find gaps like this one: it reports
missing optional dependencies, config files, fonts and services.

### What actually gets tracked

Those fragments are **derived files, not source**. DMS regenerates them from
`~/.config/DankMaterialShell/settings.json` — that single file is what the
GUI edits, and `colors.kdl` on top of it comes from matugen and changes with
every wallpaper. Tracking the fragments would mean tracking build output.

So the repo tracks `settings.json`, via
`home/modules/features/dank/settings.json`:

- `dank-capture` copies the live file into the checkout, `jq -S`-sorted so a
  save doesn't reshuffle the diff. It writes the working tree and never
  commits — changes surface in `git status` for you to review.
- With `features.dank.capture.watch` (default on) a systemd user path unit
  runs it whenever DMS saves, five seconds after the last write so a slider
  drag produces one snapshot rather than a dozen.
- On a fresh home, activation seeds `settings.json` from the tracked copy if
  the file doesn't exist yet. It is never a store symlink — that would make
  the file read-only and the Settings GUI could no longer save, the same trap
  documented for noctalia below.

`session.json` is deliberately **not** captured: it holds your weather
location, launcher history and other local state that does not belong in a
public repo. Review the diff before committing anyway — settings.json is
whatever DMS decides to put there.

One wrinkle to know about: the bar-xray toggle is the exception to
"fragments are derived" — DMS reads it back out of `dms/layout.kdl` rather
than storing it in settings.json, so that one setting is not captured.

## noctalia presets

Noctalia's `settings.json` stays runtime-managed (declarative management
would make it a read-only symlink and break the settings GUI). Instead, the
`noctalia-preset` command jq-merges a preset into the live settings file;
noctalia hot-reloads it.

```sh
noctalia-preset list
noctalia-preset floating-island   # floating bar + rounded screen corners
noctalia-preset framed-bento      # frame around the whole screen
noctalia-preset simple-top        # the previous look
noctalia-preset wallpaper-colors  # Material-You colors from the wallpaper
noctalia-preset catppuccin-static # back to the static Catppuccin scheme
```

These also have launcher entries — `Mod+Space`, type "preset".

## Launcher A/B test: noctalia vs rofi

Both launchers are bound while comparing:

| Bind              | Launcher                                          |
| ----------------- | ------------------------------------------------- |
| `Mod+Space`       | noctalia launcher (quickshell)                    |
| `Mod+Shift+Space` | rofi (mocha `launcher.rasi` theme, drun + window) |
| `Mod+Ctrl+Space`  | `style-menu` — rofi dmenu picker for niri styles  |
|                   | and noctalia presets (dmenu scripting demo)       |

The rofi theme lives in `home/modules/features/tools/rofi/rofi-config/`
(`launcher.rasi` + `catppuccin-mocha.rasi`). `style-menu` shows the rofi
side of the scripting story: pipe lines into `rofi -dmenu`, act on the
selection — the equivalent of the desktop-entry approach used for the
noctalia launcher.

Presets live in `home/modules/features/noctalia/presets/*.json` — add a new
JSON fragment there to create a preset (only include the keys you want to
override).

## Keybind changes (omarchy-inspired, noctalia IPC instead of rofi/swaylock)

| Bind               | Action                                     |
| ------------------ | ------------------------------------------ |
| `Mod+Return`       | Terminal (ghostty) — `Mod+T` still works   |
| `Mod+Space`        | Noctalia app launcher (was rofi)           |
| `Mod+Ctrl+V`       | Clipboard history                          |
| `Mod+Ctrl+E`       | Emoji picker                               |
| `Mod+N`            | Notification history                       |
| `Mod+Shift+N`      | Do not disturb toggle                      |
| `Mod+Shift+W`      | Random wallpaper                           |
| `Mod+Escape`       | Session/power menu (was: shortcut inhibit) |
| `Mod+Shift+Escape` | Toggle keyboard shortcut inhibit (moved)   |
| `Super+Alt+L`      | Lock screen via noctalia (was swaylock)    |
| `Mod+Tab`          | Back-and-forth to previous workspace       |
| `Mod+Shift+O`      | Pick dynamic screencast window             |
| Volume/brightness  | Routed through noctalia IPC → shows OSD    |

Other defaults changed: hotkey overlay no longer pops up at startup
(`Mod+Shift+?` shows it), hot corners disabled, cursor hides while typing,
numlock on, flat mouse accel, wallpaper shows inside the overview backdrop,
password managers (1Password/KeePassXC/Bitwarden) are blocked from screen
capture, PiP windows float bottom-right, and utility popups (pavucontrol,
network/bluetooth editors, file choosers) open floating.

## Trying other shells (quickshell)

Noctalia is itself quickshell-based. If you want to experiment beyond it,
the strongest alternative with first-class niri support is
[DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell)
(flake `github:AvengeMedia/DankMaterialShell/stable`, home-manager modules
`homeModules.dank-material-shell` + `homeModules.niri`). Note that noctalia
`legacy-v4` is EOL — the eventual upgrade path is noctalia v5
(`programs.noctalia`, TOML settings, `noctalia msg` IPC).
