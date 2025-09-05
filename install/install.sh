#!/bin/bash

# Flutter Package Manager - One-line installer
# Usage: curl -sSL https://raw.githubusercontent.com/user/repo/main/install.sh | bash

set -e

REPO_URL="https://github.com/daslaller/flutter_packagemanager_setup"
BRANCH="main"
INSTALL_DIR="$HOME/.flutter_package_manager"
SCRIPT_NAME="flutter-pm"

echo "🚀 Flutter Package Manager Installer"
echo "====================================="
echo ""

# Function to detect OS and package manager
detect_system() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        SCRIPT_PATH="scripts/linux-macos/linux_macos_full.sh"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        SCRIPT_PATH="scripts/linux-macos/linux_macos_full.sh"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
        OS="windows"
        SCRIPT_PATH="scripts/windows/windows_full_standalone.ps1"
        echo "❌ Windows installation via curl not supported yet"
        echo "💡 Please download manually from: $REPO_URL"
        exit 1
    else
        OS="unknown"
        echo "❌ Unsupported operating system: $OSTYPE"
        exit 1
    fi
    
    echo "🖥️  Detected OS: $OS"
}

# Function to install dependencies
install_dependencies() {
    echo ""
    echo "📦 Checking dependencies..."
    
    local missing_deps=()
    
    # Check for required tools
    if ! command -v git >/dev/null 2>&1; then
        missing_deps+=("git")
    fi
    
    if ! command -v gh >/dev/null 2>&1; then
        missing_deps+=("gh")
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        missing_deps+=("jq")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "⚠️  Missing dependencies: ${missing_deps[*]}"
        echo ""
        
        # Try to install automatically based on OS
        case "$OS" in
            macos)
                if command -v brew >/dev/null 2>&1; then
                    echo "🍺 Installing via Homebrew..."
                    for dep in "${missing_deps[@]}"; do
                        case "$dep" in
                            gh) brew install gh ;;
                            jq) brew install jq ;;
                            git) brew install git ;;
                        esac
                    done
                else
                    echo "❌ Homebrew not found. Please install missing dependencies manually:"
                    echo "   brew install gh jq git"
                    exit 1
                fi
                ;;
            linux)
                if command -v apt >/dev/null 2>&1; then
                    echo "📦 Installing via apt..."
                    sudo apt update
                    for dep in "${missing_deps[@]}"; do
                        case "$dep" in
                            gh) 
                                curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
                                echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
                                sudo apt update
                                sudo apt install gh
                                ;;
                            jq) sudo apt install jq ;;
                            git) sudo apt install git ;;
                        esac
                    done
                elif command -v yum >/dev/null 2>&1; then
                    echo "📦 Installing via yum..."
                    for dep in "${missing_deps[@]}"; do
                        case "$dep" in
                            gh) sudo yum install gh ;;
                            jq) sudo yum install jq ;;
                            git) sudo yum install git ;;
                        esac
                    done
                else
                    echo "❌ No supported package manager found. Please install manually:"
                    echo "   ${missing_deps[*]}"
                    exit 1
                fi
                ;;
        esac
        
        echo "✅ Dependencies installation complete"
    else
        echo "✅ All dependencies available"
    fi
}

