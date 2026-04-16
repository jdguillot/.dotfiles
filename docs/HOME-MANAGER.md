# Home Manager modules

This repo's Home Manager layer lives in `home/modules/` and mirrors the system-side `cyberfighter.*` namespace so host and user configuration stay consistent.

## Layout

```text
home/modules/
├── core/
│   ├── common/
│   ├── packages/
│   ├── profiles/
│   ├── system/
│   ├── users/
│   └── wsl/
└── features/
    ├── desktop/
    ├── editor/
    ├── git/
    ├── noctalia/
    ├── shell/
    ├── sops/
    ├── ssh/
    ├── terminal/
    └── tools/
```

## Core namespaces

### `cyberfighter.profile`

- `cyberfighter.profile.enable` with `desktop`, `minimal`, or `wsl`

In this repo, `home/<user>/home.nix` usually sets `cyberfighter.profile.enable = hostProfile;` so the Home Manager profile follows the host metadata exported from `flake.nix`.

### `cyberfighter.system`

Key options:

- `cyberfighter.system.username`
- `cyberfighter.system.homeDirectory`
- `cyberfighter.system.stateVersion`

### `cyberfighter.common`

Key option:

- `cyberfighter.common.enable`

This is the baseline user environment layer for shared settings and small conveniences.

### `cyberfighter.packages`

Key options:

- `cyberfighter.packages.includeDev`
- `cyberfighter.packages.extraPackages`

### `cyberfighter.users`

Key option:

- `cyberfighter.users.extraGroups`

This is metadata only on the Home Manager side; it does not replace system-side user/group declarations.

### `cyberfighter.wsl`

Key options:

- `cyberfighter.wsl.enable`
- `cyberfighter.wsl.includeWindowsPaths`
- `cyberfighter.wsl.windowsUsername`
- `cyberfighter.wsl.extraWindowsPaths`
- `cyberfighter.wsl.includeSystemPaths`

Notes:

- If `windowsUsername` is set, the module uses a fast path for Windows-path setup.
- If `includeWindowsPaths = true`, the module falls back to slower `wslpath`/`wslvar` discovery.
- When `features.ssh.enable = true` and `features.ssh.onepass = true`, the module also bridges the Windows 1Password SSH agent into WSL using `npiperelay.exe` and `socat`.

## Main feature modules

| Module | Main options | Notes |
| --- | --- | --- |
| `git` | `enable`, `extraSettings` | configures Git, Delta, and repo-specific include patterns |
| `shell` | `enable`, `bash.enable`, `fish.enable`, `fish.plugins`, `extraSessionVariables`, `extraAliases` | shared shell entry point |
| `terminal` | `enable` | shared terminal entry point |
| `editor` | `enable`, `vim.enable`, `vim.plugins`, `neovim.enable`, `vscode.enable`, `vscode.extensions` | shared editor entry point |
| `desktop` | `enable`, `firefox.enable`, `firefox.package`, `bitwarden.enable`, `extraPackages` | desktop applications for user environments |
| `ssh` | `enable`, `onepass`, `extraConfig`, `hosts` | SSH client config plus optional encrypted host snippets |
| `sops` | `enable` | enables the Home Manager `sops-nix` wrapper |
| `tools` | `enable`, `enableDefault`, `extraPackages` | shared CLI/tool bundle |
| `noctalia` | `enable` | Noctalia shell/home styling module |

## Shell submodules

| Submodule | Main options | Notes |
| --- | --- | --- |
| `shell.zsh` | `enable`, `enableCompletion`, `lazyLoadCompletion`, `enableAutosuggestions`, `enableSyntaxHighlighting`, `historySize`, `enableOhMyZsh`, `ohMyZshPlugins`, `enableStartupJoke`, `extraInitContent` | primary interactive-shell module in this repo |
| `shell.fish` | `enable` | enables Fish-specific config and hooks |
| `shell.starship` | `enable`, `useDefaultConfig`, `extraSettings` | Starship prompt setup |

Notes:

- The shell module defines shared aliases such as `ns`, `hs`, `nu`, and `nb`.
- WSL-specific shell path setup is layered in through `cyberfighter.wsl.*`, not through the shell module directly.

## Terminal submodules

| Submodule | Main options | Notes |
| --- | --- | --- |
| `terminal.alacritty` | `enable`, `opacity`, `theme`, `font`, `shell`, `startupMode`, `launchTmux` | Alacritty config wrapper |
| `terminal.ghostty` | `enable`, `theme`, `fullscreen`, `enableZshIntegration`, `launchTmux`, `confirmClose` | Ghostty config wrapper |

## Editor submodules

| Submodule | Main options | Notes |
| --- | --- | --- |
| `editor.lazyvim` | `enable`, `extraPackages`, `languageServers`, `formatters`, `treesitterParsers` | packaged LazyVim stack plus tooling |
| `editor.zed` | `enable` | Zed editor module |
| `editor.micro` | `enable` | Micro editor module |

