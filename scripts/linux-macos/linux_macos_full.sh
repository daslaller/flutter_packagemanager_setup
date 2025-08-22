#!/bin/bash

# Flutter Package Manager
# Easily add GitHub repositories as dependencies

set -e

echo "📦 Flutter Package Manager"
echo "=========================="

# Source shared functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../shared/multiselect.sh"
source "$SCRIPT_DIR/../shared/cross_platform_utils.sh"

# Function to select project source
select_project_source() {
    echo ""
    echo "📱 Flutter Project Source Selection:"
    echo "1. Scan local directories for existing Flutter projects"
    echo "2. Fetch Flutter project from GitHub repository"
    echo ""
    
    while true; do
        read -p "Enter your choice (1-2): " SOURCE_CHOICE
        
        case "$SOURCE_CHOICE" in
            1)
                echo "🔍 Selected: Local directory scan"
                return 1
                ;;
            2)
                echo "📥 Selected: GitHub repository fetch"
                return 2
                ;;
            *)
                echo "❌ Invalid choice. Please enter 1 or 2."
                ;;
        esac
    done
}

# Function to get save location for GitHub projects
get_save_location() {
    echo ""
    echo "📁 Choose save location for GitHub project:"
    
    # Default options
    DEFAULT_LOCATIONS=(
        "$HOME/Development/github-projects"
        "$HOME/Projects/github-projects"
        "$HOME/dev/github-projects"
        "./github-projects"
    )
    
    echo "Suggested locations:"
    for i in "${!DEFAULT_LOCATIONS[@]}"; do
        echo "$((i+1)). ${DEFAULT_LOCATIONS[$i]}"
    done
    echo "$((${#DEFAULT_LOCATIONS[@]}+1)). Enter custom path"
    echo ""
    
    while true; do
        read -p "Enter your choice (1-$((${#DEFAULT_LOCATIONS[@]}+1))): " LOCATION_CHOICE
        
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
    echo "$SELECTED_LOCATION"
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
    
    # Get repository data and filter for potential Flutter projects
    local REPO_JSON
    REPO_JSON=$(gh repo list --limit 100 --json name,owner,url,description,language,topics)
    
    if [ -z "$REPO_JSON" ] || [ "$REPO_JSON" = "[]" ]; then
        echo "❌ No repositories found"
        return 1
    fi
    
    # Filter for likely Flutter projects (language: Dart, topics containing flutter, or names containing flutter)
    local FLUTTER_REPO_JSON
    FLUTTER_REPO_JSON=$(echo "$REPO_JSON" | jq '[
        .[] | select(
            (.language == "Dart") or 
            (.topics[]? | test("flutter"; "i")) or 
            (.name | test("flutter"; "i")) or
            (.description // "" | test("flutter"; "i"))
        )
    ]')
    
    # Create array of repository display strings
    local FLUTTER_REPO_OPTIONS
    mapfile -t FLUTTER_REPO_OPTIONS < <(echo "$FLUTTER_REPO_JSON" | jq -r '.[] | "\(.owner.login)/\(.name) - \(.description // "No description")"')
    
    # Create array of repository URLs for processing
    local FLUTTER_REPO_URLS
    mapfile -t FLUTTER_REPO_URLS < <(echo "$FLUTTER_REPO_JSON" | jq -r '.[] | .url')
    
    if [ ${#FLUTTER_REPO_OPTIONS[@]} -eq 0 ]; then
        echo "❌ No Flutter projects found in your repositories"
        echo "💡 Try option 1 to enter a specific repository URL"
        return 1
    fi
    
    echo ""
    echo "📋 Found ${#FLUTTER_REPO_OPTIONS[@]} potential Flutter projects:"
    echo ""
    
    # Use multiselect function for single selection (could be enhanced for multiple)
    local SELECTED_INDICES=()
    multiselect "Select Flutter project to clone:" FLUTTER_REPO_OPTIONS SELECTED_INDICES
    
    if [ ${#SELECTED_INDICES[@]} -eq 0 ]; then
        echo "❌ No repository selected"
        return 1
    fi
    
    # Clone the selected repository
    local SELECTED_INDEX="${SELECTED_INDICES[0]}"
    local SELECTED_REPO_URL="${FLUTTER_REPO_URLS[$SELECTED_INDEX]}"
    
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
    fi
fi

# If no project selected yet, proceed with source selection
if [ -z "$SELECTED_PUBSPEC" ]; then
    # Select project source (local or GitHub)
    select_project_source
    SOURCE_TYPE=$?
    
    case $SOURCE_TYPE in
        1)
            # Local directory scan
            echo ""
            echo "🔍 Searching for local Flutter projects..."
            
            # Search in common directories
            SEARCH_DIRS=("$HOME/Development" "$HOME/Projects" "$HOME/dev" ".")
            
            for dir in "${SEARCH_DIRS[@]}"; do
                if [ -d "$dir" ]; then
                    while IFS= read -r -d '' project; do
                        FLUTTER_PROJECTS+=("$project")
                    done < <(find "$dir" -maxdepth 3 -name "pubspec.yaml" -print0 2>/dev/null)
                fi
            done
            
            if [ ${#FLUTTER_PROJECTS[@]} -eq 0 ]; then
                echo "❌ No Flutter projects found in local directories."
                echo "💡 Try the GitHub fetch option or run this from a Flutter project directory."
                exit 1
            fi
            ;;
        2)
            # GitHub repository fetch
            SAVE_LOCATION=$(get_save_location)
            if [ $? -ne 0 ]; then
                echo "❌ Failed to get save location"
                exit 1
            fi
            
            if ! fetch_github_project "$SAVE_LOCATION"; then
                echo "❌ Failed to fetch GitHub project"
                exit 1
            fi
            
            if [ ${#FLUTTER_PROJECTS[@]} -eq 0 ]; then
                echo "❌ No Flutter projects found in the fetched repository"
                exit 1
            fi
            ;;
        *)
            echo "❌ Invalid source selection"
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

# Get repositories
echo ""
echo "🔍 Fetching your repositories..."

# Get repository data as JSON for processing
REPO_JSON=$(gh repo list --limit 100 --json name,owner,isPrivate,url,description)

if [ -z "$REPO_JSON" ] || [ "$REPO_JSON" = "[]" ]; then
    echo "❌ No repositories found"
    exit 1
fi

# Create array of repository display strings
mapfile -t REPO_OPTIONS < <(echo "$REPO_JSON" | jq -r '.[] | "\(.owner.login)/\(.name) (\(if .isPrivate then "private" else "public" end)) - \(.description // "No description")"')

# Create array of repository full names for processing
mapfile -t REPO_NAMES < <(echo "$REPO_JSON" | jq -r '.[] | "\(.owner.login)/\(.name)"')

if [ ${#REPO_OPTIONS[@]} -eq 0 ]; then
    echo "❌ No repositories found"
    exit 1
fi

echo ""
echo "📋 Select repositories to add as packages:"
echo ""

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