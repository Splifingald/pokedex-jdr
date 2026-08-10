@echo off
cd /d "%~dp0"
echo Working directory: %cd%

rem Kill anything already bound to the dev ports first -- a leftover process
rem from a previous run holding 5173 or 8888 makes the new instance shift to
rem a different port silently, so the window stays open but localhost:8888
rem never responds.
echo Checking for processes already using ports 5173/8888...
for /f "tokens=5" %%p in ('netstat -ano ^| findstr :8888 ^| findstr LISTENING') do (
    echo   killing PID %%p on port 8888
    taskkill /F /PID %%p
)
for /f "tokens=5" %%p in ('netstat -ano ^| findstr :5173 ^| findstr LISTENING') do (
    echo   killing PID %%p on port 5173
    taskkill /F /PID %%p
)

rem Call netlify-cli directly (already installed globally) instead of "npx -y
rem netlify dev" -- npx re-checks the npm registry for the latest version on
rem every launch, and that network round-trip is what made the window sit
rem there "loading" with no output for a while.
echo Looking for netlify-cli on PATH...
where netlify
if errorlevel 1 (
    echo netlify-cli not found on PATH. Install it with: npm install -g netlify-cli
    goto end
)

echo Starting netlify dev...
call netlify dev
echo netlify dev exited with code %errorlevel%

:end
echo.
echo Press any key to close this window...
pause >nul
