#!/bin/bash

# Test script to debug multiselect input issues
source "./scripts/shared/multiselect.sh"

# Create test array
TEST_OPTIONS=("Option 1" "Option 2" "Option 3" "Option 4" "Option 5")
SELECTED=()

echo "Testing multiselect with debug mode..."
multiselect "Test Selection:" TEST_OPTIONS SELECTED false true

echo "Selected indices: ${SELECTED[@]}"
for idx in "${SELECTED[@]}"; do
    echo "Selected: ${TEST_OPTIONS[$idx]}"
done