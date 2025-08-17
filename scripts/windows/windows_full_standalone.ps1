# Windows Development Setup Script
# Run this in PowerShell: .\windows_dev_setup.ps1

param(
    [switch]$Force
)

Write-Host "🚀 Windows Development Setup" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan

# Check if running as Administrator for winget
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# Install GitHub CLI if not present
if (-not (Get-Command "gh" -ErrorAction SilentlyContinue)) {
    Write-Host "📦 Installing GitHub CLI..." -ForegroundColor Yellow
    
    if (Get-Command "winget" -ErrorAction SilentlyContinue) {
        if ($isAdmin) {
            Write-Host "🔧 Installing GitHub CLI with winget..." -ForegroundColor Green
            try {
                winget install --id GitHub.cli --silent --accept-source-agreements --accept-package-agreements
                Write-Host "✅ GitHub CLI installed successfully" -ForegroundColor Green
            } catch {
                Write-Host "❌ Failed to install GitHub CLI with winget" -ForegroundColor Red
                Write-Host "Please install manually: https://cli.github.com" -ForegroundColor Blue
                Read-Host "Press Enter after installing GitHub CLI manually..."
            }
        } else {
            Write-Host "⚠️  Installing GitHub CLI requires administrator privileges." -ForegroundColor Yellow
            Write-Host "Attempting installation without admin (may prompt for elevation)..." -ForegroundColor Yellow
            try {
                winget install --id GitHub.cli --silent --accept-source-agreements --accept-package-agreements
                Write-Host "✅ GitHub CLI installed successfully" -ForegroundColor Green
            } catch {
                Write-Host "❌ Installation failed. Please run PowerShell as Administrator or install manually:" -ForegroundColor Red
                Write-Host "https://cli.github.com" -ForegroundColor Blue
                Read-Host "Press Enter after installing GitHub CLI manually..."
            }
        }
    } elseif (Get-Command "choco" -ErrorAction SilentlyContinue) {
        Write-Host "🔧 Installing GitHub CLI with Chocolatey..." -ForegroundColor Green
        try {
            choco install gh -y
            Write-Host "✅ GitHub CLI installed successfully" -ForegroundColor Green
        } catch {
            Write-Host "❌ Failed to install GitHub CLI with Chocolatey" -ForegroundColor Red
            Write-Host "Please install manually: https://cli.github.com" -ForegroundColor Blue
            Read-Host "Press Enter after installing GitHub CLI manually..."
        }
    } elseif (Get-Command "scoop" -ErrorAction SilentlyContinue) {
        Write-Host "🔧 Installing GitHub CLI with Scoop..." -ForegroundColor Green
        try {
            scoop install gh
            Write-Host "✅ GitHub CLI installed successfully" -ForegroundColor Green
        } catch {
            Write-Host "❌ Failed to install GitHub CLI with Scoop" -ForegroundColor Red
            Write-Host "Please install manually: https://cli.github.com" -ForegroundColor Blue
            Read-Host "Press Enter after installing GitHub CLI manually..."
        }
    } else {
        Write-Host "❌ No package manager found (winget, choco, scoop). Please install GitHub CLI manually:" -ForegroundColor Red
        Write-Host "https://cli.github.com" -ForegroundColor Blue
        Read-Host "Press Enter after installing GitHub CLI..."
    }
    
    # Refresh PATH
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
}

# Check if GitHub CLI is now available
if (-not (Get-Command "gh" -ErrorAction SilentlyContinue)) {
    Write-Host "❌ GitHub CLI still not found. Please install it manually and try again." -ForegroundColor Red
    exit 1
}

# Authenticate with GitHub
Write-Host "🔐 Authenticating with GitHub..." -ForegroundColor Green
try {
    gh auth status 2>$null
    Write-Host "✅ Already authenticated with GitHub" -ForegroundColor Green
} catch {
    gh auth login
}

# Set up Git config
Write-Host "📝 Setting up Git configuration..." -ForegroundColor Green
try {
    $githubUsername = gh api user --jq .login
    $githubEmail = gh api user --jq .email
    
    if ($githubEmail -eq "null" -or [string]::IsNullOrEmpty($githubEmail)) {
        $githubEmail = Read-Host "Enter your email address"
    }
    
    git config --global user.name $githubUsername
    git config --global user.email $githubEmail
    
    Write-Host "✅ Git configured for $githubUsername" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to configure Git. Please check your GitHub authentication." -ForegroundColor Red
    exit 1
}

# Create development directory
$devDir = "$env:USERPROFILE\Development"
Write-Host "📁 Creating development directory at $devDir..." -ForegroundColor Green
New-Item -ItemType Directory -Force -Path $devDir | Out-Null

