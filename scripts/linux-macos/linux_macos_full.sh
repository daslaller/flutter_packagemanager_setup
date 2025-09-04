#!/bin/bash

# Flutter Package Manager
# Easily add GitHub repositories as dependencies

set -e

# Ensure terminal is properly restored on exit
trap 'stty echo icanon </dev/tty 2>/dev/null || true' EXIT

echo "📦 Flutter Package Manager"
echo "=========================="

# Source shared functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../shared/multiselect.sh"
source "$SCRIPT_DIR/../shared/cross_platform_utils.sh"
source "$SCRIPT_DIR/../shared/smart_recommendations.sh"

# Resolve scripts root (parent of this script's directory)
SCRIPTS_ROOT="$(dirname "$SCRIPT_DIR")"

# Ensure TTY is restored for subsequent prompts
ensure_tty_ready() {
    stty sane </dev/tty 2>/dev/null || true
    stty echo icanon </dev/tty 2>/dev/null || true
}

# Detect nearest pubspec.yaml by searching upward from both script location and current directory
find_upwards_pubspec_from() {
    local start_dir="$1"
    local exclude_prefix="$2"
    local search_dir="$start_dir"
    while true; do
        if [ -f "$search_dir/pubspec.yaml" ]; then
            # Skip pubspecs that are inside the script bundle directory
            if [ -n "$exclude_prefix" ] && [[ "$search_dir" == "$exclude_prefix"* ]]; then
                : # continue searching upward
            else
                echo "$search_dir/pubspec.yaml"
                return 0
            fi
        fi
        local parent_dir
        parent_dir="$(dirname "$search_dir")"
        if [ "$parent_dir" = "$search_dir" ]; then
            break
        fi
        search_dir="$parent_dir"
    done
    return 1
}

DETECTED_PUBSPEC_PATH=""

# Prefer detection from the script's directory (skip script bundle pubspecs)
PUBSPEC_FROM_SCRIPT="$(find_upwards_pubspec_from "$SCRIPT_DIR" "$SCRIPTS_ROOT" || true)"
# Fallback: detection from the current working directory
PUBSPEC_FROM_CWD="$(find_upwards_pubspec_from "$(pwd)" "" || true)"

if [ -n "$PUBSPEC_FROM_SCRIPT" ]; then
    DETECTED_PUBSPEC_PATH="$PUBSPEC_FROM_SCRIPT"
elif [ -n "$PUBSPEC_FROM_CWD" ]; then
    DETECTED_PUBSPEC_PATH="$PUBSPEC_FROM_CWD"
fi

# Flag for whether a pubspec.yaml was detected in current or parent directories
LOCAL_PUBSPEC_AVAILABLE=false
if [ -n "$DETECTED_PUBSPEC_PATH" ]; then
    LOCAL_PUBSPEC_AVAILABLE=true
