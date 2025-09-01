#!/bin/bash

# Test upward pubspec.yaml discovery when running from nested scripts directory

set -e

echo "🧪 Testing project discovery from nested scripts directory..."

TEST_ROOT=$(mktemp -d)
PROJECT_ROOT="$TEST_ROOT/sample_flutter_app"
NESTED_DIR="$PROJECT_ROOT/scripts/linux-macos"

mkdir -p "$NESTED_DIR"

# Create a minimal pubspec.yaml at project root
cat > "$PROJECT_ROOT/pubspec.yaml" << 'YAML'
name: sample_flutter_app
environment:
  sdk: ^3.5.0
dependencies:
  flutter:
    sdk: flutter
YAML

pushd "$NESTED_DIR" >/dev/null

# Run the same upward detection logic as the main script
DETECTED_PUBSPEC_PATH=""
SEARCH_DIR="$(pwd)"
while true; do
    if [ -f "$SEARCH_DIR/pubspec.yaml" ]; then
        DETECTED_PUBSPEC_PATH="$SEARCH_DIR/pubspec.yaml"
        break
    fi
    PARENT_DIR="$(dirname "$SEARCH_DIR")"
    if [ "$PARENT_DIR" = "$SEARCH_DIR" ]; then
        break
    fi
    SEARCH_DIR="$PARENT_DIR"
done

echo "Detected pubspec: $DETECTED_PUBSPEC_PATH"

EXPECTED="$PROJECT_ROOT/pubspec.yaml"
if [ "$DETECTED_PUBSPEC_PATH" = "$EXPECTED" ]; then
    echo "✅ Upward detection succeeded"
    RESULT=0
else
    echo "❌ Upward detection failed"
    echo "Expected: $EXPECTED"
    echo "Got     : $DETECTED_PUBSPEC_PATH"
    RESULT=1
fi

popd >/dev/null

# Cleanup
rm -rf "$TEST_ROOT"

exit $RESULT


