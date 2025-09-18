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

function Test-FlutterProject {
    param([string]$PubspecPath)
    
    if ([string]::IsNullOrEmpty($PubspecPath)) {
        return $false
    }
    
    if (-not (Test-Path $PubspecPath)) {
        return $false
    }
    
    try {
        $pubspecContent = Get-Content $PubspecPath -Raw -ErrorAction Stop
        # Check if it contains flutter dependency
        return $pubspecContent -match "flutter:\s*$"
    } catch {
        return $false
    }
}

function Get-SafePath {
    param([string]$Path)
    
    if ([string]::IsNullOrEmpty($Path)) {
        return $null
    }
    
    try {
        if (Test-Path $Path) {
            $resolvedPath = Resolve-Path $Path -ErrorAction Stop
            return $resolvedPath.Path
        }
    } catch {
        # Path resolution failed
    }
    
    return $null
}

function Show-FlutterProjectHelp {
    Write-StatusMessage "[HELP] Troubleshooting: No Flutter projects found" "Info"
    Write-StatusMessage "" "Info"
    Write-StatusMessage "Possible solutions:" "Info"
    Write-StatusMessage "  1. Navigate to your Flutter project directory:" "Subtle"
    Write-StatusMessage "     cd path\to\your\flutter\project" "Subtle"
    Write-StatusMessage "" "Info"
    Write-StatusMessage "  2. Create a new Flutter project:" "Subtle"
    Write-StatusMessage "     flutter create my_app" "Subtle"
    Write-StatusMessage "     cd my_app" "Subtle"
    Write-StatusMessage "" "Info"
    Write-StatusMessage "  3. Ensure your project has a valid pubspec.yaml with flutter dependency:" "Subtle"
    Write-StatusMessage "     dependencies:" "Subtle"
    Write-StatusMessage "       flutter:" "Subtle"
    Write-StatusMessage "         sdk: flutter" "Subtle"
    Write-StatusMessage "" "Info"
    Write-StatusMessage "  4. Check if you're in the right location:" "Subtle"
    Write-StatusMessage "     Current directory: $(Get-Location)" "Subtle"
    
    # Show what we can find in current directory
    Write-StatusMessage "" "Info"
    Write-StatusMessage "Files in current directory:" "Subtle"
    try {
        $files = Get-ChildItem -Path "." -File | Select-Object -First 10 -ExpandProperty Name
        if ($files) {
            foreach ($file in $files) {
                Write-StatusMessage "     $file" "Subtle"
            }
        } else {
            Write-StatusMessage "     (no files found)" "Subtle"
        }
    } catch {
        Write-StatusMessage "     (could not list files)" "Subtle"
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
                    Write-StatusMessage "[WARNING] Could not copy to clipboard, but here is your code: $oneTimeCode" "Warning"
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
    
    Write-StatusMessage "[INFO] Repository Selector - Use UP/DOWN arrows, SPACE to select/deselect, ENTER to confirm" "Info"
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
    
    # Validate inputs
    if ([string]::IsNullOrEmpty($PubspecPath)) {
        Write-StatusMessage "[ERROR] Invalid pubspec.yaml path provided (empty or null)" "Error"
        return $false
    }
    
    if (-not $PackageConfigs -or $PackageConfigs.Count -eq 0) {
        Write-StatusMessage "[WARNING] No package configurations provided" "Warning"
        return $true
    }
    
    Write-StatusMessage "[INFO] Adding $($PackageConfigs.Count) packages to pubspec.yaml..." "Info"
    Write-StatusMessage "[INFO] Target pubspec.yaml: $PubspecPath" "Subtle"
    
    if (-not (Test-Path $PubspecPath)) {
        Write-StatusMessage "[ERROR] pubspec.yaml not found at: $PubspecPath" "Error"
        Write-StatusMessage "[HELP] Please ensure the path is correct and the file exists" "Info"
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
    
    Write-StatusMessage "[INFO] Searching for Flutter projects in current and parent directories..." "Info"
    
    foreach ($dir in $searchDirs) {
        # Validate directory path before processing
        if ([string]::IsNullOrEmpty($dir)) {
            Write-StatusMessage "[WARNING] Skipping empty directory path" "Warning"
            continue
        }
        
        if (-not (Test-Path $dir)) {
            Write-StatusMessage "[WARNING] Directory does not exist: '$dir'" "Warning"
            continue
        }
        
        try {
            $safeDirPath = Get-SafePath $dir
            if (-not $safeDirPath) {
                Write-StatusMessage "[WARNING] Could not resolve safe path for directory: '$dir'" "Warning"
                continue
            }
            
            Write-StatusMessage "[INFO] Searching in: $safeDirPath" "Subtle"
            $projects = Get-ChildItem -Path $safeDirPath -Recurse -Name "pubspec.yaml" -Depth 2 -ErrorAction SilentlyContinue
            
            if (-not $projects) {
                Write-StatusMessage "[INFO] No pubspec.yaml files found in: $safeDirPath" "Subtle"
                continue
            }
            
            foreach ($project in $projects) {
                if ([string]::IsNullOrEmpty($project)) {
                    continue
                }
                
                try {
                    $fullPath = Join-Path $safeDirPath $project
                    $safePath = Get-SafePath $fullPath
                    
                    if ($safePath -and (Test-FlutterProject $safePath)) {
                        $flutterProjects += $safePath
                        
                        # Safe path operations with validation
                        $projectDir = $null
                        $projectName = "Unknown"
                        
                        try {
                            if (-not [string]::IsNullOrEmpty($safePath)) {
                                $projectDir = Split-Path $safePath -Parent -ErrorAction SilentlyContinue
                                if (-not [string]::IsNullOrEmpty($projectDir)) {
                                    $projectName = Split-Path $projectDir -Leaf -ErrorAction SilentlyContinue
                                    if ([string]::IsNullOrEmpty($projectName)) {
                                        $projectName = "Unknown"
                                    }
                                }
                            }
                        } catch {
                            Write-StatusMessage "[WARNING] Could not extract project name from path: $safePath" "Warning"
                            $projectName = "Unknown"
                        }
                        
                        Write-StatusMessage "[SUCCESS] Found Flutter project: $projectName ($safePath)" "Success"
                    }
                } catch {
                    Write-StatusMessage "[WARNING] Error processing pubspec.yaml: $project - $($_.Exception.Message)" "Warning"
                }
            }
        } catch {
            Write-StatusMessage "[WARNING] Error searching in directory '$dir': $($_.Exception.Message)" "Warning"
        }
    }
    
    if ($flutterProjects.Count -eq 0) {
        Write-StatusMessage "[WARNING] No Flutter projects found in search directories" "Warning"
        Write-StatusMessage "[INFO] Current directory: $(Get-Location)" "Info"
        Write-StatusMessage "[INFO] Searched directories: $($searchDirs -join ', ')" "Info"
        
        # Provide additional debugging information
        Write-StatusMessage "[DEBUG] Directory contents analysis:" "Subtle"
        foreach ($dir in $searchDirs) {
            if (Test-Path $dir) {
                try {
                    $safeDirPath = Get-SafePath $dir
                    if ($safeDirPath) {
                        $allFiles = Get-ChildItem -Path $safeDirPath -Recurse -File -Depth 2 -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*.yaml" -or $_.Name -like "*.yml" }
                        if ($allFiles) {
                            Write-StatusMessage "[DEBUG] Found YAML files in $dir`: $($allFiles.Count)" "Subtle"
                            foreach ($file in $allFiles | Select-Object -First 3) {
                                Write-StatusMessage "[DEBUG]   - $($file.FullName)" "Subtle"
                            }
                        } else {
                            Write-StatusMessage "[DEBUG] No YAML files found in $dir" "Subtle"
                        }
                    }
                } catch {
                    Write-StatusMessage "[DEBUG] Could not analyze directory $dir`: $($_.Exception.Message)" "Subtle"
                }
            }
        }
    } else {
        Write-StatusMessage "[SUCCESS] Found $($flutterProjects.Count) Flutter project(s)" "Success"
    }
    
    return $flutterProjects
}

function Update-FlutterPackages {
    param([string]$ProjectPath)
    
    # Enhanced input validation
    if ([string]::IsNullOrEmpty($ProjectPath)) {
        Write-StatusMessage "[ERROR] Invalid project path provided (empty or null)" "Error"
        return $false
    }
    
    # Use safe path resolution
    $safeProjectPath = Get-SafePath $ProjectPath
    if (-not $safeProjectPath) {
        Write-StatusMessage "[ERROR] Could not safely resolve project path: $ProjectPath" "Error"
        return $false
    }
    
    if (-not (Test-Path $safeProjectPath)) {
        Write-StatusMessage "[ERROR] Project path does not exist: $safeProjectPath" "Error"
        return $false
    }
    
    Write-StatusMessage "[INFO] Running flutter pub get..." "Info"
    
    $currentLocation = Get-Location
    try {
        # Safe directory extraction with validation
        $projectDir = $null
        try {
            if ([string]::IsNullOrEmpty($safeProjectPath)) {
                Write-StatusMessage "[ERROR] Project path is empty after validation" "Error"
                return $false
            }
            
            $projectDir = Split-Path $safeProjectPath -Parent -ErrorAction Stop
            
            if ([string]::IsNullOrEmpty($projectDir)) {
                Write-StatusMessage "[ERROR] Could not extract project directory from path: $safeProjectPath" "Error"
                return $false
            }
            
            if (-not (Test-Path $projectDir)) {
                Write-StatusMessage "[ERROR] Project directory does not exist: $projectDir" "Error"
                return $false
            }
        } catch {
            Write-StatusMessage "[ERROR] Error extracting project directory: $($_.Exception.Message)" "Error"
            return $false
        }
        
        Write-StatusMessage "[INFO] Changing to project directory: $projectDir" "Subtle"
        Set-Location $projectDir
        
        # Verify we're in the right location and pubspec.yaml exists
        $pubspecInDir = Join-Path $projectDir "pubspec.yaml"
        if (-not (Test-Path $pubspecInDir)) {
            Write-StatusMessage "[ERROR] pubspec.yaml not found in project directory: $projectDir" "Error"
            return $false
        }
        
        flutter pub get
        if ($LASTEXITCODE -eq 0) {
            Write-StatusMessage "[SUCCESS] Flutter packages updated successfully" "Success"
            return $true
        } else {
            Write-StatusMessage "[ERROR] Failed to update Flutter packages (exit code: $LASTEXITCODE)" "Error"
            return $false
        }
    } catch {
        Write-StatusMessage "[ERROR] Error running flutter pub get: $($_.Exception.Message)" "Error"
        return $false
    } finally {
        try {
            Set-Location $currentLocation
        } catch {
            Write-StatusMessage "[WARNING] Could not restore original location: $($_.Exception.Message)" "Warning"
        }
    }
}

# Flutter project detection
function Find-FlutterProjectInCurrentDir {
    $pubspecPath = Join-Path (Get-Location) "pubspec.yaml"
    if (Test-Path $pubspecPath) {
        if (Test-FlutterProject $pubspecPath) {
            return $pubspecPath
        }
    }
    return $null
}

# Check for Git dependencies in pubspec.yaml
function Test-HasGitDependencies {
    param([string]$PubspecPath)
    
    if (-not (Test-Path $PubspecPath)) {
        return $false
    }
    
    try {
        $content = Get-Content $PubspecPath -Raw
        return $content -match "git:\s*\r?\n"
    } catch {
        return $false
    }
}

# Self-update functionality
function Update-FlutterPackageManager {
    Write-StatusMessage "[INFO] Checking for Flutter Package Manager updates..." "Info"
    
    $scriptPath = $PSCommandPath
    if ([string]::IsNullOrEmpty($scriptPath)) {
        $scriptPath = $MyInvocation.MyCommand.Path
    }
    $scriptDir = Split-Path $scriptPath -Parent
    $repoRoot = Split-Path (Split-Path $scriptDir -Parent) -Parent
    
    if (Test-Path "$repoRoot\.git") {
        Write-StatusMessage "[INFO] Updating Flutter Package Manager..." "Info"
        Push-Location $repoRoot
        try {
            git fetch origin main *>$null
            $currentCommit = git rev-parse HEAD
            $latestCommit = git rev-parse origin/main
            
            if ($currentCommit -eq $latestCommit) {
                Write-StatusMessage "[SUCCESS] Flutter Package Manager is already up to date" "Success"
            } else {
                Write-StatusMessage "[INFO] Updating to latest version..." "Info"
                git pull origin main *>$null
                Write-StatusMessage "[SUCCESS] Flutter Package Manager updated successfully" "Success"
                Write-StatusMessage "[INFO] Restart recommended to use the latest version" "Info"
            }
        } catch {
            Write-StatusMessage "[ERROR] Update failed: $($_.Exception.Message)" "Error"
        } finally {
            Pop-Location
        }
    } else {
        Write-StatusMessage "[WARNING] Not a git repository. Please reinstall Flutter Package Manager" "Warning"
    }
}

# Express Git update for existing projects
function Start-ExpressGitUpdate {
    param([string]$PubspecPath)
    
    Write-StatusMessage "[INFO] Express Git Package Update Mode" "Info"
    Write-StatusMessage "======================================" "Info"
    
    $projectDir = Split-Path $PubspecPath -Parent
    $projectName = Split-Path $projectDir -Leaf
    
    Write-StatusMessage "[INFO] Project: $projectName" "Info"
    Write-StatusMessage "[INFO] Running flutter pub upgrade..." "Info"
    
    Push-Location $projectDir
    try {
        flutter pub upgrade
        if ($LASTEXITCODE -eq 0) {
            Write-StatusMessage "[SUCCESS] Git packages updated successfully" "Success"
        } else {
            Write-StatusMessage "[ERROR] Update failed" "Error"
        }
    } finally {
        Pop-Location
    }
}

# Configuration menu
function Show-ConfigurationMenu {
    Write-StatusMessage "[INFO] Configuration Settings" "Info"
    Write-StatusMessage "============================" "Info"
    Write-Host ""
    
    Write-StatusMessage "Current settings:" "Info"
    Write-StatusMessage "  Use SSH: $UseSSH" "Subtle"
    Write-StatusMessage "  Config File: $ConfigFile" "Subtle"
    Write-StatusMessage "  Interactive Mode: $Interactive" "Subtle"
    
    Write-Host ""
    Write-StatusMessage "Configuration options:" "Info"
    Write-StatusMessage "1. Toggle SSH usage" "Subtle"
    Write-StatusMessage "2. Change config file path" "Subtle"
    Write-StatusMessage "3. Toggle interactive mode" "Subtle"
    Write-StatusMessage "4. Return to main menu" "Subtle"
    
    $choice = Read-Host "Choose option (1-4, default: 4)"
    
    switch ($choice) {
        "1" {
            $script:UseSSH = -not $UseSSH
            Write-StatusMessage "[INFO] SSH usage set to: $UseSSH" "Info"
        }
        "2" {
            $newConfigFile = Read-Host "Enter config file path (current: $ConfigFile)"
            if (-not [string]::IsNullOrEmpty($newConfigFile)) {
                $script:ConfigFile = $newConfigFile
                Write-StatusMessage "[INFO] Config file set to: $ConfigFile" "Info"
            }
        }
        "3" {
            $script:Interactive = -not $Interactive
            Write-StatusMessage "[INFO] Interactive mode set to: $Interactive" "Info"
        }
        default {
            return
        }
    }
    
    # Loop back to config menu
    Show-ConfigurationMenu
}

# Main menu system
function Show-MainMenu {
    $detectedProject = Find-FlutterProjectInCurrentDir
    $hasLocalProject = $null -ne $detectedProject
    $hasGitDeps = $false
    $projectName = ""
    
    if ($hasLocalProject) {
        $projectDir = Split-Path $detectedProject -Parent
        $projectName = Split-Path $projectDir -Leaf
        $hasGitDeps = Test-HasGitDependencies $detectedProject
    }
    
    Write-Host ""
    Write-StatusMessage "📱 Flutter Package Manager - Main Menu:" "Emphasis"
    Write-StatusMessage "1. New project setup (scan directories)" "Info"
    Write-StatusMessage "2. Add packages from GitHub repositories" "Info"
    Write-StatusMessage "3. Configuration settings" "Info"
    
    if ($hasLocalProject) {
        Write-StatusMessage "4. Use detected project: $projectName [DEFAULT]" "Success"
        if ($hasGitDeps) {
            Write-StatusMessage "5. 🚀 Express Git update for $projectName" "Success"
        }
    }
    
    Write-StatusMessage "6. 🔄 Update Flutter Package Manager" "Info"
    
    $maxChoice = if ($hasLocalProject -and $hasGitDeps) { 6 } elseif ($hasLocalProject) { 6 } else { 6 }
    $defaultChoice = if ($hasLocalProject) { "4" } else { "1" }
    
    Write-Host ""
    $choice = Read-Host "Choose option (1-$maxChoice, default: $defaultChoice)"
    if ([string]::IsNullOrEmpty($choice)) { $choice = $defaultChoice }
    
    return @{
        Choice = $choice
        DetectedProject = $detectedProject
        HasLocalProject = $hasLocalProject
        HasGitDeps = $hasGitDeps
        ProjectName = $projectName
    }
}

# Run setup for new project
function Start-NewProjectSetup {
    Write-StatusMessage "[INFO] New Project Setup" "Info"
    Write-StatusMessage "======================" "Info"
    
    # Prerequisites check
    Write-StatusMessage "[INFO] Checking prerequisites..." "Info"
    
    # Check Flutter
    if (-not (Test-Command "flutter")) {
        Write-StatusMessage "[ERROR] Flutter is not installed or not in PATH" "Error"
        Write-StatusMessage "[HELP] Please install Flutter from: https://flutter.dev/" "Info"
        return $false
    }
    Write-StatusMessage "[SUCCESS] Flutter is installed" "Success"
    
    # Check Git
    if (-not (Test-Command "git")) {
        Write-StatusMessage "[ERROR] Git is not installed or not in PATH" "Error"
        Write-StatusMessage "[HELP] Please install Git from: https://git-scm.com/" "Info"
        return $false
    }
    Write-StatusMessage "[SUCCESS] Git is installed" "Success"
    
    # Install GitHub CLI
    Write-Host ""
    if (-not (Install-GitHubCLI)) {
        Write-StatusMessage "[ERROR] GitHub CLI installation failed" "Error"
        return $false
    }
    
    # Authenticate with GitHub
    Write-Host ""
    if (-not (Set-GitHubAuthentication)) {
        Write-StatusMessage "[ERROR] GitHub authentication failed" "Error"
        return $false
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
                $script:UseSSH = $false
            }
        }
    }
    
    # Find Flutter project
    Write-Host ""
    Write-StatusMessage "[INFO] Looking for Flutter projects..." "Info"
    $projects = Find-FlutterProjects
    
    if (-not $projects -or $projects.Count -eq 0) {
        Write-StatusMessage "[ERROR] No Flutter projects found in current or parent directories" "Error"
        Show-FlutterProjectHelp
        return $false
    }
    
    return Start-PackageSelection $projects[0]
}

