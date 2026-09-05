The weekly dependency bump has been applied to flake.lock and
npins/sources.json in this working tree, and the repository no longer
evaluates or builds. Your job is to make it build again without reverting
the bump.

The failing command and its output are in `build-failure.log`. Read that
first, then read AGENTS.md for how this repository is organised.

What has almost certainly happened is that an upstream release renamed or
removed something this repository still calls: a NixOS or Home Manager
option, a package attribute, a module argument, a flake output. Find the
upstream change that did it and adapt this repository to it.

Rules:

- Do not touch flake.lock or npins/sources.json. The bump is the point; a
  revert is not a fix. If an input genuinely cannot be adapted to, stop and
  explain why instead of pinning it back.
- Fix the cause, not the symptom. Deleting the option, disabling the module,
  or commenting out the host that fails is not a fix.
- Keep to this repository's conventions: options live under the
  `cyberfighter.*` namespace, service config stays in native config files,
  and comments are one to three lines covering only what the code cannot say
  itself.
- Change as little as possible. One upstream rename should be a small diff.

Verify your work by running, for the host named in the failure:

    nix build --no-link .#nixosConfigurations.<host>.config.system.build.toplevel

and then:

    nix flake check --no-build

Iterate until both pass. When they do, write a short note to `fix-notes.md`:
which input changed, what it renamed or removed, and what you changed here
to match. That file becomes part of the pull request body, so write it for
someone who has not seen the failure.

If you cannot get both commands to pass, leave the tree as it is and say so
in `fix-notes.md`. A pull request only opens when the build is green, so an
honest failure is more useful than a change that hides one.
