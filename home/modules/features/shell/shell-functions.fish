# WSL: Setup Windows paths with caching for fast startup
# This function is called by fish shell init to add Windows tool paths
function setup-wsl-windows-paths
  # Only run in WSL
  if not set -q WSL_DISTRO_NAME
    return 0
  end
  
  set cache_file "$HOME/.cache/wsl-paths"
  
  # Detect Windows username once and cache it
  if not test -f "$cache_file"; and test -d "/mnt/c/Users"
    mkdir -p "$HOME/.cache"
    # Find a valid user directory (skip system accounts and app pools)
    for user_dir in /mnt/c/Users/*/
      set username (basename "$user_dir")
      # Skip system users and app pools
      switch "$username"
        case Public Default "Default User" "All Users" Administrator 'defaultuser*' '*AppPool'
          continue
      end
      # Found a real user, cache it
      echo "$username" > "$cache_file"
      break
    end
  end
  
  # Add Windows paths if we have a cached username
  if test -f "$cache_file"
    set win_user (cat "$cache_file")
    set win_home "/mnt/c/Users/$win_user"
    
    # Only add paths that exist
    if test -d "$win_home/AppData/Local/Programs/Microsoft VS Code/bin"
      fish_add_path "$win_home/AppData/Local/Programs/Microsoft VS Code/bin"
    end
    
    if test -d "$win_home/AppData/Local/Microsoft/WinGet/Packages/equalsraf.win32yank_Microsoft.Winget.Source_8wekyb3d8bbwe"
      fish_add_path "$win_home/AppData/Local/Microsoft/WinGet/Packages/equalsraf.win32yank_Microsoft.Winget.Source_8wekyb3d8bbwe"
    end
  end
end
