@echo off
setlocal enabledelayedexpansion

echo 🚀 Auto-Setup Windows Development Environment
echo ==============================================
echo.

REM Check if Git is installed, install if not
where git >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo 📦 Installing Git for Windows...
    where winget >nul 2>nul
    if %ERRORLEVEL% NEQ 0 (
        echo ❌ winget not found. Please install Git manually: https://git-scm.com/download/win
        pause
        exit /b 1
    )
    
    winget install --id Git.Git --silent --accept-package-agreements --accept-source-agreements
    
    REM Refresh PATH
    for /f "tokens=2*" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH 2^>nul') do set "SYS_PATH=%%b"
    for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v PATH 2^>nul') do set "USER_PATH=%%b"
    set "PATH=%SYS_PATH%;%USER_PATH%"
)

REM Find Git Bash
set "GIT_BASH_PATH="
for %%p in ("C:\Program Files\Git\bin\bash.exe" "C:\Program Files (x86)\Git\bin\bash.exe") do (
    if exist "%%p" (
        set "GIT_BASH_PATH=%%p"
        goto :found_bash
    )
)

echo ❌ Git Bash not found. Please restart this script after Git installation completes.
pause
exit /b 1

:found_bash
echo ✅ Found Git Bash

REM Download setup script if not present
if not exist "quick_dev_setup.sh" (
    echo 📥 Downloading setup script...
    
    REM Try with curl (comes with Windows 10+)
    where curl >nul 2>nul
    if %ERRORLEVEL% EQU 0 (
        curl -L -o quick_dev_setup.sh "https://raw.githubusercontent.com/daslaller/your-repo/main/quick_dev_setup.sh"
    ) else (
        REM Try with PowerShell
        powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/daslaller/setup_flutter_dev_env/linux_macos_full.sh' -OutFile 'quick_dev_setup.sh'"
    )
    
    if not exist "quick_dev_setup.sh" (
        echo ❌ Failed to download setup script.
        echo Please manually download it and place it in this folder.
        pause
        exit /b 1
    )
    
    echo ✅ Setup script downloaded
)

echo.
echo 🎯 Launching development setup...
"%GIT_BASH_PATH%" -c "chmod +x quick_dev_setup.sh && ./quick_dev_setup.sh"

echo.
echo 🎉 Setup complete! You can now use Git Bash for development.

pause