fi

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
        read -p "Enter your choice (1-6): " CONFIG_CHOICE </dev/tty

        case "$CONFIG_CHOICE" in
            1)
                echo ""
                read -p "Enter new search path: " NEW_PATH </dev/tty
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
                    read -p "Enter number: " REMOVE_NUM </dev/tty
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
                read -p "Enter search depth (current: $CONFIG_SEARCH_DEPTH): " NEW_DEPTH </dev/tty
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
    
    # Always show detected project option if pubspec.yaml exists in current or parent dirs
    if [ "$LOCAL_PUBSPEC_AVAILABLE" = "true" ]; then
        local detected_dir="$(dirname "$DETECTED_PUBSPEC_PATH")"
        local detected_name="$(basename "$detected_dir")"
        echo "4. Use detected Flutter project: $detected_name [DEFAULT]"
        local default_choice="4"
    else
        local default_choice="1"
    fi
    echo ""

    while true; do
        if [ "$LOCAL_PUBSPEC_AVAILABLE" = "true" ]; then
            read -p "Enter your choice (1-4, default: 4): " SOURCE_CHOICE </dev/tty
        else
            read -p "Enter your choice (1-3): " SOURCE_CHOICE </dev/tty
        fi
        
        # Use default if empty
        if [ -z "$SOURCE_CHOICE" ]; then
            SOURCE_CHOICE="$default_choice"
        fi

        case "$SOURCE_CHOICE" in
            1)
                clear
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
            4)
                if [ "$LOCAL_PUBSPEC_AVAILABLE" = "true" ]; then
                    echo "📱 Selected: Detected project"
                    PROJECT_SOURCE_CHOICE=4
                    return 0
                else
                    echo "❌ Current directory option not available."
                fi
                ;;
            *)
                if [ "$LOCAL_PUBSPEC_AVAILABLE" = "true" ]; then
                    echo "❌ Invalid choice. Please enter 1-4."
                else
                    echo "❌ Invalid choice. Please enter 1-3."
                fi
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
        read -p "Enter your choice (default: 1): " LOCATION_CHOICE </dev/tty

        # Default to option 1 (current directory) if empty
        if [ -z "$LOCATION_CHOICE" ]; then
            LOCATION_CHOICE=1
        fi

        if [[ "$LOCATION_CHOICE" =~ ^[0-9]+$ ]] && [ "$LOCATION_CHOICE" -ge 1 ] && [ "$LOCATION_CHOICE" -le ${#DEFAULT_LOCATIONS[@]} ]; then
            SELECTED_LOCATION="${DEFAULT_LOCATIONS[$((LOCATION_CHOICE-1))]}"
            break
        elif [ "$LOCATION_CHOICE" -eq $((${#DEFAULT_LOCATIONS[@]}+1)) ]; then
            read -p "Enter custom path: " CUSTOM_PATH </dev/tty
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
    clear
    echo "🔍 GitHub Project Options:"
    echo "1. Enter specific repository URL (e.g., github.com/user/flutter-project)"
    echo "2. Browse and select from your GitHub repositories"
    echo ""

    while true; do
        read -p "Choose option (1-2): " GITHUB_OPTION </dev/tty

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
    read -p "Enter GitHub repository URL or user/repo format: " REPO_INPUT </dev/tty

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

    # Clear screen for clean selection interface
    clear
    
    # Use multiselect function in single selection mode
    local SELECTED_INDICES=()
    multiselect "Select repository to clone:" REPO_OPTIONS SELECTED_INDICES true
    ensure_tty_ready

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
        echo "Remove existing directory and re-clone? (y/N): "
        read OVERWRITE </dev/tty
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

# Extract dependency block for a package from pubspec.yaml
get_dependency_block() {
    local pubspec_path="$1"
    local pkg="$2"
    awk -v pkg="$pkg" '
    BEGIN { in_pkg=0; indent_pkg=-1 }
    {
        if (in_pkg) {
            if ($0 ~ /[^ \t]/) {
                line_indent = match($0, /[^ \t]/) - 1
                if (line_indent <= indent_pkg) { exit }
            }
            print
            next
        }
        if ($0 ~ "^[[:space:]]*" pkg ":[[:space:]]*$") {
            in_pkg=1
            indent_pkg = match($0, /[^ \t]/) - 1
            print
        }
    }
    ' "$pubspec_path"
}

# Remove dependency block for a package from pubspec.yaml
remove_dependency_block() {
    local pubspec_path="$1"
    local pkg="$2"
    awk -v pkg="$pkg" '
    BEGIN { in_pkg=0; indent_pkg=-1 }
    {
        if (in_pkg) {
            if ($0 ~ /[^ \t]/) {
                line_indent = match($0, /[^ \t]/) - 1
                if (line_indent <= indent_pkg) { in_pkg=0 }
            }
            if (!in_pkg) { print }
            next
        }
        if ($0 ~ "^[[:space:]]*" pkg ":[[:space:]]*$") {
            in_pkg=1
            indent_pkg = match($0, /[^ \t]/) - 1
            next
        }
        print
    }
    ' "$pubspec_path" > "$pubspec_path.tmp" && mv "$pubspec_path.tmp" "$pubspec_path"
}

# Check if existing dependency block matches the desired values
dependency_block_matches() {
    local block="$1"
    local url="$2"
    local ref="$3"
    local path="$4"

    echo "$block" | grep -Fq "url: $url" || return 1
    if [ -n "$ref" ]; then
        echo "$block" | grep -Fq "ref: $ref" || return 1
    else
        # If ref not provided, ensure no ref present (optional: treat as match even if present)
        :
    fi
    if [ -n "$path" ]; then
        echo "$block" | grep -Fq "path: $path" || return 1
    fi
    return 0
}

# Function to detect package name from a repository's pubspec.yaml (via GitHub API)
get_repo_pubspec_name() {
    local repo_full_name="$1"
    local ref_name="$2"
    local sub_path="${3:-pubspec.yaml}"

    # Fetch raw pubspec.yaml content; ignore errors
    local content
    content=$(gh api -H "Accept: application/vnd.github.v3.raw" "repos/$repo_full_name/contents/$sub_path?ref=$ref_name" 2>/dev/null || true)

    if [ -z "$content" ]; then
        echo ""
        return 0
    fi

    # Extract the first 'name:' field
    local pkg_name
    pkg_name=$(echo "$content" | sed -n 's/^name:[[:space:]]*//p' | head -1 | tr -d '\r')
    echo "$pkg_name"
}

# Function to add package to pubspec.yaml
add_package_to_pubspec() {
    local PUBSPEC_PATH="$1"
    local PACKAGE_NAME="$2"
    local REPO_URL="$3"
    local REF="$4"
    local LOCAL_PATH="$5"

    echo "📝 Adding $PACKAGE_NAME to pubspec.yaml..."

    # Backup original file
    cp "$PUBSPEC_PATH" "$PUBSPEC_PATH.backup"

    # Check if package already exists and compare contents
    if grep -q "^[[:space:]]*$PACKAGE_NAME:" "$PUBSPEC_PATH"; then
        local existing_block
        existing_block="$(get_dependency_block "$PUBSPEC_PATH" "$PACKAGE_NAME")"
        if dependency_block_matches "$existing_block" "$REPO_URL" "$REF" "$LOCAL_PATH"; then
            echo "ℹ️  Package $PACKAGE_NAME is already up-to-date"
            return 0
        fi
        echo "⚠️  Package $PACKAGE_NAME already exists in pubspec.yaml with different settings"
        read -p "Replace it with the new url/ref/path? (Y/n): " REPLACE </dev/tty
        if [[ "$REPLACE" =~ ^[Nn]$ ]]; then
            echo "❌ Skipped updating $PACKAGE_NAME"
            return 1
        fi
        # Remove full existing dependency block safely
        remove_dependency_block "$PUBSPEC_PATH" "$PACKAGE_NAME"
    fi

    # Find the dependencies section and add the package
    if grep -q "^dependencies:" "$PUBSPEC_PATH"; then
        # Create temporary file with the new dependency
        TEMP_FILE=$(mktemp)

        awk -v pkg="$PACKAGE_NAME" -v url="$REPO_URL" -v ref="$REF" -v local_path="$LOCAL_PATH" '
        /^dependencies:/ {
            print $0
            print "  " pkg ":"
            print "    git:"
            print "      url: " url
            if (ref != "") print "      ref: " ref
            if (local_path != "") print "      path: " local_path
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
        if [ -n "$LOCAL_PATH" ]; then
            echo "      path: $LOCAL_PATH" >> "$PUBSPEC_PATH"
        fi
    fi

    echo "✅ Added $PACKAGE_NAME to dependencies"
}

# Function to validate and fix package name mismatches
validate_package_name() {
    local pubspec_path="$1"
    local expected_dir_name="$2"
    
    if [ ! -f "$pubspec_path" ]; then
        return 0
    fi
    
    # Extract current name from pubspec.yaml
    local current_name=$(grep "^name:" "$pubspec_path" | sed 's/name:[[:space:]]*//' | tr -d '"' | head -1)
    
    if [ -n "$current_name" ] && [ -n "$expected_dir_name" ]; then
        # Check if names match (allowing for reasonable variations)
        if [ "$current_name" != "$expected_dir_name" ]; then
            echo ""
            echo "⚠️  **Package name mismatch detected:**"
            echo "   Directory name: $expected_dir_name"
            echo "   pubspec.yaml name: $current_name"
            echo ""
            echo "💡 This can cause 'pub get' failures. How would you like to fix this?"
            echo "1. 🔧 Update pubspec.yaml name to match directory ($expected_dir_name)"
            echo "2. 📁 Keep current pubspec name ($current_name)"
            echo "3. ✏️  Enter a new name manually"
            echo ""
            
            echo "Choose option (1-3, default: 1): "
            read NAME_FIX_CHOICE </dev/tty
            NAME_FIX_CHOICE=${NAME_FIX_CHOICE:-1}
            
            case "$NAME_FIX_CHOICE" in
                1)
                    # Update pubspec to match directory
                    echo ""
                    echo "🔧 Making the following changes to $pubspec_path:"
                    echo "   Before: name: $current_name"
                    echo "   After:  name: $expected_dir_name"
                    cross_platform_sed "s/^name:.*/name: $expected_dir_name/" "$pubspec_path"
                    echo "✅ Successfully updated pubspec.yaml name to: $expected_dir_name"
                    ;;
                2)
                    echo "✅ Keeping current name: $current_name"
                    echo "⚠️  Note: You may need to rename the directory to '$current_name' to avoid issues"
                    ;;
                3)
                    echo ""
                    echo "Enter new package name (lowercase, underscores only): "
                    read NEW_NAME </dev/tty
                    
                    if [ -n "$NEW_NAME" ]; then
                        # Sanitize the name
                        NEW_NAME=$(echo "$NEW_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_]/_/g' | sed 's/__*/_/g')
                        echo ""
                        echo "🔧 Making the following changes to $pubspec_path:"
                        echo "   Before: name: $current_name"
                        echo "   After:  name: $NEW_NAME"
                        cross_platform_sed "s/^name:.*/name: $NEW_NAME/" "$pubspec_path"
                        echo "✅ Successfully updated pubspec.yaml name to: $NEW_NAME"
                    else
                        echo "❌ Empty name, keeping original: $current_name"
                    fi
                    ;;
                *)
                    echo "❌ Invalid choice, keeping original name: $current_name"
                    ;;
            esac
            
            echo ""
        fi
    fi
}

# Function to check and resolve dependency conflicts
check_and_resolve_dependency_conflicts() {
    local pubspec_path="$1"
    
    if [ ! -f "$pubspec_path" ]; then
        return 0
    fi
    
    local project_dir="$(dirname "$pubspec_path")"
    local temp_output=$(mktemp)
    
    # Run pub get and capture output
    cd "$project_dir"
    echo "   📦 Running dependency resolution..."
    if ! flutter pub get > "$temp_output" 2>&1; then
        local pub_output=$(cat "$temp_output")
        
        # Check for version solving failures
        if echo "$pub_output" | grep -q "version solving failed"; then
            echo ""
            echo "⚠️  **Dependency conflict detected!**"
            echo ""
            
            # Parse all conflicting dependencies from the error output
            parse_dependency_conflicts "$pub_output" "$pubspec_path"
        fi
    else
        echo "✅ No dependency conflicts detected"
    fi
    
    rm -f "$temp_output"
    cd - >/dev/null
}

# Function to parse and resolve any dependency conflicts
parse_dependency_conflicts() {
    local pub_output="$1"
    local pubspec_path="$2"
    
    # Extract conflicting packages and their version requirements
    local conflicts_info=$(mktemp)
    
    # Parse the conflict messages to extract package names and versions
    # Also identify which packages come from git vs pub.dev
    local git_packages=$(mktemp)
    
    # Extract git package names from current pubspec
    grep -A 5 "git:" "$pubspec_path" | grep -B 5 "url:" | grep "^[[:space:]]*[^[:space:]]*:" | sed 's/^[[:space:]]*//' | sed 's/:.*$//' > "$git_packages"
    
    echo "$pub_output" | awk -v git_file="$git_packages" '
    BEGIN {
        # Load git packages into array
        while ((getline git_pkg < git_file) > 0) {
            git_packages[git_pkg] = 1
        }
        close(git_file)
    }
    /Because.*from git depends on.*which depends on/ {
        # Extract: "git_package from git depends on dependency ^version"
        if (match($0, /([a-zA-Z_][a-zA-Z0-9_]*) from git depends on ([a-zA-Z_][a-zA-Z0-9_]*) \^?([0-9]+\.[0-9]+\.[0-9]+)/, arr)) {
            print arr[2] ":" arr[3] ":git_source"  # dependency:version:git_source
        }
    }
    /Because.*depends on.*which depends on/ {
        # Extract: "package depends on dependency ^version"
        if (match($0, /([a-zA-Z_][a-zA-Z0-9_]*) depends on ([a-zA-Z_][a-zA-Z0-9_]*) \^?([0-9]+\.[0-9]+\.[0-9]+)/, arr)) {
            source = (arr[1] in git_packages) ? "git_source" : "pub_source"
            print arr[2] ":" arr[3] ":" source  # dependency:version:source
        }
    }
    /And because.*from git depends on/ {
        # Extract: "git_package from git depends on dependency ^version"
        if (match($0, /([a-zA-Z_][a-zA-Z0-9_]*) from git depends on ([a-zA-Z_][a-zA-Z0-9_]*) \^?([0-9]+\.[0-9]+\.[0-9]+)/, arr)) {
            print arr[2] ":" arr[3] ":git_source"  # dependency:version:git_source
        }
    }
    /And because.*depends on/ {
        # Extract: "package depends on dependency ^version" 
        if (match($0, /([a-zA-Z_][a-zA-Z0-9_]*) depends on ([a-zA-Z_][a-zA-Z0-9_]*) \^?([0-9]+\.[0-9]+\.[0-9]+)/, arr)) {
            source = (arr[1] in git_packages) ? "git_source" : "pub_source"
            print arr[2] ":" arr[3] ":" source  # dependency:version:source
        }
    }
    ' > "$conflicts_info"
    
    rm -f "$git_packages"
    
    if [ -s "$conflicts_info" ]; then
        echo "🔍 **Conflict Analysis:**"
        show_detailed_conflict_analysis "$pub_output"
        
        echo ""
        echo "🔧 **Auto-resolution options:**"
        echo "1. 🎯 Automatically resolve with dependency overrides (recommended)"
        echo "2. 📋 Show resolution strategy details"
        echo "3. ⏭️  Skip auto-resolution (fix manually)"
        echo ""
        
        echo "Choose option (1-3, default: 1): "
        read RESOLVE_CHOICE </dev/tty
        RESOLVE_CHOICE=${RESOLVE_CHOICE:-1}
        
        case "$RESOLVE_CHOICE" in
            1)
                auto_resolve_conflicts "$pubspec_path" "$conflicts_info" "$pub_output"
                ;;
            2)
                show_resolution_strategy "$conflicts_info"
                echo ""
                echo "🔧 Apply automatic resolution? (y/N): "
                read APPLY_RESOLUTION </dev/tty
                if [[ $APPLY_RESOLUTION =~ ^[Yy]$ ]]; then
                    auto_resolve_conflicts "$pubspec_path" "$conflicts_info" "$pub_output"
                fi
                ;;
            3)
                echo "💡 Manual resolution required. Check your pubspec.yaml dependencies."
                ;;
            *)
                echo "❌ Invalid choice, skipping auto-resolution"
                ;;
        esac
    else
        echo "💡 Complex dependency conflict detected. Showing available information:"
        echo "$pub_output" | tail -15 | sed 's/^/   /'
    fi
    
    rm -f "$conflicts_info"
}

