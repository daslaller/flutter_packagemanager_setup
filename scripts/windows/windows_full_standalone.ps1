# Enhanced Flutter Development Environment Setup for Windows
# Complete automated setup with multi-select repository interface and SSH support

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$GitToken = "",
    
    [Parameter(Mandatory=$false)]
    [string]$ConfigFile = "private-packages.json",
    
    [Parameter(Mandatory=$false)]
    [switch]$Interactive = $true,
    
    [Parameter(Mandatory=$false)]
    [switch]$UseSSH = $false
)

$ErrorActionPreference = "Stop"

# Colors for output
$Colors = @{
    Error = "Red"
    Success = "Green"
    Info = "Cyan"
    Warning = "Yellow"
    Emphasis = "Magenta"
    Subtle = "Gray"
    Selected = "Green"
    Unselected = "Gray"
}

function Write-StatusMessage {
    param(
        [string]$Message,
        [string]$Type = "Info"
    )
    $color = $Colors[$Type]
    Write-Host $Message -ForegroundColor $color
}

function Test-Command {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Install-GitHubCLI {
    Write-StatusMessage "[INFO] Checking GitHub CLI installation..." "Info"
    
    if (Test-Command "gh") {
        Write-StatusMessage "[SUCCESS] GitHub CLI is already installed" "Success"
        return $true
    }
    
    Write-StatusMessage "[INFO] GitHub CLI not found. Installing via winget..." "Warning"
    
    if (Test-Command "winget") {
        try {
            winget install --id GitHub.cli --silent --accept-package-agreements --accept-source-agreements | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-StatusMessage "[SUCCESS] GitHub CLI installed successfully" "Success"
                # Refresh PATH
                $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
                return $true
            }
        } catch {
            Write-StatusMessage "[WARNING] winget installation failed" "Warning"
        }
    }
    
    Write-StatusMessage "[ERROR] Could not install GitHub CLI automatically" "Error"
    Write-StatusMessage "[HELP] Please install manually from: https://cli.github.com/" "Info"
    return $false
}

function Set-GitHubAuthentication {
    Write-StatusMessage "[INFO] Setting up GitHub authentication..." "Info"
    
    # Check existing authentication
    try {
        gh auth status 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-StatusMessage "[SUCCESS] GitHub CLI is already authenticated" "Success"
            return $true
        }
    } catch {
        # Not authenticated, continue
    }
    
    if ([string]::IsNullOrEmpty($GitToken)) {
        Write-StatusMessage "[INFO] Starting interactive authentication..." "Info"
        Write-StatusMessage "[INFO] This will open GitHub in your browser for device authentication" "Info"
        
        try {
            # Capture the output from gh auth login to extract the one-time code
            $authOutput = & gh auth login --web 2>&1
            
            # Look for the one-time code in the output
            $codePattern = "First copy your one-time code: ([A-Z0-9-]+)"
            if ($authOutput -match $codePattern) {
                $oneTimeCode = $Matches[1]
                Write-StatusMessage "[SUCCESS] One-time code generated: $oneTimeCode" "Success"
                Write-StatusMessage "[INFO] Copying code to clipboard..." "Info"
                
                try {
                    # Copy to clipboard using built-in .NET method
                    Add-Type -AssemblyName System.Windows.Forms
                    [System.Windows.Forms.Clipboard]::SetText($oneTimeCode)
                    Write-StatusMessage "[SUCCESS] Code copied to clipboard! You can paste it in the browser." "Success"
                } catch {
                    # If clipboard fails, still show the code
                    Write-StatusMessage "[WARNING] Could not copy to clipboard, but here's your code: $oneTimeCode" "Warning"
                }
            } else {
                Write-StatusMessage "[INFO] Please follow the authentication instructions in your browser" "Info"
            }
            
            # Wait for the authentication to complete
            if ($LASTEXITCODE -eq 0) {
                Write-StatusMessage "[SUCCESS] GitHub authentication successful" "Success"
                return $true
            } else {
                Write-StatusMessage "[ERROR] Authentication failed or was cancelled" "Error"
                return $false
            }
        } catch {
            Write-StatusMessage "[ERROR] Authentication failed: $($_.Exception.Message)" "Error"
            return $false
        }
    } else {
        Write-StatusMessage "[INFO] Authenticating with provided token..." "Info"
        try {
            $GitToken | gh auth login --with-token
            if ($LASTEXITCODE -eq 0) {
                Write-StatusMessage "[SUCCESS] Token authentication successful" "Success"
                return $true
            }
        } catch {
            Write-StatusMessage "[ERROR] Token authentication failed" "Error"
            return $false
        }
    }
    
    return $false
}

