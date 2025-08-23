#!/bin/bash

# Test script for pubspec.yaml modification
set -e

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
        echo "Replacing automatically for test..."
        # Remove existing entry - use different syntax for macOS/Linux compatibility
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "/^[[:space:]]*$PACKAGE_NAME:/d" "$PUBSPEC_PATH"
        else
            sed -i "/^[[:space:]]*$PACKAGE_NAME:/d" "$PUBSPEC_PATH"
        fi
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

# Test the function
echo "🧪 Testing pubspec.yaml modification..."
echo ""

# Test adding a package
add_package_to_pubspec "test_flutter_project/pubspec.yaml" "my_custom_package" "https://github.com/user/my_custom_package.git" "main"

echo ""
echo "📄 Result:"
echo "--- Modified pubspec.yaml ---"
cat test_flutter_project/pubspec.yaml
echo ""
echo "--- Backup ---"
cat test_flutter_project/pubspec.yaml.backup