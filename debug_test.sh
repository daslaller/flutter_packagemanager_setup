#!/bin/bash

echo "=== Debugging Flutter Project Discovery ==="

# Test current directory detection
CURRENT_PUBSPEC="./pubspec.yaml"
if [ -f "$CURRENT_PUBSPEC" ]; then
    echo "✅ Found pubspec.yaml in current directory: $CURRENT_PUBSPEC"
else
    echo "❌ No pubspec.yaml in current directory"
fi

# Test directory search
echo ""
echo "=== Testing Directory Search ==="
SEARCH_DIRS=("$HOME/Development" "$HOME/Projects" "$HOME/dev" ".")
FLUTTER_PROJECTS=()

for dir in "${SEARCH_DIRS[@]}"; do
    echo "Searching in: $dir"
    if [ -d "$dir" ]; then
        while IFS= read -r -d '' project; do
            FLUTTER_PROJECTS+=("$project")
            echo "  Found: $project"
        done < <(find "$dir" -maxdepth 3 -name "pubspec.yaml" -print0 2>/dev/null)
    else
        echo "  Directory doesn't exist"
    fi
done

echo ""
echo "Total Flutter projects found: ${#FLUTTER_PROJECTS[@]}"
for project in "${FLUTTER_PROJECTS[@]}"; do
    PROJECT_DIR=$(dirname "$project")
    PROJECT_NAME=$(basename "$PROJECT_DIR")
    echo "  - $PROJECT_NAME at $PROJECT_DIR"
done