#!/bin/bash

# Cross-platform utility functions for Linux/macOS compatibility

# Function to perform in-place sed editing across platforms
cross_platform_sed() {
    local pattern="$1"
    local file="$2"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS requires empty string after -i
        sed -i '' "$pattern" "$file"
    else
        # Linux and other Unix systems
        sed -i "$pattern" "$file"
    fi
}

# Function to open URL in browser across different Linux environments
open_browser() {
    local url="$1"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        open "$url"
    elif command -v xdg-open &> /dev/null; then
        # Standard Linux (most distributions)
        xdg-open "$url" &> /dev/null &
    elif command -v gnome-open &> /dev/null; then
        # Older GNOME
        gnome-open "$url" &> /dev/null &
    elif command -v kde-open &> /dev/null; then
        # KDE
        kde-open "$url" &> /dev/null &
    elif command -v exo-open &> /dev/null; then
        # Xfce
        exo-open "$url" &> /dev/null &
    elif command -v kioclient5 &> /dev/null; then
        # KDE 5
        kioclient5 exec "$url" &> /dev/null &
    elif command -v kioclient &> /dev/null; then
        # KDE 4
        kioclient exec "$url" &> /dev/null &
    elif command -v firefox &> /dev/null; then
        # Firefox fallback
        firefox "$url" &> /dev/null &
    elif command -v google-chrome &> /dev/null; then
        # Chrome fallback
        google-chrome "$url" &> /dev/null &
    elif command -v chromium &> /dev/null; then
        # Chromium fallback
        chromium "$url" &> /dev/null &
    elif command -v lynx &> /dev/null; then
        # Text browser fallback
        echo "🌐 Opening in text browser (lynx)..."
        lynx "$url"
    else
        # No browser found - manual fallback
        echo "🌐 Please open this URL in your browser:"
        echo "   $url"
        return 1
    fi
}

# Function to copy to clipboard across platforms
copy_to_clipboard() {
    local text="$1"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        echo -n "$text" | pbcopy
        echo "✅ Copied to clipboard (macOS)"
    elif command -v xclip &> /dev/null; then
        # Linux with xclip
        echo -n "$text" | xclip -selection clipboard
        echo "✅ Copied to clipboard (xclip)"
    elif command -v xsel &> /dev/null; then
        # Linux with xsel
        echo -n "$text" | xsel --clipboard --input
        echo "✅ Copied to clipboard (xsel)"
    elif command -v wl-copy &> /dev/null; then
        # Wayland
        echo -n "$text" | wl-copy
        echo "✅ Copied to clipboard (Wayland)"
    else
        echo "⚠️  Could not copy to clipboard automatically"
        echo "    Please copy this manually: $text"
        return 1
    fi
}

# Function to detect Linux distribution for package manager suggestions
detect_linux_distro() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
        return
    fi
    
    # Check for common distro identification files
    if [ -f /etc/os-release ]; then
        # Most modern distributions
        local distro=$(grep "^ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
        echo "$distro"
    elif [ -f /etc/redhat-release ]; then
        # Red Hat, CentOS, Fedora
        if grep -q "CentOS" /etc/redhat-release; then
            echo "centos"
        elif grep -q "Red Hat" /etc/redhat-release; then
            echo "rhel"
        elif grep -q "Fedora" /etc/redhat-release; then
            echo "fedora"
        else
            echo "redhat"
        fi
    elif [ -f /etc/debian_version ]; then
        # Debian or Ubuntu
        if [ -f /etc/lsb-release ] && grep -q "Ubuntu" /etc/lsb-release; then
            echo "ubuntu"
        else
            echo "debian"
        fi
    elif [ -f /etc/arch-release ]; then
        echo "arch"
    elif [ -f /etc/gentoo-release ]; then
        echo "gentoo"
    elif [ -f /etc/alpine-release ]; then
        echo "alpine"
    else
        echo "unknown"
    fi
}

# Function to suggest package installation commands based on distro
suggest_package_install() {
    local package="$1"
    local distro=$(detect_linux_distro)
    
    case "$distro" in
        "macos")
            echo "  brew install $package"
            ;;
        "ubuntu"|"debian")
            echo "  sudo apt update && sudo apt install $package"
            ;;
        "centos"|"rhel")
            if command -v dnf &> /dev/null; then
                echo "  sudo dnf install $package"
            else
                echo "  sudo yum install $package"
            fi
            ;;
        "fedora")
            echo "  sudo dnf install $package"
            ;;
        "arch"|"manjaro")
            echo "  sudo pacman -S $package"
            ;;
        "alpine")
            echo "  sudo apk add $package"
            ;;
        "gentoo")
            echo "  sudo emerge $package"
            ;;
        "opensuse"|"suse")
            echo "  sudo zypper install $package"
            ;;
        *)
            echo "  # Install $package using your distribution's package manager"
            echo "  # Common commands:"
            echo "  #   apt install $package      (Debian/Ubuntu)"
            echo "  #   dnf install $package      (Fedora/RHEL 8+)"
            echo "  #   yum install $package      (CentOS/RHEL 7)"
            echo "  #   pacman -S $package        (Arch Linux)"
            echo "  #   zypper install $package   (openSUSE)"
            echo "  #   apk add $package          (Alpine Linux)"
            ;;
    esac
}