function Set-GitConfiguration {
    Write-StatusMessage "[INFO] Setting up Git configuration..." "Info"
    
    try {
        $githubUser = gh api user 2>$null | ConvertFrom-Json
        $githubUsername = $githubUser.login
        $githubEmail = $githubUser.email
        
        if ([string]::IsNullOrEmpty($githubEmail) -or $githubEmail -eq "null") {
            $githubEmail = "$githubUsername@users.noreply.github.com"
        }
        
        git config --global user.name $githubUsername
        git config --global user.email $githubEmail
        git config --global credential.helper store
        
        Write-StatusMessage "[SUCCESS] Git configured for $githubUsername" "Success"
        return $true
        
    } catch {
        Write-StatusMessage "[WARNING] Failed to configure Git, but continuing..." "Warning"
        return $false
    }
}

function Test-SSHKey {
    Write-StatusMessage "[INFO] Checking SSH key setup..." "Info"
    
    $sshDir = "$env:USERPROFILE\.ssh"
    $keyFile = "$sshDir\id_ed25519"
    $pubKeyFile = "$keyFile.pub"
    
    if (-not (Test-Path $keyFile) -or -not (Test-Path $pubKeyFile)) {
        Write-StatusMessage "[WARNING] SSH key not found" "Warning"
        return $false
    }
    
    # Test SSH connection to GitHub
    try {
        $sshTest = ssh -T git@github.com 2>&1
        if ($sshTest -match "successfully authenticated") {
            Write-StatusMessage "[SUCCESS] SSH key is configured and working" "Success"
            return $true
        } else {
            Write-StatusMessage "[WARNING] SSH key exists but may not be added to GitHub" "Warning"
            return $false
        }
    } catch {
        Write-StatusMessage "[WARNING] Could not test SSH connection" "Warning"
        return $false
    }
}

function New-SSHKey {
    Write-StatusMessage "[INFO] Setting up SSH key for GitHub..." "Info"
    
    $sshDir = "$env:USERPROFILE\.ssh"
    if (-not (Test-Path $sshDir)) {
        New-Item -ItemType Directory -Force -Path $sshDir | Out-Null
    }
    
    $keyFile = "$sshDir\id_ed25519"
    
    if (Test-Path $keyFile) {
        Write-StatusMessage "[INFO] SSH key already exists" "Info"
        $useExisting = Read-Host "Use existing SSH key? (Y/n)"
        if ($useExisting -notlike "n*") {
            return $true
        }
    }
    
    # Get GitHub email for SSH key
    try {
        $githubUser = gh api user 2>$null | ConvertFrom-Json
        $email = $githubUser.email
        if ([string]::IsNullOrEmpty($email) -or $email -eq "null") {
            $email = "$($githubUser.login)@users.noreply.github.com"
        }
    } catch {
        $email = Read-Host "Enter your email for the SSH key"
    }
    
    # Generate SSH key
    Write-StatusMessage "[INFO] Generating SSH key..." "Info"
    ssh-keygen -t ed25519 -C $email -f $keyFile -N '""'
    
    if ($LASTEXITCODE -eq 0) {
        Write-StatusMessage "[SUCCESS] SSH key generated successfully" "Success"
        
        # Add key to SSH agent (Windows)
        try {
            # Start SSH agent if not running
            $sshAgent = Get-Process ssh-agent -ErrorAction SilentlyContinue
            if (-not $sshAgent) {
                Start-Service ssh-agent -ErrorAction SilentlyContinue
            }
            
            ssh-add $keyFile
            Write-StatusMessage "[SUCCESS] SSH key added to SSH agent" "Success"
        } catch {
            Write-StatusMessage "[WARNING] Could not add key to SSH agent, but key was created" "Warning"
        }
        
        # Copy public key to clipboard and prompt user to add it to GitHub
        $pubKey = Get-Content "$keyFile.pub"
        try {
            Add-Type -AssemblyName System.Windows.Forms
            [System.Windows.Forms.Clipboard]::SetText($pubKey)
            Write-StatusMessage "[SUCCESS] Public key copied to clipboard!" "Success"
        } catch {
            Write-StatusMessage "[INFO] Public key: $pubKey" "Info"
        }
        
        Write-StatusMessage "[INFO] Please add this SSH key to your GitHub account:" "Info"
        Write-StatusMessage "  1. Go to https://github.com/settings/ssh/new" "Subtle"
        Write-StatusMessage "  2. Paste the key (already in clipboard)" "Subtle"
        Write-StatusMessage "  3. Give it a title (e.g., 'Windows Dev Machine')" "Subtle"
        Write-StatusMessage "  4. Click 'Add SSH key'" "Subtle"
        
        Read-Host "Press Enter after adding the key to GitHub..."
        
        # Test the connection
        return Test-SSHKey
    } else {
        Write-StatusMessage "[ERROR] Failed to generate SSH key" "Error"
        return $false
    }
}

