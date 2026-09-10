#!/usr/bin/env bash
# Reboots this host if -- and only if -- a generation is waiting for one.
#
# The pending test is upstream's, from nixpkgs' system.autoUpgrade: compare
# initrd, kernel and kernel-modules between the booted system and the system
# PROFILE. Not /run/current-system: `nixos-rebuild boot` and `deploy --boot`
# move the profile without activating, so current-system would miss exactly
# the case this exists for.
set -euo pipefail

booted="$(@READLINK@ /run/booted-system/{initrd,kernel,kernel-modules})"
built="$(@READLINK@ /nix/var/nix/profiles/system/{initrd,kernel,kernel-modules})"
if [ "$booted" = "$built" ]; then
  echo "booted system is current; nothing to reboot for"
  exit 0
fi

state=@STATE@
until_file="$state/postponed-until"
if [ -r "$until_file" ] && [ "$(cat "$until_file")" -gt "$(date +%s)" ]; then
  echo "postponed until $(date -d "@$(cat "$until_file")")"
  exit 0
fi

# `shutdown` broadcasts its own wall message to every tty, and `shutdown -c`
# cancels it -- that pair is the whole postpone mechanism, so there is no
# custom IPC here. What it does not reach is a graphical session, hence the
# notify-send loop below.
msg="Rebooting in @WARNING@ min for a new kernel. Delay it with: sudo reboot-postpone"

sessions="$(@LOGINCTL@ list-sessions --no-legend || true)"
if [ -z "$sessions" ]; then
  echo "nobody logged in; rebooting now"
  # The state dir is cleared here rather than on boot: the reboot follows
  # immediately, so this is what resets the postpone budget.
  rm -f "$until_file" "$state/postpone-count"
  exec @SHUTDOWN@ -r +1 "Rebooting for a new kernel."
fi

echo "sessions present; warning users and rebooting in @WARNING@ min"
@SHUTDOWN@ -r +@WARNING@ "$msg"

# Best effort per graphical session: a user with no bus (a plain tty login)
# already got the wall message, and a failure here must not abort the reboot.
while read -r _id uid user _rest; do
  bus="/run/user/$uid/bus"
  [ -S "$bus" ] || continue
  @RUNUSER@ -u "$user" -- env "DBUS_SESSION_BUS_ADDRESS=unix:path=$bus" \
    @NOTIFYSEND@ --urgency=critical --expire-time=0 "Reboot scheduled" "$msg" || true
done <<< "$sessions"
