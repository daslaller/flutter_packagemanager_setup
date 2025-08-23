#!/bin/bash

# Flutter Package Manager
# Easily add GitHub repositories as dependencies

set -e

echo "📦 Flutter Package Manager"
echo "=========================="

# Source shared functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Source shared functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Multi-selection menu function
# Usage: multiselect "prompt" array_name selected_indices_var_name [single_mode] [debug_mode]
multiselect() {
    local prompt="$1"
    local options_array_name="$2"
    local selected_array_name="$3"
    local single_mode="${4:-false}"
    local debug_mode="${5:-false}"

    # Create local reference to the options array (bash 3.x compatible)
    eval "local options_ref=(\"\${${options_array_name}[@]}\")"

    local selected=()
    local cursor=0
    local selected_indices=()
    local window_start=0
    local window_size=10

    # Initialize selected array with false values
    for ((i=0; i<${#options_ref[@]}; i++)); do
        selected[i]=false
    done

    draw_menu() {
        clear
        echo "$prompt"
        echo ""
        if [[ "$single_mode" == "true" ]]; then
            echo "Use ↑/↓ or j/k to navigate, SPACE/ENTER to select, numbers for direct select, q to quit"
        else
            echo "Use ↑/↓ or j/k to navigate, SPACE to select/deselect, ENTER to confirm, numbers for direct select, q to quit"
        fi

        # Calculate window bounds
        local window_end=$((window_start + window_size))
        if [[ $window_end -gt ${#options_ref[@]} ]]; then
            window_end=${#options_ref[@]}
        fi

        echo ""

        # Show 'hidden above' indicator above the list
        if [[ $window_start -gt 0 ]]; then
            echo "... ($window_start more above) ..."
            echo ""
        fi

        for ((i=window_start; i<window_end; i++)); do
            local prefix="  "
            local checkbox="[ ]"

            # Check if this item is selected
            if [[ "${selected[i]}" == "true" ]]; then
                if [[ "$single_mode" == "true" ]]; then
                    checkbox="[●]"
                else
                    checkbox="[✓]"
                fi
            fi

            # Highlight current cursor position
            if [[ $i -eq $cursor ]]; then
                prefix="► "
                echo -e "\033[7m$prefix$checkbox ${options_ref[i]}\033[0m"
            else
                echo "$prefix$checkbox ${options_ref[i]}"
            fi
        done

        # Show 'hidden below' indicator below the list
        if [[ $window_end -lt ${#options_ref[@]} ]]; then
            local remaining=$((${#options_ref[@]} - window_end))
            echo ""
            echo "... ($remaining more below) ..."
        fi

        echo ""
        if [[ "$single_mode" == "true" ]]; then
            if [[ ${#selected_indices[@]} -gt 0 ]]; then
                echo "Selected: ${options_ref[${selected_indices[0]}]}"
            else
                echo "No selection"
            fi
        else
            echo "Selected: ${#selected_indices[@]} items"
        fi
    }

    # Ensure we have a proper terminal for input
    if [[ ! -t 0 && ! -t 1 && ! -t 2 ]]; then
        echo "❌ Error: This function requires an interactive terminal"
        return 1
    fi

    # Open the controlling TTY explicitly and manage its mode locally
    local old_stty=""
    if [[ -t 0 ]]; then
        old_stty=$(stty -g 2>/dev/null)
    else
        old_stty=$(stty -g </dev/tty 2>/dev/null)
    fi

    # Use a dedicated FD for /dev/tty so stdin can't interfere
    exec 3</dev/tty 2>/dev/null || exec 3<&0

    # Non-canonical, no-echo for precise key reading on the TTY
    stty -echo -icanon min 1 time 0 </dev/tty 2>/dev/null

    cleanup() {
        # Restore terminal settings and close FD
        if [[ -n "$old_stty" ]]; then
            stty "$old_stty" </dev/tty 2>/dev/null || true
        fi
        exec 3<&- 2>/dev/null || true
    }
    trap cleanup EXIT INT TERM

    while true; do
        draw_menu

        # Read a single key from /dev/tty, skipping nulls
        local key=""
        while true; do
            if read -rsn1 -u 3 key 2>/dev/null; then
                # Filter out spurious nulls
                [[ -n "$key" ]] && break
            fi
        done

        if [[ "$debug_mode" == "true" ]]; then
            echo "DEBUG: Key pressed: '$key' (ASCII: $(printf '%d' "'$key" 2>/dev/null || echo "N/A"))" >> /tmp/multiselect_debug.log
        fi

        case "$key" in
            $'\x1b')  # ESC sequence
                # Try to read the next two bytes of an ANSI sequence with short timeouts
                local k1="" k2=""
                read -rsn1 -u 3 -t 0.02 k1 2>/dev/null || k1=""
                if [[ "$k1" == "[" ]]; then
                    read -rsn1 -u 3 -t 0.02 k2 2>/dev/null || k2=""
                    case "$k2" in
                        A) # Up
                            if ((cursor > 0)); then
                                ((cursor--))
                                (( cursor < window_start )) && window_start=$cursor
                            fi
                            ;;
                        B) # Down
                            if ((cursor < ${#options_ref[@]} - 1)); then
                                ((cursor++))
                                if [[ $cursor -ge $((window_start + window_size)) ]]; then
                                    window_start=$((cursor - window_size + 1))
                                fi
                            fi
                            ;;
                        *) : ;; # ignore other sequences
                    esac
                fi
                ;;
            'j') # Down (vim-style)
                if ((cursor < ${#options_ref[@]} - 1)); then
                    ((cursor++))
                    if [[ $cursor -ge $((window_start + window_size)) ]]; then
                        window_start=$((cursor - window_size + 1))
                    fi
                fi
                ;;
            'k') # Up (vim-style)
                if ((cursor > 0)); then
                    ((cursor--))
                    (( cursor < window_start )) && window_start=$cursor
                fi
                ;;
            ' ') # Space toggles selection in multi-select
                if [[ "$single_mode" == "true" ]]; then
                    for ((i=0; i<${#selected[@]}; i++)); do selected[i]=false; done
                    selected[cursor]=true
                    selected_indices=($cursor)
                    break
                else
                    if [[ "${selected[cursor]}" == "true" ]]; then
                        selected[cursor]=false
                        # Remove from selected_indices
                        local tmp=()
                        for si in "${selected_indices[@]}"; do
                            [[ "$si" != "$cursor" ]] && tmp+=("$si")
                        done
                        selected_indices=("${tmp[@]}")
                    else
                        selected[cursor]=true
                        selected_indices+=($cursor)
                    fi
                fi
                ;;
            $'\r'|$'\n') # Enter
                if [[ "$single_mode" == "true" ]]; then
                    for ((i=0; i<${#selected[@]}; i++)); do selected[i]=false; done
                    selected[cursor]=true
                    selected_indices=($cursor)
                    break
                else
                    if [[ ${#selected_indices[@]} -gt 0 ]]; then
                        break
                    else
                        echo ""
                        echo "⚠️  No items selected. Use SPACE to select items, then ENTER to confirm."
                        sleep 1
                    fi
                fi
                ;;
            'q'|'Q') # Quit
                selected_indices=()
                break
                ;;
            [1-9]) # Direct select by number (1-9)
                local num=$(( $(printf '%d' "'$key") - 48 ))
                if (( num>=1 && num<=${#options_ref[@]} )); then
                    local idx=$((num-1))
                    if [[ "$single_mode" == "true" ]]; then
                        for ((i=0; i<${#selected[@]}; i++)); do selected[i]=false; done
                        selected[idx]=true
                        selected_indices=($idx)
                        cursor=$idx
                        break
                    else
                        if [[ "${selected[idx]}" == "true" ]]; then
                            selected[idx]=false
                            # Remove
                            local tmp=()
                            for si in "${selected_indices[@]}"; do
                                [[ "$si" != "$idx" ]] && tmp+=("$si")
                            done
                            selected_indices=("${tmp[@]}")
                        else
                            selected[idx]=true
                            selected_indices+=("$idx")
                        fi
                        cursor=$idx
                        if [[ $cursor -lt $window_start || $cursor -ge $((window_start + window_size)) ]]; then
                            window_start=$((cursor - window_size / 2))
                            (( window_start < 0 )) && window_start=0
                        fi
                    fi
                fi
                ;;
            *) : ;; # ignore other keys
        esac
    done

    # Restore terminal settings and close tty FD
    cleanup

    # Sort selected indices
    if [[ ${#selected_indices[@]} -gt 0 ]]; then
        IFS=$'\n' selected_indices=($(sort -n <<<"${selected_indices[*]}"))
        unset IFS
    fi

    # Return selected indices using eval (bash 3.x compatible)
    eval "${selected_array_name}=(\"\${selected_indices[@]}\")"

    clear
}
source "$SCRIPT_DIR/../shared/multiselect.sh"
source "$SCRIPT_DIR/../shared/cross_platform_utils.sh"

# Default configuration
CONFIG_SEARCH_PATHS=("$HOME/Development" "$HOME/Projects" "$HOME/dev" ".")
CONFIG_SEARCH_DEPTH=3
CONFIG_FULL_DISK_SEARCH=false

# Function to configure search settings
configure_search_settings() {
    echo ""
    echo "⚙️  Search Configuration"
    echo "========================="
    echo ""

    # Show current settings
    echo "Current search paths:"
    for i in "${!CONFIG_SEARCH_PATHS[@]}"; do
        echo "  $((i+1)). ${CONFIG_SEARCH_PATHS[$i]}"
    done
    echo ""
    echo "Current search depth: $CONFIG_SEARCH_DEPTH"
    echo "Full disk search: $CONFIG_FULL_DISK_SEARCH"
    echo ""

    # Configuration options
    echo "Configuration options:"
    echo "1. Add custom search path"
    echo "2. Remove search path"
    echo "3. Set search depth"
    echo "4. Toggle full disk search"
    echo "5. Reset to defaults"
    echo "6. Continue with current settings"
    echo ""

    while true; do
        read -p "Enter your choice (1-6): " CONFIG_CHOICE

        case "$CONFIG_CHOICE" in
            1)
                echo ""
                read -p "Enter new search path: " NEW_PATH
                if [ -n "$NEW_PATH" ] && [ -d "$NEW_PATH" ]; then
                    CONFIG_SEARCH_PATHS+=("$NEW_PATH")
                    echo "✅ Added: $NEW_PATH"
                elif [ -n "$NEW_PATH" ]; then
                    echo "❌ Directory does not exist: $NEW_PATH"
                fi
                echo ""
                ;;
            2)
                if [ ${#CONFIG_SEARCH_PATHS[@]} -gt 1 ]; then
                    echo ""
                    echo "Select path to remove:"
                    for i in "${!CONFIG_SEARCH_PATHS[@]}"; do
                        echo "  $((i+1)). ${CONFIG_SEARCH_PATHS[$i]}"
                    done
                    read -p "Enter number: " REMOVE_NUM
                    if [[ "$REMOVE_NUM" =~ ^[0-9]+$ ]] && [ "$REMOVE_NUM" -ge 1 ] && [ "$REMOVE_NUM" -le ${#CONFIG_SEARCH_PATHS[@]} ]; then
                        REMOVED_PATH="${CONFIG_SEARCH_PATHS[$((REMOVE_NUM-1))]}"
                        unset CONFIG_SEARCH_PATHS[$((REMOVE_NUM-1))]
                        CONFIG_SEARCH_PATHS=("${CONFIG_SEARCH_PATHS[@]}")  # Reindex array
                        echo "✅ Removed: $REMOVED_PATH"
                    else
                        echo "❌ Invalid selection"
                    fi
                else
                    echo "❌ Cannot remove - at least one search path required"
                fi
                echo ""
                ;;
            3)
                echo ""
                read -p "Enter search depth (current: $CONFIG_SEARCH_DEPTH): " NEW_DEPTH
                if [[ "$NEW_DEPTH" =~ ^[0-9]+$ ]] && [ "$NEW_DEPTH" -gt 0 ]; then
                    CONFIG_SEARCH_DEPTH="$NEW_DEPTH"
                    echo "✅ Search depth set to: $CONFIG_SEARCH_DEPTH"
                else
                    echo "❌ Invalid depth. Must be a positive number."
                fi
                echo ""
                ;;
            4)
                if [ "$CONFIG_FULL_DISK_SEARCH" = "true" ]; then
                    CONFIG_FULL_DISK_SEARCH=false
                    echo "✅ Full disk search disabled"
                else
                    CONFIG_FULL_DISK_SEARCH=true
                    echo "⚠️  Full disk search enabled (may be slow)"
                fi
                echo ""
                ;;
            5)
                CONFIG_SEARCH_PATHS=("$HOME/Development" "$HOME/Projects" "$HOME/dev" ".")
                CONFIG_SEARCH_DEPTH=3
                CONFIG_FULL_DISK_SEARCH=false
                echo "✅ Reset to defaults"
                echo ""
                ;;
            6)
                echo "✅ Continuing with current settings"
                return 0
                ;;
            *)
                echo "❌ Invalid choice. Please enter 1-6."
                ;;
        esac
    done
}

# Function to select project source - returns choice via global variable
select_project_source() {
    echo ""
    echo "📱 Flutter Package Manager - Main Menu:"
    echo "1. Scan local directories for existing Flutter projects"
    echo "2. Fetch Flutter project from GitHub repository"
    echo "3. Configure search settings"
    echo ""

    while true; do
        read -p "Enter your choice (1-3): " SOURCE_CHOICE

        case "$SOURCE_CHOICE" in
            1)
                echo "🔍 Selected: Local directory scan"
                PROJECT_SOURCE_CHOICE=1
                return 0
                ;;
            2)
                echo "📥 Selected: GitHub repository fetch"
                PROJECT_SOURCE_CHOICE=2
                return 0
                ;;
            3)
                echo "⚙️  Selected: Configure search settings"
                PROJECT_SOURCE_CHOICE=3
                return 0
                ;;
            *)
                echo "❌ Invalid choice. Please enter 1-3."
                ;;
        esac
    done
}

# Function to get save location for GitHub projects
get_save_location() {
    echo ""
    echo "📁 Choose save location for GitHub project:"
    echo ""

    # Default options - current directory first as most common use case
    DEFAULT_LOCATIONS=(
        "."
        "$HOME/Development/github-projects"
        "$HOME/Projects/github-projects"
        "$HOME/dev/github-projects"
        "./github-projects"
    )

    echo "Suggested locations:"
    for i in "${!DEFAULT_LOCATIONS[@]}"; do
        local display_path="${DEFAULT_LOCATIONS[$i]}"
        if [ "$display_path" = "." ]; then
            display_path="$(pwd) (current directory)"
        fi
        if [ $i -eq 0 ]; then
            echo "$((i+1)). $display_path [DEFAULT]"
        else
            echo "$((i+1)). $display_path"
        fi
    done
    echo "$((${#DEFAULT_LOCATIONS[@]}+1)). Enter custom path"
    echo ""

    while true; do
        read -p "Enter your choice (default: 1): " LOCATION_CHOICE

        # Default to option 1 (current directory) if empty
        if [ -z "$LOCATION_CHOICE" ]; then
            LOCATION_CHOICE=1
        fi

        if [[ "$LOCATION_CHOICE" =~ ^[0-9]+$ ]] && [ "$LOCATION_CHOICE" -ge 1 ] && [ "$LOCATION_CHOICE" -le ${#DEFAULT_LOCATIONS[@]} ]; then
            SELECTED_LOCATION="${DEFAULT_LOCATIONS[$((LOCATION_CHOICE-1))]}"
            break
        elif [ "$LOCATION_CHOICE" -eq $((${#DEFAULT_LOCATIONS[@]}+1)) ]; then
            read -p "Enter custom path: " CUSTOM_PATH
            if [ -n "$CUSTOM_PATH" ]; then
                SELECTED_LOCATION="$CUSTOM_PATH"
                break
            else
                echo "❌ Path cannot be empty"
            fi
        else
            echo "❌ Invalid choice. Please try again."
        fi
    done

    # Create directory if it doesn't exist
    if [ ! -d "$SELECTED_LOCATION" ]; then
        echo "📁 Creating directory: $SELECTED_LOCATION"
        mkdir -p "$SELECTED_LOCATION" || {
            echo "❌ Failed to create directory: $SELECTED_LOCATION"
            return 1
        }
    fi

    echo "✅ Save location: $SELECTED_LOCATION"
    PROJECT_SAVE_LOCATION="$SELECTED_LOCATION"
}

# Function to fetch GitHub project
fetch_github_project() {
    local SAVE_LOCATION="$1"

    echo ""
    echo "🔍 GitHub Project Options:"
    echo "1. Enter specific repository URL (e.g., github.com/user/flutter-project)"
    echo "2. Browse and select from your GitHub repositories"
    echo ""

    while true; do
        read -p "Choose option (1-2): " GITHUB_OPTION

        case "$GITHUB_OPTION" in
            1)
                fetch_by_url "$SAVE_LOCATION"
                return $?
                ;;
            2)
                fetch_from_user_repos "$SAVE_LOCATION"
                return $?
                ;;
            *)
                echo "❌ Invalid choice. Please enter 1 or 2."
                ;;
        esac
    done
}

# Function to fetch by URL
fetch_by_url() {
    local SAVE_LOCATION="$1"

    echo ""
    read -p "Enter GitHub repository URL or user/repo format: " REPO_INPUT

    if [ -z "$REPO_INPUT" ]; then
        echo "❌ Repository URL cannot be empty"
        return 1
    fi

    # Parse repository URL/format
    REPO_URL=""
    if [[ "$REPO_INPUT" =~ ^https://github.com/ ]]; then
        REPO_URL="$REPO_INPUT"
    elif [[ "$REPO_INPUT" =~ ^github.com/ ]]; then
        REPO_URL="https://$REPO_INPUT"
    elif [[ "$REPO_INPUT" =~ ^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$ ]]; then
        REPO_URL="https://github.com/$REPO_INPUT"
    else
        echo "❌ Invalid repository format. Use: user/repo or full GitHub URL"
        return 1
    fi

    clone_and_scan_project "$REPO_URL" "$SAVE_LOCATION"
}

# Function to fetch from user repositories
fetch_from_user_repos() {
    local SAVE_LOCATION="$1"

    echo ""
    echo "🔍 Fetching your repositories..."

    # Get all user repositories
    local REPO_JSON
    REPO_JSON=$(gh repo list --json name,owner,url,description)

    if [ -z "$REPO_JSON" ] || [ "$REPO_JSON" = "[]" ]; then
        echo "❌ No repositories found"
        return 1
    fi

    # Create array of repository display strings (bash 3.x compatible)
    local REPO_OPTIONS=()
    while IFS= read -r line; do
        REPO_OPTIONS+=("$line")
    done < <(echo "$REPO_JSON" | jq -r '.[] | "\(.owner.login)/\(.name) - \(.description // "No description")"')

    # Create array of repository URLs for processing (bash 3.x compatible)
    local REPO_URLS=()
    while IFS= read -r line; do
        REPO_URLS+=("$line")
    done < <(echo "$REPO_JSON" | jq -r '.[] | .url')

    if [ ${#REPO_OPTIONS[@]} -eq 0 ]; then
        echo "❌ No repositories found"
        return 1
    fi

    echo ""
    echo "📋 Found ${#REPO_OPTIONS[@]} repositories:"
    echo ""

    # Use multiselect function in single selection mode
    local SELECTED_INDICES=()
    multiselect "Select repository to clone:" REPO_OPTIONS SELECTED_INDICES true

    if [ ${#SELECTED_INDICES[@]} -eq 0 ]; then
        echo "❌ No repository selected"
        return 1
    fi

    # Clone the selected repository
    local SELECTED_INDEX="${SELECTED_INDICES[0]}"
    local SELECTED_REPO_URL="${REPO_URLS[$SELECTED_INDEX]}"

    clone_and_scan_project "$SELECTED_REPO_URL" "$SAVE_LOCATION"
}

# Function to clone and scan project
clone_and_scan_project() {
    local REPO_URL="$1"
    local SAVE_LOCATION="$2"

    # Extract repository name from URL
    local REPO_NAME
    REPO_NAME=$(basename "$REPO_URL" .git)
    local CLONE_PATH="$SAVE_LOCATION/$REPO_NAME"

    echo ""
    echo "📥 Cloning repository..."
    echo "Repository: $REPO_URL"
    echo "Location: $CLONE_PATH"

    # Check if directory already exists
    if [ -d "$CLONE_PATH" ]; then
        echo "⚠️  Directory already exists: $CLONE_PATH"
        read -p "Remove existing directory and re-clone? (y/N): " OVERWRITE
        if [[ $OVERWRITE =~ ^[Yy]$ ]]; then
            rm -rf "$CLONE_PATH"
        else
            echo "📁 Using existing directory"
        fi
    fi

    # Clone repository if directory doesn't exist
    if [ ! -d "$CLONE_PATH" ]; then
        if ! git clone "$REPO_URL" "$CLONE_PATH"; then
            echo "❌ Failed to clone repository"
            return 1
        fi
        echo "✅ Repository cloned successfully"
    fi

    # Scan for Flutter projects in the cloned repository
    echo ""
    echo "🔍 Scanning for Flutter projects in cloned repository..."

    local CLONED_FLUTTER_PROJECTS=()
    while IFS= read -r -d '' project; do
        CLONED_FLUTTER_PROJECTS+=("$project")
    done < <(find "$CLONE_PATH" -name "pubspec.yaml" -print0 2>/dev/null)

    if [ ${#CLONED_FLUTTER_PROJECTS[@]} -eq 0 ]; then
        echo "❌ No Flutter projects (pubspec.yaml files) found in the cloned repository"
        echo "💡 This might not be a Flutter project or the pubspec.yaml files are in unexpected locations"
        return 1
    fi

    echo "✅ Found ${#CLONED_FLUTTER_PROJECTS[@]} Flutter project(s)"

    # Store the found projects globally for the main script to use
    FLUTTER_PROJECTS=("${CLONED_FLUTTER_PROJECTS[@]}")
    return 0
}

# Function to get relative path (cross-platform)
get_relative_path() {
    local target="$1"
    local base="${2:-$(pwd)}"

    # Try GNU realpath with --relative-to (newer Linux distributions)
    if command -v realpath >/dev/null 2>&1 && realpath --relative-to="$base" "$target" >/dev/null 2>&1; then
        realpath --relative-to="$base" "$target"
    # Try python as fallback (available on most systems)
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "import os.path; print(os.path.relpath('$target', '$base'))" 2>/dev/null || echo "$target"
    elif command -v python >/dev/null 2>&1; then
        python -c "import os.path; print(os.path.relpath('$target', '$base'))" 2>/dev/null || echo "$target"
    else
        # Final fallback - just show the full path
        echo "$target"
    fi
}

# Function to add package to pubspec.yaml
add_package_to_pubspec() {
    local PUBSPEC_PATH="$1"
    local PACKAGE_NAME="$2"
    local REPO_URL="$3"
    local REF="$4"

    echo "📝 Adding $PACKAGE_NAME to pubspec.yaml..."

    # Backup original file
    cp "$PUBSPEC_PATH" "$PUBSPEC_PATH.backup"

    # Check if package already exists
    if grep -q "^[[:space:]]*$PACKAGE_NAME:" "$PUBSPEC_PATH"; then
        echo "⚠️  Package $PACKAGE_NAME already exists in pubspec.yaml"
        read -p "Replace it? (y/N): " REPLACE
        if [[ ! $REPLACE =~ ^[Yy]$ ]]; then
            echo "❌ Cancelled"
            return 1
        fi
        # Remove existing entry - use cross-platform sed
        cross_platform_sed "/^[[:space:]]*$PACKAGE_NAME:/d" "$PUBSPEC_PATH"
    fi

    # Find the dependencies section and add the package
    if grep -q "^dependencies:" "$PUBSPEC_PATH"; then
        # Create temporary file with the new dependency
        TEMP_FILE=$(mktemp)

        awk -v pkg="$PACKAGE_NAME" -v url="$REPO_URL" -v ref="$REF" '
        /^dependencies:/ {
            print $0
            print "  " pkg ":"
            print "    git:"
            print "      url: " url
            if (ref != "") print "      ref: " ref
            in_deps = 1
            next
        }
        /^[a-zA-Z]/ && in_deps && !/^dependencies:/ {
            in_deps = 0
        }
        { print }
        ' "$PUBSPEC_PATH" > "$TEMP_FILE"

        mv "$TEMP_FILE" "$PUBSPEC_PATH"
    else
        # Add dependencies section at the end
        echo "" >> "$PUBSPEC_PATH"
        echo "dependencies:" >> "$PUBSPEC_PATH"
        echo "  $PACKAGE_NAME:" >> "$PUBSPEC_PATH"
        echo "    git:" >> "$PUBSPEC_PATH"
        echo "      url: $REPO_URL" >> "$PUBSPEC_PATH"
        if [ -n "$REF" ]; then
            echo "      ref: $REF" >> "$PUBSPEC_PATH"
        fi
    fi

    echo "✅ Added $PACKAGE_NAME to dependencies"
}

# Function to install missing dependencies
install_dependencies() {
    local missing_deps=()
    local failed_installs=()

    # Check for GitHub CLI
    if ! command -v gh &> /dev/null; then
        missing_deps+=("gh")
    fi

    # Check for jq
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "📦 Missing required dependencies: ${missing_deps[*]}"
        echo "🔧 Attempting automatic installation..."
        echo ""

        for dep in "${missing_deps[@]}"; do
            echo "Installing $dep..."
            if auto_install_package "$dep"; then
                echo "✅ $dep installation completed"
            else
                echo "❌ Failed to install $dep automatically"
                failed_installs+=("$dep")
            fi
            echo ""
        done

        # Check if installations were successful
        missing_after_install=()
        for dep in "${missing_deps[@]}"; do
            if ! command -v "$dep" &> /dev/null; then
                missing_after_install+=("$dep")
            fi
        done

        if [ ${#missing_after_install[@]} -gt 0 ]; then
            echo "❌ Some dependencies are still missing: ${missing_after_install[*]}"
            echo ""
            echo "Please install them manually using your package manager:"
            echo ""

            for dep in "${missing_after_install[@]}"; do
                echo "For $dep:"
                if [[ "$dep" == "gh" ]]; then
                    echo "  # GitHub CLI installation varies by distribution"
                    echo "  # See: https://cli.github.com for specific instructions"
                    echo "  # Or try these common methods:"
                    suggest_package_install "gh"
                else
                    suggest_package_install "$dep"
                fi
                echo ""
            done
            exit 1
        else
            echo "✅ All dependencies installed successfully!"
            echo ""
        fi
    fi
}

# Check dependencies
install_dependencies

# Function to authenticate with GitHub automatically
authenticate_github() {
    echo "🔐 Setting up GitHub authentication..."
    echo ""

    # Open browser first using cascade fallback
    echo "🌐 Opening GitHub authentication in your browser..."
    if open "https://github.com/login/device" &>/dev/null; then
        echo "✅ Browser opened successfully"
    elif command -v xdg-open &>/dev/null && xdg-open "https://github.com/login/device" &>/dev/null; then
        echo "✅ Browser opened successfully"
    elif open_browser "https://github.com/login/device"; then
        echo "✅ Browser opened successfully"
    else
        echo "❌ Could not open browser automatically."
        echo "📝 Please visit: https://github.com/login/device"
    fi

    echo ""
    echo "🔑 Starting authentication process..."
    echo "💡 The GitHub CLI will show you a code to enter in the browser"
    echo ""

    # Create a named pipe to capture the output and display it while running
    TEMP_OUTPUT=$(mktemp)

    # Run gh auth login and capture output
    {
        gh auth login --web --hostname github.com 2>&1 | tee "$TEMP_OUTPUT"
    } &
    GH_PID=$!

    # Monitor the output for the authentication code
    sleep 2
    while kill -0 $GH_PID 2>/dev/null; do
        if [ -f "$TEMP_OUTPUT" ]; then
            AUTH_CODE=$(grep -oE '[A-Z0-9]{4}-[A-Z0-9]{4}' "$TEMP_OUTPUT" 2>/dev/null | head -1)
            if [ -n "$AUTH_CODE" ] && [ ! -f "/tmp/code_copied_$AUTH_CODE" ]; then
                echo ""
                echo "📋 🎯 Authentication Code Found: $AUTH_CODE"
                echo ""
                echo "📎 Copying code to clipboard..."
                if copy_to_clipboard "$AUTH_CODE"; then
                    echo "✅ Code copied! Switch to your browser and paste it."
                else
                    echo "⚠️  Please copy manually: $AUTH_CODE"
                fi
                echo ""

                # Mark that we've processed this code
                touch "/tmp/code_copied_$AUTH_CODE"
            fi
        fi
        sleep 1
    done

    # Wait for the gh process to complete
    wait $GH_PID
    GH_EXIT_CODE=$?

    # Clean up
    rm -f "$TEMP_OUTPUT" "/tmp/code_copied_"* 2>/dev/null

    if [ $GH_EXIT_CODE -eq 0 ] && gh auth status &>/dev/null; then
        echo ""
        echo "✅ GitHub authentication successful!"
        return 0
    else
        echo ""
        echo "❌ Authentication failed or was cancelled."
        echo ""
        echo "🔧 You can try again by running: gh auth login --web"
        echo ""
        return 1
    fi
}

# Check if authenticated with GitHub
if ! gh auth status &>/dev/null; then
    echo "❌ Not authenticated with GitHub."
    echo ""
    read -p "🚀 Would you like to authenticate now? (Y/n): " auth_choice

    if [[ "$auth_choice" =~ ^[Nn]$ ]]; then
        echo "ℹ️  You can authenticate later with: gh auth login"
        exit 1
    fi

    authenticate_github
fi

# Enhanced project discovery with GitHub integration
FLUTTER_PROJECTS=()
SELECTED_PUBSPEC=""
SELECTED_PROJECT=""

# Check if current directory has pubspec.yaml
CURRENT_PUBSPEC="./pubspec.yaml"
if [ -f "$CURRENT_PUBSPEC" ]; then
    echo "📱 Found pubspec.yaml in current directory"
    read -p "Use current directory project? (Y/n): " USE_CURRENT

    if [[ ! $USE_CURRENT =~ ^[Nn]$ ]]; then
        SELECTED_PUBSPEC="$CURRENT_PUBSPEC"
        SELECTED_PROJECT=$(basename "$(pwd)")
        echo "📱 Using project: $SELECTED_PROJECT"

        # CRITICAL FIX: Initialize terminal state that GitHub operations would have done
        if command -v stty >/dev/null 2>&1; then
            # Save current state
            ORIGINAL_STTY=$(stty -g 2>/dev/null)

            # Force a terminal reset like GitHub CLI operations do
            stty sane

            # Simulate the input/output that primes the terminal for multiselect
            # This is what's missing when we skip GitHub operations
            printf "\r" >/dev/tty

            # Brief delay to let terminal settle
            sleep 0.05
        fi
    fi
fi

# If no project selected yet, proceed with source selection
if [ -z "$SELECTED_PUBSPEC" ]; then
    # Main loop for handling configuration and project selection
    while true; do
        select_project_source

        case $PROJECT_SOURCE_CHOICE in
            3)
                # Configuration
                configure_search_settings
                continue  # Go back to main menu
                ;;
            *)
                break  # Exit loop for other choices
                ;;
        esac
    done

    case $PROJECT_SOURCE_CHOICE in
        1)
            # Local directory scan
            echo ""
            echo "🔍 Searching for local Flutter projects..."

            # Use configured search paths and settings
            if [ "$CONFIG_FULL_DISK_SEARCH" = "true" ]; then
                echo "⚠️  Performing full disk search (this may take a while)..."
                while IFS= read -r -d '' project; do
                    FLUTTER_PROJECTS+=("$project")
                done < <(find / -name "pubspec.yaml" -print0 2>/dev/null)
            else
                for dir in "${CONFIG_SEARCH_PATHS[@]}"; do
                    if [ -d "$dir" ]; then
                        echo "🔍 Searching in: $dir (depth: $CONFIG_SEARCH_DEPTH)"
                        while IFS= read -r -d '' project; do
                            FLUTTER_PROJECTS+=("$project")
                        done < <(find "$dir" -maxdepth "$CONFIG_SEARCH_DEPTH" -name "pubspec.yaml" -print0 2>/dev/null)
                    fi
                done
            fi

            if [ ${#FLUTTER_PROJECTS[@]} -eq 0 ]; then
                echo "❌ No Flutter projects found in configured directories."
                echo "💡 Try configuring different search paths, enabling full disk search, or use the GitHub fetch option."
                exit 1
            fi
            ;;
        2)
            # GitHub repository fetch
            get_save_location
            if [ $? -ne 0 ]; then
                echo "❌ Failed to get save location"
                exit 1
            fi

            if ! fetch_github_project "$PROJECT_SAVE_LOCATION"; then
                echo "❌ Failed to fetch GitHub project"
                exit 1
            fi

            if [ ${#FLUTTER_PROJECTS[@]} -eq 0 ]; then
                echo "❌ No Flutter projects found in the fetched repository"
                exit 1
            fi
            ;;
        *)
            echo "❌ Invalid source selection: $PROJECT_SOURCE_CHOICE"
            exit 1
            ;;
    esac

    # Project selection from found projects
    if [ ${#FLUTTER_PROJECTS[@]} -eq 1 ]; then
        # Only one project found, use it directly
        SELECTED_PUBSPEC="${FLUTTER_PROJECTS[0]}"
        SELECTED_PROJECT=$(basename "$(dirname "$SELECTED_PUBSPEC")")
        echo "📱 Using project: $SELECTED_PROJECT"
    else
        # Multiple projects found, let user choose
        echo ""
        echo "📋 Found ${#FLUTTER_PROJECTS[@]} Flutter projects:"
        for i in "${!FLUTTER_PROJECTS[@]}"; do
            PROJECT_DIR=$(dirname "${FLUTTER_PROJECTS[$i]}")
            PROJECT_NAME=$(basename "$PROJECT_DIR")
            RELATIVE_PATH=$(get_relative_path "$PROJECT_DIR")
            echo "$((i+1)). $PROJECT_NAME ($RELATIVE_PATH)"
        done

        echo ""
        read -p "Enter project number: " PROJECT_NUM

        if [[ ! "$PROJECT_NUM" =~ ^[0-9]+$ ]] || [ "$PROJECT_NUM" -lt 1 ] || [ "$PROJECT_NUM" -gt ${#FLUTTER_PROJECTS[@]} ]; then
            echo "❌ Invalid selection"
            exit 1
        fi

        SELECTED_PUBSPEC="${FLUTTER_PROJECTS[$((PROJECT_NUM-1))]}"
        SELECTED_PROJECT=$(basename "$(dirname "$SELECTED_PUBSPEC")")
        echo "📱 Using project: $SELECTED_PROJECT"
    fi
fi

# Get repositories
echo ""
echo "🔍 Fetching your repositories..."

# Get repository data as JSON for processing
REPO_JSON=$(gh repo list --limit 100 --json name,owner,isPrivate,url,description)

if [ -z "$REPO_JSON" ] || [ "$REPO_JSON" = "[]" ]; then
    echo "❌ No repositories found"
    exit 1
fi

# Create array of repository display strings (bash 3.x compatible)
REPO_OPTIONS=()
while IFS= read -r line; do
    REPO_OPTIONS+=("$line")
done < <(echo "$REPO_JSON" | jq -r '.[] | "\(.owner.login)/\(.name) (\(if .isPrivate then "private" else "public" end)) - \(.description // "No description")"')

# Create array of repository full names for processing (bash 3.x compatible)
REPO_NAMES=()
while IFS= read -r line; do
    REPO_NAMES+=("$line")
done < <(echo "$REPO_JSON" | jq -r '.[] | "\(.owner.login)/\(.name)"')

if [ ${#REPO_OPTIONS[@]} -eq 0 ]; then
    echo "❌ No repositories found"
    exit 1
fi

echo ""
echo "📋 Select repositories to add as packages:"
echo ""

# CRITICAL FIX: When starting from current directory (pubspec.yaml present),
# we missed the terminal initialization that GitHub operations provide.
# We need to simulate what gh commands do to properly initialize terminal input handling.
if [ -f "./pubspec.yaml" ] && [ -n "$SELECTED_PUBSPEC" ]; then
    # We used current directory, so we missed GitHub operations that initialize terminal
    echo "🔧 Initializing terminal for interactive selection..."

    # Simulate the exact terminal initialization that GitHub CLI operations perform
    if command -v stty >/dev/null 2>&1; then
        # This is what gh repo list and other gh commands do internally
        stty -icanon min 1 time 0 2>/dev/null

        # Critical: simulate the I/O interaction that gh commands create
        # This primes the terminal's input buffer handling
        printf '' >/dev/tty, c 2>/dev/null

        # Brief settle time like network operations create
        sleep 0.02

        # Reset to normal state for the prompt display
        stty icanon 2>/dev/null
    fi

    echo "✓ Terminal ready for selection"
fi

# Use multiselect function
SELECTED_INDICES=()
multiselect "Select repositories (SPACE to select, ENTER to confirm):" REPO_OPTIONS SELECTED_INDICES

if [ ${#SELECTED_INDICES[@]} -eq 0 ]; then
    echo "❌ No repositories selected"
    exit 1
fi

echo "📦 Selected ${#SELECTED_INDICES[@]} repositories:"
SELECTED_REPOS=()
for idx in "${SELECTED_INDICES[@]}"; do
    echo "  - ${REPO_NAMES[idx]}"
    SELECTED_REPOS+=("${REPO_NAMES[idx]}")
done

# Process each selected repository
echo ""
echo "🔧 Processing selected repositories..."

ADDED_PACKAGES=()
FAILED_PACKAGES=()

for REPO_FULL_NAME in "${SELECTED_REPOS[@]}"; do
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📦 Processing: $REPO_FULL_NAME"

    REPO_NAME=$(echo "$REPO_FULL_NAME" | cut -d'/' -f2)
    REPO_URL="https://github.com/$REPO_FULL_NAME.git"

    # Ask for package name with default
    echo ""
    read -p "Package name for $REPO_FULL_NAME (default: $REPO_NAME): " PACKAGE_NAME
    PACKAGE_NAME=${PACKAGE_NAME:-$REPO_NAME}

    # Sanitize package name (replace hyphens with underscores, etc.)
    PACKAGE_NAME=$(echo "$PACKAGE_NAME" | sed 's/-/_/g' | sed 's/[^a-zA-Z0-9_]//g')

    # Get branches and tags
    echo ""
    echo "🏷️  Available references for $REPO_FULL_NAME:"
    echo "Branches:"
    gh api "repos/$REPO_FULL_NAME/branches" --jq '.[].name' 2>/dev/null | head -5 | sed 's/^/  /' || echo "  (Could not fetch branches)"

    echo "Tags:"
    gh api "repos/$REPO_FULL_NAME/tags" --jq '.[].name' 2>/dev/null | head -3 | sed 's/^/  /' || echo "  (No tags found)"

    echo ""
    read -p "Specify branch/tag (default: main): " REF
    REF=${REF:-main}

    # Add to pubspec
    echo ""
    echo "📝 Adding $PACKAGE_NAME to pubspec.yaml..."
    if add_package_to_pubspec "$SELECTED_PUBSPEC" "$PACKAGE_NAME" "$REPO_URL" "$REF"; then
        ADDED_PACKAGES+=("$PACKAGE_NAME ($REPO_FULL_NAME)")
        echo "✅ Successfully added $PACKAGE_NAME"
    else
        FAILED_PACKAGES+=("$PACKAGE_NAME ($REPO_FULL_NAME)")
        echo "❌ Failed to add $PACKAGE_NAME"
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 Package processing complete!"
echo ""

if [ ${#ADDED_PACKAGES[@]} -gt 0 ]; then
    echo "✅ Successfully added ${#ADDED_PACKAGES[@]} packages:"
    for package in "${ADDED_PACKAGES[@]}"; do
        echo "  ✓ $package"
    done
fi

if [ ${#FAILED_PACKAGES[@]} -gt 0 ]; then
    echo ""
    echo "❌ Failed to add ${#FAILED_PACKAGES[@]} packages:"
    for package in "${FAILED_PACKAGES[@]}"; do
        echo "  ✗ $package"
    done
fi

echo ""
echo "🚀 Next steps:"
PROJECT_DIR=$(dirname "$SELECTED_PUBSPEC")
echo "  cd $PROJECT_DIR"
echo "  flutter pub get"

# Ask if they want to run pub get automatically
if [ "$(dirname "$SELECTED_PUBSPEC")" = "." ]; then
    echo ""
    read -p "Run 'flutter pub get' now? (y/N): " RUN_PUB_GET
    if [[ $RUN_PUB_GET =~ ^[Yy]$ ]]; then
        echo "📦 Running flutter pub get..."
        flutter pub get
        echo "✅ Dependencies installed!"
    fi
fi

if [ ${#ADDED_PACKAGES[@]} -gt 0 ]; then
    echo ""
    echo "💫 Import in your Dart code with:"
    for package in "${ADDED_PACKAGES[@]}"; do
        package_name=$(echo "$package" | cut -d' ' -f1)
        echo "  import 'package:$package_name/$package_name.dart';"
    done
fi
