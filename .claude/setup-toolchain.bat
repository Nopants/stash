@echo off
setlocal

:: ============================================================
:: Stash Build Toolchain Setup
:: Installs Go, MinGW64 (GCC + mingw32-make), and activates pnpm.
:: Run as Administrator.
:: ============================================================

echo.
echo === Stash Toolchain Setup ===
echo.

:: Check admin privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: This script must be run as Administrator.
    echo Right-click and select "Run as administrator".
    pause
    exit /b 1
)

:: --- Go ---
echo [1/4] Installing Go...
where go >nul 2>&1
if %errorlevel% equ 0 (
    echo       Go is already installed:
    go version
) else (
    winget install GoLang.Go --accept-source-agreements --accept-package-agreements
    if %errorlevel% neq 0 (
        echo ERROR: Go installation failed.
        pause
        exit /b 1
    )
    echo       Go installed successfully.
)

:: --- MinGW64 ---
echo.
echo [2/4] Installing MinGW64 (GCC + mingw32-make)...
where gcc >nul 2>&1
if %errorlevel% equ 0 (
    echo       MinGW64 is already installed:
    gcc --version 2>&1 | findstr /i "gcc"
) else (
    choco install mingw -y
    if %errorlevel% neq 0 (
        echo ERROR: MinGW64 installation failed.
        echo Make sure Chocolatey is installed: https://chocolatey.org/install
        pause
        exit /b 1
    )
    echo       MinGW64 installed successfully.
)

:: --- pnpm via corepack ---
echo.
echo [3/4] Activating pnpm via corepack...
where corepack >nul 2>&1
if %errorlevel% equ 0 (
    corepack enable
    echo       pnpm activated via corepack.
) else (
    echo ERROR: corepack not found. Is Node.js installed?
    echo Install Node.js first: winget install OpenJS.NodeJS.LTS
    pause
    exit /b 1
)

:: --- Verify ---
echo.
echo [4/4] Verifying installation...
echo.

echo Checking Go...
where go >nul 2>&1 && (go version) || echo       NOT FOUND - restart terminal and retry

echo Checking GCC...
where gcc >nul 2>&1 && (gcc --version 2>&1 | findstr /i "gcc") || echo       NOT FOUND - restart terminal and retry

echo Checking mingw32-make...
where mingw32-make >nul 2>&1 && (mingw32-make --version 2>&1 | findstr /i "Make") || echo       NOT FOUND - restart terminal and retry

echo Checking pnpm...
where pnpm >nul 2>&1 && (pnpm --version) || echo       NOT FOUND - restart terminal and retry

echo.
echo === Setup complete ===
echo If any tool shows "NOT FOUND", close this terminal, open a new one, and run
echo the verify commands again. PATH changes require a terminal restart.
echo.
pause
