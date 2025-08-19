# Enhanced Flutter Development Environment Setup for Windows

Automated setup for Flutter development with **multi-select repository interface**, **SSH support**, and **private package management**.

## 🚀 Quick Start

**Double-click to run:**
```
windows\setup-windows.bat
```

That's it! The setup will guide you through everything with an intuitive interface.

## ✨ Key Features

### 🎯 **Multi-Select Repository Interface**
- Interactive checklist with arrow navigation
- Use **SPACE** to select/deselect repositories
- Use **ENTER** to confirm your selection
- Select multiple private repositories at once

### 🔐 **SSH Support for Private Repositories**  
- Automatic SSH key generation and setup
- One-click GitHub SSH key integration
- Secure access to private repositories
- Automatic clipboard copy of SSH keys

### 📦 **Intelligent Package Management**
- Automatic pubspec.yaml updates
- Branch/tag selection for each package
- Monorepo support with path specification
- Backup creation before modifications

### 🔄 **One-Click Authentication**
- GitHub CLI auto-installation via winget
- Device authentication with clipboard integration
- Automatic Git configuration
- Credential helper setup

## 📁 Directory Structure

```
setup_flutter_dev_env/
├── README.md                           # This documentation
├── private-packages.json               # Sample configuration file
└── windows/
    ├── setup-windows.bat              # One-click launcher
    ├── setup-windows.ps1              # Enhanced PowerShell script
    └── private-packages.json          # Windows-specific config
```

## 🎮 How to Use

### 1. **Run the Setup**
Double-click `windows\setup-windows.bat` or run:
```powershell
.\windows\setup-windows.bat
```

### 2. **Follow the Interactive Interface**
1. **Prerequisites Check** - Auto-installs GitHub CLI if needed
2. **GitHub Authentication** - One-time code automatically copied to clipboard
3. **Git Configuration** - Auto-configures with your GitHub details
4. **SSH Setup** (optional) - For enhanced private repository access
5. **Repository Selection** - Multi-select interface for choosing packages
6. **Package Configuration** - Configure each selected repository
7. **Auto-Update** - Automatic pubspec.yaml updates and `flutter pub get`

### 3. **Repository Selection Interface**

The enhanced interface shows all your repositories:

```
🔍 Select repositories to add as Flutter packages:

Navigation: ↑↓ arrows | Selection: SPACE | Confirm: ENTER | Quit: Q

  [ ] your-org/flutter-shared-ui (🔒 private) - Shared UI components
> [✓] your-org/api-client (🔒 private) - API client library  
  [ ] your-org/utils (🌐 public) - Common utilities
  [✓] your-org/auth-package (🔒 private) - Authentication package

Selected: 2 repositories
```

**Controls:**
- **↑↓ arrows** - Navigate through repositories
- **SPACE** - Select/deselect current repository
- **ENTER** - Confirm selection and continue
- **Q** - Quit without selecting

### 4. **Package Configuration**

For each selected repository, you'll configure:
```
Configuring package: your-org/api-client
Package name (default: api_client): 
Available branches: main, develop, feature/v2
Branch/tag (default: main): develop
Path within repository (optional, for monorepos): packages/core
```

## ⚙️ Advanced Usage

### Command Line Options

```powershell
# Basic interactive mode (default)
.\setup-windows.ps1

# Use SSH for private repositories
.\setup-windows.ps1 -UseSSH

# Authenticate with token
.\setup-windows.ps1 -GitToken "ghp_your_token_here"

# Use custom configuration file
.\setup-windows.ps1 -ConfigFile "my-packages.json"

# Combine options
.\setup-windows.ps1 -UseSSH -GitToken "ghp_xxx" -ConfigFile "prod-packages.json"
```

### SSH vs HTTPS

| Method | Best For | Authentication |
|--------|----------|----------------|
| **HTTPS** | Public repos, CI/CD | Personal access tokens |
| **SSH** | Private repos, development | SSH keys |

**SSH Benefits:**
- More secure for private repositories
- No token expiration issues
- Better for development workflows
- Automatic setup with GitHub integration

## 📋 Configuration File Format

Create `private-packages.json` for automated package management:

```json
{
  "packages": [
    {
      "name": "shared_ui_components",
      "git_url": "git@github.com:your-org/flutter-shared-ui.git",
      "branch": "main",
      "path": "",
      "description": "Shared UI components"
    },
    {
      "name": "api_client",
      "git_url": "https://github.com/your-org/api-client.git", 
      "branch": "develop",
      "path": "packages/client",
      "description": "API client for backend services"
    }
  ]
}
```

