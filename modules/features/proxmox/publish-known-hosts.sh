#!/usr/bin/env bash
# Publish this node's SSH host keys into the PVE cluster known_hosts.
#
# PVE 9 writes only /etc/pve/nodes/<node>/ssh_known_hosts, but every node
# still resolves peers through the legacy /etc/pve/priv/known_hosts, and
# nothing populates it for a node joined outside `pvecm add`. Entries are
# needed under BOTH the hostname and the IP: SSH by IP fails independently
# of SSH by name, so a name-only entry works until something dials the IP.
set -euo pipefail

KNOWN_HOSTS="@KNOWN_HOSTS@"
NODE_NAME="@NODE_NAME@"
NODE_ADDR="@NODE_ADDR@"
TIMEOUT="@TIMEOUT@"

# pmxcfs mounts /etc/pve late and keeps it read-only until the node is
# quorate. Writing before then fails; wait, but never block the boot.
deadline=$((SECONDS + TIMEOUT))
while ((SECONDS < deadline)); do
  [ -w "$KNOWN_HOSTS" ] && break
  sleep 2
done

if [ ! -w "$KNOWN_HOSTS" ]; then
  echo "$KNOWN_HOSTS not writable after ${TIMEOUT}s (no quorum?); published nothing" >&2
  exit 0
fi

missing=""
for host in "$NODE_ADDR" "$NODE_NAME"; do
  for keyfile in /etc/ssh/ssh_host_ed25519_key.pub /etc/ssh/ssh_host_rsa_key.pub; do
    [ -r "$keyfile" ] || continue
    keytype=$(awk '{ print $1 }' "$keyfile")
    keydata=$(awk '{ print $2 }' "$keyfile")
    # Field comparison, not grep: an IP's dots are regex wildcards.
    if awk -v h="$host" -v t="$keytype" \
      '$1 == h && $2 == t { found = 1 } END { exit !found }' "$KNOWN_HOSTS"; then
      continue
    fi
    missing+="${host} ${keytype} ${keydata}"$'\n'
  done
done

if [ -z "$missing" ]; then
  echo "${NODE_NAME} (${NODE_ADDR}) already present in $KNOWN_HOSTS"
  exit 0
fi

printf '%s' "$missing" >>"$KNOWN_HOSTS"
printf '%s' "$missing" | awk '{ print "published: " $1 " " $2 }'
