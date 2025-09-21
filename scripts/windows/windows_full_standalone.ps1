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
        $useExisting = Read-Host 'Use existing SSH key? (Y/n)'
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
        $email = Read-Host 'Enter your email for the SSH key'
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
        
        Read-Host 'Press Enter after adding the key to GitHub...'
        
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
    $windowStart = 0
    $windowSize = 15  # Show 15 items at a time
    $searchFilter = ""
    $searchMode = $false
    
    # Filter repositories based on search
    $filteredRepos = $Repositories
    $indexMapping = 0..($Repositories.Count - 1)
    
    Write-StatusMessage "[INFO] Enhanced Repository Selector" "Info"
    Write-Host ""
    
    while ($true) {
        # Clear screen and show header
        Clear-Host
        Write-Host ""
        Write-StatusMessage "[SEARCH] Select repositories to add as Flutter packages:" "Emphasis"
        Write-Host ""
        
        if ($searchMode) {
            Write-StatusMessage "[SEARCH] Search Mode - Type to filter, ESC to exit search" "Info"
            Write-StatusMessage "Filter: $searchFilter" "Emphasis"
        } else {
            Write-StatusMessage "Navigation: Up/Down arrows | Page: PageUp/PageDown | Search: S | Select: SPACE | Confirm: ENTER | Quit: Q" "Subtle"
        }
        
        Write-Host ""
        Write-StatusMessage "Showing $($filteredRepos.Count) repositories (Total: $($Repositories.Count))" "Subtle"
        Write-Host ""
        
        # Calculate window bounds
        $windowEnd = [Math]::Min($windowStart + $windowSize - 1, $filteredRepos.Count - 1)
        
        # Show repositories in current window
        for ($i = $windowStart; $i -le $windowEnd; $i++) {
            if ($i -ge $filteredRepos.Count) { break }
            
            $repo = $filteredRepos[$i]
            $originalIndex = $indexMapping[$i]
            $repoName = "$($repo.owner.login)/$($repo.name)"
            $privacy = if ($repo.isPrivate) { "[PRIVATE]" } else { "[PUBLIC]" }
            $description = if ($repo.description) { 
                $desc = $repo.description
                if ($desc.Length -gt 60) { 
                    "- $($desc.Substring(0, 57))..." 
                } else { 
                    "- $desc" 
                }
            } else { 
                "- No description" 
            }
            
            $isSelected = $selectedIndices -contains $originalIndex
            $isCurrent = $i -eq $currentIndex
            
            $marker = if ($isSelected) { "[X]" } else { "[ ]" }
            $cursor = if ($isCurrent) { ">" } else { " " }
            $lineNumber = "{0:D2}" -f ($i + 1)
            
            $color = if ($isCurrent) { 
                if ($isSelected) { "Selected" } else { "Emphasis" }
            } else {
                if ($isSelected) { "Selected" } else { "Unselected" }
            }
            
            # Highlight search terms
            $displayName = $repoName
            if ($searchFilter -and $repoName -match [regex]::Escape($searchFilter)) {
                $displayName = $repoName -replace [regex]::Escape($searchFilter), "[$searchFilter]"
            }
            
            $line = "$cursor $marker $lineNumber. $displayName $privacy"
            Write-Host $line -ForegroundColor $Colors[$color]
            Write-Host "     $description" -ForegroundColor $Colors["Subtle"]
        }
        
        # Show pagination info
        if ($filteredRepos.Count -gt $windowSize) {
            Write-Host ""
            $currentPage = [Math]::Floor($windowStart / $windowSize) + 1
            $totalPages = [Math]::Ceiling($filteredRepos.Count / $windowSize)
            Write-StatusMessage "Page $currentPage of $totalPages" "Subtle"
        }
        
        Write-Host ""
        if ($selectedIndices.Count -gt 0) {
            Write-StatusMessage "[SELECTED] Selected: $($selectedIndices.Count) repositories" "Selected"
            
            # Show selected repository names
            $selectedNames = @()
            foreach ($idx in $selectedIndices) {
                $selectedNames += "$($Repositories[$idx].owner.login)/$($Repositories[$idx].name)"
            }
            Write-StatusMessage "Selected: $($selectedNames -join ', ')" "Subtle"
        } else {
            Write-StatusMessage "No repositories selected" "Subtle"
        }
        
        # Handle input
        if ($searchMode) {
            $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            
            if ($key.VirtualKeyCode -eq 27) { # ESC
                $searchMode = $false
                continue
            } elseif ($key.VirtualKeyCode -eq 8) { # Backspace
                if ($searchFilter.Length -gt 0) {
                    $searchFilter = $searchFilter.Substring(0, $searchFilter.Length - 1)
                }
            } elseif ($key.Character -match '[a-zA-Z0-9\-_/\s]') {
                $searchFilter += $key.Character
            }
            
            # Apply filter
            if ($searchFilter) {
                $filteredRepos = @()
                $newIndexMapping = @()
                for ($i = 0; $i -lt $Repositories.Count; $i++) {
                    $repo = $Repositories[$i]
                    $searchText = "$($repo.owner.login)/$($repo.name) $($repo.description)"
                    if ($searchText -match [regex]::Escape($searchFilter)) {
                        $filteredRepos += $repo
                        $newIndexMapping += $i
                    }
                }
                $indexMapping = $newIndexMapping
            } else {
                $filteredRepos = $Repositories
                $indexMapping = 0..($Repositories.Count - 1)
            }
            
            # Reset position
            $currentIndex = 0
            $windowStart = 0
            continue
        }
        
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        
        switch ($key.VirtualKeyCode) {
            38 { # Up arrow
                $currentIndex = if ($currentIndex -gt 0) { $currentIndex - 1 } else { $filteredRepos.Count - 1 }
                
                # Adjust window if needed
                if ($currentIndex -lt $windowStart) {
                    $windowStart = [Math]::Max(0, $currentIndex - $windowSize + 1)
                }
                if ($currentIndex -ge $windowStart + $windowSize) {
                    $windowStart = $currentIndex - $windowSize + 1
                }
            }
            40 { # Down arrow
                $currentIndex = if ($currentIndex -lt $filteredRepos.Count - 1) { $currentIndex + 1 } else { 0 }
                
                # Adjust window if needed
                if ($currentIndex -ge $windowStart + $windowSize) {
                    $windowStart = $currentIndex - $windowSize + 1
                }
                if ($currentIndex -lt $windowStart) {
                    $windowStart = 0
                }
            }
            33 { # Page Up
                $windowStart = [Math]::Max(0, $windowStart - $windowSize)
                $currentIndex = [Math]::Max(0, $currentIndex - $windowSize)
            }
            34 { # Page Down
                $windowStart = [Math]::Min($filteredRepos.Count - $windowSize, $windowStart + $windowSize)
                $currentIndex = [Math]::Min($filteredRepos.Count - 1, $currentIndex + $windowSize)
                if ($windowStart -lt 0) { $windowStart = 0 }
            }
            36 { # Home
                $currentIndex = 0
                $windowStart = 0
            }
            35 { # End
                $currentIndex = $filteredRepos.Count - 1
                $windowStart = [Math]::Max(0, $filteredRepos.Count - $windowSize)
            }
            32 { # Space
                if ($currentIndex -lt $filteredRepos.Count) {
                    $originalIndex = $indexMapping[$currentIndex]
                    if ($selectedIndices -contains $originalIndex) {
                        $selectedIndices = $selectedIndices | Where-Object { $_ -ne $originalIndex }
                    } else {
                        $selectedIndices += $originalIndex
                    }
                }
            }
            65 { # A - Select All (visible)
                for ($i = $windowStart; $i -lt [Math]::Min($windowStart + $windowSize, $filteredRepos.Count); $i++) {
                    $originalIndex = $indexMapping[$i]
                    if ($selectedIndices -notcontains $originalIndex) {
                        $selectedIndices += $originalIndex
                    }
                }
            }
            67 { # C - Clear selection
                $selectedIndices = @()
            }
            83 { # S - Search
                $searchMode = $true
                $searchFilter = ""
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
    $path = Read-Host 'Path within repository (optional, for monorepos)'
    
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
                            Write-StatusMessage "[DEBUG] Found YAML files in ${dir}: $($allFiles.Count)" "Subtle"
                            foreach ($file in $allFiles | Select-Object -First 3) {
                                Write-StatusMessage "[DEBUG]   - $($file.FullName)" "Subtle"
                            }
                        } else {
                            Write-StatusMessage "[DEBUG] No YAML files found in $dir" "Subtle"
                        }
                    }
                } catch {
                    Write-StatusMessage "[DEBUG] Could not analyze directory ${dir}: $($_.Exception.Message)" "Subtle"
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
    
    $choice = Read-Host 'Choose option (1-4, default: 4)'
    
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
    Write-StatusMessage "[FLUTTER] Flutter Package Manager - Main Menu:" "Emphasis"
    Write-StatusMessage "1. New project setup (scan directories)" "Info"
    Write-StatusMessage "2. Add packages from GitHub repositories" "Info"
    Write-StatusMessage "3. Configuration settings" "Info"
    
    if ($hasLocalProject) {
        Write-StatusMessage "4. Use detected project: $projectName [DEFAULT]" "Success"
        if ($hasGitDeps) {
            Write-StatusMessage "5. [EXPRESS] Express Git update for $projectName" "Success"
        }
        Write-StatusMessage "6. [CACHE] Git cache management" "Info"
    }
    
    Write-StatusMessage "7. [UPDATE] Update Flutter Package Manager" "Info"
    
    $maxChoice = if ($hasLocalProject -and $hasGitDeps) { 7 } elseif ($hasLocalProject) { 7 } else { 7 }
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
    
    # Smart code analysis and recommendations
    Write-Host ""
    Write-StatusMessage "[INFO] Running smart code analysis..." "Info"
    $analysisPatterns = Analyze-CodePatterns $projectDir
    
    if ($analysisPatterns) {
        Write-Host ""
        Generate-SmartRecommendations $analysisPatterns
        Write-Host ""
        
        $useRecommendations = Read-Host "Would you like to prioritize these recommended packages? (Y/n)"
        if ($useRecommendations -notlike "n*") {
            $script:SmartRecommendations = $analysisPatterns
        }
    }
    
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
    Write-StatusMessage "[PACKAGE] Flutter Package Manager v2.0" "Emphasis"
    Write-StatusMessage "[AI] AI-Powered Git Dependency Management" "Emphasis"
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
                if ($menuResult.HasLocalProject) {
                    Write-StatusMessage "[INFO] Starting Git cache management..." "Info"
                    $projectDir = Split-Path $menuResult.DetectedProject -Parent
                    Clear-GitCache -ProjectDir $projectDir
                    break
                } else {
                    Write-StatusMessage "[ERROR] Invalid option: 6" "Error"
                    continue
                }
            }
            "7" {
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

# Smart Package Recommendations System
function Get-PackageRecommendations {
    param([string]$Pattern)
    
    $recommendations = @{
        "setState_pattern" = @(
            @{ Name = "riverpod"; Score = 9.2; Description = "Elegant state management with excellent API design" },
            @{ Name = "provider"; Score = 8.1; Description = "Simple but can get verbose with complex state" },
            @{ Name = "bloc"; Score = 7.3; Description = "Powerful but often over-engineered for simple apps" }
        )
        "SharedPreferences_pattern" = @(
            @{ Name = "hive"; Score = 8.8; Description = "Ingenious NoSQL database with beautiful syntax" },
            @{ Name = "shared_preferences"; Score = 6.5; Description = "Basic but gets messy with complex data" },
            @{ Name = "sqflite"; Score = 7.8; Description = "Powerful but overkill for simple key-value storage" }
        )
        "manual_http" = @(
            @{ Name = "dio"; Score = 9.1; Description = "Elegant HTTP client with interceptors and clean API" },
            @{ Name = "http"; Score = 7.2; Description = "Basic but requires lots of boilerplate for complex scenarios" }
        )
        "Navigator_push" = @(
            @{ Name = "go_router"; Score = 8.9; Description = "Declarative routing with excellent type safety" },
            @{ Name = "auto_route"; Score = 8.2; Description = "Code generation approach, less boilerplate" }
        )
        "manual_json" = @(
            @{ Name = "json_serializable"; Score = 8.7; Description = "Code generation eliminates boilerplate and errors" },
            @{ Name = "freezed"; Score = 9.0; Description = "Immutable classes with union types - incredibly elegant" }
        )
        "manual_auth" = @(
            @{ Name = "firebase_auth"; Score = 8.9; Description = "Comprehensive auth solution with great API" },
            @{ Name = "supabase_auth"; Score = 8.4; Description = "Clean alternative to Firebase" }
        )
        "Container_styling" = @(
            @{ Name = "flutter_screenutil"; Score = 8.3; Description = "Responsive design made simple" },
            @{ Name = "styled_widget"; Score = 8.6; Description = "Eloquent widget styling without nesting hell" }
        )
        "TextEditingController_forms" = @(
            @{ Name = "reactive_forms"; Score = 8.8; Description = "Reactive programming for forms - very elegant" },
            @{ Name = "flutter_form_builder"; Score = 7.9; Description = "Declarative but can be verbose" }
        )
        "Image_network" = @(
            @{ Name = "cached_network_image"; Score = 8.5; Description = "Intelligent caching with smooth loading states" },
            @{ Name = "fast_cached_network_image"; Score = 8.7; Description = "Even faster with better memory management" }
        )
        "print_debugging" = @(
            @{ Name = "logger"; Score = 8.4; Description = "Beautiful colored logs with different levels" },
            @{ Name = "talker"; Score = 8.6; Description = "Comprehensive logging and error tracking" }
        )
        "AnimationController_manual" = @(
            @{ Name = "flutter_animate"; Score = 9.3; Description = "Declarative animations with incredible ease of use" },
            @{ Name = "lottie"; Score = 8.1; Description = "Complex animations via After Effects files" }
        )
        "DateTime_formatting" = @(
            @{ Name = "intl"; Score = 8.0; Description = "Internationalization with date formatting" },
            @{ Name = "timeago"; Score = 7.8; Description = "Human-readable relative time" }
        )
        "manual_singletons" = @(
            @{ Name = "get_it"; Score = 8.2; Description = "Service locator pattern done right" },
            @{ Name = "injectable"; Score = 8.5; Description = "Code generation for DI - less boilerplate" }
        )
    }
    
    return $recommendations[$Pattern]
}

function Get-QualityExplanation {
    param([double]$Score)
    
    $scoreInt = [Math]::Floor($Score)
    
    switch ($scoreInt) {
        9 { return "[STAR] Exceptional: Ingenious design, elegant API, solves complex problems simply" }
        8 { return "[EXCELLENT] Excellent: Great architecture, clean code, well-designed API" }
        7 { return "[GOOD] Very Good: Solid implementation, good design patterns" }
        6 { return "[OK] Decent: Gets the job done but lacks ingenuity" }
        default { return "[BASIC] Functional: Works but could be more elegant" }
    }
}

function Get-QualityLevel {
    param([double]$Score)
    
    $scoreInt = [Math]::Floor($Score)
    
    switch ($scoreInt) {
        9 { return "[*]" }
        8 { return "[+]" }
        7 { return "[~]" }
        default { return "[.]" }
    }
}

function Get-PatternTitle {
    param([string]$Pattern)
    
    $titles = @{
        "setState_pattern" = "State Management Opportunity"
        "SharedPreferences_pattern" = "Local Storage Enhancement"
        "manual_http" = "HTTP Client Improvement"
        "Navigator_push" = "Navigation Architecture"
        "manual_json" = "JSON Serialization"
        "manual_auth" = "Authentication Solution"
        "Container_styling" = "UI Styling Architecture"
        "TextEditingController_forms" = "Form Management"
        "Image_network" = "Image Loading Optimization"
        "print_debugging" = "Logging Infrastructure"
        "AnimationController_manual" = "Animation Framework"
        "DateTime_formatting" = "Date/Time Handling"
        "manual_singletons" = "Dependency Injection"
    }
    
    return $titles[$Pattern] ?? "Code Enhancement"
}

function Get-PatternExplanation {
    param([string]$Pattern)
    
    $explanations = @{
        "setState_pattern" = "Moving to a proper state management solution reduces complexity and improves maintainability"
        "SharedPreferences_pattern" = "Modern storage solutions offer better performance, type safety, and developer experience"
        "manual_http" = "Dedicated HTTP clients provide interceptors, error handling, and cleaner APIs"
        "Navigator_push" = "Declarative navigation reduces boilerplate and provides better type safety"
        "manual_json" = "Code generation eliminates runtime errors and reduces boilerplate significantly"
        "manual_auth" = "Authentication providers handle security concerns and edge cases you might miss"
        "Container_styling" = "Styling libraries reduce widget nesting and make responsive design easier"
        "TextEditingController_forms" = "Form libraries provide validation, reactive updates, and cleaner architecture"
        "Image_network" = "Image caching improves performance and provides loading states out of the box"
        "print_debugging" = "Proper logging tools provide filtering, formatting, and production-safe debugging"
        "AnimationController_manual" = "Animation frameworks eliminate boilerplate and provide declarative syntax"
        "DateTime_formatting" = "Internationalization libraries handle locales and provide consistent formatting"
        "manual_singletons" = "Dependency injection containers provide better testing and cleaner architecture"
    }
    
    return $explanations[$Pattern] ?? "This pattern could benefit from a more elegant solution"
}

function Analyze-CodePatterns {
    param([string]$ProjectDir)
    
    Write-StatusMessage "[ANALYZE] Analyzing your Flutter code for improvement opportunities..." "Info"
    Write-Host ""
    
    if (-not (Test-Path $ProjectDir)) {
        Write-StatusMessage "[ERROR] Project directory not found: $ProjectDir" "Error"
        return $null
    }
    
    # Find all Dart files
    try {
        $dartFiles = Get-ChildItem -Path $ProjectDir -Recurse -Filter "*.dart" -File | Where-Object {
            $_.FullName -notlike "*\.git*" -and $_.FullName -notlike "*\build\*"
        }
        
        if (-not $dartFiles) {
            Write-StatusMessage "[WARNING] No Dart files found in project" "Warning"
            return $null
        }
        
        Write-StatusMessage "[SCAN] Scanning $($dartFiles.Count) Dart files..." "Info"
        Write-Host ""
        
        # Combine all dart files for analysis
        $allContent = ""
        foreach ($file in $dartFiles) {
            try {
                $allContent += Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
                $allContent += "`n"
            } catch {
                # Skip files that can't be read
            }
        }
        
        $foundPatterns = @()
        
        # setState Pattern Detection
        $setStateCount = ([regex]::Matches($allContent, "setState\(")).Count
        if ($setStateCount -gt 0) {
            $foundPatterns += @{ Pattern = "setState_pattern"; Count = $setStateCount }
            Write-StatusMessage "[STATE] State Management: Found $setStateCount setState() calls" "Info"
        }
        
        # SharedPreferences Pattern Detection
        $prefsCount = ([regex]::Matches($allContent, "SharedPreferences")).Count
        if ($prefsCount -gt 0) {
            $foundPatterns += @{ Pattern = "SharedPreferences_pattern"; Count = $prefsCount }
            Write-StatusMessage "[STORAGE] Local Storage: Found $prefsCount SharedPreferences usages" "Info"
        }
        
        # Manual HTTP Detection
        $httpGetCount = ([regex]::Matches($allContent, "http\.get|http\.post")).Count
        $httpClientCount = ([regex]::Matches($allContent, "HttpClient")).Count
        $dioCount = ([regex]::Matches($allContent, "dio|Dio")).Count
        $totalHttp = $httpGetCount + $httpClientCount
        
        if ($totalHttp -gt 0 -and $dioCount -eq 0) {
            $foundPatterns += @{ Pattern = "manual_http"; Count = $totalHttp }
            Write-StatusMessage "[HTTP] HTTP Calls: Found $totalHttp manual HTTP implementations" "Info"
        }
        
        # Navigation Pattern Detection
        $navCount = ([regex]::Matches($allContent, "Navigator\.push")).Count
        $routerCount = ([regex]::Matches($allContent, "go_router|GoRouter")).Count
        
        if ($navCount -gt 0 -and $routerCount -eq 0) {
            $foundPatterns += @{ Pattern = "Navigator_push"; Count = $navCount }
            Write-StatusMessage "[NAV] Navigation: Found $navCount imperative navigation calls" "Info"
        }
        
        # Manual JSON Pattern Detection
        $jsonCount = ([regex]::Matches($allContent, "fromJson|toJson")).Count
        $jsonSerializableCount = ([regex]::Matches($allContent, "json_serializable|JsonSerializable")).Count
        
        if ($jsonCount -gt 0 -and $jsonSerializableCount -eq 0) {
            $foundPatterns += @{ Pattern = "manual_json"; Count = $jsonCount }
            Write-StatusMessage "[JSON] JSON Handling: Found $jsonCount manual JSON implementations" "Info"
        }
        
        # Authentication Pattern Detection
        $authCount = ([regex]::Matches($allContent, "login|signIn|authenticate")).Count
        $firebaseAuthCount = ([regex]::Matches($allContent, "firebase_auth|FirebaseAuth")).Count
        
        if ($authCount -gt 0 -and $firebaseAuthCount -eq 0) {
            $foundPatterns += @{ Pattern = "manual_auth"; Count = $authCount }
            Write-StatusMessage "[AUTH] Authentication: Found $authCount manual auth implementations" "Info"
        }
        
        # Container Styling Detection
        $containerCount = ([regex]::Matches($allContent, "Container\(")).Count
        if ($containerCount -gt 10) {
            $foundPatterns += @{ Pattern = "Container_styling"; Count = $containerCount }
            Write-StatusMessage "[UI] UI Styling: Found $containerCount Container widgets (potential styling complexity)" "Info"
        }
        
        # Form Handling Detection
        $controllerCount = ([regex]::Matches($allContent, "TextEditingController")).Count
        if ($controllerCount -gt 3) {
            $foundPatterns += @{ Pattern = "TextEditingController_forms"; Count = $controllerCount }
            Write-StatusMessage "[FORM] Form Handling: Found $controllerCount TextEditingController instances" "Info"
        }
        
        # Image Network Detection
        $imageCount = ([regex]::Matches($allContent, "Image\.network")).Count
        $cachedImageCount = ([regex]::Matches($allContent, "cached_network_image")).Count
        
        if ($imageCount -gt 0 -and $cachedImageCount -eq 0) {
            $foundPatterns += @{ Pattern = "Image_network"; Count = $imageCount }
            Write-StatusMessage "[IMAGE] Image Loading: Found $imageCount uncached network images" "Info"
        }
        
        # Print Debugging Detection
        $printCount = ([regex]::Matches($allContent, "print\(")).Count
        $loggerCount = ([regex]::Matches($allContent, "logger|Logger")).Count
        
        if ($printCount -gt 5 -and $loggerCount -eq 0) {
            $foundPatterns += @{ Pattern = "print_debugging"; Count = $printCount }
            Write-StatusMessage "[DEBUG] Debugging: Found $printCount print statements (could use proper logging)" "Info"
        }
        
        # Animation Detection
        $animCount = ([regex]::Matches($allContent, "AnimationController|Animation<")).Count
        $flutterAnimateCount = ([regex]::Matches($allContent, "flutter_animate")).Count
        
        if ($animCount -gt 0 -and $flutterAnimateCount -eq 0) {
            $foundPatterns += @{ Pattern = "AnimationController_manual"; Count = $animCount }
            Write-StatusMessage "[ANIM] Animations: Found $animCount manual animation implementations" "Info"
        }
        
        # DateTime Formatting Detection
        $dateFormatCount = ([regex]::Matches($allContent, "DateTime.*toString|DateFormat.*format")).Count
        if ($dateFormatCount -gt 0) {
            $foundPatterns += @{ Pattern = "DateTime_formatting"; Count = $dateFormatCount }
            Write-StatusMessage "[DATE] Date Formatting: Found $dateFormatCount date formatting operations" "Info"
        }
        
        # Manual Singleton Detection
        $singletonCount = ([regex]::Matches($allContent, "static.*getInstance|static.*_instance")).Count
        if ($singletonCount -gt 0) {
            $foundPatterns += @{ Pattern = "manual_singletons"; Count = $singletonCount }
            Write-StatusMessage "[DEPS] Dependency Management: Found $singletonCount manual singleton patterns" "Info"
        }
        
        if ($foundPatterns.Count -eq 0) {
            Write-StatusMessage "[SUCCESS] Code analysis complete - no obvious improvement opportunities found!" "Success"
            Write-StatusMessage "   Your code is already well-structured!" "Success"
            return $null
        }
        
        Write-Host ""
        Write-StatusMessage "[REPORT] Analysis complete: Found $($foundPatterns.Count) improvement opportunities" "Info"
        Write-Host ""
        
        return $foundPatterns
        
    } catch {
        Write-StatusMessage "[ERROR] Error during code analysis: $($_.Exception.Message)" "Error"
        return $null
    }
}

function Generate-SmartRecommendations {
    param($Patterns)
    
    if (-not $Patterns -or $Patterns.Count -eq 0) {
        return
    }
    
    Write-StatusMessage "[AI] SMART RECOMMENDATIONS - Packages that could improve your code:" "Emphasis"
    Write-StatusMessage "=================================================================" "Info"
    Write-Host ""
    
    $recCount = 0
    
    foreach ($patternInfo in $Patterns) {
        $recommendations = Get-PackageRecommendations $patternInfo.Pattern
        
        if ($recommendations) {
            $recCount++
            
            Write-StatusMessage "**$recCount. $(Get-PatternTitle $patternInfo.Pattern)** ($($patternInfo.Count) occurrences found)" "Emphasis"
            Write-Host ""
            
            foreach ($recommendation in $recommendations) {
                $qualityLevel = Get-QualityLevel $recommendation.Score
                $qualityExplanation = Get-QualityExplanation $recommendation.Score
                
                Write-StatusMessage "   [PACKAGE] **$($recommendation.Name)** (Quality: $($recommendation.Score)/10) $qualityLevel" "Info"
                Write-StatusMessage "      [INFO] $($recommendation.Description)" "Subtle"
                Write-StatusMessage "      [QUALITY] $qualityExplanation" "Subtle"
                Write-Host ""
            }
            
            Write-StatusMessage "   [WHY] **Why this matters:** $(Get-PatternExplanation $patternInfo.Pattern)" "Info"
            Write-Host ""
            Write-StatusMessage $("-" * 80) "Subtle"
            Write-Host ""
        }
    }
    
    if ($recCount -eq 0) {
        Write-StatusMessage "[SUCCESS] No specific recommendations found - your code patterns look great!" "Success"
    } else {
        Write-Host ""
        Write-StatusMessage "[STEPS] **Next Steps:**" "Info"
        Write-StatusMessage "   1. Review the recommendations above" "Subtle"
        Write-StatusMessage "   2. When adding packages, flutter-pm will prioritize these high-quality options" "Subtle"
        Write-StatusMessage "   3. Each package includes architectural guidance for integration" "Subtle"
        Write-Host ""
        Write-StatusMessage "[QUALITY] **Quality Focus:** These recommendations prioritize elegant, ingenious solutions" "Info"
        Write-StatusMessage "   over popular but overcomplicated alternatives." "Subtle"
    }
}

# Advanced Git Cache Management
function Get-PubCacheDir {
    $cacheDir = "$env:LOCALAPPDATA\Pub\Cache\git"
    if (Test-Path $cacheDir) {
        return $cacheDir
    }
    
    $alternateCache = "$env:USERPROFILE\.pub-cache\git"
    if (Test-Path $alternateCache) {
        return $alternateCache
    }
    
    return $null
}

function Clear-GitCache {
    param(
        [string]$ProjectDir = ".",
        [string[]]$PackageNames = @(),
        [switch]$Nuclear = $false
    )
    
    Write-StatusMessage "[INFO] Git Cache Management" "Info"
    Write-StatusMessage "============================" "Info"
    
    $cacheDir = Get-PubCacheDir
    if (-not $cacheDir) {
        Write-StatusMessage "[WARNING] Pub cache directory not found" "Warning"
        return $false
    }
    
    Write-StatusMessage "[INFO] Cache directory: $cacheDir" "Subtle"
    
    if ($Nuclear) {
        Write-StatusMessage "[WARNING] Nuclear option: Clearing all cache and locks" "Warning"
        
        $lockPath = Join-Path $ProjectDir "pubspec.lock"
        if (Test-Path $lockPath) {
            $backupPath = "$lockPath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            Copy-Item $lockPath $backupPath
            Write-StatusMessage "[INFO] Backed up pubspec.lock" "Info"
            Remove-Item $lockPath -Force
            Write-StatusMessage "[INFO] Removed pubspec.lock" "Info"
        }
        
        try {
            Remove-Item "$cacheDir\*" -Recurse -Force -ErrorAction SilentlyContinue
            Write-StatusMessage "[SUCCESS] Cleared entire Git cache" "Success"
        } catch {
            Write-StatusMessage "[WARNING] Could not clear entire cache: $($_.Exception.Message)" "Warning"
        }
    } elseif ($PackageNames.Count -gt 0) {
        Write-StatusMessage "[INFO] Clearing cache for specific packages..." "Info"
        
        foreach ($packageName in $PackageNames) {
            try {
                $packageDirs = Get-ChildItem -Path $cacheDir -Directory | Where-Object { 
                    $_.Name -like "$packageName-*" 
                }
                
                foreach ($dir in $packageDirs) {
                    Remove-Item $dir.FullName -Recurse -Force
                    Write-StatusMessage "[SUCCESS] Cleared cache for $packageName" "Success"
                }
                
                if ($packageDirs.Count -eq 0) {
                    Write-StatusMessage "[INFO] No cached files found for $packageName" "Info"
                }
            } catch {
                Write-StatusMessage "[WARNING] Could not clear cache for ${packageName}: $($_.Exception.Message)" "Warning"
            }
        }
    } else {
        Write-StatusMessage "[INFO] Available cache management options:" "Info"
        Write-StatusMessage "1. Clear specific package cache" "Subtle"
        Write-StatusMessage "2. Nuclear option - clear all cache and locks" "Subtle"
        Write-StatusMessage "3. Force upgrade Git packages" "Subtle"
        Write-StatusMessage "4. Return to main menu" "Subtle"
        
        $choice = Read-Host 'Choose option (1-4, default: 4)'
        
        switch ($choice) {
            "1" {
                $packageName = Read-Host "Enter package name to clear cache for"
                if (-not [string]::IsNullOrEmpty($packageName)) {
                    Clear-GitCache -ProjectDir $ProjectDir -PackageNames @($packageName)
                }
            }
            "2" {
                $confirm = Read-Host "Are you sure you want to clear ALL cache? This will force re-download of all Git packages (y/N)"
                if ($confirm -like "y*") {
                    Clear-GitCache -ProjectDir $ProjectDir -Nuclear
                }
            }
            "3" {
                Force-UpgradeGitPackages -ProjectDir $ProjectDir
            }
            default {
                return
            }
        }
    }
    
    # Run flutter pub get after cache operations
    Write-StatusMessage "[INFO] Running flutter pub get..." "Info"
    $currentLocation = Get-Location
    try {
        Set-Location $ProjectDir
        flutter pub get
        if ($LASTEXITCODE -eq 0) {
            Write-StatusMessage "[SUCCESS] Flutter packages updated successfully" "Success"
        } else {
            Write-StatusMessage "[WARNING] Flutter pub get completed with warnings" "Warning"
        }
    } finally {
        Set-Location $currentLocation
    }
    
    return $true
}

function Force-UpgradeGitPackages {
    param([string]$ProjectDir = ".")
    
    Write-StatusMessage "[INFO] Forcing Git package updates..." "Info"
    
    $currentLocation = Get-Location
    try {
        Set-Location $ProjectDir
        
        # Try flutter pub upgrade first
        flutter pub upgrade
        
        # Check if --force-upgrade is available
        $upgradeHelp = flutter pub upgrade --help 2>&1 | Out-String
        if ($upgradeHelp -match "--force-upgrade") {
            Write-StatusMessage "[INFO] Using --force-upgrade flag" "Info"
            flutter pub upgrade --force-upgrade
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-StatusMessage "[SUCCESS] Git packages upgraded successfully" "Success"
        } else {
            Write-StatusMessage "[WARNING] Upgrade completed with warnings" "Warning"
        }
    } catch {
        Write-StatusMessage "[ERROR] Error during upgrade: $($_.Exception.Message)" "Error"
    } finally {
        Set-Location $currentLocation
    }
}

# Project Auto-Fix Capabilities
function Test-FlutterProjectHealth {
    param([string]$ProjectDir)
    
    $issues = @()
    $fixes = @()
    
    # Check for missing main.dart
    $mainDartPath = Join-Path $ProjectDir "lib\main.dart"
    if (-not (Test-Path $mainDartPath)) {
        $issues += "Missing lib/main.dart"
        $fixes += "create_main_dart"
    }
    
    # Check for Git repository
    $gitPath = Join-Path $ProjectDir ".git"
    if (-not (Test-Path $gitPath)) {
        $issues += "Not a Git repository"
        $fixes += "init_git"
    }
    
    # Check pubspec.yaml syntax
    $pubspecPath = Join-Path $ProjectDir "pubspec.yaml"
    if (Test-Path $pubspecPath) {
        $pubspecContent = Get-Content $pubspecPath -Raw
        if (-not ($pubspecContent -match "name:")) {
            $issues += "Invalid pubspec.yaml format"
            $fixes += "fix_pubspec"
        }
    }
    
    return @{
        Issues = $issues
        Fixes = $fixes
    }
}

function Apply-ProjectAutoFixes {
    param(
        [string]$ProjectDir,
        [string[]]$Fixes
    )
    
    Write-StatusMessage "[INFO] Applying Automatic Fixes" "Info"
    Write-StatusMessage "===============================" "Info"
    
    foreach ($fix in $Fixes) {
        switch ($fix) {
            "create_main_dart" {
                Write-StatusMessage "[INFO] Creating lib/main.dart with Flutter template..." "Info"
                
                $libDir = Join-Path $ProjectDir "lib"
                if (-not (Test-Path $libDir)) {
                    New-Item -ItemType Directory -Path $libDir -Force | Out-Null
                }
                
                $mainDartContent = @"
import 'package:flutter/material.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Flutter Demo Home Page')),
      body: Center(child: Text('Hello Flutter!')),
    );
  }
}
"@
                
                $mainDartPath = Join-Path $libDir "main.dart"
                $mainDartContent | Set-Content $mainDartPath -Encoding UTF8
                Write-StatusMessage "[SUCCESS] Created lib/main.dart" "Success"
            }
            "init_git" {
                Write-StatusMessage "[INFO] Initializing Git repository..." "Info"
                
                $currentLocation = Get-Location
                try {
                    Set-Location $ProjectDir
                    git init | Out-Null
                    Write-StatusMessage "[SUCCESS] Git repository initialized" "Success"
                } catch {
                    Write-StatusMessage "[ERROR] Failed to initialize Git: $($_.Exception.Message)" "Error"
                } finally {
                    Set-Location $currentLocation
                }
            }
            "fix_pubspec" {
                Write-StatusMessage "[INFO] Fixing pubspec.yaml format..." "Info"
                Write-StatusMessage "[WARNING] Manual pubspec.yaml review recommended" "Warning"
            }
        }
    }
    
    Write-Host ""
    Write-StatusMessage "[SUCCESS] Auto-fixes complete!" "Success"
    Write-Host ""
}