# Package selection workflow
function Start-PackageSelection {
    param([string]$PubspecPath)
    
    # Validate the project path
    if ([string]::IsNullOrEmpty($PubspecPath) -or -not (Test-Path $PubspecPath)) {
        Write-StatusMessage "[ERROR] Invalid project path" "Error"
        return $false
    }
    
    if (-not (Test-FlutterProject $PubspecPath)) {
        Write-StatusMessage "[ERROR] Not a valid Flutter project" "Error"
        return $false
    }
    
    $safeProjectPath = Get-SafePath $PubspecPath
    if (-not $safeProjectPath) {
        Write-StatusMessage "[ERROR] Could not safely resolve project path" "Error"
        return $false
    }
    
    $projectDir = Split-Path $safeProjectPath -Parent
    $projectName = Split-Path $projectDir -Leaf
    
    Write-StatusMessage "[SUCCESS] Using Flutter project: $projectName" "Success"
    Write-StatusMessage "[INFO] Project path: $projectDir" "Subtle"
    
    # Interactive repository selection
    Write-Host ""
    $packageConfigs = Start-InteractiveRepositorySelection
    
    if ($packageConfigs -and $packageConfigs.Count -gt 0) {
        Write-Host ""
        if (Add-PackagesToPubspec $packageConfigs $safeProjectPath) {
            Write-Host ""
            Update-FlutterPackages $safeProjectPath
            
            Write-Host ""
            Write-StatusMessage "========================================" "Emphasis"
            Write-StatusMessage "[SUCCESS] Setup completed!" "Success"
            Write-StatusMessage "========================================" "Emphasis"
            
            Write-Host ""
            Write-StatusMessage "Next steps:" "Info"
            Write-StatusMessage "  - Navigate to your project: cd $projectDir" "Subtle"
            Write-StatusMessage "  - Start coding with your new packages!" "Subtle"
            Write-Host ""
        }
    } else {
        Write-StatusMessage "[INFO] No packages configured. You can run this script again to add packages." "Info"
    }
    
    return $true
}

