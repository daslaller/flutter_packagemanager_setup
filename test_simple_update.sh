#!/bin/bash

# Universal Git Update Function Test
universal_git_update() {
    local repo_path="${1:-.}"
    local target_branch="${2:-main}"
    local update_type="${3:-self}"
    local target_commit="${4:-}"
    
    echo "Universal Git Update Check"
    echo "Repository: $repo_path"
    echo "Target branch: $target_branch"
    echo "Update type: $update_type"
    
    local original_dir=$(pwd)
    if ! cd "$repo_path" 2>/dev/null; then
        echo "Cannot access repository: $repo_path"
        return 1
    fi
    
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "Not a Git repository: $repo_path"
        cd "$original_dir"
        return 1
    fi
    
    local current_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    local current_commit=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    local current_short=$(echo "$current_commit" | cut -c1-7)
    
    echo "Current branch: $current_branch"
    echo "Current commit: $current_short"
    echo ""
    
    echo "Checking remote status..."
    local remote_output=$(git remote -v update 2>&1)
    echo "Remote update result:"
    echo "$remote_output"
    echo ""
    
    echo "Repository status:"
    local status_output=$(git status -uno)
    echo "$status_output" | head -3
    echo ""
    
    local updates_available=false
    local remote_commit=""
    local remote_short=""
    
    if [ -n "$target_commit" ]; then
        echo "Comparing against target commit: $(echo "$target_commit" | cut -c1-7)"
        if [ "$current_commit" != "$target_commit" ]; then
            updates_available=true
            remote_commit="$target_commit"
            remote_short=$(echo "$target_commit" | cut -c1-7)
        fi
    else
        remote_commit=$(git rev-parse "origin/$target_branch" 2>/dev/null || echo "unknown")
        remote_short=$(echo "$remote_commit" | cut -c1-7)
        
        echo "Remote commit: $remote_short"
        
        if [ "$current_commit" != "$remote_commit" ] && [ "$remote_commit" != "unknown" ]; then
            updates_available=true
        fi
        
        if echo "$status_output" | grep -q "behind.*by.*commit"; then
            updates_available=true
        fi
    fi
    
    echo ""
    if [ "$updates_available" = true ]; then
        echo "Updates Available!"
        echo "Current: $current_short"
        echo "Target:  $remote_short"
    else
        echo "Already up to date"
        echo "Current: $current_short"
        echo "Remote:  $remote_short"
    fi
    
    cd "$original_dir"
    echo ""
    return 0
}

echo "Testing Universal Git Update Function"
echo "===================================="

echo "Test 1: Flutter-PM self-update"
universal_git_update "." "main" "self"

previous_commit=$(git log --oneline -n 5 | tail -1 | cut -d' ' -f1)
if [ -n "$previous_commit" ]; then
    echo "Test 2: Specific commit comparison"
    universal_git_update "." "main" "package" "$previous_commit"
fi

echo "Testing Complete!"