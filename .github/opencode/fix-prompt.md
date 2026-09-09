The weekly dependency bump has been applied to flake.lock and
npins/sources.json in this working tree, and the repository no longer
evaluates or builds. Your job is to get it building again, by one of two
routes: adapt this repository to an upstream change, or hold one input back.
Both are real outcomes. Deciding which one this is, quickly, is most of the
work.

Read `build-failure.log` first. Its last line names every target that
failed, in the form the build script uses:

    failed to build: home:cyberfighter@razer-nixos home:cyberfighter@ryzn-server

Then read AGENTS.md for how this repository is organised.

## Decide which kind of failure this is before you edit anything

**Ours — adapt the repository.** The error names a file in this repo, and
the cause is that upstream changed something we call and we have not
followed yet. An option renamed, moved namespace, or was removed; a package
attribute moved; a module's arguments changed; a flake output went away; a
service moved to a new config format; a deprecation that used to warn now
fails. Find the upstream change and follow it here.

This is the common case and it is the point of this step. Adapting is the
right answer even when it is not a one-liner — a rename that touches four
hosts is still a rename. If you can name the upstream commit or release
note that changed it, and the lines here that have to change to match, you
are in this case: make the change.

**Upstream's — hold the input back.** The error is in upstream's own tree
and no edit here is the right fix. The reliable signs:

- a fixed-output hash mismatch (`hash mismatch in fixed-output derivation`,
  a stale `vendorHash`, `cargoHash`, `npmDepsHash`) in a package that the
  input itself defines
- upstream's own source failing to compile, or its own tests failing
- an upstream flake output that no longer evaluates on its own terms

That class is upstream's bug, it is usually fixed within days, and patching
around it from here means carrying a hash or a patch that goes stale the
moment upstream fixes it — and that then fails silently, next week, as a
mismatch in the other direction. Hold the input and let the following run
pick the real fix up.

The question that separates the two: **would the fix edit a description of
upstream's package, or this repository's own configuration?** Editing this
repository's configuration is the job. If instead you find yourself writing
a `vendorHash`, hanging an `.overrideAttrs` off someone else's derivation,
or adding a patch file for another project's source, you are on the wrong
side of that line. Hold instead.

Do not hold because adapting looks like work. Specifically, do not hold for:

- a renamed, moved, or removed option, attribute, or module argument — that
  is the case above, and following it is the job
- a migration upstream announced and this repo has not made yet
- a deprecation that has become an error
- not having found the cause yet. A hold names the input that is broken; if
  you cannot name it and say what is broken in *its* tree, you do not have a
  hold, you have an unfinished diagnosis. Write that up instead.

## Holding an input back

    .github/scripts/hold-input.sh <name> "<what is broken upstream>" [<issue or PR url>]

`<name>` is the flake input or npins pin exactly as it appears in
`flake.lock`'s root inputs or in `upstream-signal/sources.json`. The script
pins that one input back to the revision `main` has and replays the rest of
the week's bump on top, so everything else still moves.

Give the URL whenever you can find one — the upstream issue or pull request
that reports or fixes what you hit. A ledger watches it week to week and
releases the hold when it moves, so a hold with something tracked resolves
itself and a hold with nothing tracked sits at last month's revision until
someone notices. Search upstream's tracker for the error before you give up
on finding one; if there genuinely is no report, say so in `fix-notes.md`
and pass no URL.

Hold one input, not several. If a second one is genuinely broken too, hold
it separately and re-check in between — a hold that was not needed freezes a
dependency for a week for no reason.

Do not edit flake.lock or npins/sources.json by hand. `hold-input.sh` is the
only supported way to move them here, and a hand edit does not survive the
replay.

## Working inside the budget

You have @BUDGET_MINUTES@ minutes of wall clock for all of this, every build
included. That is less than it sounds: the model you are running on is
shared with other work on this host and can be slow to answer, and a NixOS
toplevel build takes minutes.

- Evaluate before you build. `nix eval --raw
  .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath` takes
  seconds and catches every Nix-level mistake that a build would, without
  the build.
- Build only the targets that the last line of `build-failure.log` names:

      nix build --no-link .#nixosConfigurations.<host>.config.system.build.toplevel
      nix build --no-link '.#homeConfigurations."<user>@<host>".activationPackage'

  A `home:` prefix in that line means the second form. Building a host
  toplevel to check a home failure proves nothing and costs minutes.
- Do not run `.github/scripts/check-and-build.sh` yourself. It builds every
  host and every home from scratch, and it runs automatically after you stop
  anyway; running it here can eat the whole budget on targets that were
  never broken. It also truncates `build-failure.log`, so you would lose the
  failure you are reading.
- Reproduce, then hypothesise. One command that shows the real error is
  worth more than three that confirm what you already assumed.
- Never conclude from a command whose stderr you discarded. If you redirect
  to `/dev/null` and read a count of zero, you have measured your own
  redirect. Re-run it showing stderr before you believe the number.
- Halfway through the budget, stop and take stock, and be honest about
  which of these you are in:
  - a verified diagnosis and an adaptation under way — keep going, that is
    the work, and finish it
  - a verified diagnosis that the breakage is in the input's own tree —
    hold it and be done
  - no diagnosis yet — you are not going to reach one in the time left.
    Write up what you ruled out and stop. Do not hold an input on a guess:
    a hold that was not needed freezes a dependency for a week and hides
    the real cause from next week's run.

## Leave a tree you have verified

Whatever is in the working tree when you stop gets built, and if it goes
green it gets pushed. An unverified edit is worse than no edit: it turns a
diagnosable upstream failure into a confusing one of your own making, and
the human reading the run sees your error instead of the real one.

- If an edit does not evaluate, revert it (`git checkout -- <file>`) rather
  than leaving it for the re-check to trip over.
- If you run out of time mid-experiment, revert the experiment.
- An untouched tree with an honest `fix-notes.md` is a good outcome. A
  half-applied guess is not.

## Rules

- Fix the cause, not the symptom. Deleting the option, disabling the module,
  or commenting out the host that fails is not a fix.
- Keep to this repository's conventions: options live under the
  `cyberfighter.*` namespace, service config stays in native config files,
  and comments are one to three lines covering only what the code cannot say
  itself.
- Change as little as possible, but as much as the upstream change actually
  requires. Following one rename across four hosts is a small diff repeated
  four times, not a big change; a diff that grows past what the failure
  named is a sign you are fixing something else.

## fix-notes.md

Write it before you run out of time, not after. It becomes part of the pull
request body, or of the summary explaining why there is no pull request, so
write it for someone who has not seen the failure: which input changed, what
broke, and what you did about it — adapted the repository, or held the input
and why. If you got nowhere, say that plainly. A pull request only opens when
the tree is green, so an honest failure is more useful than a change that
hides one.
