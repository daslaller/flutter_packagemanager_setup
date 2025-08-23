#!/bin/bash

# Cross-platform compatibility test script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/shared/cross_platform_utils.sh"

echo "🧪 Cross-Platform Compatibility Test"
echo "====================================="
echo ""

# Test 1: Distribution Detection
echo "1. Testing distribution detection..."
DISTRO=$(detect_linux_distro)
echo "   Detected: $DISTRO"
echo ""

# Test 2: Package Installation Suggestions
echo "2. Testing package installation suggestions..."
echo "   For 'jq':"
suggest_package_install "jq"
echo ""
echo "   For 'gh':"
suggest_package_install "gh"
echo ""

# Test 3: Cross-platform sed (simulate with temp file)
echo "3. Testing cross-platform sed..."
TEMP_FILE=$(mktemp)
echo -e "line1\ntest_package: ^1.0.0\nline3" > "$TEMP_FILE"
echo "   Original file:"
cat "$TEMP_FILE" | sed 's/^/     /'

echo "   After removing 'test_package' line:"
cross_platform_sed "/test_package:/d" "$TEMP_FILE"
cat "$TEMP_FILE" | sed 's/^/     /'
rm "$TEMP_FILE"
echo ""

# Test 4: Browser opening (dry run)
echo "4. Testing browser detection..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "   macOS detected - would use 'open' command"
elif command -v xdg-open &> /dev/null; then
    echo "   ✅ xdg-open available (standard Linux)"
elif command -v gnome-open &> /dev/null; then
    echo "   ✅ gnome-open available (older GNOME)"
elif command -v kde-open &> /dev/null; then
    echo "   ✅ kde-open available (KDE)"
elif command -v exo-open &> /dev/null; then
    echo "   ✅ exo-open available (Xfce)"
elif command -v firefox &> /dev/null; then
    echo "   ✅ Firefox available as fallback"
elif command -v google-chrome &> /dev/null; then
    echo "   ✅ Chrome available as fallback"
elif command -v chromium &> /dev/null; then
    echo "   ✅ Chromium available as fallback"
else
    echo "   ⚠️  No browser opener found - will show manual URL"
fi
echo ""

# Test 5: Clipboard detection
echo "5. Testing clipboard support..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "   macOS detected - would use 'pbcopy'"
elif command -v xclip &> /dev/null; then
    echo "   ✅ xclip available"
elif command -v xsel &> /dev/null; then
    echo "   ✅ xsel available"
elif command -v wl-copy &> /dev/null; then
    echo "   ✅ wl-copy available (Wayland)"
else
    echo "   ⚠️  No clipboard tool found - will show manual copy instruction"
fi
echo ""

# Test 6: Python availability for realpath fallback
echo "6. Testing Python availability for path resolution..."
if command -v python3 &> /dev/null; then
    echo "   ✅ python3 available"
    python3 -c "import os.path; print('   Test: ' + os.path.relpath('/home/user/project', '/home/user'))"
elif command -v python &> /dev/null; then
    echo "   ✅ python available"
    python -c "import os.path; print('   Test: ' + os.path.relpath('/home/user/project', '/home/user'))"
else
    echo "   ⚠️  No Python found - will use full paths"
fi
echo ""

# Test 7: Common Linux command availability
echo "7. Testing common command availability..."
COMMANDS=("find" "grep" "awk" "sed" "cut" "tr" "sort" "head" "tail")
for cmd in "${COMMANDS[@]}"; do
    if command -v "$cmd" &> /dev/null; then
        echo "   ✅ $cmd"
    else
        echo "   ❌ $cmd (CRITICAL - script may fail)"
    fi
done
echo ""

echo "✅ Cross-platform compatibility test completed!"
echo ""
echo "💡 Summary:"
echo "   - Distribution: $DISTRO"
echo "   - All critical commands should be available on standard Linux distributions"
echo "   - Fallbacks are provided for missing optional tools"
echo "   - Script should work on Ubuntu, Debian, CentOS, Fedora, Arch, Alpine, and macOS"