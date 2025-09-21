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

Write-Host "[INSTALL] Flutter Package Manager (Windows)" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# Check PowerShell version first  
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "[WARNING] PowerShell 5.0+ recommended for best compatibility" -ForegroundColor Yellow
    Write-Host "[INFO] Current version: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
    Write-Host "[INFO] Some features like emoji display may not work correctly" -ForegroundColor Yellow
    Write-Host ""
    
    if ($PSVersionTable.PSVersion.Major -lt 3) {
        Write-Host "[ERROR] PowerShell 3.0 is the absolute minimum required" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "[OFFER] Would you like to automatically install PowerShell 7? (Recommended)" -ForegroundColor Cyan
    Write-Host "  This will fix emoji display issues and improve performance" -ForegroundColor Gray
    $installChoice = Read-Host "Install PowerShell 7 now? (y/N)"
    
    if ($installChoice -match '^[Yy]') {
        Write-Host "[INFO] Installing PowerShell 7 using Microsoft's official installer..." -ForegroundColor Yellow
        try {
            # Try winget first (fastest)
            if (Get-Command winget -ErrorAction SilentlyContinue) {
                Write-Host "[INFO] Using winget..." -ForegroundColor Gray
                & winget install Microsoft.PowerShell --silent --accept-package-agreements --accept-source-agreements
                Write-Host "[SUCCESS] PowerShell 7 installed via winget!" -ForegroundColor Green
            } else {
                # Use Microsoft's official installer script
                Write-Host "[INFO] Using Microsoft's official installer..." -ForegroundColor Gray
                iex "& { $(irm https://aka.ms/install-powershell.ps1) } -UseMSI -Quiet"
                Write-Host "[SUCCESS] PowerShell 7 installed via Microsoft installer!" -ForegroundColor Green
            }
            
            Write-Host ""
            Write-Host "[NEXT] Please restart this script in PowerShell 7 for the best experience:" -ForegroundColor Cyan
            Write-Host "  1. Open Start Menu and search for 'PowerShell 7'" -ForegroundColor White
            Write-Host "  2. Run this command again:" -ForegroundColor White
            Write-Host "     iwr -useb https://raw.githubusercontent.com/daslaller/flutter_packagemanager_setup/main/install/install.ps1 | iex" -ForegroundColor Yellow
            exit 0
        } catch {
            Write-Host "[WARNING] Automatic installation failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "[FALLBACK] You can install manually:" -ForegroundColor Yellow
            Write-Host "  • Download from: https://github.com/PowerShell/PowerShell/releases" -ForegroundColor White
            Write-Host "  • Or use: winget install Microsoft.PowerShell" -ForegroundColor White
        }
    }
}

Write-Host "[SUCCESS] PowerShell version check passed (v$($PSVersionTable.PSVersion))" -ForegroundColor Green
Write-Host ""

# Function to detect and install dependencies
function Install-Dependencies {
    Write-Host "[INFO] Checking dependencies..." -ForegroundColor Yellow
    
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
        Write-Host "[WARNING] Missing dependencies: $($missing -join ', ')" -ForegroundColor Red
        Write-Host ""
        Write-Host "[ACTION] Please install the missing dependencies:" -ForegroundColor Yellow
        
        if ($missing -contains "Git") {
            Write-Host "  • Git: https://git-scm.com/download/win" -ForegroundColor White
        }
        
        if ($missing -contains "GitHub CLI") {
            Write-Host "  • GitHub CLI: https://cli.github.com" -ForegroundColor White
            Write-Host "    Or via winget: winget install GitHub.cli" -ForegroundColor Gray
        }
        
        Write-Host ""
        Write-Host "[TIP] Alternative: Use chocolatey or winget:" -ForegroundColor Cyan
        Write-Host "  choco install git gh" -ForegroundColor Gray
        Write-Host "  winget install Git.Git GitHub.cli" -ForegroundColor Gray
        
        exit 1
    } else {
        Write-Host "[SUCCESS] All dependencies available" -ForegroundColor Green
    }
}

