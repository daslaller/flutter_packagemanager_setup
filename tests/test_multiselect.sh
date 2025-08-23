#!/bin/bash

# Test script for multiselect functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/shared/multiselect.sh"

echo "Testing multiselect functionality..."
echo ""

# Create test options
TEST_OPTIONS=(
    "user/repo1 (public) - My first repository"
    "user/repo2 (private) - My second repository" 
    "organization/repo3 (public) - Organization repository"
    "user/another-repo (public) - Another test repository"
)

SELECTED_INDICES=()

echo "Test multiselect with ${#TEST_OPTIONS[@]} options:"
multiselect "Select test repositories:" TEST_OPTIONS SELECTED_INDICES

echo "Results:"
echo "Selected ${#SELECTED_INDICES[@]} items:"
for idx in "${SELECTED_INDICES[@]}"; do
    echo "  [$idx] ${TEST_OPTIONS[idx]}"
done