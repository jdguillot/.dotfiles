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