# Function to download the package manager
function Download-PackageManager {
    Write-Host ""
    Write-Host "[INFO] Downloading Flutter Package Manager..." -ForegroundColor Yellow
    
    # Create install directory
    if (!(Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    }
    
    # Check if it's already a git repo
    if (Test-Path "$InstallDir\.git") {
        Write-Host "[UPDATE] Updating existing installation..." -ForegroundColor Cyan
        Push-Location $InstallDir
        try {
            # Check if we can update the repository
            $currentBranch = git branch --show-current 2>$null
            if ($LASTEXITCODE -ne 0) {
                throw "Could not determine current branch"
            }
            
            # Stash any local changes to preserve user modifications
            $stashResult = git stash push -m "Auto-stash before update $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" 2>$null
            $hasStash = $LASTEXITCODE -eq 0 -and $stashResult -notlike "*No local changes to save*"
            
            if ($hasStash) {
                Write-Host "[INFO] Stashed local changes to preserve user modifications" -ForegroundColor Cyan
            }
            
            # Fetch latest changes
            git fetch origin $Branch *>$null
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to fetch from origin"
            }
            
            # Update to latest version
            git reset --hard "origin/$Branch" *>$null
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to reset to origin/$Branch"
            }
            
            # Restore stashed changes if any
            if ($hasStash) {
                Write-Host "[INFO] Attempting to restore your local changes..." -ForegroundColor Cyan
                git stash pop 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "[SUCCESS] Local changes restored successfully" -ForegroundColor Green
                } else {
                    Write-Host "[WARNING] Could not auto-restore local changes. Check 'git stash list' if needed." -ForegroundColor Yellow
                }
            }
            
            Write-Host "[SUCCESS] Update complete - existing installation preserved" -ForegroundColor Green
        } catch {
            Write-Host "[WARNING] Git update failed: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "[INFO] Falling back to fresh installation..." -ForegroundColor Yellow
            Pop-Location
            
            # Backup existing installation before removing
            $backupDir = "$InstallDir.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            if (Test-Path $InstallDir) {
                try {
                    Write-Host "[INFO] Creating backup of existing installation..." -ForegroundColor Cyan
                    Move-Item $InstallDir $backupDir -ErrorAction Stop
                    Write-Host "[SUCCESS] Backup created at: $backupDir" -ForegroundColor Green
                } catch {
                    Write-Host "[WARNING] Could not create backup: $($_.Exception.Message)" -ForegroundColor Yellow
                    try {
                        Remove-Item $InstallDir -Recurse -Force -ErrorAction Stop
                    } catch {
                        Write-Host "[ERROR] Could not remove old installation: $($_.Exception.Message)" -ForegroundColor Red
                        return
                    }
                }
            }
            
            # Fresh clone
            git clone $RepoUrl $InstallDir
        } finally {
            try {
                Pop-Location
            } catch {
                # Ignore pop location errors
            }
        }
    } else {
        Write-Host "[INFO] Downloading fresh installation..." -ForegroundColor Cyan
        if (Test-Path $InstallDir) {
            # Backup existing non-git directory
            $backupDir = "$InstallDir.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            try {
                Write-Host "[INFO] Backing up existing directory..." -ForegroundColor Cyan
                Move-Item $InstallDir $backupDir -ErrorAction Stop
                Write-Host "[SUCCESS] Backup created at: $backupDir" -ForegroundColor Green
            } catch {
                Write-Host "[WARNING] Could not backup existing directory, removing it..." -ForegroundColor Yellow
                Remove-Item $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        git clone $RepoUrl $InstallDir
    }
    
    Write-Host "[SUCCESS] Download complete" -ForegroundColor Green
}

# Function to create global command
function Create-GlobalCommand {
    Write-Host ""
    Write-Host "[SETUP] Setting up global command..." -ForegroundColor Yellow
    
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
            Write-Host "[SUCCESS] Global command created: $ScriptName" -ForegroundColor Green
            Write-Host "[INFO] Restart your terminal to use the command globally" -ForegroundColor Cyan
        } catch {
            Write-Host "[WARNING] Cannot modify PATH automatically" -ForegroundColor Yellow
            Write-Host "[INFO] Add manually: $InstallDir" -ForegroundColor Cyan
            Write-Host "[INFO] Or run: $wrapperBat" -ForegroundColor Cyan
        }
    } else {
        Write-Host "[SUCCESS] PATH already contains install directory" -ForegroundColor Green
    }
}

# Function to run immediately (optional)
function Run-Immediately {
    Write-Host ""
    Write-Host "[COMPLETE] Installation complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "[OPTIONS] Available options:" -ForegroundColor Cyan
    Write-Host "1. [RUN] Run Flutter Package Manager now"
    Write-Host "2. [EXIT] Exit (run later with '$ScriptName')"
    Write-Host ""
    
    $choice = Read-Host "Choose option (1-2, default: 1)"
    if ([string]::IsNullOrEmpty($choice)) { $choice = "1" }
    
    switch ($choice) {
        "1" {
            Write-Host "[STARTING] Flutter Package Manager..." -ForegroundColor Cyan
            Write-Host ""
            Push-Location $InstallDir
            & powershell -ExecutionPolicy Bypass -File "scripts\windows\windows_full_standalone.ps1"
            Pop-Location
        }
        "2" {
            Write-Host "[READY] Ready to use! Run '$ScriptName' anytime to start." -ForegroundColor Green
        }
        default {
            Write-Host "[READY] Ready to use! Run '$ScriptName' anytime to start." -ForegroundColor Green
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
    Write-Host "[INSTALL] Installing without running..." -ForegroundColor Yellow
    Install-Dependencies
    Download-PackageManager
    Create-GlobalCommand
    Write-Host "[SUCCESS] Installation complete! Run '$ScriptName' to start." -ForegroundColor Green
    exit 0
}

if ($Update) {
    Write-Host "[UPDATE] Updating Flutter Package Manager..." -ForegroundColor Yellow
    Download-PackageManager
    Write-Host "[SUCCESS] Update complete!" -ForegroundColor Green
    exit 0
}

# Run main installation
Main