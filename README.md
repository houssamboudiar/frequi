# Houssam's Personal FreqUI

This is my personal fork and customization of FreqUI - the web interface for Freqtrade. This repository contains my custom UI modifications, themes, and enhancements for my personal trading bot dashboard.

## About This Fork

This repository is based on [FreqUI](https://github.com/freqtrade/frequi) - the official web UI for Freqtrade. I've customized it with:

- 🎨 **Custom Themes**: Personalized color schemes and layouts
- 📊 **Enhanced Charts**: Custom indicators and EMA visualizations
- ⚡ **Performance Tweaks**: Optimized for my trading workflow
- 🔧 **Custom Components**: Additional UI elements for my specific needs

Built with [Vue.js](https://vuejs.org/) and [PrimeVue](https://primevue.org/).

## Integration with My Freqtrade Bot

This UI connects to my personalized Freqtrade bot: [houssamboudiar/freqtrade](https://github.com/houssamboudiar/freqtrade)

## 🚀 Quick Start

### Prerequisites
- [Node.js](https://nodejs.org/) (v16 or higher)
- [PNPM](https://pnpm.io/) package manager
- My personalized [Freqtrade bot](https://github.com/houssamboudiar/freqtrade) running with API enabled

### Setup & Run

1. **Clone this repository**:
   ```bash
   git clone https://github.com/houssamboudiar/frequi.git
   cd frequi
   ```

2. **Install dependencies**:
   ```bash
   pnpm install
   ```

3. **Start development server**:
   ```bash
   pnpm run dev
   ```

4. **Access the UI**: Open http://localhost:3000

### Docker Setup

```bash
docker compose up -d
# Access using http://localhost:3000/
```

## 🎨 My Customizations

- **EMA Indicators**: Custom EMA visualization that integrates with my Redis-based EMA scripts
- **Personal Dashboard**: Tailored layout for my trading strategy monitoring
- **Custom Alerts**: Enhanced notification system for my trading signals
- **Performance Metrics**: Additional charts for my specific trading analytics

## ⚙️ Configuration

Make sure your Freqtrade bot (from my personal repository) has CORS configured for:
- `http://localhost:3000` (development)
- `http://127.0.0.1:3000` (alternative)

Add this to your `user_data/config.json`:
```json
{
  "api_server": {
    "enabled": true,
    "listen_ip_address": "0.0.0.0",
    "listen_port": 8080,
    "CORS_origins": ["http://localhost:3000", "http://127.0.0.1:3000"]
  }
}
```
## 🛠️ Development Commands

### Build for production
```bash
pnpm run build
```

### Lint and fix files
```bash
pnpm run lint
```

### Build and run docker version
```bash
docker-compose build
docker-compose up -d
```

## 📖 Original FreqUI Information

This fork is based on FreqUI - the official web interface for Freqtrade. For original documentation and community support:
- 📖 [Original FreqUI Repository](https://github.com/freqtrade/frequi)
- 🤖 [Freqtrade Documentation](https://www.freqtrade.io)
- 💬 [Discord Community](https://discord.gg/freqtrade)

## 🔗 Related Repositories

- 🤖 [My Personal Freqtrade Bot](https://github.com/houssamboudiar/freqtrade) - The backend trading bot
- 📊 Custom EMA scripts integration
- ⚙️ Personalized trading strategies

---

*This is a personal fork of [FreqUI](https://github.com/freqtrade/frequi) customized by Houssam Boudiar for personal trading dashboard needs.*
