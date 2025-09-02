#!/bin/bash

# Quick utility to fix pubspec.yaml name mismatches
# This addresses the specific error: "name" field doesn't match expected name

echo "🔧 Pubspec Name Mismatch Fixer"
echo "=============================="
echo ""

# Function to fix a single pubspec.yaml
fix_pubspec_name() {
    local pubspec_path="$1"
    local expected_name="$2"
    
    if [ ! -f "$pubspec_path" ]; then
        echo "❌ File not found: $pubspec_path"
        return 1
    fi
    
    # Extract current name
    local current_name=$(grep "^name:" "$pubspec_path" | sed 's/name:[[:space:]]*//' | tr -d '"' | head -1)
    
    if [ -n "$current_name" ] && [ "$current_name" != "$expected_name" ]; then
        echo "🔍 Found mismatch in $pubspec_path:"
        echo "   Current name: $current_name"
        echo "   Expected name: $expected_name"
        
        # Backup original file
        cp "$pubspec_path" "$pubspec_path.backup"
        
        # Update the name
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/^name:.*/name: $expected_name/" "$pubspec_path"
        else
            sed -i "s/^name:.*/name: $expected_name/" "$pubspec_path"
        fi
        
        echo "✅ Fixed: Updated name to '$expected_name'"
        echo "📄 Backup saved as: $pubspec_path.backup"
        return 0
    else
        echo "✅ No mismatch found in $pubspec_path"
        return 0
    fi
}

# Check if user provided specific path
if [ $# -eq 1 ]; then
    # User provided a pubspec.yaml path
    PUBSPEC_PATH="$1"
    if [[ "$PUBSPEC_PATH" != *"pubspec.yaml" ]]; then
        PUBSPEC_PATH="$PUBSPEC_PATH/pubspec.yaml"
    fi
    
    EXPECTED_NAME=$(basename "$(dirname "$PUBSPEC_PATH")")
    fix_pubspec_name "$PUBSPEC_PATH" "$EXPECTED_NAME"
    
elif [ $# -eq 2 ]; then
    # User provided pubspec path and expected name
    fix_pubspec_name "$1" "$2"
    
else
    # Auto-scan current directory and common locations
    echo "🔍 Scanning for pubspec.yaml files with name mismatches..."
    echo ""
    
    SEARCH_DIRS=("." "$HOME/Development" "$HOME/Projects" "$HOME/dev")
    FIXED_COUNT=0
    
    for dir in "${SEARCH_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            echo "Scanning: $dir"
            
            while IFS= read -r -d '' pubspec; do
                expected_name=$(basename "$(dirname "$pubspec")")
                if fix_pubspec_name "$pubspec" "$expected_name"; then
                    ((FIXED_COUNT++))
                fi
                echo ""
            done < <(find "$dir" -maxdepth 3 -name "pubspec.yaml" -print0 2>/dev/null)
        fi
    done
    
    echo ""
    echo "🎉 Scan complete! Fixed $FIXED_COUNT name mismatches."
    
    if [ $FIXED_COUNT -gt 0 ]; then
        echo ""
        echo "💡 **Next steps:**"
        echo "  1. Review the changes in your pubspec.yaml files"
        echo "  2. Run 'flutter pub get' to validate the fixes"
        echo "  3. Test your applications to ensure everything works"
        echo ""
        echo "📄 **Backup files created** with .backup extension if you need to revert"
    fi
fi

echo ""
echo "✨ Use this script anytime you encounter name mismatch errors!"
echo "📖 Usage:"
echo "  ./fix_pubspec_names.sh                    # Auto-scan and fix"
echo "  ./fix_pubspec_names.sh /path/to/project   # Fix specific project"
echo "  ./fix_pubspec_names.sh pubspec.yaml name # Fix with custom name"