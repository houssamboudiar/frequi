#!/bin/bash
# Personal FreqUI Setup Script
# Author: Houssam Boudiar

echo "🎨 Setting up Houssam's Personal FreqUI Dashboard..."

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js 16+ first."
    echo "   Download from: https://nodejs.org/"
    exit 1
fi

# Check Node.js version
NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 16 ]; then
    echo "❌ Node.js version 16 or higher is required. Current version: $(node -v)"
    exit 1
fi

# Check if PNPM is installed
if ! command -v pnpm &> /dev/null; then
    echo "📦 Installing PNPM package manager..."
    npm install -g pnpm
fi

echo "📦 Installing dependencies..."
pnpm install

echo "🔧 Setting up development environment..."

# Create personal config template if it doesn't exist
if [ ! -f "config.personal.json" ]; then
    echo "⚙️  Creating personal configuration template..."
    cat > config.personal.json << EOL
{
  "freqtradeApiUrl": "http://localhost:8080",
  "theme": "dark",
  "personalSettings": {
    "defaultPair": "ETH/USDT",
    "refreshInterval": 5000,
    "enableCustomEmaCharts": true
  }
}
EOL
    echo "✅ Personal config template created!"
else
    echo "✅ Personal configuration already exists."
fi

echo "🚀 Starting development server..."
echo ""
echo "📖 Next steps:"
echo "   1. Make sure your Freqtrade bot is running on localhost:8080"
echo "   2. Access FreqUI at: http://localhost:3000"
echo "   3. Customize config.personal.json for your preferences"
echo ""
echo "🔧 Development commands:"
echo "   - Start dev server: pnpm run dev"
echo "   - Build for production: pnpm run build"
echo "   - Run tests: pnpm run test"
echo "   - Lint code: pnpm run lint"

# Start the development server
pnpm run dev
