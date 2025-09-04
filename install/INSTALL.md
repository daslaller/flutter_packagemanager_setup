# 🚀 Flutter Package Manager - One-Line Installation

## Quick Install & Run

```bash
curl -sSL https://raw.githubusercontent.com/daslaller/flutter_packagemanager_setup/main/install.sh | bash
```

## Installation Options

### 📥 Install Only (Don't Run)
```bash
curl -sSL https://raw.githubusercontent.com/daslaller/flutter_packagemanager_setup/main/install.sh | bash -s -- --no-run
```

### 🔄 Update Existing Installation
```bash
curl -sSL https://raw.githubusercontent.com/daslaller/flutter_packagemanager_setup/main/install.sh | bash -s -- --update
```

### 📖 Show Help
```bash
curl -sSL https://raw.githubusercontent.com/daslaller/flutter_packagemanager_setup/main/install.sh | bash -s -- --help
```

## What the Installer Does

1. **🔍 Auto-detects** your operating system (macOS/Linux)
2. **📦 Installs dependencies**:
   - Git (if missing)
   - GitHub CLI (`gh`)
   - jq (JSON processor)
3. **📥 Downloads** the latest Flutter Package Manager
4. **🔗 Creates global command** `flutter-pm`
5. **🚀 Optionally runs** immediately

## After Installation

### Global Command Available
```bash
flutter-pm  # Run from anywhere!
```

### Manual Execution
```bash
~/.flutter_package_manager/flutter-pm
```

### Add to PATH (if global install failed)
```bash
echo 'export PATH="$HOME/.flutter_package_manager:$PATH"' >> ~/.bashrc
echo 'export PATH="$HOME/.flutter_package_manager:$PATH"' >> ~/.zshrc
```

## Features

- ✅ **Zero-download workflow** - run directly from GitHub
- 🔄 **Auto-updates** - always get the latest version
- 🌍 **Cross-platform** - works on macOS and Linux
- 🛡️ **Safe installation** - creates backups, handles permissions
- 🔧 **Dependency management** - installs required tools automatically

## Security Note

The installer downloads from the official repository and runs with standard permissions. Review the install script before running if desired:

```bash
curl -sSL https://raw.githubusercontent.com/daslaller/flutter_packagemanager_setup/main/install.sh
```

---

## 💡 Pro Tips

**For teams/CI:**
```bash
# Install silently without prompts
curl -sSL https://raw.githubusercontent.com/daslaller/flutter_packagemanager_setup/main/install.sh | bash -s -- --no-run
```

**Quick package management:**
```bash
# One command to rule them all
curl -sSL https://raw.githubusercontent.com/daslaller/flutter_packagemanager_setup/main/install.sh | bash
```

**Keep updated:**
```bash
# Update and run latest version
curl -sSL https://raw.githubusercontent.com/daslaller/flutter_packagemanager_setup/main/install.sh | bash -s -- --update && flutter-pm
```