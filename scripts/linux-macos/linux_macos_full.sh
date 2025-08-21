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

# Function to get Flutter projects from GitHub
get_github_flutter_projects() {
    echo "🔍 Searching GitHub for Flutter projects..."
    
    # Get user's Flutter repositories from GitHub
    local GITHUB_FLUTTER_JSON
    GITHUB_FLUTTER_JSON=$(gh repo list --limit 100 --json name,owner,description,url --jq '.[] | select(.name | test("flutter|dart"; "i")) | select(.description // "" | test("flutter|dart"; "i"))')
    
    if [ -z "$GITHUB_FLUTTER_JSON" ]; then
        # If no Flutter-specific repos found, try broader search
        echo "🔍 No Flutter-specific repos found, searching all repositories..."
        GITHUB_FLUTTER_JSON=$(gh repo list --limit 50 --json name,owner,description,url)
    fi
    
    echo "$GITHUB_FLUTTER_JSON"
}

# Function to clone and setup GitHub project
clone_github_project() {
    local REPO_FULL_NAME="$1"
    local TARGET_DIR="$2"
    
    echo "📥 Cloning $REPO_FULL_NAME..."
    
    # Determine clone directory
    local CLONE_DIR
    if [ -n "$TARGET_DIR" ]; then
        CLONE_DIR="$TARGET_DIR"
    else
        # Default to ~/Development or ~/Projects
        if [ -d "$HOME/Development" ]; then
            CLONE_DIR="$HOME/Development/$(echo "$REPO_FULL_NAME" | cut -d'/' -f2)"
        elif [ -d "$HOME/Projects" ]; then
            CLONE_DIR="$HOME/Projects/$(echo "$REPO_FULL_NAME" | cut -d'/' -f2)"
        else
            CLONE_DIR="$HOME/$(echo "$REPO_FULL_NAME" | cut -d'/' -f2)"
        fi
    fi
    
    # Check if directory already exists
    if [ -d "$CLONE_DIR" ]; then
        echo "⚠️  Directory $CLONE_DIR already exists"
        read -p "Use existing directory? (Y/n): " USE_EXISTING
        if [[ ! "$USE_EXISTING" =~ ^[Nn]$ ]]; then
            if [ -f "$CLONE_DIR/pubspec.yaml" ]; then
                echo "✅ Using existing project at $CLONE_DIR"
                echo "$CLONE_DIR/pubspec.yaml"
                return 0
            else
                echo "❌ Existing directory is not a Flutter project"
                return 1
            fi
        else
            echo "❌ Cancelled"
            return 1
        fi
    fi
    
    # Clone the repository
    if gh repo clone "$REPO_FULL_NAME" "$CLONE_DIR"; then
        # Check if it's actually a Flutter project
        if [ -f "$CLONE_DIR/pubspec.yaml" ]; then
            echo "✅ Successfully cloned Flutter project to $CLONE_DIR"
            echo "$CLONE_DIR/pubspec.yaml"
            return 0
        else
            echo "❌ Cloned repository is not a Flutter project (no pubspec.yaml found)"
            echo "🗑️  Removing cloned directory..."
            rm -rf "$CLONE_DIR"
            return 1
        fi
    else
        echo "❌ Failed to clone repository"
        return 1
    fi
}

