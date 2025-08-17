# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains a Flutter Package Manager setup system that helps developers easily add GitHub repositories as dependencies to Flutter projects. The system includes automated development environment setup scripts for Windows, macOS, and Linux platforms.

## Repository Structure

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
│       └── multiselect.sh           # Reusable multiselect component
├── tests/
│   └── test_multiselect.sh          # Test for multiselect functionality
├── examples/
│   └── test_flutter_project/        # Example Flutter project
├── docs/
├── README.md
└── CLAUDE.md
```

## Key Scripts and Usage

### For Unix Systems (Linux/macOS)
- **Main script**: `scripts/linux-macos/linux_macos_full.sh`
- **Usage**: `./scripts/linux-macos/linux_macos_full.sh`
- **Purpose**: Interactive Flutter package manager with multiselect interface that searches for Flutter projects and adds multiple GitHub repositories as git dependencies

### For Windows Systems
- **PowerShell script**: `windows_full_standalone.ps1`
- **Usage**: `.\windows_full_standalone.ps1`
- **Batch launchers**: 
  - `auto_and_download_windows.bat` - Downloads and runs setup script
  - `auto_and_use_local_sh.bat` - Uses local setup script

## Core Functionality

### Package Management System
- **Project Discovery**: Automatically finds Flutter projects in common directories (`~/Development`, `~/Projects`, `~/dev`, current directory)
- **Repository Integration**: Uses GitHub CLI (`gh`) to list user repositories and add them as git dependencies
- **pubspec.yaml Modification**: Automatically modifies pubspec.yaml files to add git dependencies with proper formatting
- **Reference Selection**: Allows selection of specific branches or tags for dependencies
- **Multiselection**: Allaws the user to select multiple different repositories from the command line to be used as packages, list repositories and let the user mark each repository wanted with spacebar and enter to confirm.

### Setup Scripts Architecture
- **Environment Setup**: Installs and configures Git, GitHub CLI
- **Authentication**: Handles GitHub authentication via GitHub CLI
- **Cross-platform Support**: Separate implementations for Windows (PowerShell/Batch) and Unix (Bash)

## Prerequisites and Dependencies

### Required Tools
- **Git**: Version control system
- **GitHub CLI (`gh`)**: For repository access and authentication
- **Flutter**: For Flutter project management (when working with Flutter projects)

### Authentication Requirements
- GitHub authentication via `gh auth login`
- Proper Git configuration (user.name, user.email)

## Key Functions

### scripts/linux-macos/linux_macos_full.sh:
- `add_package_to_pubspec()`: Core function for modifying pubspec.yaml files
- Project discovery logic using `find` command
- Repository listing via GitHub CLI API
- **Multiselect interface**: Interactive menu with spacebar selection for multiple repositories
- Batch processing of selected repositories with individual configuration

### scripts/shared/multiselect.sh:
- `multiselect()`: Reusable interactive multiselect component
- Cross-platform keyboard navigation (arrow keys, j/k)
- Visual feedback with checkboxes and highlighting
- Supports spacebar selection and Enter confirmation

### windows_full_standalone.ps1:
- `Add-PackageToPubspec()`: PowerShell equivalent of pubspec modification
- `Manage-Packages()`: Main package management workflow
- Windows-specific path handling and environment setup

## Common Development Workflows

### Adding Multiple Packages to Flutter Project
1. Run the appropriate script for your platform
2. Authenticate with GitHub (automatic browser flow)
3. Select target Flutter project from discovered projects  
4. **Use multiselect interface** to choose multiple repositories:
   - Navigate with ↑/↓ arrow keys or j/k
   - Press SPACE to select/deselect repositories
   - Press ENTER to confirm selection
   - Press q to quit
5. For each selected repository:
   - Specify package name (defaults to repository name)
   - Select branch/tag reference (defaults to 'main')
6. Script automatically updates pubspec.yaml and provides summary of changes

### Setting Up Development Environment
1. Run platform-specific setup script
2. Scripts handle Git and GitHub CLI installation
3. Authenticate with GitHub
4. Configure Git user settings
5. Create development directory structure

## File Modification Patterns

### pubspec.yaml Updates
The scripts add dependencies in this format:
```yaml
dependencies:
  package_name:
    git:
      url: https://github.com/owner/repo.git
      ref: branch_or_tag
```

### Backup Strategy
- Original pubspec.yaml files are backed up as `pubspec.yaml.backup` before modification
- Package replacement prompts user for confirmation if package already exists

## Error Handling and Validation

- Git and GitHub CLI availability checks
- GitHub authentication status verification
- pubspec.yaml existence validation
- Input sanitization for package names (hyphens converted to underscores)
- Repository URL parsing and validation