function Show-RepositorySelector {
    param(
        [array]$Repositories
    )
    
    $selectedIndices = @()
    $currentIndex = 0
    
    Write-StatusMessage "[INFO] Repository Selector - Use ↑↓ arrows, SPACE to select/deselect, ENTER to confirm" "Info"
    Write-Host ""
    
    while ($true) {
        # Clear screen and show header
        Clear-Host
        Write-Host ""
        Write-StatusMessage "Select repositories to add as Flutter packages:" "Emphasis"
        Write-Host ""
        Write-StatusMessage "Navigation: UP/DOWN arrows | Selection: SPACE | Confirm: ENTER | Quit: Q" "Subtle"
        Write-Host ""
        
        # Show repositories with selection indicators
        for ($i = 0; $i -lt $Repositories.Count; $i++) {
            $repo = $Repositories[$i]
            $repoName = "$($repo.owner.login)/$($repo.name)"
            $privacy = if ($repo.isPrivate) { "[PRIVATE]" } else { "[PUBLIC]" }
            $description = if ($repo.description) { "- $($repo.description)" } else { "- No description" }
            
            $isSelected = $selectedIndices -contains $i
            $isCurrent = $i -eq $currentIndex
            
            $marker = if ($isSelected) { "[X]" } else { "[ ]" }
            $cursor = if ($isCurrent) { ">" } else { " " }
            
            $color = if ($isCurrent) { 
                if ($isSelected) { "Selected" } else { "Emphasis" }
            } else {
                if ($isSelected) { "Selected" } else { "Unselected" }
            }
            
            $line = "$cursor $marker $repoName ($privacy) $description"
            Write-Host $line -ForegroundColor $Colors[$color]
        }
        
        Write-Host ""
        if ($selectedIndices.Count -gt 0) {
            Write-StatusMessage "Selected: $($selectedIndices.Count) repositories" "Selected"
        } else {
            Write-StatusMessage "No repositories selected" "Subtle"
        }
        
        # Handle input
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        switch ($key.VirtualKeyCode) {
            38 { # Up arrow
                $currentIndex = if ($currentIndex -gt 0) { $currentIndex - 1 } else { $Repositories.Count - 1 }
            }
            40 { # Down arrow
                $currentIndex = if ($currentIndex -lt $Repositories.Count - 1) { $currentIndex + 1 } else { 0 }
            }
            32 { # Space
                if ($selectedIndices -contains $currentIndex) {
                    $selectedIndices = $selectedIndices | Where-Object { $_ -ne $currentIndex }
                } else {
                    $selectedIndices += $currentIndex
                }
            }
            13 { # Enter
                break
            }
            81 { # Q
                return @()
            }
        }
    }
    
    Clear-Host
    return $selectedIndices
}

