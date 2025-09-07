#!/bin/bash

# Universal Git Update Function - External Testing
# Uses git status and git remote commands for maximum reliability

# Universal function that can handle both self-updates and package updates
universal_git_update() {
    local repo_path="${1:-.}"  # Default to current directory
    local target_branch="${2:-main}"  # Default to main branch
    local update_type="${3:-self}"  # 'self' or 'package'
    local target_commit="${4:-}"  # Optional: specific commit to compare against
    
    echo ""
    echo "🔄 **Universal Git Update Check**"
    echo "================================="
    echo "📍 Repository: $repo_path"
    echo "📍 Target branch: $target_branch"
    echo "📍 Update type: $update_type"
    
    # Change to repository directory
    local original_dir=$(pwd)
    if ! cd "$repo_path" 2>/dev/null; then
        echo "❌ Cannot access repository: $repo_path"
        return 1
    fi
    
    # Verify this is a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo "❌ Not a Git repository: $repo_path"
        cd "$original_dir"
        return 1
    fi
    
    # Get current branch and commit
    local current_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    local current_commit=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    local current_short=$(echo "$current_commit" | cut -c1-7)
    
    echo "📍 Current branch: $current_branch"
    echo "📍 Current commit: $current_short"
    echo ""
    
    # Use git remote update (combines fetch + status info)
    echo "🔍 Checking remote status..."
    local remote_output=$(git remote -v update 2>&1)
    echo "📡 Remote update output:"
    echo "$remote_output" | sed 's/^/   /'
    echo ""
    
    # Use git status for comprehensive status
    echo "📋 Repository status:"
    local status_output=$(git status -uno --porcelain=v1)
    local status_summary=$(git status -uno | head -3)
    echo "$status_summary" | sed 's/^/   /'
    echo ""
    
    # Determine if updates are available
    local updates_available=false
    local remote_commit=""
    local remote_short=""
    
    if [ -n "$target_commit" ]; then
        # Specific commit comparison mode
        echo "🎯 Comparing against target commit: $(echo "$target_commit" | cut -c1-7)"
        if [ "$current_commit" != "$target_commit" ]; then
            updates_available=true
            remote_commit="$target_commit"
            remote_short=$(echo "$target_commit" | cut -c1-7)
        fi
    else
        # Branch comparison mode - check against remote branch
        remote_commit=$(git rev-parse "origin/$target_branch" 2>/dev/null || echo "unknown")
        remote_short=$(echo "$remote_commit" | cut -c1-7)
        
        echo "📍 Remote commit: $remote_short"
        
        if [ "$current_commit" != "$remote_commit" ] && [ "$remote_commit" != "unknown" ]; then
            updates_available=true
        fi
        
        # Double-check with git status info
        if echo "$status_summary" | grep -q "behind.*by.*commit"; then
            updates_available=true
        fi
    fi
    
    echo ""
    if [ "$updates_available" = true ]; then
        echo "🔄 **Updates Available!**"
        echo "   Current: $current_short"
        echo "   Target:  $remote_short"
        echo ""
        
        # Show what would change
        if [ "$remote_commit" != "unknown" ] && [ -z "$target_commit" ]; then
            echo "📋 Recent changes:"
            git log --oneline --max-count=5 HEAD..origin/$target_branch 2>/dev/null | sed 's/^/   • /' || echo "   (Unable to show changes)"
            echo ""
        fi
        
        # Interactive update option
        read -p "🔄 Apply update? (y/N): " update_choice
        
        if [[ "$update_choice" =~ ^[Yy]$ ]]; then
            echo ""
            echo "🔄 Applying update..."
            
            if [ -n "$target_commit" ]; then
                # Specific commit checkout
                if git checkout "$target_commit" 2>/dev/null; then
                    echo "✅ Successfully updated to commit: $(git rev-parse --short HEAD)"
                else
                    echo "❌ Failed to checkout target commit"
                    cd "$original_dir"
                    return 1
                fi
            else
                # Branch pull
                if git pull origin "$target_branch" 2>/dev/null; then
                    local new_commit=$(git rev-parse --short HEAD)
                    echo "✅ Successfully updated to commit: $new_commit"
                else
                    echo "❌ Failed to pull updates"
                    cd "$original_dir"
                    return 1
                fi
            fi
            
            echo ""
            echo "🎯 **Verification:**"
            local final_status=$(git status -uno | head -2)
            echo "$final_status" | sed 's/^/   /'
            
            if echo "$final_status" | grep -q "up to date"; then
                echo ""
                echo "🎉 ✅ Update completed successfully!"
            else
                echo ""
                echo "⚠️  Update may need verification - check status above"
            fi
        else
            echo "⏭️  Update skipped"
        fi
    else
        echo "✅ **Already up to date**"
        echo "   Current: $current_short"
        echo "   Remote:  $remote_short"
    fi
    
    cd "$original_dir"
    echo ""
    return 0
}

# Test scenarios
echo "🧪 **Testing Universal Git Update Function**"
echo "============================================"

# Test 1: Self-update scenario (flutter-pm repository)
echo ""
echo "🧪 Test 1: Flutter-PM self-update"
universal_git_update "." "main" "self"

# Test 2: Package repo scenario (would be used for Git dependencies)
echo ""
echo "🧪 Test 2: Package repo update simulation"
echo "   (This would be used for Git dependencies in .pub-cache/git)"
echo "   Simulating with current repo but different target branch/commit..."

# Get a previous commit for testing
previous_commit=$(git log --oneline -n 5 | tail -1 | cut -d' ' -f1)
if [ -n "$previous_commit" ]; then
    echo ""
    echo "🧪 Test 3: Specific commit comparison"
    universal_git_update "." "main" "package" "$previous_commit"
else
    echo "   No previous commits available for testing"
fi

echo ""
echo "🎯 **Testing Complete!**"
echo "Function handles both self-update and package update scenarios"