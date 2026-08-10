@echo off
cd /d "%~dp0"

rem Kill anything already bound to the dev ports first -- a leftover process
rem from a previous run holding 5173 or 8888 makes the new instance shift to
rem a different port silently, so the window stays open but localhost:8888
rem never responds.
for /f "tokens=5" %%p in ('netstat -ano ^| findstr :8888 ^| findstr LISTENING') do taskkill /F /PID %%p >nul 2>&1
for /f "tokens=5" %%p in ('netstat -ano ^| findstr :5173 ^| findstr LISTENING') do taskkill /F /PID %%p >nul 2>&1

rem Call netlify-cli directly (already installed globally) instead of "npx -y
rem netlify dev" -- npx re-checks the npm registry for the latest version on
rem every launch, and that network round-trip is what made the window sit
rem there "loading" with no output for a while.
where netlify >nul 2>&1
if errorlevel 1 (
    echo netlify-cli not found on PATH. Install it with: npm install -g netlify-cli
    pause
    exit /b 1
)

netlify dev
if errorlevel 1 (
    echo.
    echo netlify dev exited with an error ^(see above^).
    pause
)
