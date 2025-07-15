@echo off
REM Check if Freqtrade API is accessible
REM Author: Houssam Boudiar

echo 🔍 Checking Freqtrade API connection...
echo.

REM Check if Freqtrade API is responding
curl -s http://localhost:8080/api/v1/ping > nul 2>&1
if %errorlevel%==0 (
    echo ✅ Freqtrade API is accessible at http://localhost:8080
    echo 🎯 You can now start FreqUI with: start_frequi.bat
) else (
    echo ❌ Freqtrade API is not accessible at http://localhost:8080
    echo.
    echo 💡 Solutions:
    echo    1. Make sure your Freqtrade Docker containers are running:
    echo       cd ..\freqtrade
    echo       freqtrade_manager.bat status
    echo.
    echo    2. If not running, start them:
    echo       cd ..\freqtrade
    echo       freqtrade_manager.bat start
    echo.
    echo    3. Check if API is enabled in your config.json
)

echo.
echo 🐳 Checking Docker containers...
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" --filter "name=houssam_freqtrade"

echo.
pause