# Monorepo Support Functions
function Detect-MonorepoStructure {
    param([string]$ProjectPath)
    
    $packages = @()
    $isMonorepo = $false
    
    try {
        # Look for packages directory (common monorepo pattern)
        $packagesDir = Join-Path $ProjectPath "packages"
        if (Test-Path $packagesDir) {
            $subPackages = Get-ChildItem -Path $packagesDir -Directory | Where-Object {
                Test-Path (Join-Path $_.FullName "pubspec.yaml")
            }
            
            if ($subPackages.Count -gt 0) {
                $isMonorepo = $true
                foreach ($pkg in $subPackages) {
                    $packages += @{
                        Name = $pkg.Name
                        Path = $pkg.FullName
                        RelativePath = "packages/$($pkg.Name)"
                        PubspecPath = Join-Path $pkg.FullName "pubspec.yaml"
                    }
                }
                Write-StatusMessage "[INFO] Detected monorepo with $($packages.Count) packages in /packages" "Info"
            }
        }
        
        # Look for apps directory (Flutter multi-app pattern)
        $appsDir = Join-Path $ProjectPath "apps"
        if (Test-Path $appsDir) {
            $appPackages = Get-ChildItem -Path $appsDir -Directory | Where-Object {
                Test-Path (Join-Path $_.FullName "pubspec.yaml")
            }
            
            if ($appPackages.Count -gt 0) {
                $isMonorepo = $true
                foreach ($pkg in $appPackages) {
                    $packages += @{
                        Name = $pkg.Name
                        Path = $pkg.FullName
                        RelativePath = "apps/$($pkg.Name)"
                        PubspecPath = Join-Path $pkg.FullName "pubspec.yaml"
                        Type = "app"
                    }
                }
                Write-StatusMessage "[INFO] Detected $($appPackages.Count) apps in /apps directory" "Info"
            }
        }
        
        # Look for modules directory (custom monorepo pattern)
        $modulesDir = Join-Path $ProjectPath "modules"
        if (Test-Path $modulesDir) {
            $modulePackages = Get-ChildItem -Path $modulesDir -Directory | Where-Object {
                Test-Path (Join-Path $_.FullName "pubspec.yaml")
            }
            
            if ($modulePackages.Count -gt 0) {
                $isMonorepo = $true
                foreach ($pkg in $modulePackages) {
                    $packages += @{
                        Name = $pkg.Name
                        Path = $pkg.FullName
                        RelativePath = "modules/$($pkg.Name)"
                        PubspecPath = Join-Path $pkg.FullName "pubspec.yaml"
                        Type = "module"
                    }
                }
                Write-StatusMessage "[INFO] Detected $($modulePackages.Count) modules in /modules directory" "Info"
            }
        }
        
        # Recursive search for nested packages (up to 2 levels deep)
        $nestedPackages = Get-ChildItem -Path $ProjectPath -Recurse -Depth 2 -File -Name "pubspec.yaml" | Where-Object {
            $_ -notlike "build\*" -and $_ -notlike ".git\*" -and $_ -ne "pubspec.yaml"
        }
        
        foreach ($pubspecFile in $nestedPackages) {
            $fullPath = Join-Path $ProjectPath $pubspecFile
            $packageDir = Split-Path $fullPath -Parent
            $packageName = Split-Path $packageDir -Leaf
            $relativePath = Split-Path $pubspecFile -Parent
            
            # Skip if already detected
            if ($packages | Where-Object { $_.Path -eq $packageDir }) {
                continue
            }
            
            if (Test-FlutterProject $fullPath) {
                $packages += @{
                    Name = $packageName
                    Path = $packageDir
                    RelativePath = $relativePath
                    PubspecPath = $fullPath
                    Type = "nested"
                }
                $isMonorepo = $true
            }
        }
        
        return @{
            IsMonorepo = $isMonorepo
            Packages = $packages
            MainProject = if (-not $isMonorepo) { $ProjectPath } else { $null }
        }
        
    } catch {
        Write-StatusMessage "[ERROR] Error detecting monorepo structure: $($_.Exception.Message)" "Error"
        return @{
            IsMonorepo = $false
            Packages = @()
            MainProject = $ProjectPath
        }
    }
}

