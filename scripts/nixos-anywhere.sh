#!/usr/bin/env bash

copy() {
  if command -v wl-copy >/dev/null 2>&1; then
    wl-copy
  elif command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard
  elif command -v xsel >/dev/null 2>&1; then
    xsel --clipboard --input
  elif command -v pbcopy >/dev/null 2>&1; then
    pbcopy
  elif command -v clip.exe >/dev/null 2>&1; then
    clip.exe
  else
    echo "No clipboard utility found" >&2
    return 1
  fi
}

read -p "What is the hostname: " HOSTNAME
read -p "What is the target. user@host -p port: " -a TARGET
read -p "Do you want to create a hardware-configuration.nix? [Y/n]: " HARDCONFIG
read -p "Should this host be able to access secrets? [y/N]: " SECRETS

if [[ ! $HARDCONFIG =~ ^[Nn]$ ]]; then
  GENHARD=(--generate-hardware-config nixos-generate-config ./hosts/$HOSTNAME/hardware-configuration.nix)
else
  GENHARD=()
fi


# Create a temporary directory
temp=$(mktemp -d)

# Function to cleanup temporary directory on exit
cleanup() {
  rm -rf "$temp"
}
trap cleanup EXIT

# Create the directory where sshd expects to find the host keys
install -d -m755 "$temp/etc/ssh"

# Decrypt your private key from the password store and copy it to the temporary directory
op item get $HOSTNAME --vault='Dev' || op item create --category ssh-key --title=${HOSTNAME} --vault 'Dev'
op read "op://Dev/${HOSTNAME}/private key?ssh-format=openssh" > "$temp/etc/ssh/ssh_host_ed25519_key"
# op read "op://Dev/${HOSTNAME}/public key" > "$temp/etc/ssh/ssh_host_ed25519_key.pub"

# Set the correct permissions so sshd will accept the key
chmod 600 "$temp/etc/ssh/ssh_host_ed25519_key"

# Open secrets file to add new ssh key can
if [[ ! $SECRETS =~ ^[Yy]$ ]]; then
  echo "Skipping secrets"
else
  nix-shell -p ssh-to-age --run ssh-to-age < "${temp}/etc/ssh/ssh_host_ed25519_key.pub" \
    | sed "s/^/- \\&$HOSTNAME /" \
    | copy
  "$EDITOR" ./.sops.yaml
  sops updatekeys ./secrets/secrets.yaml
fi


# Install NixOS to the host system with our secrets
cmd=(
  nix run github:nix-community/nixos-anywhere --
  --extra-files "$temp"
  --flake ".#$HOSTNAME"
  "${GENHARD[@]}"
  --target-host "${TARGET[@]}"
)

printf '%q ' "${cmd[@]}"
echo
"${cmd[@]}"

