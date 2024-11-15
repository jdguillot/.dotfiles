#!/run/current-system/sw/bin/bash

# Define SSH key path
SSH_KEY_PATH="$HOME/.ssh/id_ed25519"

# Unlock Bitwarden session if needed
# export BW_SESSION=$(bw unlock --raw)

# Check if the SSH key already exists
if [[ ! -f "$SSH_KEY_PATH" ]]; then
    # Fetch the passphrase from Bitwarden
    PASSPHRASE=$(bw get password "Razer SSH Key")

    # Check if the passphrase was successfully retrieved
    if [[ -z "$PASSPHRASE" ]]; then
        echo "Error: Failed to retrieve passphrase from Bitwarden. Exiting."
        exit 1
    fi
    
    # Generate the SSH key with the retrieved passphrase
    echo "Generating a new SSH key at $SSH_KEY_PATH."
    ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -C "$USER@$(hostname)" -N "$PASSPHRASE"

    # Start the ssh-agent and add the key to it
    eval "$(ssh-agent -s)"
    echo "$PASSPHRASE" | ssh-add "$SSH_KEY_PATH"
else
    echo "SSH Key already exists."
fi