function Select-MonorepoPackage {
    param($MonorepoInfo)
    
    if (-not $MonorepoInfo.IsMonorepo -or $MonorepoInfo.Packages.Count -eq 0) {
        return $null
    }
    
    Write-StatusMessage "[INFO] Monorepo Structure Detected" "Info"
    Write-StatusMessage "======================================" "Info"
    Write-Host ""
    
    Write-StatusMessage "Available packages:" "Info"
    for ($i = 0; $i -lt $MonorepoInfo.Packages.Count; $i++) {
        $package = $MonorepoInfo.Packages[$i]
        $type = if ($package.Type) { "[$($package.Type.ToUpper())]" } else { "[PACKAGE]" }
        Write-StatusMessage "$($i + 1). $($package.Name) $type" "Subtle"
        Write-StatusMessage "    Path: $($package.RelativePath)" "Subtle"
    }
    
    Write-Host ""
    Write-StatusMessage "0. Work with all packages" "Info"
    Write-Host ""
    
    do {
        $choice = Read-Host "Select package to configure (0-$($MonorepoInfo.Packages.Count), default: 0)"
        if ([string]::IsNullOrEmpty($choice)) { $choice = "0" }
    } while (-not ($choice -match '^\d+$' -and [int]$choice -ge 0 -and [int]$choice -le $MonorepoInfo.Packages.Count))
    
    $choiceInt = [int]$choice
    
    if ($choiceInt -eq 0) {
        return $MonorepoInfo.Packages
    } else {
        return @($MonorepoInfo.Packages[$choiceInt - 1])
    }
}

