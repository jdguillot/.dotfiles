# Domain glossary

Names the concepts this repo's module interfaces are built around. When a
new option or module names one of these, use the term as defined here; when
a design conversation sharpens or adds a term, update this file in the same
change.

- **Host metadata** — the single entry per machine in `hosts/default.nix`:
  identity (hostname, username, stateVersion), `profile`, `traits`, `home`
  (home folder or null), and `deploy`. Everything else — flake outputs, CI
  matrix, module defaults — derives from it; registering a host is one
  entry.

- **Profile** — what kind of machine this is (`desktop`, `wsl`, `minimal`,
  `none`); bundles overridable defaults. Declared in host metadata,
  defaulted into both the system and home option trees.

- **Trait** — what a host is *for* (currently `dev`), orthogonal to its
  profile. One declaration drives dev-flavored defaults on both sides;
  either side can override its copy to break the symmetry.

- **Compose project** — a docker compose service run as a boot-time systemd
  oneshot, declared via `cyberfighter.features.compose.projects.<name>`.
  The shared module owns the lifecycle invariants and the `<name>-compose`
  day-2 wrapper; service modules declare only what they run.

- **Route** — a service published through traefik, declared once as
  `traefik.routes.<name>` (host, port, auth, backend). The traefik module
  renders it as docker labels or a file-provider fragment; callers never
  spell entrypoints, cert resolvers, or middleware chains.

- **Catalog** — a data table inside a module mapping names to vendored
  things (skills, MCP servers), where adding an entry is one line and
  per-entry fields (`requires`, `default`) carry the invariants. The `lsp`
  module is the reference shape.

- **Container bridge** — a bridge interface containers reach the host
  through. Compose modules publish theirs into
  `cyberfighter.features.docker.containerBridges`; host services opt in
  with `exposeToContainers`, which opens their port on every registered
  bridge and nowhere else.

- **Name-style secret** — the sops convention: a module option takes a
  secret *name* (with a default), and the module declares the
  `sops.secrets` entry itself — mode, owner, restartUnits. `*File` options
  are the path-style escape hatch that bypasses sops.
