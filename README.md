# Flutter Package Manager

A cross-platform tool that transforms GitHub into your private package manager for Flutter projects. Easily add GitHub repositories as git dependencies with an interactive interface.

## ⚡ Quick Start (One-Line Install)

### 🐧 **Linux/macOS**

#### 🚀 Install & Run Immediately
```bash
curl -sSL https://raw.githubusercontent.com/daslaller/flutter_packagemanager_setup/main/install.sh | bash
```

#### 🏃 Run Directly (No Installation) 
```bash
curl -sSL https://raw.githubusercontent.com/daslaller/flutter_packagemanager_setup/main/run.sh | bash
```

#### 📦 Install Only (Run Later)
```bash
curl -sSL https://raw.githubusercontent.com/daslaller/flutter_packagemanager_setup/main/install.sh | bash -s -- --no-run
flutter-pm  # Run anytime!
```

### 🪟 **Windows**

#### 🚀 Install & Run Immediately
```powershell
iwr -useb https://raw.githubusercontent.com/daslaller/flutter_packagemanager_setup/main/install.ps1 | iex
```

#### 🏃 Run Directly (No Installation)
```powershell
iwr -useb https://raw.githubusercontent.com/daslaller/flutter_packagemanager_setup/main/run.ps1 | iex
```

#### 📦 Install Only (Run Later)
```powershell
iwr -useb https://raw.githubusercontent.com/daslaller/flutter_packagemanager_setup/main/install.ps1 | iex -NoRun
flutter-pm  # Run anytime!
```

## 🚀 Features

- **🤖 Smart Dependency Recommendations**: AI-powered code analysis that detects Flutter patterns and suggests high-quality packages with intelligent quality scoring
- **🔍 Enhanced Project Discovery**: 
  - **Local Scan**: Automatically finds Flutter projects in common directories
  - **GitHub Fetch**: Clone Flutter projects directly from GitHub with custom save locations
- **📦 Multi-Repository Selection**: Select multiple repositories at once using an interactive interface
- **🎯 Cross-Platform**: Works on Linux, macOS, and Windows
- **🔐 GitHub Integration**: Seamless authentication and repository access via GitHub CLI
- **⚡ Interactive UI**: Spacebar to select, arrow keys to navigate, Enter to confirm
- **🛡️ Safe Operations**: Automatic backups before modifying pubspec.yaml files

## 📁 Project Structure

```
flutter_packagemanager_setup/
├── scripts/
│   ├── linux-macos/
│   │   └── linux_macos_full.sh      # Main script for Unix systems
│   ├── windows/
│   │   ├── windows_full_standalone.ps1
│   │   ├── auto_and_download_windows.bat
│   │   └── auto_and_use_local_sh.bat
│   └── shared/
│       ├── multiselect.sh           # Reusable multiselect component
│       └── smart_recommendations.sh  # AI-powered package recommendations
├── tests/
│   └── test_multiselect.sh          # Test for multiselect functionality
├── test_smart_recommendations.sh    # Test for smart recommendations system
├── examples/
│   └── test_flutter_project/        # Example Flutter project
├── docs/
├── future-plans.md                  # Comprehensive AI roadmap
└── README.md
```

## 🛠️ Prerequisites

### Linux/macOS
- **Git**: Version control system
- **GitHub CLI (`gh`)**: For repository access and authentication
- **jq**: JSON processor for parsing GitHub API responses
- **Flutter**: For Flutter project management

### Installation Commands

