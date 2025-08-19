@echo off
setlocal

REM ===============================================
REM Flutter Development Environment Setup Launcher
REM ===============================================
REM This script bypasses PowerShell execution policy
REM and provides a clean one-click setup experience
REM ===============================================

title Flutter Dev Environment Setup

echo.
echo  ====================================================
echo  ==                                                ==
echo  ==   Flutter Development Environment Setup       ==
echo  ==                                                ==
echo  ====================================================
echo.

REM Get the directory where this batch file is located
set "SCRIPT_DIR=%~dp0"

REM Check if the PowerShell script exists
if not exist "%SCRIPT_DIR%setup-windows.ps1" (
    echo [ERROR] setup-windows.ps1 not found!
    echo.
    echo Expected location: %SCRIPT_DIR%setup-windows.ps1
    echo.
    echo Please ensure both files are in the same directory.
    echo.
    pause
    exit /b 1
)

echo [INFO] Initializing setup...
echo.

REM Check PowerShell version
powershell -Command "if ($PSVersionTable.PSVersion.Major -lt 3) { exit 1 }" 2>nul
if %ERRORLEVEL% neq 0 (
    echo [ERROR] PowerShell 3.0 or higher is required.
    echo Please update PowerShell and try again.
    echo.
    pause
    exit /b 1
)

echo [SUCCESS] PowerShell version check passed
echo.

REM Show what we're about to do
echo [INFO] This setup will:
echo    - Install GitHub CLI if needed
echo    - Set up GitHub authentication
echo    - Configure Git credentials
echo    - Add private packages to your Flutter project
echo    - Run flutter pub get
echo.

set /p "confirm=Continue with setup? (Y/n): "
if /i "%confirm%"=="n" (
    echo Setup cancelled.
    pause
    exit /b 0
)

echo.
echo [INFO] Launching PowerShell setup...
echo ===============================================
echo.

REM Launch PowerShell with bypass policy
REM This allows the script to run without changing system-wide execution policy
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%setup-windows.ps1"

set "PS_EXIT_CODE=%ERRORLEVEL%"

echo.
echo ===============================================

if %PS_EXIT_CODE% equ 0 (
    echo [SUCCESS] Setup completed successfully!
    echo.
    echo [INFO] Your Flutter development environment is ready!
    echo.
    echo [NEXT STEPS] You can now:
    echo    - Clone your private repositories
    echo    - Build and run your Flutter projects
    echo    - Add more packages anytime by running this setup again
) else (
    echo [WARNING] Setup completed with warnings or errors.
    echo.
    echo [HELP] Check the output above for any issues.
    echo    You may need to run some steps manually.
)

echo.
echo [HELP] Need help? Check the setup-windows.ps1 file for details.
echo.
pause