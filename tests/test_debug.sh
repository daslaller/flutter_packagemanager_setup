#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/shared/multiselect.sh"

# Test multi-mode
echo "=== Testing MULTI mode ==="
TEST_OPTIONS=("Option 1" "Option 2" "Option 3")
SELECTED=()
multiselect "Test multi-mode (should allow spacebar toggle):" TEST_OPTIONS SELECTED

echo "Multi-mode result: Selected ${#SELECTED[@]} items"
for idx in "${SELECTED[@]}"; do
    echo "  [$idx] ${TEST_OPTIONS[idx]}"
done

echo ""
echo "=== Testing SINGLE mode ==="
SELECTED2=()
multiselect "Test single-mode (should exit on spacebar):" TEST_OPTIONS SELECTED2 true

echo "Single-mode result: Selected ${#SELECTED2[@]} items"
for idx in "${SELECTED2[@]}"; do
    echo "  [$idx] ${TEST_OPTIONS[idx]}"
done
