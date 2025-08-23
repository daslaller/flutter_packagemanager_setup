# Cross-Platform Compatibility Guide

This document outlines the cross-platform compatibility measures implemented in the Flutter Package Manager to ensure it works seamlessly across different Linux distributions and macOS.

## 🎯 Tested Platforms

### ✅ Fully Supported
- **macOS** 10.15+ (Catalina and newer)
- **Ubuntu** 18.04+ / Debian 10+
- **CentOS** 7+ / RHEL 7+
- **Fedora** 30+
- **Arch Linux** (rolling release)
- **Alpine Linux** 3.12+

### 🔶 Expected to Work
- **openSUSE Leap** 15.2+
- **Manjaro** (Arch-based)
- **Linux Mint** 19+
- **PopOS** 20.04+
- **Elementary OS** 5.1+

## 🔧 Compatibility Features Implemented

### 1. **Cross-Platform Path Resolution**
- **Problem**: `realpath --relative-to` not available on older Linux distributions
- **Solution**: Multi-tier fallback system:
  1. GNU `realpath` with `--relative-to` (newer Linux)
  2. Python `os.path.relpath()` (universally available)
  3. Full path display (final fallback)

### 2. **Cross-Platform Text Editing**
- **Problem**: `sed -i` syntax differs between macOS and Linux
- **Solution**: `cross_platform_sed()` function detects OS and uses appropriate syntax:
  - macOS: `sed -i '' "pattern" file`
  - Linux: `sed -i "pattern" file`

### 3. **Universal Browser Opening**
- **Problem**: Different desktop environments use different commands
- **Solution**: Comprehensive fallback chain:
  1. `open` (macOS)
  2. `xdg-open` (Standard Linux)
  3. `gnome-open` (Older GNOME)
  4. `kde-open` (KDE)
  5. `exo-open` (Xfce)
  6. `kioclient5`/`kioclient` (KDE 4/5)
  7. Direct browser executables (`firefox`, `chrome`, `chromium`)
  8. Text browser (`lynx`)
  9. Manual URL display

### 4. **Package Manager Detection**
- **Problem**: Different Linux distributions use different package managers
- **Solution**: Automatic distribution detection and package manager suggestions:
  - **Ubuntu/Debian**: `apt`
  - **CentOS/RHEL**: `yum`/`dnf`
  - **Fedora**: `dnf`
  - **Arch Linux**: `pacman`
  - **Alpine**: `apk`
  - **openSUSE**: `zypper`
  - **Gentoo**: `emerge`

### 5. **Clipboard Integration**
- **Problem**: Multiple clipboard systems across different environments
- **Solution**: Multi-system support:
  1. `pbcopy` (macOS)
  2. `xclip` (X11 Linux)
  3. `xsel` (X11 Linux alternative)
  4. `wl-copy` (Wayland Linux)
  5. Manual copy instruction fallback

## 🧪 Testing Strategy

### Automated Compatibility Testing
Run the compatibility test suite:
```bash
./tests/test_cross_platform.sh
```

### Manual Testing Checklist
For each target platform:

1. **Dependencies Check**
   - [ ] Script detects missing `gh` and `jq`
   - [ ] Provides correct installation commands for the distribution
   
2. **Path Resolution**
   - [ ] Project discovery works correctly
   - [ ] Relative paths display properly
   
3. **Browser Integration**
   - [ ] GitHub authentication opens browser automatically
   - [ ] Fallback to manual URL works if browser fails
   
4. **File Operations**
   - [ ] pubspec.yaml modification works
   - [ ] Backup files created successfully
   - [ ] Package replacement works correctly

5. **User Interface**
   - [ ] Multiselect interface displays correctly
   - [ ] Keyboard navigation works (arrows, j/k, space, enter)
   - [ ] Visual feedback is clear

## 🐛 Known Limitations

### Minimal Systems
- **BusyBox environments**: May lack some commands (use full GNU/Linux)
- **Docker Alpine**: Install `bash` and `findutils` packages
- **Very old systems**: Python 2.6 or earlier may not have `os.path.relpath`

### Wayland-only Systems
- Clipboard integration requires `wl-copy`
- Browser opening may require `xdg-open` polyfill

### Headless Systems
- Browser authentication requires manual URL copying
- No clipboard integration available

## 🔨 Distribution-Specific Notes

### **Ubuntu/Debian**
```bash
# Install dependencies
sudo apt update
sudo apt install gh jq

# GitHub CLI may require adding repository first:
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update
sudo apt install gh
```

### **CentOS/RHEL**
```bash
# EPEL repository required for jq
sudo yum install epel-release
sudo yum install jq

# GitHub CLI installation varies by version
# See: https://cli.github.com for specific instructions
```

### **Arch Linux**
```bash
# Install from official repositories
sudo pacman -S github-cli jq
```

### **Alpine Linux**
```bash
# Install bash and required tools
sudo apk add bash findutils github-cli jq

# Note: Use bash instead of sh
bash ./scripts/linux-macos/linux_macos_full.sh
```

## 🚀 Performance Optimizations

### Command Availability Caching
- Command existence checked once at startup
- Results cached for session duration
- Reduces repeated `command -v` calls

### Efficient Distribution Detection
- Uses `/etc/os-release` (modern standard)
- Falls back to legacy detection files
- Cached after first detection

### Minimal External Dependencies
- Only requires `gh`, `jq`, and standard Unix tools
- Python used as fallback, not requirement
- No GUI framework dependencies

## 📊 Compatibility Matrix

| Feature | macOS | Ubuntu | CentOS | Arch | Alpine | Status |
|---------|-------|---------|---------|------|---------|---------|
| Basic functionality | ✅ | ✅ | ✅ | ✅ | ✅ | Full |
| Path resolution | ✅ | ✅ | ✅ | ✅ | ⚠️* | Good |
| Browser opening | ✅ | ✅ | ✅ | ✅ | ⚠️** | Good |
| Package detection | ✅ | ✅ | ✅ | ✅ | ✅ | Full |
| Clipboard support | ✅ | ✅ | ✅ | ✅ | ❌*** | Good |

*Requires Python for older systems  
**May need manual URL in headless environments  
***No clipboard in headless/minimal systems

## 🤝 Contributing Compatibility Fixes

When adding new features or fixing compatibility issues:

1. **Test on multiple platforms** when possible
2. **Use feature detection** instead of OS detection
3. **Provide graceful fallbacks** for missing tools
4. **Update this documentation** with new compatibility notes
5. **Add test cases** to `test_cross_platform.sh`