# Dependency Conflict Resolution
function Analyze-DependencyConflicts {
    param([string]$PubspecPath)
    
    if (-not (Test-Path $PubspecPath)) {
        return @{
            HasConflicts = $false
            Conflicts = @()
        }
    }
    
    try {
        $projectDir = Split-Path $PubspecPath -Parent
        $lockPath = Join-Path $projectDir "pubspec.lock"
        
        if (-not (Test-Path $lockPath)) {
            Write-StatusMessage "[INFO] No pubspec.lock found. Running flutter pub get first..." "Info"
            
            $currentLocation = Get-Location
            try {
                Set-Location $projectDir
                flutter pub get | Out-Null
            } finally {
                Set-Location $currentLocation
            }
        }
        
        if (-not (Test-Path $lockPath)) {
            return @{
                HasConflicts = $false
                Conflicts = @()
                Error = "Could not generate pubspec.lock"
            }
        }
        
        # Read pubspec.yaml to get declared dependencies
        $pubspecContent = Get-Content $PubspecPath -Raw
        $declaredDeps = @{}
        
        # Extract version constraints from pubspec.yaml
        if ($pubspecContent -match '(?s)dependencies:(.*?)(?=\n\w|\n#|\Z)') {
            $depsSection = $Matches[1]
            $lines = $depsSection -split "`n"
            
            foreach ($line in $lines) {
                if ($line -match '^\s*([a-zA-Z_][a-zA-Z0-9_]*)\s*:\s*(.+)$') {
                    $packageName = $Matches[1].Trim()
                    $constraint = $Matches[2].Trim()
                    
                    # Skip Flutter SDK and Git dependencies for version conflict analysis
                    if ($constraint -notmatch '^flutter$' -and $constraint -notmatch 'git:') {
                        $declaredDeps[$packageName] = $constraint
                    }
                }
            }
        }
        
        # Read pubspec.lock to get resolved versions
        $lockContent = Get-Content $lockPath -Raw
        $resolvedDeps = @{}
        
        if ($lockContent -match '(?s)packages:(.*?)(?=\nsdks:|\Z)') {
            $packagesSection = $Matches[1]
            $lines = $packagesSection -split "`n"
            
            $currentPackage = $null
            foreach ($line in $lines) {
                if ($line -match '^\s*([a-zA-Z_][a-zA-Z0-9_]*):$') {
                    $currentPackage = $Matches[1].Trim()
                } elseif ($currentPackage -and $line -match '^\s*version:\s*"([^"]+)"') {
                    $resolvedDeps[$currentPackage] = $Matches[1].Trim()
                }
            }
        }
        
        # Detect potential conflicts
        $conflicts = @()
        
        # Check for outdated dependencies
        foreach ($package in $declaredDeps.Keys) {
            if ($resolvedDeps.ContainsKey($package)) {
                $declared = $declaredDeps[$package]
                $resolved = $resolvedDeps[$package]
                
                # Simple version conflict detection
                if ($declared -match '^\^?(\d+)\.(\d+)\.(\d+)' -and $resolved -match '^(\d+)\.(\d+)\.(\d+)') {
                    $declaredMajor = [int]$Matches[1]
                    $resolvedMajor = [int]$Matches[1]
                    
                    if ($declaredMajor -ne $resolvedMajor) {
                        $conflicts += @{
                            Package = $package
                            Type = "MajorVersionMismatch"
                            Declared = $declared
                            Resolved = $resolved
                            Severity = "High"
                            Description = "Major version mismatch between declared ($declared) and resolved ($resolved)"
                        }
                    }
                }
            }
        }
        
        # Look for common conflict patterns in pub output
        $currentLocation = Get-Location
        try {
            Set-Location $projectDir
            
            # Run pub deps to check for conflicts
            $pubDepsOutput = flutter pub deps 2>&1 | Out-String
            
            if ($pubDepsOutput -match "conflict|incompatible|failed to resolve") {
                $conflicts += @{
                    Package = "Multiple"
                    Type = "ResolutionConflict"
                    Description = "Pub dependency resolution conflicts detected"
                    Severity = "Medium"
                    Output = $pubDepsOutput
                }
            }
            
        } catch {
            # Ignore errors in pub deps check
        } finally {
            Set-Location $currentLocation
        }
        
        return @{
            HasConflicts = $conflicts.Count -gt 0
            Conflicts = $conflicts
            DeclaredDeps = $declaredDeps
            ResolvedDeps = $resolvedDeps
        }
        
    } catch {
        Write-StatusMessage "[ERROR] Error analyzing dependencies: $($_.Exception.Message)" "Error"
        return @{
            HasConflicts = $false
            Conflicts = @()
            Error = $_.Exception.Message
        }
    }
}

