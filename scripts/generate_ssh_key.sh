#!/run/current-system/sw/bin/bash

# Define SSH key path
SSH_KEY_PATH="$HOME/.ssh/id_ed25519"

# Unlock Bitwarden session if needed
BW_STATUS=$(bw status | jq -r .status)
if [[ "$BW_STATUS" == "unauthenticated" ]]; then
    echo "Please log in to Bitwarden."
    export BW_SESSION=$(bw login --raw)
elif [[ "$BW_STATUS" == "locked" ]]; then
    echo "Please unlock your Bitwarden vault."
    export BW_SESSION=$(bw unlock --raw)
elif [[ -z "$BW_SESSION" ]]; then
    echo "Please unlock your Bitwarden vault again."
    export BW_SESSION=$(bw unlock --raw)
elif [[ "$BW_STATUS" == "unlocked" && -n "$BW_SESSION" ]]; then
    echo "You are already logged in to Bitwarden."
fi

# Check if the SSH key already exists
if [[ ! -f "$SSH_KEY_PATH" ]]; then
    # Fetch the passphrase from Bitwarden
    PASSPHRASE=$(bw get password "$(hostname -s) SSH Key")

  # Check if the passphrase was successfully retrieved
  if [[ -z "$PASSPHRASE" ]]; then
      echo "Failed to retrieve passphrase from Bitwarden."
      read -r -p "Do you want to create a new SSH key and store it in Bitwarden? [Y/n]: " response
      response=${response:-Y}
  fi

  if [[ "$response" =~ ^([yY]|yes)$ ]]; then
      while true; do
          read -s -p "Enter a passphrase for your SSH key: " PASSPHRASE
          echo
          read -s -p "Confirm passphrase: " PASSPHRASE_CONFIRM
          echo
          
          if [[ "$PASSPHRASE" == "$PASSPHRASE_CONFIRM" ]]; then
              break
          else
              echo "Passphrases do not match. Please try again."
              echo
          fi
      done
      
      BW_TEMPLATE_LOGIN=$(bw get template item.login | \
        jq --arg username "$(whoami)" \
          --arg pass "$PASSPHRASE" \
          '.username = $username | .password = $pass | .totp = null')
      
      bw get template item | \
        jq --argjson login "$BW_TEMPLATE_LOGIN" \
          --arg hostname "$(hostname -s)" \
          '.name = ($hostname + " SSH Key") | .notes = null | .login = $login' | \
        bw encode | \
        bw create item
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