function Get-RepositoryConfiguration {
    param(
        [object]$Repository,
        [bool]$UseSSH = $false
    )
    
    $repoName = $Repository.name
    $repoFullName = "$($Repository.owner.login)/$($Repository.name)"
    
    Write-Host ""
    Write-StatusMessage "Configuring package: $repoFullName" "Emphasis"
    
    # Package name
    $packageName = Read-Host "Package name (default: $repoName)"
    if ([string]::IsNullOrEmpty($packageName)) {
        $packageName = $repoName
    }
    $packageName = $packageName -replace "-", "_" -replace "[^a-zA-Z0-9_]", ""
    
    # Branch/tag
    Write-StatusMessage "Fetching available branches..." "Info"
    try {
        $branches = gh api "repos/$repoFullName/branches" | ConvertFrom-Json | Select-Object -First 5 -ExpandProperty name
        Write-StatusMessage "Available branches: $($branches -join ', ')" "Subtle"
    } catch {
        Write-StatusMessage "Could not fetch branches" "Warning"
    }
    
    $ref = Read-Host "Branch/tag (default: main)"
    if ([string]::IsNullOrEmpty($ref)) {
        $ref = "main"
    }
    
    # Path within repository
    $path = Read-Host "Path within repository (optional, for monorepos)"
    
    # Determine URL based on SSH preference and repository privacy
    $gitUrl = if ($UseSSH -and $Repository.isPrivate) {
        "git@github.com:$repoFullName.git"
    } else {
        $Repository.url + ".git"
    }
    
    return @{
        name = $packageName
        git_url = $gitUrl
        branch = $ref
        path = $path
        description = $Repository.description
        isPrivate = $Repository.isPrivate
    }
}

function Add-PackagesToPubspec {
    param($PackageConfigs, $PubspecPath)
    
    Write-StatusMessage "[INFO] Adding $($PackageConfigs.Count) packages to pubspec.yaml..." "Info"
    
    if (-not (Test-Path $PubspecPath)) {
        Write-StatusMessage "[ERROR] pubspec.yaml not found at: $PubspecPath" "Error"
        return $false
    }
    
    # Backup original file
    $backupPath = "$PubspecPath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item $PubspecPath $backupPath
    Write-StatusMessage "[INFO] Created backup: $(Split-Path $backupPath -Leaf)" "Subtle"
    
    $pubspecContent = Get-Content $PubspecPath -Raw
    $modified = $false
    
    foreach ($package in $PackageConfigs) {
        Write-StatusMessage "[INFO] Adding package: $($package.name)" "Info"
        
        # Check if package already exists
        if ($pubspecContent -match "^\s*$($package.name)\s*:") {
            Write-StatusMessage "[WARNING] Package '$($package.name)' already exists, skipping..." "Warning"
            continue
        }
        
        # Build dependency entry
        $dependencyLines = @()
        $dependencyLines += "  $($package.name):"
        $dependencyLines += "    git:"
        $dependencyLines += "      url: $($package.git_url)"
        
        if (![string]::IsNullOrEmpty($package.branch)) {
            $dependencyLines += "      ref: $($package.branch)"
        }
        
        if (![string]::IsNullOrEmpty($package.path)) {
            $dependencyLines += "      path: $($package.path)"
        }
        
        # Find dependencies section and add package
        if ($pubspecContent -match "(?m)^dependencies:\s*$") {
            $lines = $pubspecContent -split "`n"
            $dependenciesIndex = -1
            
            for ($i = 0; $i -lt $lines.Length; $i++) {
                if ($lines[$i] -match "^dependencies:\s*$") {
                    $dependenciesIndex = $i
                    break
                }
            }
            
            if ($dependenciesIndex -ge 0) {
                # Insert after flutter: sdk: flutter line
                $insertIndex = $dependenciesIndex + 1
                
                # Look for flutter: sdk: flutter and insert after it
                for ($i = $dependenciesIndex + 1; $i -lt $lines.Length; $i++) {
                    if ($lines[$i] -match "^\s*flutter:\s*$" -and $i + 1 -lt $lines.Length -and $lines[$i + 1] -match "^\s*sdk:\s*flutter\s*$") {
                        $insertIndex = $i + 2
                        break
                    }
                    if ($lines[$i] -match "^[a-zA-Z]" -and $lines[$i] -notmatch "^dependencies:") {
                        break
                    }
                }
                
                # Insert the new dependency
                $newLines = @()
                $newLines += $lines[0..($insertIndex-1)]
                $newLines += ""
                $newLines += $dependencyLines
                if ($insertIndex -lt $lines.Length) {
                    $newLines += $lines[$insertIndex..($lines.Length-1)]
                }
                
                $pubspecContent = $newLines -join "`n"
                $modified = $true
                
                Write-StatusMessage "[SUCCESS] Added $($package.name) to dependencies" "Success"
            }
        }
    }
    
    if ($modified) {
        $pubspecContent | Set-Content $PubspecPath -Encoding UTF8
        Write-StatusMessage "[SUCCESS] pubspec.yaml updated successfully" "Success"
        
        # Show summary of added packages
        Write-Host ""
        Write-StatusMessage "Added packages:" "Emphasis"
        foreach ($package in $PackageConfigs) {
            $privacy = if ($package.isPrivate) { "[PRIVATE]" } else { "[PUBLIC]" }
            Write-StatusMessage "  $privacy $($package.name) from $($package.git_url)" "Subtle"
        }
        
        return $true
    } else {
        Write-StatusMessage "[INFO] No packages were added" "Info"
        return $true
    }
}