# Function to add package to pubspec.yaml
function Add-PackageToPubspec {
    param(
        [string]$PubspecPath,
        [string]$PackageName,
        [string]$RepoUrl,
        [string]$Ref
    )
    
    if (-not (Test-Path $PubspecPath)) {
        Write-Host "❌ pubspec.yaml not found at $PubspecPath" -ForegroundColor Red
        return $false
    }
    
    Write-Host "📝 Adding $PackageName to pubspec.yaml..." -ForegroundColor Yellow
    
    # Backup original file
    Copy-Item $PubspecPath "$PubspecPath.backup"
    
    # Read the pubspec content
    $content = Get-Content $PubspecPath
    
    # Check if package already exists
    if ($content | Select-String "^\s*$PackageName\s*:") {
        $replace = Read-Host "⚠️  Package $PackageName already exists. Replace it? (y/N)"
        if ($replace -ne "y" -and $replace -ne "Y") {
            Write-Host "❌ Cancelled" -ForegroundColor Red
            return $false
        }
        # Remove existing entry
        $content = $content | Where-Object { $_ -notmatch "^\s*$PackageName\s*:" }
    }
    
    # Find dependencies section
    $dependenciesIndex = -1
    for ($i = 0; $i -lt $content.Length; $i++) {
        if ($content[$i] -match "^dependencies\s*:") {
            $dependenciesIndex = $i
            break
        }
    }
    
    if ($dependenciesIndex -ge 0) {
        # Insert after dependencies line
        $newLines = @()
        $newLines += "  $PackageName" + ":"
        $newLines += "    git:"
        $newLines += "      url: $RepoUrl"
        if (![string]::IsNullOrEmpty($Ref)) {
            $newLines += "      ref: $Ref"
        }
        
        # Insert the new dependency
        $newContent = @()
        $newContent += $content[0..$dependenciesIndex]
        $newContent += $newLines
        $newContent += $content[($dependenciesIndex + 1)..($content.Length - 1)]
        
        $newContent | Set-Content $PubspecPath
    } else {
        # Add dependencies section
        "" | Add-Content $PubspecPath
        "dependencies:" | Add-Content $PubspecPath
        "  $PackageName" + ":" | Add-Content $PubspecPath
        "    git:" | Add-Content $PubspecPath
        "      url: $RepoUrl" | Add-Content $PubspecPath
        if (![string]::IsNullOrEmpty($Ref)) {
            "      ref: $Ref" | Add-Content $PubspecPath
        }
    }
    
    Write-Host "✅ Added $PackageName to dependencies" -ForegroundColor Green
    return $true
}