# Function to download the package manager with smart update detection
download_package_manager() {
    echo ""
    echo "📥 Downloading Flutter Package Manager..."
    
    # Create install directory with proper error handling
    if [ ! -d "$INSTALL_DIR" ]; then
        echo "📥 Fresh installation detected"
        if mkdir -p "$INSTALL_DIR" 2>/dev/null; then
            if git clone "$REPO_URL" "$INSTALL_DIR" 2>/dev/null; then
                echo "✅ Download complete"
                return 0
            else
                echo "❌ Git clone failed"
                rm -rf "$INSTALL_DIR" 2>/dev/null
                exit 1
            fi
        else
            echo "❌ Could not create installation directory"
            exit 1
        fi
    fi
    
    # Smart update detection for existing installation
    if [ -d "$INSTALL_DIR/.git" ]; then
        echo "🔍 Analyzing existing installation for selective updates..."
        
        cd "$INSTALL_DIR" || { echo "❌ Could not access installation directory"; exit 1; }
        
        # Get current commit hash
        local current_commit=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
        
        # Fetch latest changes to compare
        git fetch origin "$BRANCH" >/dev/null 2>&1 || true
        local latest_commit=$(git rev-parse "origin/$BRANCH" 2>/dev/null || echo "unknown")
        
        if [ "$current_commit" = "$latest_commit" ]; then
            echo "✅ Installation is already up to date (commit: ${current_commit:0:7})"
            cd - >/dev/null
            return 0
        fi
        
        echo "🔄 Updates available (${current_commit:0:7} → ${latest_commit:0:7})"
        echo "📋 Analyzing file changes for selective update..."
        
        # Get list of changed files between commits
        local changed_files=$(git diff --name-only HEAD "origin/$BRANCH" 2>/dev/null)
        
        if [ -z "$changed_files" ]; then
            echo "✅ No file changes detected, updating commit reference only..."
            git pull origin "$BRANCH" >/dev/null 2>&1
            cd - >/dev/null
            return 0
        fi
        
        # Show what files will be updated
        echo ""
        echo "📝 **Files to be updated:**"
        echo "$changed_files" | while read -r file; do
            if [ -n "$file" ]; then
                # Get file size for context
                local size=""
                if [ -f "$file" ]; then
                    size=" ($(wc -c < "$file" 2>/dev/null || echo "0") bytes)"
                fi
                echo "   📄 $file$size"
            fi
        done
        
        echo ""
        echo "🔧 **Update options:**"
        echo "1. 🚀 Update all changed files (recommended)"
        echo "2. 🎯 Select specific files to update"
        echo "3. 📋 Show detailed file differences"
        echo "4. ⏭️  Skip update (keep current version)"
        echo ""
        
        echo "Choose option (1-4, default: 1): "
        read UPDATE_CHOICE </dev/tty 2>/dev/null || UPDATE_CHOICE=1
        UPDATE_CHOICE=${UPDATE_CHOICE:-1}
        
        case "$UPDATE_CHOICE" in
            1)
                perform_selective_update "$changed_files" "all"
                ;;
            2)
                select_files_to_update "$changed_files"
                ;;
            3)
                show_file_differences "$changed_files"
                echo ""
                echo "🔧 Apply updates now? (y/N): "
                read APPLY_UPDATES </dev/tty 2>/dev/null || APPLY_UPDATES="N"
                if [[ $APPLY_UPDATES =~ ^[Yy]$ ]]; then
                    perform_selective_update "$changed_files" "all"
                fi
                ;;
            4)
                echo "⏭️  Keeping current version (${current_commit:0:7})"
                cd - >/dev/null
                return 0
                ;;
            *)
                echo "❌ Invalid choice, updating all files..."
                perform_selective_update "$changed_files" "all"
                ;;
        esac
        
        cd - >/dev/null || true
    else
        echo "📂 Non-git installation detected, performing full replacement..."
        if [ -n "$INSTALL_DIR" ] && [ "$INSTALL_DIR" != "/" ] && [ "$INSTALL_DIR" != "$HOME" ]; then
            rm -rf "$INSTALL_DIR"
            git clone "$REPO_URL" "$INSTALL_DIR"
            echo "✅ Fresh installation complete"
        else
            echo "❌ Safety check failed: Invalid INSTALL_DIR"
            exit 1
        fi
    fi
}

# Function to perform selective file updates
perform_selective_update() {
    local changed_files="$1"
    local update_mode="$2"
    
    echo ""
    echo "🔄 **Performing selective update...**"
    echo ""
    
    if [ "$update_mode" = "all" ]; then
        # Update all changed files
        echo "📦 Updating all changed files..."
        if git pull origin "$BRANCH" >/dev/null 2>&1; then
            local new_commit=$(git rev-parse HEAD 2>/dev/null | cut -c1-7)
            echo "✅ **Update complete!** (now at commit: $new_commit)"
        else
            echo "⚠️  Git pull encountered issues, but installation can continue"
            local current_commit=$(git rev-parse HEAD 2>/dev/null | cut -c1-7)
            echo "📍 Staying at current commit: $current_commit"
        fi
        
        echo ""
        echo "📋 **Files updated:**"
        echo "$changed_files" | while read -r file; do
            if [ -n "$file" ]; then
                echo "   ✨ $file"
            fi
        done
    else
        # Selective file update (would require more complex git operations)
        echo "🎯 Selective file update not yet implemented, updating all..."
        if git pull origin "$BRANCH" >/dev/null 2>&1; then
            echo "✅ Update successful"
        else
            echo "⚠️  Git pull encountered issues"
        fi
    fi
}

# Function to select specific files to update
select_files_to_update() {
    local changed_files="$1"
    
    echo ""
    echo "🎯 **Select files to update:**"
    echo ""
    
    local i=1
    echo "$changed_files" | while read -r file; do
        if [ -n "$file" ]; then
            echo "$i. 📄 $file"
            i=$((i+1))
        fi
    done
    
    echo ""
    echo "Enter file numbers (comma-separated, or 'all'): "
    read FILE_SELECTION </dev/tty 2>/dev/null || FILE_SELECTION="all"
    
    if [ "$FILE_SELECTION" = "all" ]; then
        perform_selective_update "$changed_files" "all"
    else
        echo "💡 Individual file selection requires full update - updating all..."
        perform_selective_update "$changed_files" "all"
    fi
}