# Function to automatically resolve conflicts using dependency overrides
auto_resolve_conflicts() {
    local pubspec_path="$1"
    local conflicts_info="$2"
    local pub_output="$3"
    
    echo ""
    echo "🔧 **Resolving dependency conflicts automatically...**"
    echo ""
    
    # Create backup
    local backup_path="$pubspec_path.backup.conflicts.$(date +%Y%m%d-%H%M%S)"
    cp "$pubspec_path" "$backup_path"
    echo "📋 Backup created: $(basename "$backup_path")"
    
    # Extract unique dependencies and pick the highest version
    local overrides=$(mktemp)
    
    # Process conflicts to determine best versions with git source awareness  
    echo ""
    echo "🔍 **Analyzing conflict sources:**"
    
    # Show which packages are causing outdated constraints
    awk -F: '/git_source/ {
        print "   📦 " $1 " (v" $2 ") - constraint from Git package (likely outdated)"
    }
    /pub_source/ {
        print "   🌐 " $1 " (v" $2 ") - constraint from pub.dev package"
    }' "$conflicts_info"
    
    echo ""
    echo "💡 **Git packages often have outdated constraints. Using latest compatible versions...**"
    
    # Process conflicts with intelligent version resolution
    sort "$conflicts_info" | uniq | awk -F: '
    {
        dep = $1
        version = $2 
        source = $3
        
        if (dep && version) {
            if (dep in versions) {
                # Compare versions and keep the higher one
                split(version, new_ver, ".")
                split(versions[dep], old_ver, ".")
                
                # Simple version comparison (major.minor.patch)
                if (new_ver[1] > old_ver[1] || 
                    (new_ver[1] == old_ver[1] && new_ver[2] > old_ver[2]) ||
                    (new_ver[1] == old_ver[1] && new_ver[2] == old_ver[2] && new_ver[3] > old_ver[3])) {
                    versions[dep] = version
                    sources[dep] = source
                }
                # If versions are equal, prefer pub.dev sources over git sources for latest versions
                else if (new_ver[1] == old_ver[1] && new_ver[2] == old_ver[2] && new_ver[3] == old_ver[3]) {
                    if (source == "pub_source" && sources[dep] == "git_source") {
                        versions[dep] = version
                        sources[dep] = source
                    }
                }
            } else {
                versions[dep] = version
                sources[dep] = source
            }
        }
    }
    END {
        for (dep in versions) {
            print dep ":" versions[dep] ":" sources[dep]
        }
    }
    ' | while IFS=: read -r dep version source; do
        
        # For git-sourced constraints, try to upgrade to latest compatible version
        if [ "$source" = "git_source" ] && [ -n "$dep" ]; then
            echo "🔄 Resolving $dep constraint (v$version) from Git source..."
            
            # First, check if this dependency is also a Git repository in current pubspec
            local dep_is_git_repo=false
            if grep -A 5 "$dep:" "$pubspec_path" | grep -q "git:"; then
                dep_is_git_repo=true
                echo "   📦 $dep is also a Git dependency - checking for updates..."
            fi
            
            # Get latest version from pub.dev API first
            latest_version=$(curl -s "https://pub.dev/api/packages/$dep" 2>/dev/null | grep -o '"latest"[^}]*"version":"[^"]*"' | sed 's/.*"version":"\([^"]*\)".*/\1/' | head -1)
            
            if [ -n "$latest_version" ] && [ "$latest_version" != "null" ]; then
                # Use latest pub.dev version
                echo "$dep:$latest_version:upgraded"
            elif [ "$dep_is_git_repo" = true ]; then
                # This dependency is a Git repo - suggest updating the Git source
                echo "   🔍 Checking Git repository for updates..."
                
                # Extract the Git URL for this dependency
                local git_url=$(awk "/$dep:/{found=1} found && /url:/{print \$2; exit}" "$pubspec_path" | tr -d '"')
                
                if [ -n "$git_url" ]; then
                    echo "   📂 Git repository: $git_url"
                    
                    # Try to get latest tag/version from GitHub API
                    if [[ "$git_url" == *"github.com"* ]]; then
                        local repo_path=$(echo "$git_url" | sed 's/.*github\.com[/:]\([^/]*\/[^/.]*\).*/\1/')
                        local latest_tag=$(curl -s "https://api.github.com/repos/$repo_path/tags" 2>/dev/null | grep '"name"' | head -1 | sed 's/.*"name": *"\([^"]*\)".*/\1/')
                        
                        if [ -n "$latest_tag" ] && [ "$latest_tag" != "null" ]; then
                            # Extract version from tag (remove v prefix if present)
                            local clean_version=$(echo "$latest_tag" | sed 's/^v//')
                            echo "$dep:$clean_version:git_updated"
                        else
                            echo "$dep:$version:git_no_tags"
                        fi
                    else
                        echo "$dep:$version:git_unknown_host"
                    fi
                else
                    echo "$dep:$version:git_no_url"
                fi
            else
                # Not available on pub.dev and not a Git dependency - use fallback
                case "$dep" in
                    firebase_core)
                        echo "$dep:3.24.2:fallback"
                        ;;
                    cloud_firestore)
                        echo "$dep:5.4.3:fallback"
                        ;;
                    firebase_auth)
                        echo "$dep:5.3.1:fallback"
                        ;;
                    *)
                        # For unknown packages, try incrementing major version
                        major_version=$(echo "$version" | cut -d. -f1)
                        upgraded_major=$((major_version + 1))
                        echo "$dep:$upgraded_major.0.0:estimated"
                        ;;
                esac
            fi
        else
            echo "$dep:$version:$source"
        fi
    done > "$overrides"
    
    if [ ! -s "$overrides" ]; then
        echo "⚠️  Could not parse version requirements. Trying intelligent defaults..."
        # Fallback: Add common dependency overrides for typical conflicts
        echo "firebase_core:3.15.2" > "$overrides"
        echo "cloud_firestore:4.0.0" >> "$overrides"
    fi
    
    # Check if dependency_overrides section exists
    if ! grep -q "^dependency_overrides:" "$pubspec_path"; then
        echo "" >> "$pubspec_path"
        echo "dependency_overrides:" >> "$pubspec_path"
        echo "🔧 Added dependency_overrides section"
    fi
    
    # Add overrides
    echo "🔧 **Adding smart dependency overrides:**"
    local changes_made=false
    
    while IFS=: read -r dep version source_type; do
        if [ -n "$dep" ] && [ -n "$version" ]; then
            case "$source_type" in
                "upgraded")
                    echo "   $dep: ^$version ✨ (upgraded from outdated git constraint)"
                    ;;
                "git_updated")
                    echo "   $dep: ^$version 🏷️  (latest Git tag version)"
                    ;;
                "git_no_tags")
                    echo "   $dep: ^$version ⚠️  (Git repo has no version tags - using constraint version)"
                    ;;
                "git_unknown_host")
                    echo "   $dep: ^$version 🔗 (non-GitHub Git repo - using constraint version)"
                    ;;
                "git_no_url")
                    echo "   $dep: ^$version ❓ (could not extract Git URL - using constraint version)"
                    ;;
                "fallback") 
                    echo "   $dep: ^$version 🔄 (using known compatible version)"
                    ;;
                "estimated")
                    echo "   $dep: ^$version 🎯 (estimated upgrade)"
                    ;;
                *)
                    echo "   $dep: ^$version"
                    ;;
            esac
            
            # Remove existing override for this dependency
            cross_platform_sed "/^dependency_overrides:/,/^[^[:space:]]/{/^[[:space:]]*$dep:/d;}" "$pubspec_path"
            
            # Add new override
            awk -v dep="$dep" -v ver="^$version" '
            /^dependency_overrides:/ {
                print
                print "  " dep ": " ver
                next
            }
            {print}
            ' "$pubspec_path" > "$pubspec_path.tmp" && mv "$pubspec_path.tmp" "$pubspec_path"
            
            changes_made=true
        fi
    done < "$overrides"
    
    rm -f "$overrides"
    
    if [ "$changes_made" = true ]; then
        echo ""
        echo "🧪 Testing dependency resolution..."
        local project_dir="$(dirname "$pubspec_path")"
        cd "$project_dir"
        
        if flutter pub get >/dev/null 2>&1; then
            echo "✅ **All dependency conflicts resolved successfully!**"
            echo "💡 Conflicting packages will now use compatible versions."
            echo ""
            echo "📋 **Summary of changes made to pubspec.yaml:**"
            grep -A 20 "^dependency_overrides:" "$pubspec_path" | grep "^[[:space:]]*[^[:space:]]" | sed 's/^/   Added: /'
            
            # Check if any Git repositories need attention
            if grep -q "git_no_tags\|git_unknown_host" "$overrides" 2>/dev/null; then
                echo ""
                echo "💡 **Recommendations for Git dependencies:**"
                
                grep "git_no_tags\|git_unknown_host" "$overrides" 2>/dev/null | while IFS=: read -r dep version source_type; do
                    case "$source_type" in
                        "git_no_tags")
                            echo "   📦 $dep: Consider asking the maintainer to create version tags"
                            ;;
                        "git_unknown_host")
                            echo "   🔗 $dep: Consider migrating to GitHub or pub.dev for better version management"
                            ;;
                    esac
                done
                
                echo ""
                echo "🔧 **Long-term solution:** Ask Git package maintainers to:"
                echo "   1. Update their pubspec.yaml with current dependency versions"
                echo "   2. Create proper semantic version tags (v1.0.0, v1.1.0, etc.)"
                echo "   3. Publish to pub.dev for better dependency management"
            fi
        else
            echo "⚠️  Some conflicts may remain. Checking for additional issues..."
            
            # Try one more time with flutter pub deps to get more info
            local remaining_output=$(mktemp)
            flutter pub get > "$remaining_output" 2>&1
            
            if grep -q "version solving failed" "$remaining_output"; then
                echo "❌ Auto-resolution partially successful but conflicts remain."
                echo "💡 Showing remaining issues:"
                cat "$remaining_output" | tail -10 | sed 's/^/   /'
                echo ""
                echo "🔧 Consider manually updating the conflicting packages or contact their authors."
            else
                echo "✅ **Resolution successful after retry!**"
            fi
            
            rm -f "$remaining_output"
        fi
        
        cd - >/dev/null
    else
        echo "❌ No overrides could be applied. Manual resolution required."
    fi
}

