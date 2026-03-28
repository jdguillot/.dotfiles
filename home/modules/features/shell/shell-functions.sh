# Startup joke system with caching
# Shows a random joke from cache on shell startup (instant!)
# Refreshes cache in background once a day
show-startup-joke() {
  local cache_dir="$HOME/.cache/dadjokes"
  local cache_file="$cache_dir/jokes.json"
  local last_update="$cache_dir/last_update"
  
  # Create cache directory if needed
  mkdir -p "$cache_dir"
  
  # Initialize cache if empty or missing
  if [ ! -f "$cache_file" ] || [ ! -s "$cache_file" ]; then
    # Provide some fallback jokes so it works offline (JSON array format)
    cat > "$cache_file" << 'EOF'
[
  "Why don't scientists trust atoms? Because they make up everything.",
  "What do you call a fake noodle? An impasta.",
  "Why did the scarecrow win an award? He was outstanding in his field.",
  "What do you call a bear with no teeth? A gummy bear.",
  "Why don't eggs tell jokes? They'd crack each other up.",
  "I'm reading a book about anti-gravity. It's impossible to put down!",
  "Did you hear about the mathematician who's afraid of negative numbers? He'll stop at nothing to avoid them.",
  "Why did the bicycle fall over? Because it was two tired!",
  "What do you call a dinosaur that crashes his car? Tyrannosaurus Wrecks!",
  "Why can't you hear a pterodactyl go to the bathroom? Because the 'P' is silent!"
]
EOF
    echo "0" > "$last_update"
  fi
  
  # Show a random joke from cache (instant - no network!)
  # Use jq to safely parse JSON and get random joke
  if command -v jq >/dev/null; then
    local total_jokes=$(jq 'length' "$cache_file")
    local random_index=$((RANDOM % total_jokes))
    local joke=$(jq -r ".[$random_index]" "$cache_file")
  else
    # Fallback if jq not available (less reliable but works)
    local joke=$(grep -o '"[^"]*"' "$cache_file" | sed 's/"//g' | shuf -n 1)
  fi
  
  # Display with cowsay and lolcat if available
  if command -v cowsay >/dev/null && command -v lolcat >/dev/null; then
    echo "$joke" | cowsay -f sus | lolcat
  else
    echo "💭 $joke"
  fi
  
  # Refresh cache in background if older than 1 day (non-blocking!)
  local current_time=$(date +%s)
  local last_update_time=$(cat "$last_update" 2>/dev/null || echo 0)
  local time_diff=$((current_time - last_update_time))
  
  # 86400 seconds = 1 day
  if [ $time_diff -gt 86400 ]; then
    # Fork to background so it doesn't block shell startup
    # Redirect all output and disown to prevent job notifications
    {
      # Use a temp file for new jokes
      local temp_file="$cache_dir/jokes.tmp"
      
      # Fetch 50 new jokes to build up cache (more variety!)
      # With 1 second delay, this takes ~50 seconds in background
      for i in {1..50}; do
        new_joke=$(curl -s --max-time 3 -H "Accept: text/plain" https://icanhazdadjoke.com 2>/dev/null)
        if [ -n "$new_joke" ] && [ "$new_joke" != "The internet is not responding" ]; then
          # Properly escape the joke for JSON and append
          echo "$new_joke" >> "$temp_file"
        fi
        sleep 1  # Be nice to the API - 1 second between requests
      done
      
      # Convert text file to JSON array and merge with existing cache
      if command -v jq >/dev/null && [ -f "$temp_file" ]; then
        # Read existing jokes
        local existing=$(cat "$cache_file")
        
        # Convert new jokes to JSON array
        local new_jokes=$(jq -R -s 'split("\n") | map(select(length > 0))' "$temp_file")
        
        # Merge and deduplicate, keep last 100 unique jokes
        echo "$existing" | jq --argjson new "$new_jokes" '. + $new | unique | .[-100:]' > "$cache_file.tmp"
        mv "$cache_file.tmp" "$cache_file"
        rm -f "$temp_file"
      fi
      
      # Update timestamp
      echo "$current_time" > "$last_update"
    } &>/dev/null &
    disown  # Prevent "job completed" messages
  fi
}

# Manual joke fetcher (for the dadjoke alias)
dadjoke() {
  local joke=$(curl -s --max-time 2 -H "Accept: text/plain" https://icanhazdadjoke.com 2>/dev/null || echo "The internet is not responding")
  if command -v cowsay >/dev/null && command -v lolcat >/dev/null; then
    echo "$joke" | cowsay -f sus | lolcat
  else
    echo "💭 $joke"
  fi
}

# Bitwarden helper: Create new item with auto-generated password
bw-new-item() {
  if [[ "${1}" == "-h" || "${1}" == "--help" ]]; then
    echo "Usage: bw-new-item <item-name> <item-username>"
    echo ""
    echo "Creates a new Bitwarden item with the specified name."
    echo "Generates a random password automatically."
    return 0
  fi
  
  if [[ -z "${1}" ]]; then
    echo "Error: item name and username is required"
    echo "Use 'bw-new-item --help' for usage information"
    return 1
  fi
  
  export BW_SESSION=$(bw unlock --raw)
  local item_name="${1}"
  local password=$(bw generate -ulns)
  local organizationId="f9bb87fe-6c97-40c5-8f53-d43901f548ce"
  local collectionId="c68c3d1f-dc7c-496a-8e97-bd2bc65a9601"
  local login_template=$(bw get template item.login | jq --arg user "${item_name}" --arg pass "${password}" '.username=$user | .password=$pass | .totp=null')
  bw get template item | jq --arg name "${item_name}" --arg oid "${organizationId}" --arg cid "${collectionId}" --argjson login "${login_template}" '.name=$name | .organizationId=$oid | .collectionIds=[$cid] | .notes=null | .login=$login' | bw encode | bw create item
}

# WSL: Setup Windows paths with caching for fast startup
# This function is called by shell init to add Windows tool paths
setup-wsl-windows-paths() {
  # Only run in WSL
  [ -z "$WSL_DISTRO_NAME" ] && return 0
  
  local cache_file="$HOME/.cache/wsl-paths"
  
  # Detect Windows username once and cache it
  if [ ! -f "$cache_file" ] && [ -d "/mnt/c/Users" ]; then
    mkdir -p "$HOME/.cache"
    # Find a valid user directory (skip system accounts and app pools)
    for user_dir in /mnt/c/Users/*/; do
      local username=$(basename "$user_dir")
      # Skip system users and app pools
      case "$username" in
        Public|Default|"Default User"|"All Users"|Administrator|defaultuser*|*AppPool) continue ;;
      esac
      # Found a real user, cache it
      echo "$username" > "$cache_file"
      break
    done
  fi
  
  # Add Windows paths if we have a cached username
  if [ -f "$cache_file" ]; then
    local win_user=$(cat "$cache_file")
    local win_home="/mnt/c/Users/$win_user"
    
    # Only add paths that exist
    [ -d "$win_home/AppData/Local/Programs/Microsoft VS Code/bin" ] && \
      export PATH="$win_home/AppData/Local/Programs/Microsoft VS Code/bin:$PATH"

    [ -d "$win_home/AppData/Local/Microsoft/WindowsApps" ] && \
      export PATH="$win_home/AppData/Local/Microsoft/WindowsApps:$PATH"

    [ -d "$win_home/AppData/Local/Microsoft/WinGet/Links" ] && \
      export PATH="$win_home/AppData/Local/Microsoft/WinGet/Links:$PATH"

    [ -d "$win_home/AppData/Local/Microsoft/WinGet/Packages/equalsraf.win32yank_Microsoft.Winget.Source_8wekyb3d8bbwe" ] && \
      export PATH="$win_home/AppData/Local/Microsoft/WinGet/Packages/equalsraf.win32yank_Microsoft.Winget.Source_8wekyb3d8bbwe:$PATH"
  fi
}