# Function to show detailed file differences
show_file_differences() {
    local changed_files="$1"
    
    echo ""
    echo "📋 **Detailed File Changes:**"
    echo "============================"
    
    echo "$changed_files" | while read -r file; do
        if [ -n "$file" ]; then
            echo ""
            echo "📄 **$file**"
            echo "$(printf '%.50s' "$(printf '%*s' 50 '' | tr ' ' '-')")"
            
            # Show file diff summary
            local additions=$(git diff --numstat HEAD "origin/$BRANCH" -- "$file" 2>/dev/null | cut -f1)
            local deletions=$(git diff --numstat HEAD "origin/$BRANCH" -- "$file" 2>/dev/null | cut -f2)
            
            if [ -n "$additions" ] && [ -n "$deletions" ]; then
                echo "   📊 Changes: +$additions additions, -$deletions deletions"
            fi
            
            # Show first few lines of diff for context
            echo "   📝 Preview:"
            git diff HEAD "origin/$BRANCH" -- "$file" 2>/dev/null | head -20 | sed 's/^/      /'
            
            # Check if this is a critical file
            case "$file" in
                *linux_macos_full.sh)
                    echo "   🎯 **Main script file** - contains core functionality"
                    ;;
                *windows*.ps1)
                    echo "   🪟 **Windows script** - Windows-specific functionality"
                    ;;
                install.sh)
                    echo "   📦 **Installer script** - installation and update logic"
                    ;;
                README.md)
                    echo "   📚 **Documentation** - user instructions and info"
                    ;;
                *)
                    echo "   📁 **Supporting file** - additional functionality"
                    ;;
            esac
        fi
    done
}

# Function to create global command
create_global_command() {
    echo ""
    echo "🔗 Setting up global command..."
    
    # Create a wrapper script
    local wrapper_script="/usr/local/bin/$SCRIPT_NAME"
    
    cat > "$INSTALL_DIR/$SCRIPT_NAME" << EOF
#!/bin/bash
# Flutter Package Manager global wrapper
exec bash "$INSTALL_DIR/$SCRIPT_PATH" "\$@"
EOF
    
    chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
    
    # Try to create symlink in /usr/local/bin
    if [ -w "/usr/local/bin" ]; then
        ln -sf "$INSTALL_DIR/$SCRIPT_NAME" "$wrapper_script"
        echo "✅ Global command created: $SCRIPT_NAME"
    else
        echo "⚠️  Cannot create global command (permission denied)"
        echo "💡 Run manually with: $INSTALL_DIR/$SCRIPT_NAME"
        echo "💡 Or add to PATH: export PATH=\"$INSTALL_DIR:\$PATH\""
        
        # Suggest adding to shell profile
        echo ""
        echo "🔧 To add permanently, add this to your shell profile:"
        echo "   echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> ~/.bashrc"
        echo "   echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> ~/.zshrc"
    fi
}

# Function to run immediately (optional)
run_immediately() {
    echo ""
    echo "🚀 Installation complete!"
    echo ""
    echo "📋 Available options:"
    echo "1. 🎯 Run Flutter Package Manager now"
    echo "2. ✅ Exit (run later with '$SCRIPT_NAME')"
    echo ""
    
    echo "Choose option (1-2, default: 1): "
    read RUN_CHOICE </dev/tty 2>/dev/null || RUN_CHOICE=1
    RUN_CHOICE=${RUN_CHOICE:-1}
    
    case "$RUN_CHOICE" in
        1)
            echo "🚀 Starting Flutter Package Manager..."
            echo ""
            cd "$INSTALL_DIR" || { echo "❌ Could not access installation directory"; exit 1; }
            exec bash "$SCRIPT_PATH"
            ;;
        2)
            echo "✅ Ready to use! Run '$SCRIPT_NAME' anytime to start."
            ;;
        *)
            echo "✅ Ready to use! Run '$SCRIPT_NAME' anytime to start."
            ;;
    esac
}

# Main installation flow
main() {
    detect_system
    install_dependencies
    download_package_manager
    create_global_command
    run_immediately
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "Flutter Package Manager Installer"
        echo ""
        echo "Usage:"
        echo "  curl -sSL $REPO_URL/raw/$BRANCH/install.sh | bash"
        echo "  curl -sSL $REPO_URL/raw/$BRANCH/install.sh | bash -s -- --no-run"
        echo ""
        echo "Options:"
        echo "  --help, -h    Show this help"
        echo "  --no-run      Install only, don't run immediately"
        echo "  --update      Update existing installation"
        exit 0
        ;;
    --no-run)
        echo "🔧 Installing without running..."
        detect_system
        install_dependencies  
        download_package_manager
        create_global_command
        echo "✅ Installation complete! Run '$SCRIPT_NAME' to start."
        exit 0
        ;;
    --update)
        echo "🔄 Updating Flutter Package Manager..."
        detect_system
        download_package_manager
        echo "✅ Update complete!"
        exit 0
        ;;
    *)
        main
        ;;
esac