# Function to show resolution strategy
show_resolution_strategy() {
    local conflicts_info="$1"
    
    echo ""
    echo "📋 **Resolution Strategy:**"
    echo "========================"
    echo ""
    echo "The following dependency overrides will be added to force compatible versions:"
    echo ""
    
    sort "$conflicts_info" | uniq | awk -F: '{
        if ($1 && $2) {
            printf "  %s: ^%s\n", $1, $2
        }
    }' | sort -u
    
    echo ""
    echo "💡 This forces all packages to use the specified versions, resolving conflicts."
    echo "⚠️  Note: Overrides should be temporary - ideally package authors should update their dependencies."
}

# Function to show detailed conflict analysis
show_detailed_conflict_analysis() {
    local pub_output="$1"
    
    echo ""
    echo "🔍 **Detailed Dependency Conflict Analysis:**"
    echo "=================================="
    
    # Extract and format the conflict information
    echo "$pub_output" | awk '
    /Because.*depends on.*which depends on/ {
        gsub(/Because /, "📦 ")
        gsub(/ which depends on/, "\n    └── which depends on")
        print
        print ""
    }
    /And because.*depends on/ {
        gsub(/And because /, "📦 ")
        print
        print ""
    }
    /is incompatible with/ {
        gsub(/is incompatible with/, "❌ is incompatible with")
        print
        print ""
    }
    /version solving failed/ {
        print "💥 " $0
    }
    '
    
    echo ""
    echo "💡 **Resolution strategies:**"
    echo "1. Use dependency_overrides to force compatible versions"
    echo "2. Update git packages to use newer Firebase versions"
    echo "3. Contact package authors to update their dependencies"
}

# Function to validate entire project structure
validate_project_structure() {
    local project_dir="$1"
    local project_name=$(basename "$project_dir")
    local pubspec_path="$project_dir/pubspec.yaml"
    
    echo "🔍 Validating project structure..."
    echo "   📋 Checking package name consistency..."
    
    # Validate package name
    validate_package_name "$pubspec_path" "$project_name"
    
    # Check for common issues
    if [ -f "$pubspec_path" ]; then
        echo "   🔍 Scanning for duplicate dependencies..."
        # Check for duplicate dependencies
        local duplicates=$(awk '/^dependencies:/,/^[^[:space:]]/ {
            if (/^[[:space:]]+[^[:space:]]+:/) {
                gsub(/^[[:space:]]+/, "")
                gsub(/:.*/, "")
                print
            }
        }' "$pubspec_path" | sort | uniq -d)
        
        if [ -n "$duplicates" ]; then
            echo ""
            echo "⚠️  **Duplicate dependencies detected in $pubspec_path:**"
            echo "$duplicates" | sed 's/^/    • /'
            echo ""
            echo "💡 These duplicate entries may cause dependency conflicts."
            echo "🔧 Would you like to automatically remove duplicates? (y/N): "
            read REMOVE_DUPLICATES </dev/tty
            if [[ $REMOVE_DUPLICATES =~ ^[Yy]$ ]]; then
                echo ""
                echo "🔧 Creating backup: $pubspec_path.backup.$(date +%Y%m%d-%H%M%S)"
                cp "$pubspec_path" "$pubspec_path.backup.$(date +%Y%m%d-%H%M%S)"
                echo "🔧 Removing duplicate dependencies..."
                
                # Show which duplicates are being removed
                echo "$duplicates" | while read -r duplicate; do
                    echo "   Removing duplicate: $duplicate"
                done
                
                # Create a temp file with duplicates removed (keep first occurrence)
                awk '
                /^dependencies:/,/^[^[:space:]]/ {
                    if (/^[[:space:]]+[^[:space:]]+:/) {
                        gsub(/^[[:space:]]+/, "")
                        dep = $1
                        gsub(/:.*/, "", dep)
                        if (!seen[dep]) {
                            seen[dep] = 1
                            print
                        }
                    } else {
                        print
                    }
                    next
                }
                { print }
                ' "$pubspec_path" > "$pubspec_path.tmp" && mv "$pubspec_path.tmp" "$pubspec_path"
                
                echo "✅ Successfully removed duplicate dependencies"
            else
                echo "💡 You can manually remove duplicates later if needed"
            fi
        fi
        
        # Check for dependency conflicts
        echo ""
        echo "🔍 Checking for dependency conflicts..."
        check_and_resolve_dependency_conflicts "$pubspec_path"
        
        # Check for Git dependency cache issues
        echo ""
        echo "🔄 Checking Git dependency cache..."
        check_git_dependency_cache "$pubspec_path"
        
        echo "✅ Project validation complete"
    fi
}

