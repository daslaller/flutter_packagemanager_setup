# Flutter Package Manager - Windows PowerShell Installer
# Usage: iwr -useb https://raw.githubusercontent.com/daslaller/flutter_packagemanager_setup/main/install.ps1 | iex

param(
    [switch]$NoRun,
    [switch]$Update,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

$RepoUrl = "https://github.com/daslaller/flutter_packagemanager_setup"
$Branch = "main"
$InstallDir = "$env:USERPROFILE\.flutter_package_manager"
$ScriptName = "flutter-pm"

Write-Host "🚀 Flutter Package Manager Installer (Windows)" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# Function to detect and install dependencies
function Install-Dependencies {
    Write-Host "📦 Checking dependencies..." -ForegroundColor Yellow
    
    $missing = @()
    
    # Check for Git
    if (!(Get-Command git -ErrorAction SilentlyContinue)) {
        $missing += "Git"
    }
    
    # Check for GitHub CLI
    if (!(Get-Command gh -ErrorAction SilentlyContinue)) {
        $missing += "GitHub CLI"
    }
    
    if ($missing.Count -gt 0) {
        Write-Host "⚠️  Missing dependencies: $($missing -join ', ')" -ForegroundColor Red
        Write-Host ""
        Write-Host "🔧 Please install the missing dependencies:" -ForegroundColor Yellow
        
        if ($missing -contains "Git") {
            Write-Host "  • Git: https://git-scm.com/download/win" -ForegroundColor White
        }
        
        if ($missing -contains "GitHub CLI") {
            Write-Host "  • GitHub CLI: https://cli.github.com" -ForegroundColor White
            Write-Host "    Or via winget: winget install GitHub.cli" -ForegroundColor Gray
        }
        
        Write-Host ""
        Write-Host "💡 Alternative: Use chocolatey or winget:" -ForegroundColor Cyan
        Write-Host "  choco install git gh" -ForegroundColor Gray
        Write-Host "  winget install Git.Git GitHub.cli" -ForegroundColor Gray
        
        exit 1
    } else {
        Write-Host "✅ All dependencies available" -ForegroundColor Green
    }
}

# Function to download the package manager
function Download-PackageManager {
    Write-Host ""
    Write-Host "📥 Downloading Flutter Package Manager..." -ForegroundColor Yellow
    
    # Create install directory
    if (!(Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    }
    
    # Check if it's already a git repo
    if (Test-Path "$InstallDir\.git") {
        Write-Host "📂 Updating existing installation..." -ForegroundColor Cyan
        Push-Location $InstallDir
        try {
            git pull origin $Branch *>$null
            Write-Host "✅ Update complete" -ForegroundColor Green
        } catch {
            Write-Host "⚠️  Update failed, downloading fresh copy..." -ForegroundColor Yellow
            Pop-Location
            Remove-Item $InstallDir -Recurse -Force
            git clone $RepoUrl $InstallDir
        }
        Pop-Location
    } else {
        Write-Host "📥 Downloading fresh installation..." -ForegroundColor Cyan
        if (Test-Path $InstallDir) {
            Remove-Item $InstallDir -Recurse -Force
        }
        git clone $RepoUrl $InstallDir
    }
    
    Write-Host "✅ Download complete" -ForegroundColor Green
}

# Function to create global command
function Create-GlobalCommand {
    Write-Host ""
    Write-Host "🔗 Setting up global command..." -ForegroundColor Yellow
    
    # Create batch wrapper
    $wrapperBat = "$InstallDir\$ScriptName.bat"
    $wrapperContent = @"
@echo off
cd /d "$InstallDir"
powershell -ExecutionPolicy Bypass -File "scripts\windows\windows_full_standalone.ps1" %*
"@
    
    $wrapperContent | Out-File -FilePath $wrapperBat -Encoding ASCII
    
    # Try to add to system PATH
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    
    if ($userPath -notlike "*$InstallDir*") {
        try {
            [Environment]::SetEnvironmentVariable("Path", "$userPath;$InstallDir", "User")
            Write-Host "✅ Global command created: $ScriptName" -ForegroundColor Green
            Write-Host "💡 Restart your terminal to use the command globally" -ForegroundColor Cyan
        } catch {
            Write-Host "⚠️  Cannot modify PATH automatically" -ForegroundColor Yellow
            Write-Host "💡 Add manually: $InstallDir" -ForegroundColor Cyan
            Write-Host "💡 Or run: $wrapperBat" -ForegroundColor Cyan
        }
    } else {
        Write-Host "✅ PATH already contains install directory" -ForegroundColor Green
    }
}

# Function to run immediately (optional)
function Run-Immediately {
    Write-Host ""
    Write-Host "🚀 Installation complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 Available options:" -ForegroundColor Cyan
    Write-Host "1. 🎯 Run Flutter Package Manager now"
    Write-Host "2. ✅ Exit (run later with '$ScriptName')"
    Write-Host ""
    
    $choice = Read-Host "Choose option (1-2, default: 1)"
    if ([string]::IsNullOrEmpty($choice)) { $choice = "1" }
    
    switch ($choice) {
        "1" {
            Write-Host "🚀 Starting Flutter Package Manager..." -ForegroundColor Cyan
            Write-Host ""
            Push-Location $InstallDir
            & powershell -ExecutionPolicy Bypass -File "scripts\windows\windows_full_standalone.ps1"
            Pop-Location
        }
        "2" {
            Write-Host "✅ Ready to use! Run '$ScriptName' anytime to start." -ForegroundColor Green
        }
        default {
            Write-Host "✅ Ready to use! Run '$ScriptName' anytime to start." -ForegroundColor Green
        }
    }
}

# Main installation flow
function Main {
    Install-Dependencies
    Download-PackageManager
    Create-GlobalCommand
    Run-Immediately
}

# Handle command line arguments
if ($Help) {
    Write-Host "Flutter Package Manager Installer (Windows)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  iwr -useb $RepoUrl/raw/$Branch/install.ps1 | iex"
    Write-Host "  iwr -useb $RepoUrl/raw/$Branch/install.ps1 | iex; `$LASTEXITCODE = 0"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Help         Show this help"
    Write-Host "  -NoRun        Install only, don't run immediately" 
    Write-Host "  -Update       Update existing installation"
    exit 0
}

if ($NoRun) {
    Write-Host "🔧 Installing without running..." -ForegroundColor Yellow
    Install-Dependencies
    Download-PackageManager
    Create-GlobalCommand
    Write-Host "✅ Installation complete! Run '$ScriptName' to start." -ForegroundColor Green
    exit 0
}

if ($Update) {
    Write-Host "🔄 Updating Flutter Package Manager..." -ForegroundColor Yellow
    Download-PackageManager
    Write-Host "✅ Update complete!" -ForegroundColor Green
    exit 0
}

# Run main installation
Main