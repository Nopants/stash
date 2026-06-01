@echo off
setlocal

:: ============================================================
:: Stash Development Mode
:: Starts the Go backend + Vite dev server with hot-reload.
:: Run from the repo root (the directory containing the Makefile).
::
:: - Backend runs on http://localhost:9999
:: - Frontend runs on http://localhost:3000 (open this in browser)
:: - Edit files in ui/v2.5/src/ and the browser refreshes automatically
::
:: Press Ctrl+C to stop the Vite dev server.
:: Close the "Stash Backend" window to stop the backend.
:: ============================================================

echo.
echo === Stash Dev Mode ===
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

:: Step 1: Install dependencies and generate code (one-time)
echo [1/3] Installing dependencies and generating code...
mingw32-make pre-ui
if %errorlevel% neq 0 (
    echo ERROR: pnpm install failed.
    pause
    exit /b 1
)

mingw32-make generate
if %errorlevel% neq 0 (
    echo ERROR: Code generation failed.
    pause
    exit /b 1
)

:: Step 2: Start backend in a new window
echo.
echo [2/3] Starting Go backend on :9999...
start "Stash Backend" cmd /k "mingw32-make server-start"

:: Give the backend a moment to start
timeout /t 3 /nobreak >nul

:: Step 3: Start Vite dev server in this window
echo.
echo [3/3] Starting Vite dev server on :3000...
echo.
echo Open http://localhost:3000 in your browser.
echo Press Ctrl+C to stop.
echo.

mingw32-make ui-start