# Function to select project directory
select_project_directory() {
    local CURRENT_PUBSPEC="./pubspec.yaml"
    local FLUTTER_PROJECTS=()
    local PROJECT_OPTIONS=()
    local GITHUB_PROJECTS=()
    
    echo "🔍 Discovering Flutter projects..."
    
    # Add current directory option if it has pubspec.yaml
    if [ -f "$CURRENT_PUBSPEC" ]; then
        FLUTTER_PROJECTS+=("$CURRENT_PUBSPEC")
        PROJECT_OPTIONS+=("📁 Current Directory - $(basename "$(pwd)") ($(pwd))")
    fi
    
    # Search in common directories
    SEARCH_DIRS=("$HOME/Development" "$HOME/Projects" "$HOME/dev" ".")
    
    for dir in "${SEARCH_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            while IFS= read -r -d '' project; do
                # Skip if it's the current directory (already added above)
                if [ "$(realpath "$(dirname "$project")")" != "$(realpath ".")" ]; then
                    FLUTTER_PROJECTS+=("$project")
                fi
            done < <(find "$dir" -maxdepth 3 -name "pubspec.yaml" -print0 2>/dev/null)
        fi
    done
    
    # Add remaining local projects to options
    for project in "${FLUTTER_PROJECTS[@]}"; do
        if [ "$project" != "$CURRENT_PUBSPEC" ]; then
            PROJECT_DIR=$(dirname "$project")
            PROJECT_NAME=$(basename "$PROJECT_DIR")
            RELATIVE_PATH=$(get_relative_path "$PROJECT_DIR")
            PROJECT_OPTIONS+=("💻 $PROJECT_NAME ($RELATIVE_PATH)")
        fi
    done
    
    # Get GitHub Flutter projects
    echo ""
    GITHUB_FLUTTER_JSON=$(get_github_flutter_projects)
    
    if [ -n "$GITHUB_FLUTTER_JSON" ] && [ "$GITHUB_FLUTTER_JSON" != "[]" ]; then
        # Parse GitHub projects and add to options
        while IFS= read -r line; do
            if [ -n "$line" ]; then
                REPO_NAME=$(echo "$line" | jq -r '.name')
                REPO_OWNER=$(echo "$line" | jq -r '.owner.login')
                REPO_DESC=$(echo "$line" | jq -r '.description // "No description"')
                GITHUB_PROJECTS+=("$REPO_OWNER/$REPO_NAME")
                PROJECT_OPTIONS+=("🌐 $REPO_OWNER/$REPO_NAME - $REPO_DESC")
            fi
        done < <(echo "$GITHUB_FLUTTER_JSON" | jq -c '.')
    fi
    
    # Add option to select a custom directory
    PROJECT_OPTIONS+=("🗂️  Select custom directory...")
    
    if [ ${#PROJECT_OPTIONS[@]} -eq 0 ]; then
        echo "❌ No Flutter projects found. Run this from a Flutter project directory or select a custom directory."
        exit 1
    fi
    
    echo ""
    echo "📂 Select a project directory:"
    echo ""
    
    # Use single-select for project selection
    SELECTED_INDEX=-1
    singleselect "Select a Flutter project (ENTER to select):" PROJECT_OPTIONS SELECTED_INDEX
    
    if [ "$SELECTED_INDEX" -eq -1 ]; then
        echo "❌ No project selected"
        exit 1
    fi
    
    local CURRENT_COUNT=0
    local LOCAL_COUNT=${#FLUTTER_PROJECTS[@]}
    local GITHUB_COUNT=${#GITHUB_PROJECTS[@]}
    
    # Handle custom directory selection (last option)
    if [ "$SELECTED_INDEX" -eq $((${#PROJECT_OPTIONS[@]} - 1)) ]; then
        echo ""
        echo "🗂️  Enter custom directory path:"
        read -p "Path: " CUSTOM_PATH
        
        # Expand tilde and relative paths
        CUSTOM_PATH=$(eval echo "$CUSTOM_PATH")
        
        if [ ! -d "$CUSTOM_PATH" ]; then
            echo "❌ Directory does not exist: $CUSTOM_PATH"
            exit 1
        fi
        
        CUSTOM_PUBSPEC="$CUSTOM_PATH/pubspec.yaml"
        if [ ! -f "$CUSTOM_PUBSPEC" ]; then
            echo "❌ No pubspec.yaml found in: $CUSTOM_PATH"
            exit 1
        fi
        
        SELECTED_PUBSPEC="$CUSTOM_PUBSPEC"
        SELECTED_PROJECT=$(basename "$CUSTOM_PATH")
        return
    fi
    
    # Check if selection is current directory
    if [ -f "$CURRENT_PUBSPEC" ] && [ "$SELECTED_INDEX" -eq 0 ]; then
        SELECTED_PUBSPEC="$CURRENT_PUBSPEC"
        SELECTED_PROJECT=$(basename "$(pwd)")
        return
    fi
    
    # Adjust index if current directory was included
    local ADJUSTED_INDEX=$SELECTED_INDEX
    if [ -f "$CURRENT_PUBSPEC" ]; then
        ADJUSTED_INDEX=$((SELECTED_INDEX - 1))
    fi
    
    # Check if selection is local project
    if [ "$ADJUSTED_INDEX" -lt "$LOCAL_COUNT" ]; then
        SELECTED_PUBSPEC="${FLUTTER_PROJECTS[$ADJUSTED_INDEX]}"
        SELECTED_PROJECT=$(basename "$(dirname "$SELECTED_PUBSPEC")")
        return
    fi
    
    # Selection must be GitHub project
    local GITHUB_INDEX=$((ADJUSTED_INDEX - LOCAL_COUNT))
    if [ "$GITHUB_INDEX" -lt "$GITHUB_COUNT" ]; then
        local SELECTED_GITHUB_REPO="${GITHUB_PROJECTS[$GITHUB_INDEX]}"
        echo ""
        echo "📥 Selected GitHub project: $SELECTED_GITHUB_REPO"
        
        # Ask for clone location
        echo ""
        read -p "📁 Clone to directory (leave empty for default): " CLONE_DIR
        
        # Clone the project
        CLONED_PUBSPEC=$(clone_github_project "$SELECTED_GITHUB_REPO" "$CLONE_DIR")
        if [ $? -eq 0 ] && [ -f "$CLONED_PUBSPEC" ]; then
            SELECTED_PUBSPEC="$CLONED_PUBSPEC"
            SELECTED_PROJECT=$(basename "$(dirname "$SELECTED_PUBSPEC")")
        else
            echo "❌ Failed to clone and setup GitHub project"
            exit 1
        fi
    else
        echo "❌ Invalid selection"
        exit 1
    fi
}

# Select project directory
select_project_directory

echo "📱 Using project: $SELECTED_PROJECT"

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