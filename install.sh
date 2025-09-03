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

# Function to download the package manager
download_package_manager() {
    echo ""
    echo "📥 Downloading Flutter Package Manager..."
    
    # Create install directory
    mkdir -p "$INSTALL_DIR"
    
    # Download the repository
    if [ -d "$INSTALL_DIR/.git" ]; then
        echo "📂 Updating existing installation..."
        cd "$INSTALL_DIR"
        git pull origin "$BRANCH" >/dev/null 2>&1 || {
            echo "⚠️  Update failed, downloading fresh copy..."
            cd ..
            rm -rf "$INSTALL_DIR"
            git clone "$REPO_URL" "$INSTALL_DIR"
        }
    else
        echo "📥 Downloading fresh installation..."
        if [ -d "$INSTALL_DIR" ]; then
            rm -rf "$INSTALL_DIR"
        fi
        git clone "$REPO_URL" "$INSTALL_DIR"
    fi
    
    echo "✅ Download complete"
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
    read RUN_CHOICE </dev/tty
    RUN_CHOICE=${RUN_CHOICE:-1}
    
    case "$RUN_CHOICE" in
        1)
            echo "🚀 Starting Flutter Package Manager..."
            echo ""
            cd "$INSTALL_DIR"
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