@echo off
REM Start Houssam's Personal FreqUI Dashboard
REM Author: Houssam Boudiar

echo 🎨 Starting Houssam's Personal FreqUI Dashboard...
echo.
echo 📡 Make sure your Freqtrade bot is running on localhost:8080
echo 🔗 FreqUI will be available at: http://localhost:3000
echo.

cd /d "%~dp0"
pnpm dev

pause