function Start-InteractiveRepositorySelection {
    Write-StatusMessage "[INFO] Starting interactive repository selection..." "Info"
    
    Write-StatusMessage "[INFO] Fetching your repositories..." "Info"
    try {
        $repos = gh repo list --limit 100 --json name,owner,isPrivate,url,description | ConvertFrom-Json
        
        if ($repos.Count -eq 0) {
            Write-StatusMessage "[ERROR] No repositories found" "Error"
            return $null
        }
        
        Write-StatusMessage "[SUCCESS] Found $($repos.Count) repositories" "Success"
        
        # Show multi-select interface
        $selectedIndices = Show-RepositorySelector -Repositories $repos
        
        if ($selectedIndices.Count -eq 0) {
            Write-StatusMessage "[INFO] No repositories selected" "Info"
            return $null
        }
        
        Write-StatusMessage "[SUCCESS] Selected $($selectedIndices.Count) repositories" "Success"
        
        # Configure each selected repository
        $packageConfigs = @()
        foreach ($index in $selectedIndices) {
            $repo = $repos[$index]
            $config = Get-RepositoryConfiguration -Repository $repo -UseSSH $UseSSH
            $packageConfigs += $config
        }
        
        return $packageConfigs
        
    } catch {
        Write-StatusMessage "[ERROR] Failed to fetch repositories: $($_.Exception.Message)" "Error"
        return $null
    }
}

function Find-FlutterProjects {
    $flutterProjects = @()
    $searchDirs = @(".", "..")
    
    foreach ($dir in $searchDirs) {
        if (Test-Path $dir) {
            try {
                $projects = Get-ChildItem -Path $dir -Recurse -Name "pubspec.yaml" -Depth 2 -ErrorAction SilentlyContinue
                foreach ($project in $projects) {
                    $fullPath = Join-Path $dir $project
                    $resolvedPath = Resolve-Path $fullPath
                    $flutterProjects += $resolvedPath.Path
                }
            } catch {
                # Ignore errors
            }
        }
    }
    
    return $flutterProjects
}

function Update-FlutterPackages {
    param([string]$ProjectPath)
    
    Write-StatusMessage "[INFO] Running flutter pub get..." "Info"
    
    $currentLocation = Get-Location
    try {
        Set-Location (Split-Path $ProjectPath)
        
        flutter pub get
        if ($LASTEXITCODE -eq 0) {
            Write-StatusMessage "[SUCCESS] Flutter packages updated successfully" "Success"
            return $true
        } else {
            Write-StatusMessage "[ERROR] Failed to update Flutter packages" "Error"
            return $false
        }
    } catch {
        Write-StatusMessage "[ERROR] Error running flutter pub get" "Error"
        return $false
    } finally {
        Set-Location $currentLocation
    }
}