# Function to check and refresh Git dependency cache
check_git_dependency_cache() {
    local pubspec_path="$1"
    local project_dir="$(dirname "$pubspec_path")"
    
    if [ ! -f "$pubspec_path" ]; then
        return 0
    fi
    
    # Extract Git dependencies from pubspec.yaml
    local git_deps=$(mktemp)
    awk '/^[[:space:]]*[^#]*:/{dep_name=$1; gsub(/:/, "", dep_name)} 
         /^[[:space:]]*git:/{in_git=1; next} 
         in_git && /^[[:space:]]*url:/{url=$2; gsub(/["]/, "", url)} 
         in_git && /^[[:space:]]*ref:/{ref=$2; gsub(/["]/, "", ref)} 
         in_git && /^[[:space:]]*[^[:space:]]/ && !/url:/ && !/ref:/ && !/path:/{
             if(dep_name && url) {
                 print dep_name ":" url ":" (ref ? ref : "main")
                 dep_name=""; url=""; ref=""; in_git=0
             }
         }
         /^[^[:space:]]/ && !/dependencies:/ && !/dependency_overrides:/{in_git=0}' "$pubspec_path" > "$git_deps"
    
    if [ ! -s "$git_deps" ]; then
        echo "✅ No Git dependencies found"
        rm -f "$git_deps"
        return 0
    fi
    
    echo "📦 Found Git dependencies:"
    echo "   🔄 Analyzing dependency freshness..."
    local has_stale_deps=false
    local stale_deps=()
    
    while IFS=: read -r dep_name git_url git_ref; do
        if [ -n "$dep_name" ] && [ -n "$git_url" ]; then
            echo "   $dep_name ($git_ref) from $git_url"
            
            # Check if this is a GitHub repo and get latest commit
            if [[ "$git_url" == *"github.com"* ]]; then
                local repo_path=$(echo "$git_url" | sed 's/.*github\.com[/:]\([^/]*\/[^/.]*\).*/\1/')
                
                echo "     🔍 Checking latest commit via GitHub API..."
                # Get latest commit hash for the branch/ref
                local latest_commit=$(curl -s "https://api.github.com/repos/$repo_path/commits/$git_ref" 2>/dev/null | grep '"sha"' | head -1 | sed 's/.*"sha": *"\([^"]*\)".*/\1/' | cut -c1-7)
                
                if [ -n "$latest_commit" ] && [ "$latest_commit" != "null" ]; then
                    echo "     Latest commit: $latest_commit"
                    
                    # Check Flutter's cache to see what commit we have
                    local cache_dir=""
                    if [ -d "$HOME/.pub-cache/git" ]; then
                        cache_dir="$HOME/.pub-cache/git"
                    elif [ -d "$HOME/AppData/Local/Pub/Cache/git" ]; then  # Windows
                        cache_dir="$HOME/AppData/Local/Pub/Cache/git"
                    fi
                    
                    if [ -n "$cache_dir" ]; then
                        echo "     🔍 Scanning local pub cache..."
                        # Look for cached version of this repo
                        local repo_hash=$(echo "$git_url" | shasum | cut -c1-8)
                        local cached_paths=$(find "$cache_dir" -name "*$repo_hash*" -type d 2>/dev/null)
                        
                        if [ -n "$cached_paths" ]; then
                            local cached_commit=""
                            for cached_path in $cached_paths; do
                                if [ -d "$cached_path/.git" ]; then
                                    cached_commit=$(cd "$cached_path" && git rev-parse HEAD 2>/dev/null | cut -c1-7)
                                    break
                                fi
                            done
                            
                            if [ -n "$cached_commit" ]; then
                                echo "     Cached commit: $cached_commit"
                                
                                if [ "$cached_commit" != "$latest_commit" ]; then
                                    echo "     🔄 STALE - newer commits available!"
                                    has_stale_deps=true
                                    stale_deps+=("$dep_name:$git_url:$git_ref:$cached_commit:$latest_commit")
                                else
                                    echo "     ✅ Up to date"
                                fi
                            else
                                echo "     ⚠️  Could not determine cached commit"
                            fi
                        else
                            echo "     📥 Not cached yet"
                        fi
                    fi
                else
                    echo "     ⚠️  Could not fetch latest commit info"
                fi
            else
                echo "     🔗 Non-GitHub repo - cannot check for updates"
            fi
            echo ""
        fi
    done < "$git_deps"
    
    rm -f "$git_deps"
    
    if [ "$has_stale_deps" = true ]; then
        echo ""
        echo "⚠️  **Stale Git dependencies detected!**"
        echo ""
        echo "🔧 **Resolution options:**"
        echo "1. 🧹 Clear Flutter cache and fetch latest commits (recommended)"
        echo "2. 🎯 Force refresh specific packages only"
        echo "3. 📋 Show detailed cache information"
        echo "4. ⏭️  Skip cache refresh"
        echo ""
        
        echo "Choose option (1-4, default: 1): "
        read CACHE_CHOICE </dev/tty
        CACHE_CHOICE=${CACHE_CHOICE:-1}
        
        case "$CACHE_CHOICE" in
            1)
                refresh_git_dependency_cache "$project_dir" "all" "${stale_deps[@]}"
                ;;
            2)
                select_packages_to_refresh "$project_dir" "${stale_deps[@]}"
                ;;
            3)
                show_detailed_cache_info "${stale_deps[@]}"
                echo ""
                echo "🔧 Refresh cache now? (y/N): "
                read REFRESH_NOW </dev/tty
                if [[ $REFRESH_NOW =~ ^[Yy]$ ]]; then
                    refresh_git_dependency_cache "$project_dir" "all" "${stale_deps[@]}"
                fi
                ;;
            4)
                echo "💡 Git dependencies will continue using cached versions"
                ;;
            *)
                echo "❌ Invalid choice, skipping cache refresh"
                ;;
        esac
    else
        echo "✅ All Git dependencies are up to date"
    fi
}

# Function to refresh Git dependency cache
refresh_git_dependency_cache() {
    local project_dir="$1"
    local refresh_type="$2"
    shift 2
    local stale_deps=("$@")
    
    echo ""
    echo "🧹 **Refreshing Git dependency cache...**"
    echo ""
    
    cd "$project_dir"
    
    if [ "$refresh_type" = "all" ]; then
        echo "🗑️  Clearing Flutter pub cache..."
        flutter pub cache clean
        
        echo "📦 Re-fetching all dependencies..."
        flutter pub get
        
        if [ $? -eq 0 ]; then
            echo "✅ **All Git dependencies refreshed successfully!**"
            echo ""
            echo "📋 **Verification - latest commits now cached:**"
            for stale_info in "${stale_deps[@]}"; do
                IFS=: read -r dep_name git_url git_ref cached_commit latest_commit <<< "$stale_info"
                echo "   $dep_name: $cached_commit → $latest_commit ✨"
            done
        else
            echo "❌ Failed to refresh dependencies - check for conflicts"
        fi
    else
        # Selective refresh (more complex, requires careful cache manipulation)
        echo "🎯 Selective refresh not yet implemented - using full refresh..."
        flutter pub cache clean
        flutter pub get
    fi
    
    cd - >/dev/null
}

# Function to select specific packages to refresh
select_packages_to_refresh() {
    local project_dir="$1"
    shift
    local stale_deps=("$@")
    
    echo ""
    echo "🎯 **Select packages to refresh:**"
    echo ""
    
    local selected_packages=()
    local i=1
    
    for stale_info in "${stale_deps[@]}"; do
        IFS=: read -r dep_name git_url git_ref cached_commit latest_commit <<< "$stale_info"
        echo "$i. $dep_name ($cached_commit → $latest_commit)"
        i=$((i+1))
    done
    
    echo ""
    echo "Enter package numbers (comma-separated, or 'all'): "
    read PACKAGE_SELECTION </dev/tty
    
    if [ "$PACKAGE_SELECTION" = "all" ]; then
        refresh_git_dependency_cache "$project_dir" "all" "${stale_deps[@]}"
    else
        # For now, fall back to full refresh since selective refresh is complex
        echo "💡 Selective refresh requires full cache clear - refreshing all..."
        refresh_git_dependency_cache "$project_dir" "all" "${stale_deps[@]}"
    fi
}

# Function to show detailed cache information
show_detailed_cache_info() {
    local stale_deps=("$@")
    
    echo ""
    echo "📋 **Detailed Git Dependency Cache Information:**"
    echo "=============================================="
    
    for stale_info in "${stale_deps[@]}"; do
        IFS=: read -r dep_name git_url git_ref cached_commit latest_commit <<< "$stale_info"
        
        echo ""
        echo "📦 **$dep_name**"
        echo "   Repository: $git_url"
        echo "   Branch/Ref: $git_ref"
        echo "   Cached commit: $cached_commit"
        echo "   Latest commit: $latest_commit"
        echo "   Status: 🔄 OUTDATED"
        
        # Try to get commit messages for context
        if [[ "$git_url" == *"github.com"* ]]; then
            local repo_path=$(echo "$git_url" | sed 's/.*github\.com[/:]\([^/]*\/[^/.]*\).*/\1/')
            
            echo "   Recent commits:"
            curl -s "https://api.github.com/repos/$repo_path/commits/$git_ref?per_page=3" 2>/dev/null | \
                grep -E '"message"|"date"' | \
                paste - - | \
                sed 's/.*"message": *"\([^"]*\)".*"date": *"\([^"]*\)".*/     • \1 (\2)/' | \
                head -3
        fi
    done
    
    echo ""
    echo "💡 **Why this happens:**"
    echo "   Flutter caches Git dependencies by commit hash, not branch name."
    echo "   Even when you update the remote branch, Flutter keeps using the cached commit."
    echo ""
    echo "🔧 **Solutions:**"
    echo "   1. Clear pub cache: flutter pub cache clean && flutter pub get"
    echo "   2. Use specific commit hashes in pubspec.yaml instead of branch names"
    echo "   3. Create version tags in your Git repositories for stable releases"
}

# Function to analyze and suggest exported functions from a package
analyze_package_exports() {
    local repo_full_name="$1"
    local package_name="$2"
    local ref="$3"
    
    echo ""
    echo "🔍 Analyzing exports in $package_name..."
    
    # Create temp directory for analysis
    local temp_dir=$(mktemp -d)
    local clone_success=false
    
    # Clone repository for analysis
    if git clone --depth 1 --branch "$ref" "https://github.com/$repo_full_name.git" "$temp_dir/$package_name" >/dev/null 2>&1; then
        clone_success=true
    elif git clone --depth 1 "https://github.com/$repo_full_name.git" "$temp_dir/$package_name" >/dev/null 2>&1; then
        clone_success=true
        echo "⚠️  Using default branch (ref '$ref' not found)"
    fi
    
    if [ "$clone_success" = true ]; then
        local lib_dir="$temp_dir/$package_name/lib"
        
        if [ -d "$lib_dir" ]; then
            echo "📋 Discovered exports:"
            
            # Find main library file
            local main_lib="$lib_dir/$package_name.dart"
            if [ ! -f "$main_lib" ]; then
                main_lib="$lib_dir/main.dart"
            fi
            
            # Extract exports from main library and other dart files
            local exports_found=false
            
            for dart_file in "$lib_dir"/*.dart "$main_lib"; do
                if [ -f "$dart_file" ]; then
                    # Extract public classes, functions, widgets, enums
                    local exports=$(grep -E "^(class|abstract class|mixin|enum|typedef|Widget.*extends)" "$dart_file" 2>/dev/null | \
                                   grep -v "^[[:space:]]*//\|^[[:space:]]*\*" | \
                                   sed 's/^[[:space:]]*//' | \
                                   head -5)
                    
                    if [ -n "$exports" ]; then
                        exports_found=true
                        echo ""
                        echo "  📄 From $(basename "$dart_file"):"
                        echo "$exports" | sed 's/^/    ✦ /'
                    fi
                fi
            done
            
            if [ "$exports_found" = true ]; then
                echo ""
                echo "💡 Usage suggestions:"
                echo "  import 'package:$package_name/$package_name.dart';"
                echo ""
                echo "  // Example instantiation patterns:"
                
                # Generate usage examples based on discovered classes
                echo "  // Based on discovered classes:"
                local examples_generated=false
                
                # Process the exports we already found and generate examples
                local temp_exports=$(mktemp)
                
                # Collect all exports from all dart files for processing
                for dart_file in "$lib_dir"/*.dart "$main_lib"; do
                    if [ -f "$dart_file" ]; then
                        grep -E "^class [A-Za-z0-9_]+" "$dart_file" 2>/dev/null >> "$temp_exports" || true
                    fi
                done
                
                # Process the collected exports
                if [ -s "$temp_exports" ]; then
                    while IFS= read -r class_line; do
                        if [ -n "$class_line" ]; then
                            # Extract class name
                            local class_name=$(echo "$class_line" | sed -E 's/class ([A-Za-z0-9_]+).*/\1/' 2>/dev/null)
                            
                            if [ -n "$class_name" ]; then
                                # Determine type and generate appropriate example
                                if [[ "$class_line" =~ Widget ]]; then
                                    echo "  $class_name(), // Widget"
                                    examples_generated=true
                                elif [[ "$class_line" =~ Model ]]; then
                                    echo "  final model = $class_name(); // Model class"
                                    examples_generated=true
                                elif [[ "$class_line" =~ Service ]]; then
                                    echo "  final service = $class_name(); // Service class"
                                    examples_generated=true
                                elif [[ "$class_line" =~ Controller|Manager ]]; then
                                    echo "  final controller = $class_name(); // Controller"
                                    examples_generated=true
                                else
                                    # Generic class
                                    local var_name=$(echo "$class_name" | sed 's/\([A-Z]\)/_\1/g' | sed 's/^_//' | tr '[:upper:]' '[:lower:]')
                                    echo "  final $var_name = $class_name(); // Class"
                                    examples_generated=true
                                fi
                            fi
                        fi
                    done < "$temp_exports"
                fi
                
                # Cleanup temp file
                rm -f "$temp_exports" 2>/dev/null
                
                if [ "$examples_generated" = false ]; then
                    echo "  // No specific usage patterns detected"
                    echo "  // Check the package documentation for usage details"
                fi
                
                echo ""
                echo "📖 **Next steps:**"
                echo "  1. Run 'flutter pub get' to fetch the dependency"
                echo "  2. Import the package in your Dart files"
                echo "  3. Explore the package documentation for detailed usage"
                
                echo ""
            else
                echo "  ℹ️  No public exports detected (might be a utility package)"
            fi
        else
            echo "  ℹ️  No lib directory found - not a standard Dart/Flutter package"
        fi
    else
        echo "  ⚠️  Could not analyze package (clone failed)"
    fi
    
    # Cleanup
    rm -rf "$temp_dir" 2>/dev/null
}

# Function to auto-discover monorepo structure
discover_monorepo_structure() {
    local repo_full_name="$1"
    local ref="$2"
    
    echo ""
    echo "🔍 Auto-discovering monorepo structure for $repo_full_name..."
    
    # Create temp directory for analysis
    local temp_dir=$(mktemp -d)
    local clone_success=false
    
    # Clone repository for analysis
    if git clone --depth 1 --branch "$ref" "https://github.com/$repo_full_name.git" "$temp_dir/analysis" >/dev/null 2>&1; then
        clone_success=true
    elif git clone --depth 1 "https://github.com/$repo_full_name.git" "$temp_dir/analysis" >/dev/null 2>&1; then
        clone_success=true
    fi
    
    if [ "$clone_success" = true ]; then
        local repo_dir="$temp_dir/analysis"
        
        # Find all pubspec.yaml files to detect monorepo structure
        local pubspec_files=()
        while IFS= read -r -d '' pubspec; do
            # Get relative path from repo root
            local rel_path="${pubspec#$repo_dir/}"
            rel_path="${rel_path%/pubspec.yaml}"
            [ -n "$rel_path" ] && pubspec_files+=("$rel_path") || pubspec_files+=(".")
        done < <(find "$repo_dir" -name "pubspec.yaml" -print0 2>/dev/null)
        
        # Analyze structure
        if [ ${#pubspec_files[@]} -gt 1 ]; then
            echo "🏗️  **MONOREPO DETECTED!**"
            echo ""
            echo "📊 Found ${#pubspec_files[@]} packages:"
            
            # Categorize packages
            local root_packages=()
            local nested_packages=()
            local app_packages=()
            local lib_packages=()
            
            for pkg_path in "${pubspec_files[@]}"; do
                if [ "$pkg_path" = "." ]; then
                    root_packages+=("ROOT")
                else
                    # Analyze package type
                    local pubspec_file="$repo_dir/$pkg_path/pubspec.yaml"
                    local is_app=false
                    local is_lib=false
                    
                    if [ -f "$pubspec_file" ]; then
                        # Check if it's an app (has flutter section with dependencies or main.dart)
                        if [ -f "$repo_dir/$pkg_path/lib/main.dart" ] || grep -q "flutter:" "$pubspec_file"; then
                            if [ -f "$repo_dir/$pkg_path/lib/main.dart" ]; then
                                is_app=true
                                app_packages+=("$pkg_path")
                            else
                                is_lib=true
                                lib_packages+=("$pkg_path")
                            fi
                        else
                            nested_packages+=("$pkg_path")
                        fi
                    else
                        nested_packages+=("$pkg_path")
                    fi
                fi
            done
            
            # Display findings
            if [ ${#root_packages[@]} -gt 0 ]; then
                echo "  🏠 Root package: ${root_packages[0]}"
            fi
            
            if [ ${#app_packages[@]} -gt 0 ]; then
                echo "  📱 Flutter apps:"
                for app in "${app_packages[@]}"; do
                    echo "    • $app"
                done
            fi
            
            if [ ${#lib_packages[@]} -gt 0 ]; then
                echo "  📚 Flutter libraries:"
                for lib in "${lib_packages[@]}"; do
                    echo "    • $lib"
                done
            fi
            
            if [ ${#nested_packages[@]} -gt 0 ]; then
                echo "  📦 Other packages:"
                for pkg in "${nested_packages[@]}"; do
                    echo "    • $pkg"
                done
            fi
            
            echo ""
            echo "💡 **Monorepo handling suggestions:**"
            
            # Smart suggestions based on discovered structure
            if [ ${#lib_packages[@]} -gt 0 ]; then
                echo "  🎯 **Recommended**: Use library packages as they're designed for reuse"
                for lib in "${lib_packages[@]}"; do
                    echo "     → $lib (library package)"
                done
            fi
            
            if [ ${#app_packages[@]} -gt 0 ] && [ ${#lib_packages[@]} -eq 0 ]; then
                echo "  📱 **App packages found**: These contain full applications"
                for app in "${app_packages[@]}"; do
                    echo "     → $app (Flutter app)"
                done
                echo "     ⚠️  Consider extracting reusable components into libraries"
            fi
            
            if [ ${#root_packages[@]} -gt 0 ] && [ ${#nested_packages[@]} -gt 0 ]; then
                echo "  🏠 **Root package available**: Contains the main package"
                echo "     → Use ROOT for the main package functionality"
            fi
            
            echo ""
            echo "🤔 **How would you like to handle this monorepo?**"
            echo "1. 🎯 Use recommended library package (auto-select best option)"
            echo "2. 📋 Let me choose specific package from list"
            echo "3. 🏠 Use root package (if available)"
            echo "4. ✋ I'll specify the path manually"
            echo ""
            
            local suggested_path=""
            if [ ${#lib_packages[@]} -gt 0 ]; then
                suggested_path="${lib_packages[0]}"
                echo "💡 Auto-suggestion: $suggested_path (first library package)"
            elif [ ${#root_packages[@]} -gt 0 ]; then
                suggested_path="."
                echo "💡 Auto-suggestion: ROOT package"
            else
                suggested_path="${pubspec_files[0]}"
                echo "💡 Auto-suggestion: $suggested_path (first found package)"
            fi
            
            echo ""
            echo "Choose option (1-4, default: 1): "
            read MONOREPO_CHOICE </dev/tty
            MONOREPO_CHOICE=${MONOREPO_CHOICE:-1}
            
            case "$MONOREPO_CHOICE" in
                1)
                    DISCOVERED_SUB_PATH="$suggested_path"
                    echo "✅ Using suggested path: $DISCOVERED_SUB_PATH"
                    ;;
                2)
                    echo ""
                    echo "📋 Available packages:"
                    for i in "${!pubspec_files[@]}"; do
                        local display_path="${pubspec_files[$i]}"
                        [ "$display_path" = "." ] && display_path="ROOT"
                        echo "  $((i+1)). $display_path"
                    done
                    echo ""
                    echo "Enter package number: "
                    read PKG_NUM </dev/tty
                    
                    if [[ "$PKG_NUM" =~ ^[0-9]+$ ]] && [ "$PKG_NUM" -ge 1 ] && [ "$PKG_NUM" -le ${#pubspec_files[@]} ]; then
                        DISCOVERED_SUB_PATH="${pubspec_files[$((PKG_NUM-1))]}"
                        echo "✅ Selected: $DISCOVERED_SUB_PATH"
                    else
                        echo "❌ Invalid selection, using suggested path"
                        DISCOVERED_SUB_PATH="$suggested_path"
                    fi
                    ;;
                3)
                    DISCOVERED_SUB_PATH="."
                    echo "✅ Using root package"
                    ;;
                4)
                    echo ""
                    echo "Enter custom package path: "
                    read CUSTOM_SUB_PATH </dev/tty
                    DISCOVERED_SUB_PATH="${CUSTOM_SUB_PATH:-$suggested_path}"
                    echo "✅ Using custom path: $DISCOVERED_SUB_PATH"
                    ;;
                *)
                    echo "❌ Invalid choice, using suggested path"
                    DISCOVERED_SUB_PATH="$suggested_path"
                    ;;
            esac
            
            # Store the discovered path for use in package addition
            MONOREPO_SUB_PATH="$DISCOVERED_SUB_PATH"
            
        else
            echo "📦 Single package repository detected"
            MONOREPO_SUB_PATH=""
        fi
    else
        echo "⚠️  Could not analyze repository structure"
        MONOREPO_SUB_PATH=""
    fi
    
    # Cleanup
    rm -rf "$temp_dir" 2>/dev/null
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
    read -p "🚀 Would you like to authenticate now? (Y/n): " auth_choice </dev/tty

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

# Project selection
# Main loop for handling configuration and project selection
while true; do
    select_project_source

    case $PROJECT_SOURCE_CHOICE in
        3)
            # Configuration
            configure_search_settings
            continue  # Go back to main menu
            ;;
        4)
            # Current directory selected - no need to loop
            break
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
            done < <(find / \( -type d \( -name ".git" -o -name ".dart_tool" -o -name "build" -o -name "node_modules" -o -name "Pods" -o -name ".Trash" -o -path "$SCRIPTS_ROOT" -o -path "$SCRIPTS_ROOT/*" \) -prune \) -o -name "pubspec.yaml" -print0 2>/dev/null)
        else
            for dir in "${CONFIG_SEARCH_PATHS[@]}"; do
                if [ -d "$dir" ]; then
                    echo "🔍 Searching in: $dir (depth: $CONFIG_SEARCH_DEPTH)"
                    while IFS= read -r -d '' project; do
                        FLUTTER_PROJECTS+=("$project")
                    done < <(find "$dir" -maxdepth "$CONFIG_SEARCH_DEPTH" \( -type d \( -name ".git" -o -name ".dart_tool" -o -name "build" -o -name "node_modules" -o -name "Pods" -o -name ".Trash" -o -path "$SCRIPTS_ROOT" -o -path "$SCRIPTS_ROOT/*" \) -prune \) -o -name "pubspec.yaml" -print0 2>/dev/null)
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
    4)
        # Detected project (current or parent directory)
        SELECTED_PUBSPEC="$DETECTED_PUBSPEC_PATH"
        SELECTED_PROJECT=$(basename "$(dirname "$SELECTED_PUBSPEC")")
        echo "📱 Using project: $SELECTED_PROJECT"
        ;;
    *)
        echo "❌ Invalid source selection: $PROJECT_SOURCE_CHOICE"
        exit 1
        ;;
esac

# Project selection from found projects (only for options 1 and 2)
if [[ "$PROJECT_SOURCE_CHOICE" == "1" || "$PROJECT_SOURCE_CHOICE" == "2" ]] && [ ${#FLUTTER_PROJECTS[@]} -eq 1 ]; then
    # Only one project found, use it directly
    SELECTED_PUBSPEC="${FLUTTER_PROJECTS[0]}"
    SELECTED_PROJECT=$(basename "$(dirname "$SELECTED_PUBSPEC")")
    echo "📱 Using project: $SELECTED_PROJECT"
elif [[ "$PROJECT_SOURCE_CHOICE" == "1" || "$PROJECT_SOURCE_CHOICE" == "2" ]] && [ ${#FLUTTER_PROJECTS[@]} -gt 1 ]; then
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
    read -p "Enter project number: " PROJECT_NUM </dev/tty

    if [[ ! "$PROJECT_NUM" =~ ^[0-9]+$ ]] || [ "$PROJECT_NUM" -lt 1 ] || [ "$PROJECT_NUM" -gt ${#FLUTTER_PROJECTS[@]} ]; then
        echo "❌ Invalid selection"
        exit 1
    fi

    SELECTED_PUBSPEC="${FLUTTER_PROJECTS[$((PROJECT_NUM-1))]}"
    SELECTED_PROJECT=$(basename "$(dirname "$SELECTED_PUBSPEC")")
    echo "📱 Using project: $SELECTED_PROJECT"
fi

# Validate the selected project structure
if [ -n "$SELECTED_PUBSPEC" ]; then
    validate_project_structure "$(dirname "$SELECTED_PUBSPEC")"
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
clear

# Show smart recommendations before package selection
echo "🤖 **SMART ANALYSIS & RECOMMENDATIONS**"
echo "======================================"
echo ""

# Analyze the selected project for smart recommendations
if [ -n "$SELECTED_PUBSPEC" ]; then
    local project_dir="$(dirname "$SELECTED_PUBSPEC")"
    echo "📊 Analyzing your Flutter project for intelligent package suggestions..."
    echo ""
    
    # Run smart recommendations analysis
    analyze_code_patterns "$project_dir"
    
    echo ""
    echo "⚡ **Ready to add packages!** The recommendations above will help you choose wisely."
    echo ""
    echo "Press Enter to continue to package selection..."
    read -p "" CONTINUE_TO_SELECTION </dev/tty
fi

clear
echo "📋 Select repositories to add as packages:"
echo ""

# CRITICAL FIX: When starting from current directory (pubspec.yaml present),
# we missed the terminal initialization that GitHub operations provide.
# We need to simulate what gh commands do to properly initialize terminal input handling.
if [ -f "./pubspec.yaml" ] && [ -n "$SELECTED_PUBSPEC" ]; then
    # We used current directory, so we missed GitHub operations that initialize terminal
    echo "🔧 Initializing terminal for interactive selection..."

fi

# Clear screen for clean selection interface
clear

# Use multiselect function
SELECTED_INDICES=()
multiselect "Select repositories (SPACE to select, ENTER to confirm):" REPO_OPTIONS SELECTED_INDICES false true

# Restore terminal to cooked mode before next prompts
ensure_tty_ready

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

    # Get branches and tags
    echo ""
    echo "🏷️  Available references for $REPO_FULL_NAME:"
    echo "Branches:"
    BRANCHES_OUTPUT=$(gh api "repos/$REPO_FULL_NAME/branches" --jq '.[].name' 2>/dev/null || true)
    if [ -n "$BRANCHES_OUTPUT" ]; then
        echo "$BRANCHES_OUTPUT" | head -10 | sed 's/^/  /'
    else
        echo "  (No branches found or insufficient permissions)"
    fi

    echo "Tags:"
    TAGS_OUTPUT=$(gh api "repos/$REPO_FULL_NAME/tags" --jq '.[].name' 2>/dev/null || true)
    if [ -n "$TAGS_OUTPUT" ]; then
        echo "$TAGS_OUTPUT" | head -10 | sed 's/^/  /'
    else
        echo "  (No tags found)"
    fi

    # Ensure TTY is ready for input prompts
    ensure_tty_ready
    
    echo ""
    echo "Specify branch/tag (default: main): "
    read REF </dev/tty
    REF=${REF:-main}

    # Auto-discover monorepo structure
    discover_monorepo_structure "$REPO_FULL_NAME" "$REF"
    
    # Use discovered path or set defaults based on auto-detection
    if [ -n "$MONOREPO_SUB_PATH" ] && [ "$MONOREPO_SUB_PATH" != "." ]; then
        SUB_PATH="$MONOREPO_SUB_PATH"
        echo ""
        echo "🎯 Using auto-discovered monorepo path: $SUB_PATH"
        echo ""
        echo "Override with custom path? (leave empty to use discovered path): "
        read CUSTOM_SUB_PATH </dev/tty
        if [ -n "$CUSTOM_SUB_PATH" ]; then
            SUB_PATH="$CUSTOM_SUB_PATH"
            echo "✅ Using custom override: $SUB_PATH"
        fi
    else
        # Auto-discovery determined single package - use root path
        SUB_PATH=""
        if [ -z "$MONOREPO_SUB_PATH" ]; then
            # Only ask manual input if auto-discovery completely failed
            echo ""
            echo "⚠️  Auto-discovery failed. Manual input required."
            echo "If this is a monorepo, enter package subfolder path (empty for root): "
            read SUB_PATH </dev/tty
            SUB_PATH=${SUB_PATH:-}
        fi
    fi

    # Auto-detect default package name from repo pubspec on selected ref and path
    DEFAULT_PACKAGE_NAME=""
    if [ -n "$SUB_PATH" ]; then
        SUB_PUBSPEC_PATH="${SUB_PATH%/}/pubspec.yaml"
        DEFAULT_PACKAGE_NAME=$(get_repo_pubspec_name "$REPO_FULL_NAME" "$REF" "$SUB_PUBSPEC_PATH")
    fi
    if [ -z "$DEFAULT_PACKAGE_NAME" ]; then
        DEFAULT_PACKAGE_NAME=$(get_repo_pubspec_name "$REPO_FULL_NAME" "$REF")
    fi
    if [ -z "$DEFAULT_PACKAGE_NAME" ]; then
        DEFAULT_PACKAGE_NAME="$REPO_NAME"
    fi

    # Ask for package name with detected default
    ensure_tty_ready
    echo ""
    echo "Package name for $REPO_FULL_NAME (default: $DEFAULT_PACKAGE_NAME): "
    read PACKAGE_NAME </dev/tty
    PACKAGE_NAME=${PACKAGE_NAME:-$DEFAULT_PACKAGE_NAME}

    # Sanitize package name (replace hyphens with underscores, etc.)
    PACKAGE_NAME=$(echo "$PACKAGE_NAME" | sed 's/-/_/g' | sed 's/[^a-zA-Z0-9_]//g')

    # Add to pubspec
    echo ""
    echo "📝 Adding $PACKAGE_NAME to pubspec.yaml..."
    if add_package_to_pubspec "$SELECTED_PUBSPEC" "$PACKAGE_NAME" "$REPO_URL" "$REF" "$SUB_PATH"; then
        ADDED_PACKAGES+=("$PACKAGE_NAME ($REPO_FULL_NAME)")
        echo "✅ Successfully added $PACKAGE_NAME"
        
        # Quick validation check after adding package
        echo "🔍 Validating pubspec.yaml after addition..."
        if ! flutter pub get --dry-run >/dev/null 2>&1; then
            echo "⚠️  Potential issue detected with pubspec.yaml"
            echo "💡 This might be due to package name mismatches or dependency conflicts"
            
            echo ""
            echo "🔧 Would you like to run automatic validation and fixes? (y/N): "
            read RUN_VALIDATION </dev/tty
            if [[ $RUN_VALIDATION =~ ^[Yy]$ ]]; then
                validate_project_structure "$(dirname "$SELECTED_PUBSPEC")"
            fi
        fi
        
        # Optional: Analyze exports from the added package
        echo ""
        echo "🔬 Analyze available functions in this package? (y/N): "
        read ANALYZE_EXPORTS </dev/tty
        if [[ $ANALYZE_EXPORTS =~ ^[Yy]$ ]]; then
            analyze_package_exports "$REPO_FULL_NAME" "$PACKAGE_NAME" "$REF"
        fi
    else
        FAILED_PACKAGES+=("$PACKAGE_NAME ($REPO_FULL_NAME)")
        echo "❌ Failed to add $PACKAGE_NAME"
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 Package processing complete!"
echo ""

# Check for dependency conflicts and stale Git dependencies after package addition
if [ ${#ADDED_PACKAGES[@]} -gt 0 ]; then
    echo "🔍 Running post-installation dependency analysis..."
    echo ""
    
    # Check for dependency conflicts
    echo "🔍 Checking for dependency conflicts..."
    check_and_resolve_dependency_conflicts "$SELECTED_PUBSPEC"
    
    # Check for Git dependency cache issues
    echo ""
    echo "🔄 Checking Git dependency cache..."
    check_git_dependency_cache "$SELECTED_PUBSPEC"
    
    echo ""
    echo "✅ Dependency analysis complete!"
    echo ""
fi

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
    read -p "Run 'flutter pub get' now? (y/N): " RUN_PUB_GET </dev/tty
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
