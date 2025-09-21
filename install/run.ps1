# Flutter Package Manager - Windows Direct Run (No Installation)
# Usage: iwr -useb https://raw.githubusercontent.com/user/repo/main/run.ps1 | iex

param(
    [switch]$Help
)

$ErrorActionPreference = "Stop"

$RepoUrl = "https://github.com/daslaller/flutter_packagemanager_setup"
$Branch = "main"
$TempDir = [System.IO.Path]::GetTempPath() + [System.Guid]::NewGuid().ToString()

Write-Host "📦 Flutter Package Manager - Direct Run (Windows)" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# Check PowerShell version first
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "⚠️  PowerShell 5.0+ recommended for best experience" -ForegroundColor Yellow
    Write-Host "Current version: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
    Write-Host "Some features like emojis may not display correctly" -ForegroundColor Gray
    Write-Host ""
    
    if ($PSVersionTable.PSVersion.Major -lt 3) {
        Write-Host "❌ PowerShell 3.0 is the minimum required version" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "💡 For the best experience, consider installing PowerShell 7:" -ForegroundColor Cyan
    Write-Host "   winget install Microsoft.PowerShell" -ForegroundColor White
    Write-Host ""
}

Write-Host "✅ PowerShell version: $($PSVersionTable.PSVersion)" -ForegroundColor Green
Write-Host ""

# Function to cleanup on exit
function Cleanup {
    if (Test-Path $TempDir) {
        Write-Host "🧹 Cleaning up temporary files..." -ForegroundColor Gray
        Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Register cleanup
Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action { Cleanup } | Out-Null

# Quick dependency check
function Check-Dependencies {
    $missing = @()
    
    if (!(Get-Command git -ErrorAction SilentlyContinue)) { $missing += "git" }
    if (!(Get-Command gh -ErrorAction SilentlyContinue)) { $missing += "gh" }
    
    if ($missing.Count -gt 0) {
        Write-Host "❌ Missing dependencies: $($missing -join ', ')" -ForegroundColor Red
        Write-Host ""
        Write-Host "🔧 Quick install commands:" -ForegroundColor Yellow
        Write-Host "  winget install Git.Git GitHub.cli" -ForegroundColor White
        Write-Host "  # or"
        Write-Host "  choco install git gh" -ForegroundColor White
        Write-Host ""
        Write-Host "💡 Or use the full installer: iwr -useb $RepoUrl/raw/$Branch/install.ps1 | iex" -ForegroundColor Cyan
        exit 1
    }
    
    Write-Host "✅ All dependencies available" -ForegroundColor Green
}

# Download and run
function Run-PackageManager {
    Write-Host "📥 Downloading to temporary location..." -ForegroundColor Yellow
    
    # Clone to temp directory
    try {
        git clone --depth 1 --branch $Branch $RepoUrl $TempDir *>$null
        Write-Host "✅ Download complete" -ForegroundColor Green
        Write-Host ""
        Write-Host "🚀 Starting Flutter Package Manager..." -ForegroundColor Cyan
        Write-Host ""
        
        # Run the Windows PowerShell script
        Push-Location $TempDir
        & powershell -ExecutionPolicy Bypass -File "scripts\windows\windows_full_standalone.ps1"
        Pop-Location
        
    } catch {
        Write-Host "❌ Download failed" -ForegroundColor Red
        Write-Host "💡 Check your internet connection or try the full installer" -ForegroundColor Yellow
        exit 1
    }
}

# Main execution
function Main {
    Check-Dependencies
    Run-PackageManager
}

# Handle arguments
if ($Help) {
    Write-Host "Flutter Package Manager - Direct Run (Windows)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This script downloads and runs the package manager without installation."
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  iwr -useb $RepoUrl/raw/$Branch/run.ps1 | iex"
    Write-Host ""
    Write-Host "For permanent installation, use:"
    Write-Host "  iwr -useb $RepoUrl/raw/$Branch/install.ps1 | iex"
    exit 0
} else {
    Main
}

# Cleanup on exit
Cleanup