function Main {
    Write-Host ""
    Write-StatusMessage "========================================" "Emphasis"
    Write-StatusMessage "Enhanced Flutter Development Setup" "Emphasis"
    Write-StatusMessage "========================================" "Emphasis"
    Write-Host ""
    
    # Prerequisites check
    Write-StatusMessage "[INFO] Checking prerequisites..." "Info"
    
    # Check Flutter
    if (-not (Test-Command "flutter")) {
        Write-StatusMessage "[ERROR] Flutter is not installed or not in PATH" "Error"
        Write-StatusMessage "[HELP] Please install Flutter from: https://flutter.dev/" "Info"
        return 1
    }
    Write-StatusMessage "[SUCCESS] Flutter is installed" "Success"
    
    # Check Git
    if (-not (Test-Command "git")) {
        Write-StatusMessage "[ERROR] Git is not installed or not in PATH" "Error"
        Write-StatusMessage "[HELP] Please install Git from: https://git-scm.com/" "Info"
        return 1
    }
    Write-StatusMessage "[SUCCESS] Git is installed" "Success"
    
    # Install GitHub CLI
    Write-Host ""
    if (-not (Install-GitHubCLI)) {
        Write-StatusMessage "[ERROR] GitHub CLI installation failed" "Error"
        return 1
    }
    
    # Authenticate with GitHub
    Write-Host ""
    if (-not (Set-GitHubAuthentication)) {
        Write-StatusMessage "[ERROR] GitHub authentication failed" "Error"
        return 1
    }
    
    # Configure Git
    Write-Host ""
    Set-GitConfiguration | Out-Null
    
    # SSH setup for private repositories
    if ($UseSSH) {
        Write-Host ""
        Write-StatusMessage "[INFO] Setting up SSH for private repositories..." "Info"
        if (-not (Test-SSHKey)) {
            if (-not (New-SSHKey)) {
                Write-StatusMessage "[WARNING] SSH setup failed, falling back to HTTPS" "Warning"
                $UseSSH = $false
            }
        }
    }
    
    # Find Flutter project
    Write-Host ""
    Write-StatusMessage "[INFO] Looking for Flutter projects..." "Info"
    $projects = Find-FlutterProjects
    
    if ($projects.Count -eq 0) {
        Write-StatusMessage "[ERROR] No Flutter projects found in current directory" "Error"
        Write-StatusMessage "[HELP] Navigate to your Flutter project directory and run setup again" "Info"
        return 1
    }
    
    $selectedProject = $projects[0]
    $projectName = Split-Path (Split-Path $selectedProject) -Leaf
    Write-StatusMessage "[SUCCESS] Using Flutter project: $projectName" "Success"
    
    # Interactive repository selection
    Write-Host ""
    $packageConfigs = Start-InteractiveRepositorySelection
    
    if ($packageConfigs -and $packageConfigs.Count -gt 0) {
        Write-Host ""
        if (Add-PackagesToPubspec $packageConfigs $selectedProject) {
            Write-Host ""
            Update-FlutterPackages $selectedProject
        }
    } else {
        Write-StatusMessage "[INFO] No packages configured. You can run this script again to add packages." "Info"
    }
    
    # Summary
    Write-Host ""
    Write-StatusMessage "========================================" "Emphasis"
    Write-StatusMessage "[SUCCESS] Setup completed!" "Success"
    Write-StatusMessage "========================================" "Emphasis"
    Write-Host ""
    
    Write-StatusMessage "What's next?" "Info"
    Write-StatusMessage "  - Clone repositories: gh repo clone owner/repo" "Subtle"
    Write-StatusMessage "  - Navigate to your project and start coding!" "Subtle"
    Write-StatusMessage "  - Use 'gh repo list' to see all repositories" "Subtle"
    Write-Host ""
    
    return 0
}

# Run main function
try {
    $exitCode = Main
    exit $exitCode
} catch {
    Write-StatusMessage "[ERROR] Unexpected error: $($_.Exception.Message)" "Error"
    exit 1
}