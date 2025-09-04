#!/bin/bash

# Simple test script without debug mode
source "./scripts/shared/multiselect.sh"

# Create test array
TEST_OPTIONS=("Option 1" "Option 2" "Option 3")
SELECTED=()

echo "Testing basic multiselect..."
multiselect "Test Selection:" TEST_OPTIONS SELECTED false false

echo "Selected indices: ${SELECTED[@]}"
for idx in "${SELECTED[@]}"; do
    echo "Selected: ${TEST_OPTIONS[$idx]}"
done