**macOS (via Homebrew):**
```bash
brew install gh jq
```

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install gh jq
```

**CentOS/RHEL:**
```bash
sudo yum install gh jq
```

## 🚀 Quick Start

### 1. Clone and Setup
```bash
git clone <repository-url>
cd flutter_packagemanager_setup
chmod +x scripts/linux-macos/linux_macos_full.sh
```

### 2. Run the Script
```bash
./scripts/linux-macos/linux_macos_full.sh
```

### 3. Follow the Interactive Process
1. **Authentication**: The script will open GitHub authentication in your browser
2. **Project Source Selection**: Choose how to find your Flutter project:
   - **Local Scan**: Find existing projects on your machine
   - **GitHub Fetch**: Clone a project from GitHub (with custom save location)
   - **Detected Project (new)**: If you run the script from a nested folder (e.g. `your_app/scripts/linux-macos`), it will automatically detect the nearest parent project containing `pubspec.yaml` and offer it as the default selection.
3. **Project Selection**: Choose your Flutter project from discovered/cloned projects
4. **Repository Selection**: Use the interactive multi-selector:
   - `↑/↓` or `j/k` to navigate
   - `SPACE` to select/deselect repositories
   - `ENTER` to confirm selection
   - `q` to quit
5. **Package Configuration**: For each selected repository:
   - Choose package name (defaults to repository name)
   - Select branch/tag reference (defaults to 'main')
6. **Automatic Integration**: Script updates pubspec.yaml with git dependencies

## 🎮 Interactive Interface

The multiselect interface provides an intuitive way to choose multiple repositories:

```
Select repositories (SPACE to select, ENTER to confirm):

Use ↑/↓ or j/k to navigate, SPACE to select/deselect, ENTER to confirm, q to quit

  [ ] user/flutter_widgets (public) - Custom Flutter widgets
► [✓] user/api_client (private) - API client library  
  [✓] org/shared_models (public) - Shared data models
  [ ] user/another_package (public) - Another useful package

Selected: 2 items
```

## 📦 Generated Dependencies

The script adds dependencies to your pubspec.yaml in this format:

```yaml
dependencies:
  flutter:
    sdk: flutter
  custom_widgets:
    git:
      url: https://github.com/user/flutter_widgets.git
      ref: main
  api_client:
    git:
      url: https://github.com/user/api_client.git
      ref: v1.2.0
```

## 🔧 Advanced Usage

### Custom Repository URLs
You can also add repositories by providing URLs directly instead of selecting from your repositories.

### Branch/Tag Selection
For each repository, you can specify:
- Specific branches (e.g., `develop`, `feature/new-api`)
- Tagged releases (e.g., `v1.0.0`, `v2.1.3`)
- Commit hashes for precise version control

### Backup and Recovery
- Original pubspec.yaml files are automatically backed up as `.backup`
- If a package already exists, you'll be prompted to replace it
- Failed operations don't affect your original files

## 🧪 Testing

Test the multiselect functionality:
```bash
chmod +x tests/test_multiselect.sh
./tests/test_multiselect.sh
```

## 🐛 Troubleshooting

### Common Issues

**"GitHub CLI not found"**
```bash
# Install GitHub CLI first
brew install gh  # macOS
# or follow: https://cli.github.com
```

**"Not authenticated with GitHub"**
```bash
gh auth login
# Follow the browser authentication process
```

**"No Flutter projects found"**
- You can now run the script from inside a nested `scripts` directory; it will detect the nearest parent with `pubspec.yaml`.
- Or ensure your Flutter projects are in standard directories:
  - `~/Development`
  - `~/Projects`
  - `~/dev`

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is open source. See LICENSE file for details.

## 🤝 Major Contributors

### 🚀 **Daslaller** - Creator & Lead Developer
- Original concept and architecture
- Core Flutter Package Manager implementation
- Cross-platform support (Windows, macOS, Linux)
- Interactive multiselect interface
- GitHub integration and authentication system

### 🤖 **Claude (Anthropic)** - AI Development Partner
- **Smart Dependency Recommendations System** - AI-powered code analysis that detects Flutter patterns and suggests high-quality packages with intelligent quality scoring (Phase 1 of the AI roadmap)
- **Advanced Code Pattern Detection** - Comprehensive analysis engine that identifies improvement opportunities across 10+ Flutter/Dart patterns
- **Quality-First Package Database** - Curated recommendations prioritizing code elegance and ingenuity over popularity
- **Installer Reliability Engineering** - Fixed critical bugs in curl|bash installations and terminal input handling
- **Documentation & Architecture** - Comprehensive future roadmap planning and technical documentation

*This collaboration represents a unique partnership between human creativity and AI technical expertise, resulting in an intelligent package management system that prioritizes code quality and developer experience.*

## 🔗 Related

- [GitHub CLI Documentation](https://cli.github.com)
- [Flutter Dependencies Guide](https://docs.flutter.dev/development/packages-and-plugins/using-packages)
- [Git Dependencies in pubspec.yaml](https://dart.dev/tools/pub/dependencies#git-packages)