**Configuration Options:**
- **name**: Package name in pubspec.yaml (use underscores)
- **git_url**: Full Git repository URL (SSH or HTTPS)
- **branch**: Git branch/tag to use (optional, defaults to "main")
- **path**: Subdirectory path within repo (optional, for monorepos)
- **description**: Human-readable description (optional)

## 🔧 What the Script Does

### 1. **Prerequisites Installation**
- ✅ Installs GitHub CLI via winget (if missing)
- ✅ Verifies Flutter and Git installations
- ✅ Sets up PowerShell execution environment

### 2. **Authentication Setup**
- 🔑 GitHub CLI device authentication
- 📋 Auto-copies one-time codes to clipboard
- ⚙️ Configures Git with GitHub credentials
- 🔐 Sets up credential helpers

### 3. **SSH Configuration** (when enabled)
- 🔑 Generates ED25519 SSH keys
- 📋 Copies public key to clipboard
- 🔗 Guides through GitHub SSH key setup
- ✅ Tests SSH connection to GitHub

### 4. **Repository Management**
- 📋 Fetches all your GitHub repositories
- 🎯 Multi-select interface for choosing packages
- ⚙️ Individual configuration for each package
- 📦 Batch processing of selected repositories

### 5. **Flutter Project Updates**
- 📄 Automatic pubspec.yaml backup
- ➕ Adds Git dependencies to dependencies section
- 🔄 Runs `flutter pub get` automatically
- ✅ Verifies successful package installation

## 🛠️ Prerequisites

### Required (Auto-installed)
- **Flutter SDK**: https://flutter.dev/docs/get-started/install
- **Git**: https://git-scm.com/downloads
- **GitHub CLI**: Automatically installed via winget

### Optional
- **SSH Client**: Built into Windows 10/11
- **Personal Access Token**: For token-based authentication

## 🔒 Security Features

### SSH Key Management
- **ED25519 keys** (modern, secure algorithm)
- **Automatic SSH agent integration**
- **GitHub connection testing**
- **Clipboard integration** for easy setup

### Credential Storage
- **Windows Credential Manager** integration
- **Git credential helper** configuration
- **Secure token storage**
- **No plain-text credential storage**

## 🚨 Troubleshooting

### Common Issues

**"Execution Policy" Error:**
```
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**GitHub CLI Not Found:**
- Run as Administrator or install manually from https://cli.github.com/

**SSH Authentication Fails:**
1. Ensure SSH key is added to GitHub: https://github.com/settings/ssh
2. Test with: `ssh -T git@github.com`
3. Re-run setup with `-UseSSH` flag

**Private Repository Access Denied:**
1. Verify you have repository access
2. Use SSH for private repositories (`-UseSSH`)
3. Check GitHub token permissions (repo scope required)

**Flutter Pub Get Fails:**
1. Verify repository URLs are accessible
2. Check branch/tag names exist
3. Ensure Flutter project structure is valid

### Debug Mode

For detailed debugging, run PowerShell script directly:
```powershell
.\windows\setup-windows.ps1 -Verbose
```

## 🎯 Next Steps After Setup

### 1. **Verify Installation**
```bash
flutter pub deps
flutter doctor
```

### 2. **Import Packages**
```dart
import 'package:your_package_name/your_package_name.dart';
```

### 3. **Development Workflow**
```bash
# Clone repositories for development
gh repo clone your-org/your-package
cd your-package

# Make changes and test
flutter test

# Update in your main project
cd ../your-main-project
flutter pub get
```

### 4. **Team Collaboration**
- Commit `private-packages.json` to your repository
- Share SSH setup instructions with team
- Document package usage in your project README

## 💡 Pro Tips

### Efficient Development
- **Use SSH** for private repositories (faster, more secure)
- **Pin to specific versions** using tags instead of branches
- **Use monorepo paths** for sharing code between packages
- **Keep packages small** and focused on single responsibilities

### Team Workflows  
- **Standardize branch names** (main, develop, staging)
- **Use semantic versioning** for package releases
- **Document package APIs** thoroughly
- **Set up CI/CD** for package repositories

### Performance Optimization
- **Specify exact refs** instead of branch names for production
- **Use local packages** during development
- **Cache packages** in CI/CD environments
- **Monitor dependency tree** with `flutter pub deps`

## 🤝 Support

For issues with this setup script:
- Check the troubleshooting section above
- Review PowerShell execution policies
- Verify GitHub CLI installation and authentication

For Flutter-specific issues:
- Run `flutter doctor` to check your installation
- Visit https://flutter.dev/docs for comprehensive documentation

## 🎉 Success!

Your enhanced Flutter development environment is ready! You now have:

✅ **One-click setup** for new team members  
✅ **Multi-repository package management**  
✅ **Secure SSH authentication** for private repos  
✅ **Automated pubspec.yaml management**  
✅ **Professional development workflow**  

**Happy coding!** 🚀