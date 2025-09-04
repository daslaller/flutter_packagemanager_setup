#!/bin/bash

# Flutter Package Manager - Direct Run (No Installation)
# Usage: curl -sSL https://raw.githubusercontent.com/user/repo/main/run.sh | bash

set -e

REPO_URL="https://github.com/daslaller/flutter_packagemanager_setup"
BRANCH="main"
TEMP_DIR=$(mktemp -d)

echo "📦 Flutter Package Manager - Direct Run"
echo "======================================="
echo ""

# Function to cleanup on exit
cleanup() {
    echo "🧹 Cleaning up temporary files..."
    rm -rf "$TEMP_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# Quick dependency check
check_dependencies() {
    local missing=()
    
    command -v git >/dev/null 2>&1 || missing+=("git")
    command -v gh >/dev/null 2>&1 || missing+=("gh") 
    command -v jq >/dev/null 2>&1 || missing+=("jq")
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo "❌ Missing dependencies: ${missing[*]}"
        echo ""
        echo "🔧 Quick install commands:"
        
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "  brew install ${missing[*]}"
        elif command -v apt >/dev/null 2>&1; then
            echo "  sudo apt install ${missing[*]}"
        elif command -v yum >/dev/null 2>&1; then
            echo "  sudo yum install ${missing[*]}"
        fi
        
        echo ""
        echo "💡 Or use the full installer: curl -sSL $REPO_URL/raw/$BRANCH/install.sh | bash"
        exit 1
    fi
    
    echo "✅ All dependencies available"
}

# Download and run
run_package_manager() {
    echo "📥 Downloading to temporary location..."
    
    # Clone to temp directory
    if git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$TEMP_DIR/flutter_pm" >/dev/null 2>&1; then
        echo "✅ Download complete"
        echo ""
        echo "🚀 Starting Flutter Package Manager..."
        echo ""
        
        # Determine script path based on OS
        if [[ "$OSTYPE" == "darwin"* ]] || [[ "$OSTYPE" == "linux-gnu"* ]]; then
            cd "$TEMP_DIR/flutter_pm"
            exec bash "scripts/linux-macos/linux_macos_full.sh"
        else
            echo "❌ Unsupported OS for direct run: $OSTYPE"
            exit 1
        fi
    else
        echo "❌ Download failed"
        echo "💡 Check your internet connection or try the full installer"
        exit 1
    fi
}

# Main execution
main() {
    check_dependencies
    run_package_manager
}

# Handle arguments
case "${1:-}" in
    --help|-h)
        echo "Flutter Package Manager - Direct Run"
        echo ""
        echo "This script downloads and runs the package manager without installation."
        echo ""
        echo "Usage:"
        echo "  curl -sSL $REPO_URL/raw/$BRANCH/run.sh | bash"
        echo ""
        echo "For permanent installation, use:"
        echo "  curl -sSL $REPO_URL/raw/$BRANCH/install.sh | bash"
        exit 0
        ;;
    *)
        main
        ;;
esac