function Suggest-ConflictResolutions {
    param($ConflictAnalysis)
    
    if (-not $ConflictAnalysis.HasConflicts) {
        return
    }
    
    Write-StatusMessage "[WARNING] Dependency Conflicts Detected" "Warning"
    Write-StatusMessage "=========================================" "Warning"
    Write-Host ""
    
    foreach ($conflict in $ConflictAnalysis.Conflicts) {
        Write-StatusMessage "Conflict: $($conflict.Package)" "Error"
        Write-StatusMessage "Type: $($conflict.Type)" "Subtle"
        Write-StatusMessage "Severity: $($conflict.Severity)" "Warning"
        Write-StatusMessage "Description: $($conflict.Description)" "Subtle"
        
        # Suggest resolution strategies
        Write-StatusMessage "[SUGGEST] Resolution suggestions:" "Info"
        
        switch ($conflict.Type) {
            "MajorVersionMismatch" {
                Write-StatusMessage "  1. Update pubspec.yaml constraint to allow newer version" "Subtle"
                Write-StatusMessage "  2. Use 'flutter pub upgrade $($conflict.Package)'" "Subtle"
                Write-StatusMessage "  3. Check package changelog for breaking changes" "Subtle"
            }
            "ResolutionConflict" {
                Write-StatusMessage "  1. Run 'flutter pub deps' to see detailed dependency tree" "Subtle"
                Write-StatusMessage "  2. Use dependency_overrides in pubspec.yaml" "Subtle"
                Write-StatusMessage "  3. Update conflicting packages to compatible versions" "Subtle"
                Write-StatusMessage "  4. Consider using 'flutter pub upgrade --major-versions'" "Subtle"
            }
            default {
                Write-StatusMessage "  1. Run 'flutter pub upgrade' to resolve automatically" "Subtle"
                Write-StatusMessage "  2. Check package documentation for compatibility" "Subtle"
            }
        }
        
        Write-Host ""
    }
    
    Write-StatusMessage "[TOOLS] **Automated Resolution Options:**" "Info"
    Write-StatusMessage "1. Try automatic upgrade" "Subtle"
    Write-StatusMessage "2. Clear cache and rebuild dependencies" "Subtle"
    Write-StatusMessage "3. Show detailed dependency analysis" "Subtle"
    Write-StatusMessage "4. Continue without changes" "Subtle"
    
    $choice = Read-Host "Choose resolution option (1-4, default: 4)"
    
    switch ($choice) {
        "1" {
            Write-StatusMessage "[INFO] Attempting automatic upgrade..." "Info"
            $projectDir = Split-Path (Get-Location) -Parent
            Force-UpgradeGitPackages -ProjectDir $projectDir
        }
        "2" {
            Write-StatusMessage "[INFO] Clearing cache and rebuilding..." "Info"
            $projectDir = Split-Path (Get-Location) -Parent
            Clear-GitCache -ProjectDir $projectDir -Nuclear
        }
        "3" {
            Write-StatusMessage "[INFO] Dependency analysis:" "Info"
            $projectDir = Split-Path (Get-Location) -Parent
            $currentLocation = Get-Location
            try {
                Set-Location $projectDir
                flutter pub deps
            } finally {
                Set-Location $currentLocation
            }
        }
        default {
            Write-StatusMessage "[INFO] Continuing with current configuration..." "Info"
        }
    }
}