function Main {
    Write-Host ""
    Write-StatusMessage "📦 Flutter Package Manager v2.0" "Emphasis"
    Write-StatusMessage "🤖 AI-Powered Git Dependency Management" "Emphasis"
    Write-StatusMessage "========================================" "Emphasis"
    Write-Host ""
    
    while ($true) {
        $menuResult = Show-MainMenu
        
        switch ($menuResult.Choice) {
            "1" {
                Write-StatusMessage "[INFO] Starting new project setup..." "Info"
                Start-NewProjectSetup | Out-Null
                break
            }
            "2" {
                Write-StatusMessage "[INFO] Starting GitHub repository selection..." "Info"
                if ($menuResult.HasLocalProject) {
                    Start-PackageSelection $menuResult.DetectedProject | Out-Null
                } else {
                    Write-StatusMessage "[WARNING] No local Flutter project detected" "Warning"
                    Write-StatusMessage "[INFO] Please navigate to a Flutter project directory or create one first" "Info"
                }
                break
            }
            "3" {
                Show-ConfigurationMenu
                continue
            }
            "4" {
                if ($menuResult.HasLocalProject) {
                    Write-StatusMessage "[INFO] Using detected project: $($menuResult.ProjectName)" "Info"
                    Start-PackageSelection $menuResult.DetectedProject | Out-Null
                    break
                } else {
                    Write-StatusMessage "[ERROR] Invalid option: 4" "Error"
                    continue
                }
            }
            "5" {
                if ($menuResult.HasLocalProject -and $menuResult.HasGitDeps) {
                    Start-ExpressGitUpdate $menuResult.DetectedProject
                    break
                } else {
                    Write-StatusMessage "[ERROR] Invalid option: 5" "Error"
                    continue
                }
            }
            "6" {
                Update-FlutterPackageManager
                break
            }
            default {
                Write-StatusMessage "[ERROR] Invalid choice: $($menuResult.Choice)" "Error"
                continue
            }
        }
        
        # Ask if user wants to continue
        Write-Host ""
        $continue = Read-Host "Return to main menu? (Y/n)"
        if ($continue -like "n*") {
            break
        }
    }
    
    Write-StatusMessage "[INFO] Thank you for using Flutter Package Manager!" "Info"
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