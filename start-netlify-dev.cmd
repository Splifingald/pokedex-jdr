@echo off
cd /d "%~dp0"

rem Kill anything already bound to the dev ports first -- a leftover process
rem from a previous run holding 5173 or 8888 makes the new instance shift to
rem a different port silently, so the window stays open but localhost:8888
rem never responds.
for /f "tokens=5" %%p in ('netstat -ano ^| findstr :8888 ^| findstr LISTENING') do taskkill /F /PID %%p >nul 2>&1
for /f "tokens=5" %%p in ('netstat -ano ^| findstr :5173 ^| findstr LISTENING') do taskkill /F /PID %%p >nul 2>&1

npx -y netlify dev