function Validate-FlutterEnvironment {
    param([string]$PubspecPath)
    
    $projectDir = Split-Path $PubspecPath -Parent
    
    # Check for monorepo structure
    $monorepoInfo = Detect-MonorepoStructure $projectDir
    
    if ($monorepoInfo.IsMonorepo) {
        Write-Host ""
        Write-StatusMessage "[MONOREPO] **Monorepo Structure Detected**" "Info"
        Write-StatusMessage "====================================" "Info"
        Write-StatusMessage "Found $($monorepoInfo.Packages.Count) packages in this repository" "Info"
        
        $selectedPackages = Select-MonorepoPackage $monorepoInfo
        if ($selectedPackages) {
            # Update the global variable to work with selected packages
            $script:MonorepoPackages = $selectedPackages
        }
    }
    
    # Standard health check
    $healthCheck = Test-FlutterProjectHealth $projectDir
    
    if ($healthCheck.Issues.Count -gt 0) {
        Write-Host ""
        Write-StatusMessage "[ANALYSIS] **Project Analysis - Issues Detected**" "Info"
        Write-StatusMessage "========================================" "Info"
        
        foreach ($issue in $healthCheck.Issues) {
            Write-StatusMessage "[WARNING] $issue" "Warning"
        }
        
        Write-Host ""
        Write-StatusMessage "[AUTOFIX] **Auto-Fix Available**" "Info"
        Write-StatusMessage "I can automatically fix these issues to ensure optimal Flutter development." "Info"
        Write-Host ""
        
        $applyFixes = Read-Host "Apply automatic fixes? (Y/n)"
        if ($applyFixes -notlike "n*") {
            Apply-ProjectAutoFixes $projectDir $healthCheck.Fixes
        }
    }
    
    # Analyze dependency conflicts
    Write-Host ""
    Write-StatusMessage "[INFO] Analyzing dependency conflicts..." "Info"
    $conflictAnalysis = Analyze-DependencyConflicts $PubspecPath
    
    if ($conflictAnalysis.HasConflicts) {
        Suggest-ConflictResolutions $conflictAnalysis
    } else {
        Write-StatusMessage "[SUCCESS] No dependency conflicts detected" "Success"
    }
}

# Run main function
try {
    $exitCode = Main
    exit $exitCode
} catch {
    Write-StatusMessage "[ERROR] Unexpected error: $($_.Exception.Message)" "Error"
    exit 1
}