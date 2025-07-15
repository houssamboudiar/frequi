@echo off
REM Personal FreqUI Setup Script for Windows
REM Author: Houssam Boudiar

echo 🎨 Setting up Houssam's Personal FreqUI Dashboard...

REM Check if Node.js is installed
node --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Node.js is not installed. Please install Node.js 16+ first.
    echo    Download from: https://nodejs.org/
    pause
    exit /b 1
)

REM Check if PNPM is installed
pnpm --version >nul 2>&1
if errorlevel 1 (
    echo 📦 Installing PNPM package manager...
    npm install -g pnpm
)

echo 📦 Installing dependencies...
pnpm install

echo 🔧 Setting up development environment...

REM Create personal config template if it doesn't exist
if not exist "config.personal.json" (
    echo ⚙️ Creating personal configuration template...
    (
        echo {
        echo   "freqtradeApiUrl": "http://localhost:8080",
        echo   "theme": "dark",
        echo   "personalSettings": {
        echo     "defaultPair": "ETH/USDT",
        echo     "refreshInterval": 5000,
        echo     "enableCustomEmaCharts": true
        echo   }
        echo }
    ) > config.personal.json
    echo ✅ Personal config template created!
) else (
    echo ✅ Personal configuration already exists.
)

echo 🚀 Ready to start development!
echo.
echo 📖 Next steps:
echo    1. Make sure your Freqtrade bot is running on localhost:8080
echo    2. Run: pnpm run dev
echo    3. Access FreqUI at: http://localhost:3000
echo    4. Customize config.personal.json for your preferences
echo.
echo 🔧 Development commands:
echo    - Start dev server: pnpm run dev
echo    - Build for production: pnpm run build
echo    - Run tests: pnpm run test
echo    - Lint code: pnpm run lint
echo.
pause
