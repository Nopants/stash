@echo off
setlocal

:: ============================================================
:: Stash Full Build
:: Builds the complete stash.exe from source (frontend + backend).
:: Run from the repo root (the directory containing the Makefile).
:: ============================================================

echo.
echo === Stash Full Build ===
echo.

:: Check we're in the right directory
if not exist "Makefile" (
    echo ERROR: Makefile not found in current directory.
    echo Run this script from the stash repo root.
    pause
    exit /b 1
)

:: Check tools
where mingw32-make >nul 2>&1 || (echo ERROR: mingw32-make not found. Run setup-toolchain.bat first. & pause & exit /b 1)
where go >nul 2>&1 || (echo ERROR: go not found. Run setup-toolchain.bat first. & pause & exit /b 1)
where gcc >nul 2>&1 || (echo ERROR: gcc not found. Run setup-toolchain.bat first. & pause & exit /b 1)

:: Step 1: Install frontend dependencies
echo [1/4] Installing frontend dependencies (pnpm install)...
mingw32-make pre-ui
if %errorlevel% neq 0 (
    echo ERROR: pnpm install failed.
    pause
    exit /b 1
)

:: Step 2: Generate GraphQL code
echo.
echo [2/4] Running GraphQL code generation...
mingw32-make generate
if %errorlevel% neq 0 (
    echo ERROR: Code generation failed.
    pause
    exit /b 1
)

:: Step 3: Build frontend
echo.
echo [3/4] Building frontend (Vite)...
mingw32-make ui
if %errorlevel% neq 0 (
    echo ERROR: Frontend build failed.
    pause
    exit /b 1
)

:: Step 4: Build Go binary
echo.
echo [4/4] Building Go binary...
mingw32-make build
if %errorlevel% neq 0 (
    echo ERROR: Go build failed.
    pause
    exit /b 1
)

echo.
echo === Build complete ===
echo.

:: Find the output binary
if exist "stash.exe" (
    echo Binary: %cd%\stash.exe
    for %%A in (stash.exe) do echo Size:   %%~zA bytes
) else (
    echo Binary built successfully. Check the repo root for the output file.
)

echo.
pause