# Function to manage packages
function Manage-Packages {
    Write-Host ""
    Write-Host "📦 Package Management" -ForegroundColor Cyan
    Write-Host "====================" -ForegroundColor Cyan
    
    # Find Flutter projects
    Write-Host "🔍 Looking for Flutter projects..." -ForegroundColor Yellow
    $flutterProjects = @()
    
    # Search in development directory and current directory
    $searchDirs = @($devDir, ".")
    
    foreach ($dir in $searchDirs) {
        if (Test-Path $dir) {
            $projects = Get-ChildItem -Path $dir -Recurse -Name "pubspec.yaml" -Depth 3 2>$null
            foreach ($project in $projects) {
                $fullPath = Join-Path $dir $project
                $flutterProjects += $fullPath
            }
        }
    }
    
    if ($flutterProjects.Count -eq 0) {
        Write-Host "📂 No Flutter projects found in $devDir" -ForegroundColor Yellow
        Write-Host "   Clone or create a Flutter project first!" -ForegroundColor Yellow
        return
    }
    
    # Select Flutter project
    Write-Host ""
    Write-Host "Select a Flutter project:" -ForegroundColor Green
    for ($i = 0; $i -lt $flutterProjects.Count; $i++) {
        $projectDir = Split-Path $flutterProjects[$i]
        $projectName = Split-Path $projectDir -Leaf
        $relativePath = Resolve-Path $projectDir -Relative
        Write-Host "$($i + 1). $projectName ($relativePath)" -ForegroundColor White
    }
    
    $projectNum = Read-Host "Enter project number"
    
    if (-not ($projectNum -match "^\d+$") -or [int]$projectNum -lt 1 -or [int]$projectNum -gt $flutterProjects.Count) {
        Write-Host "❌ Invalid selection" -ForegroundColor Red
        return
    }
    
    $selectedPubspec = $flutterProjects[[int]$projectNum - 1]
    $selectedProject = Split-Path (Split-Path $selectedPubspec) -Leaf
    
    Write-Host "📱 Selected project: $selectedProject" -ForegroundColor Green
    
    # List repositories
    Write-Host ""
    Write-Host "🔍 Fetching your repositories..." -ForegroundColor Yellow
    
    try {
        $repos = gh repo list --limit 50 --json name,owner,isPrivate,url | ConvertFrom-Json
        
        if ($repos.Count -eq 0) {
            Write-Host "❌ No repositories found" -ForegroundColor Red
            return
        }
        
        Write-Host ""
        Write-Host "Available repositories:" -ForegroundColor Green
        for ($i = 0; $i -lt $repos.Count; $i++) {
            $privacy = if ($repos[$i].isPrivate) { "private" } else { "public" }
            Write-Host "$($i + 1). $($repos[$i].owner.login)/$($repos[$i].name) ($privacy)" -ForegroundColor White
        }
        
        Write-Host ""
        $repoNum = Read-Host "Enter repository number (or 'q' to quit)"
        
        if ($repoNum -eq "q") {
            return
        }
        
        if (-not ($repoNum -match "^\d+$") -or [int]$repoNum -lt 1 -or [int]$repoNum -gt $repos.Count) {
            Write-Host "❌ Invalid selection" -ForegroundColor Red
            return
        }
        
        $selectedRepo = $repos[[int]$repoNum - 1]
        $repoFullName = "$($selectedRepo.owner.login)/$($selectedRepo.name)"
        $repoName = $selectedRepo.name
        
        Write-Host "📦 Selected repository: $repoFullName" -ForegroundColor Green
        
        # Ask for package name
        Write-Host ""
        $packageName = Read-Host "Package name (default: $repoName)"
        if ([string]::IsNullOrEmpty($packageName)) {
            $packageName = $repoName
        }
        
        # Sanitize package name
        $packageName = $packageName -replace "-", "_" -replace "[^a-zA-Z0-9_]", ""
        
        # Ask for reference
        Write-Host ""
        Write-Host "🏷️  Available branches and tags:" -ForegroundColor Yellow
        try {
            $branches = gh api "repos/$repoFullName/branches" | ConvertFrom-Json | Select-Object -First 5 -ExpandProperty name
            $branches | ForEach-Object { Write-Host "  branch: $_" -ForegroundColor Gray }
        } catch {
            Write-Host "  (Could not fetch branches)" -ForegroundColor Gray
        }
        
        try {
            $tags = gh api "repos/$repoFullName/tags" | ConvertFrom-Json | Select-Object -First 3 -ExpandProperty name
            $tags | ForEach-Object { Write-Host "  tag: $_" -ForegroundColor Gray }
        } catch {
            Write-Host "  (No tags found)" -ForegroundColor Gray
        }
        
        Write-Host ""
        $ref = Read-Host "Specify branch/tag (default: main)"
        if ([string]::IsNullOrEmpty($ref)) {
            $ref = "main"
        }
        
        # Add to pubspec
        $repoUrl = "https://github.com/$repoFullName.git"
        $success = Add-PackageToPubspec $selectedPubspec $packageName $repoUrl $ref
        
        if ($success) {
            Write-Host ""
            Write-Host "🎉 Package added successfully!" -ForegroundColor Green
            Write-Host ""
            Write-Host "📄 Added to pubspec.yaml:" -ForegroundColor Yellow
            Write-Host "  $packageName" + ":" -ForegroundColor White
            Write-Host "    git:" -ForegroundColor White
            Write-Host "      url: $repoUrl" -ForegroundColor White
            if (![string]::IsNullOrEmpty($ref)) {
                Write-Host "      ref: $ref" -ForegroundColor White
            }
            
            Write-Host ""
            Write-Host "🚀 Next steps:" -ForegroundColor Green
            $projectDir = Split-Path $selectedPubspec
            Write-Host "  cd $projectDir" -ForegroundColor White
            Write-Host "  flutter pub get" -ForegroundColor White
            
            Write-Host ""
            Write-Host "💫 Import in your Dart code with:" -ForegroundColor Green
            Write-Host "  import 'package:$packageName/$packageName.dart';" -ForegroundColor White
            
            # Ask if they want to add another package
            Write-Host ""
            $addAnother = Read-Host "Add another package? (y/N)"
            if ($addAnother -eq "y" -or $addAnother -eq "Y") {
                Manage-Packages
            }
        }
        
    } catch {
        Write-Host "❌ Failed to fetch repositories: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "✅ Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "🎯 What would you like to do?" -ForegroundColor Cyan
Write-Host "1. Clone repositories to start working" -ForegroundColor White
Write-Host "2. Add packages to existing Flutter projects" -ForegroundColor White
Write-Host "3. Exit" -ForegroundColor White
Write-Host ""

$choice = Read-Host "Enter your choice (1-3)"

switch ($choice) {
    "1" {
        Write-Host ""
        Write-Host "📥 Clone repositories:" -ForegroundColor Green
        Write-Host "   cd $devDir" -ForegroundColor White
        Write-Host "   gh repo clone username/your-app" -ForegroundColor White
        Write-Host "   gh repo clone username/your-package" -ForegroundColor White
    }
    "2" {
        Manage-Packages
    }
    "3" {
        Write-Host "👋 Happy coding!" -ForegroundColor Green
    }
    default {
        Write-Host "ℹ️  You can run this script again anytime to add packages!" -ForegroundColor Blue
    }
}