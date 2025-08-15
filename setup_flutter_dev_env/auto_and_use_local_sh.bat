@echo off
setlocal enabledelayedexpansion

echo 🚀 Windows Development Setup Launcher
echo =====================================
echo.

REM Check if running as Administrator
net session >nul 2>&1
if %errorLevel% == 0 (
    echo ✅ Running as Administrator
) else (
    echo ⚠️  Not running as Administrator - some installations may require elevation
)

echo.

REM Check if Git is already installed
where git >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo ✅ Git is already installed
    goto :check_bash
) else (
    echo 📦 Git not found - installing Git for Windows...
)

REM Check if winget is available
where winget >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ❌ winget not found. Please install Git for Windows manually:
    echo https://git-scm.com/download/win
    echo.
    echo After installation, re-run this script.
    pause
    exit /b 1
)

REM Install Git for Windows
echo Installing Git for Windows with winget...
winget install --id Git.Git --silent --accept-package-agreements --accept-source-agreements

if %ERRORLEVEL% NEQ 0 (
    echo ❌ Failed to install Git for Windows automatically.
    echo Please install manually from: https://git-scm.com/download/win
    echo.
    echo After installation, re-run this script.
    pause
    exit /b 1
)

echo ✅ Git for Windows installed successfully!
echo.

REM Refresh environment variables
echo 🔄 Refreshing environment variables...
for /f "tokens=2*" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH 2^>nul') do set "SYS_PATH=%%b"
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v PATH 2^>nul') do set "USER_PATH=%%b"
set "PATH=%SYS_PATH%;%USER_PATH%"

:check_bash
REM Find Git Bash executable
set "GIT_BASH_PATH="

REM Common installation paths for Git Bash
set "SEARCH_PATHS=C:\Program Files\Git\bin\bash.exe"
set "SEARCH_PATHS=%SEARCH_PATHS%;C:\Program Files (x86)\Git\bin\bash.exe"
set "SEARCH_PATHS=%SEARCH_PATHS%;%LOCALAPPDATA%\Programs\Git\bin\bash.exe"
set "SEARCH_PATHS=%SEARCH_PATHS%;%PROGRAMFILES%\Git\bin\bash.exe"

for %%p in (%SEARCH_PATHS%) do (
    if exist "%%p" (
        set "GIT_BASH_PATH=%%p"
        goto :found_bash
    )
)

REM If not found in common paths, try to find it via where command
for /f "tokens=*" %%i in ('where bash 2^>nul') do (
    set "GIT_BASH_PATH=%%i"
    goto :found_bash
)

REM Still not found
echo ❌ Git Bash not found. Please ensure Git for Windows is properly installed.
echo You can download it from: https://git-scm.com/download/win
pause
exit /b 1

:found_bash
echo ✅ Found Git Bash at: %GIT_BASH_PATH%
echo.

REM Check if the bash script exists
if not exist "quick_dev_setup.sh" (
    echo ❌ Script 'quick_dev_setup.sh' not found in current directory.
    echo.
    echo Please ensure you have the bash script in the same folder as this batch file.
    echo You can download it or create it with the setup script content.
    echo.
    pause
    exit /b 1
)

echo ✅ Found setup script: quick_dev_setup.sh
echo.

REM Make the script executable and run it
echo 🎯 Launching Git Bash with setup script...
echo.
echo ==========================================
echo   Running in Git Bash environment...
echo ==========================================
echo.

REM Run the bash script in Git Bash
"%GIT_BASH_PATH%" -c "chmod +x quick_dev_setup.sh && ./quick_dev_setup.sh"

echo.
echo ==========================================
echo   Back to Windows Command Prompt
echo ==========================================
echo.

if %ERRORLEVEL% EQU 0 (
    echo ✅ Setup completed successfully!
) else (
    echo ⚠️  Setup script finished with warnings or errors.
)

echo.
echo 🎉 Development environment setup complete!
echo.
echo 💡 Next time you can run the bash script directly:
echo    Right-click in folder ^> "Git Bash Here" ^> ./quick_dev_setup.sh
echo.

pause