The base `editor` module also supports simple `vim`, `neovim`, and `vscode` toggles directly under `cyberfighter.features.editor.*`.

## Tool submodules

All tool submodules live below `cyberfighter.features.tools.*`.

| Submodule | Main options | Notes |
| --- | --- | --- |
| `tmux` | `enable`, `shell`, `historyLimit`, `escapeTime`, `theme` | tmux config |
| `zellij` | `enable` | Zellij multiplexer |
| `yazi` | `enable`, `theme` | terminal file manager |
| `btop` | `enable`, `theme` | system monitor |
| `lazygit` | `enable`, `settings` | Git TUI |
| `jujutsu` | `enable`, `userName`, `userEmail`, `useSecretsForIdentity`, `extraSettings` | can consume SOPS identity data |
| `carapace` | `enable`, `enableZshIntegration`, `enableBashIntegration`, `enableFishIntegration` | shell completion helpers |
| `direnv` | `enable` | direnv integration |
| `rofi` | `enable` | app launcher |
| `sesh` | `enable` | session helper |
| `fastfetch` | `enable` | system info output |
| `opencode` | `enable`, `theme` | opencode config |
| `mc` | `enable` | Midnight Commander wrapper; note the option name is `mc`, not `midnight-commander` |
| `copilotMcp` | `enable`, `enableFilesystem`, `enableNix`, `enableAwesomeCopilot` | writes `~/.copilot/mcp-config.json` for Copilot MCP servers |

## SSH and SOPS integration

### `cyberfighter.features.ssh`

The SSH module does three things:

- manages the base Home Manager SSH client config
- optionally points `SSH_AUTH_SOCK` at `~/.1password/agent.sock`
- optionally renders host aliases from encrypted SOPS data in `home/modules/features/ssh/ssh-hosts.yaml`

Example:

```nix
{
  cyberfighter.features.ssh = {
    enable = true;
    onepass = true;
    hosts = [
      "thkpd-pve1"
      "simple-vm"
    ];
  };
}
```

If `hosts` is non-empty and `ssh-hosts.yaml` exists, the module enables the Home Manager SOPS layer by default and generates an `Include` file for those host aliases.

### `cyberfighter.features.sops`

The Home Manager SOPS wrapper is intentionally small.

When enabled, it:

- uses `secrets/secrets_common.yaml`
- stores an age key at `~/.config/sops/age/keys.txt`
- exposes these shared secrets:
  - `personal-info/fullname`
  - `personal-info/email`
  - `personal-info/github`
  - `personal-info/work-email`
  - `personal-info/work-github`

See [`SOPS.md`](SOPS.md) for the full secrets workflow.

## Practical examples

### Desktop-oriented home config

```nix
{
  cyberfighter = {
    profile.enable = hostProfile;

    system = {
      username = "myuser";
      homeDirectory = "/home/myuser";
      stateVersion = "24.11";
    };

    packages.includeDev = true;

    features = {
      ssh = {
        enable = true;
        onepass = true;
        hosts = [ "simple-vm" ];
      };

      shell = {
        fish.enable = true;
        zsh.enable = true;
        starship.enable = true;
      };

      editor = {
        neovim.enable = true;
        lazyvim.enable = true;
      };

      terminal = {
        enable = true;
        ghostty.enable = true;
      };

      desktop = {
        enable = true;
        firefox.enable = true;
        bitwarden.enable = true;
      };

      tools = {
        tmux.enable = true;
        lazygit.enable = true;
        yazi.enable = true;
        copilotMcp.enable = true;
      };
    };
  };
}
```

### WSL-focused home config

```nix
{
  cyberfighter = {
    profile.enable = "wsl";

    wsl = {
      enable = true;
      windowsUsername = "mywindowsuser";
      includeSystemPaths = false;
    };

    features = {
      ssh = {
        enable = true;
        onepass = true;
      };

      shell.zsh.enable = true;
      editor.lazyvim.enable = true;
      tools.direnv.enable = true;
    };
  };
}
```

## Current usage patterns in this repo

The checked-in home configs currently show three broad patterns:

- `home/cyberfighter/home.nix`: full desktop-oriented setup with SSH, Fish/Zsh, LazyVim, Zed, Ghostty, Alacritty, Bitwarden, Noctalia, and several tool submodules
- `home/jdguillot/home.nix`: work-oriented WSL setup with SSH, LazyVim, Firefox, Direnv, tmux, zellij, `mc`, and work Git include files
- `home/minimal/home.nix`: smaller server/VM setup with SSH, Zsh, Neovim/LazyVim, tmux, Yazi, and a lighter tool set

## Further reading

- Home Manager manual: <https://nix-community.github.io/home-manager/>
- Home Manager options: <https://nix-community.github.io/home-manager/options.xhtml>
- `sops-nix`: <https://github.com/Mic92/sops-nix>
- MyNixOS search: <https://mynixos.com/>
