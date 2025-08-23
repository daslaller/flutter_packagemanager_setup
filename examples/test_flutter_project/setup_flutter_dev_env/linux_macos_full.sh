#!/bin/bash

# Flutter Package Manager
# Easily add GitHub repositories as dependencies

set -e

echo "📦 Flutter Package Manager"
echo "=========================="

# Check if gh is installed and authenticated
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI not found. Please install it first:"
    echo "   https://cli.github.com"
    exit 1
fi

if ! gh auth status &>/dev/null; then
    echo "❌ Not authenticated with GitHub. Run 'gh auth login' first."
    exit 1
fi

# Find current directory's pubspec.yaml or search for Flutter projects
CURRENT_PUBSPEC="./pubspec.yaml"
FLUTTER_PROJECTS=()

if [ -f "$CURRENT_PUBSPEC" ]; then
    echo "📱 Found pubspec.yaml in current directory"
    SELECTED_PUBSPEC="$CURRENT_PUBSPEC"
    SELECTED_PROJECT=$(basename "$(pwd)")
else
    echo "🔍 Searching for Flutter projects..."
    
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
        echo "❌ No Flutter projects found. Run this from a Flutter project directory."
        exit 1
    fi
    
    echo ""
    echo "Select a Flutter project:"
    for i in "${!FLUTTER_PROJECTS[@]}"; do
        PROJECT_DIR=$(dirname "${FLUTTER_PROJECTS[$i]}")
        PROJECT_NAME=$(basename "$PROJECT_DIR")
        RELATIVE_PATH=$(realpath --relative-to="$(pwd)" "$PROJECT_DIR" 2>/dev/null || echo "$PROJECT_DIR")
        echo "$((i+1)). $PROJECT_NAME ($RELATIVE_PATH)"
    done
    
    read -p "Enter project number: " PROJECT_NUM
    
    if [[ ! "$PROJECT_NUM" =~ ^[0-9]+$ ]] || [ "$PROJECT_NUM" -lt 1 ] || [ "$PROJECT_NUM" -gt ${#FLUTTER_PROJECTS[@]} ]; then
        echo "❌ Invalid selection"
        exit 1
    fi
    
    SELECTED_PUBSPEC="${FLUTTER_PROJECTS[$((PROJECT_NUM-1))]}"
    SELECTED_PROJECT=$(basename "$(dirname "$SELECTED_PUBSPEC")")
fi

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
        # Remove existing entry (simplified - removes the package name line)
        sed -i "/^[[:space:]]*$PACKAGE_NAME:/d" "$PUBSPEC_PATH"
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

REPOS=$(gh repo list --limit 100 --json name,owner,isPrivate,url,description | \
    jq -r '.[] | "\(.owner.login)/\(.name) (\(if .isPrivate then "private" else "public" end)) - \(.description // "No description")"')

if [ -z "$REPOS" ]; then
    echo "❌ No repositories found"
    exit 1
fi

echo ""
echo "📋 Available repositories:"
echo "$REPOS" | nl -w3 -s'. '

echo ""
echo "💡 Tip: You can also enter a custom repository URL"
read -p "Enter repository number or URL: " SELECTION

# Handle custom URL input
if [[ "$SELECTION" =~ ^https?:// ]] || [[ "$SELECTION" =~ ^git@ ]]; then
    # Custom URL provided
    REPO_URL="$SELECTION"
    if [[ "$REPO_URL" =~ github\.com[/:]([^/]+)/([^/\.]+) ]]; then
        REPO_OWNER="${BASH_REMATCH[1]}"
        REPO_NAME="${BASH_REMATCH[2]}"
        REPO_FULL_NAME="$REPO_OWNER/$REPO_NAME"
    else
        echo "❌ Could not parse repository name from URL"
        exit 1
    fi
elif [[ "$SELECTION" =~ ^[0-9]+$ ]]; then
    # Repository number selected
    SELECTED_REPO_LINE=$(echo "$REPOS" | sed -n "${SELECTION}p")
    if [ -z "$SELECTED_REPO_LINE" ]; then
        echo "❌ Invalid repository number"
        exit 1
    fi
    
    # Extract repository info
    REPO_FULL_NAME=$(echo "$SELECTED_REPO_LINE" | sed 's/ (.*) - .*//')
    REPO_NAME=$(echo "$REPO_FULL_NAME" | cut -d'/' -f2)
    REPO_URL="https://github.com/$REPO_FULL_NAME.git"
else
    echo "❌ Invalid selection"
    exit 1
fi

echo "📦 Selected repository: $REPO_FULL_NAME"

# Ask for package name
echo ""
read -p "Package name (default: $REPO_NAME): " PACKAGE_NAME
PACKAGE_NAME=${PACKAGE_NAME:-$REPO_NAME}

# Sanitize package name (replace hyphens with underscores, etc.)
PACKAGE_NAME=$(echo "$PACKAGE_NAME" | sed 's/-/_/g' | sed 's/[^a-zA-Z0-9_]//g')

# Get branches and tags
echo ""
echo "🏷️  Available references:"
echo "Branches:"
gh api "repos/$REPO_FULL_NAME/branches" --jq '.[].name' 2>/dev/null | head -5 | sed 's/^/  /' || echo "  (Could not fetch branches)"

echo "Tags:"
gh api "repos/$REPO_FULL_NAME/tags" --jq '.[].name' 2>/dev/null | head -3 | sed 's/^/  /' || echo "  (No tags found)"

echo ""
read -p "Specify branch/tag (default: main): " REF
REF=${REF:-main}

# Add to pubspec
add_package_to_pubspec "$SELECTED_PUBSPEC" "$PACKAGE_NAME" "$REPO_URL" "$REF"

echo ""
echo "🎉 Package added successfully!"
echo ""
echo "📄 Added to pubspec.yaml:"
echo "  $PACKAGE_NAME:"
echo "    git:"
echo "      url: $REPO_URL"
if [ -n "$REF" ]; then
    echo "      ref: $REF"
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

echo ""
echo "💫 Import in your Dart code with:"
echo "  import 'package:$PACKAGE_NAME/$PACKAGE_NAME.dart';"