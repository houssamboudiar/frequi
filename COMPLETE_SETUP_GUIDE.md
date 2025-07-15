# 🚀 Complete Setup Guide - Houssam's Personal Trading Ecosystem

This guide will help you get both your Freqtrade bot and FreqUI dashboard running together.

## 📋 Prerequisites Check

✅ **Docker**: Installed and running  
✅ **Node.js**: v16+ installed  
✅ **PNPM**: Package manager installed  

## 🐳 Step 1: Start Freqtrade Bot (Backend)

1. **Navigate to Freqtrade directory**:
   ```cmd
   cd C:\Users\houss\freqtrade
   ```

2. **Add your API keys** (IMPORTANT):
   - Edit `.env` file
   - Replace `your_binance_api_key_here` with your actual Binance API key
   - Replace `your_binance_secret_key_here` with your actual Binance secret key

3. **Start the trading bot**:
   ```cmd
   freqtrade_manager.bat start
   ```

## 🎨 Step 2: Start FreqUI Dashboard (Frontend)

1. **Navigate to FreqUI directory**:
   ```cmd
   cd C:\Users\houss\frequi
   ```

2. **Start FreqUI dashboard**:
   ```cmd
   start_frequi.bat
   ```

3. **Access your dashboard**: http://localhost:3000

## 🎯 Your Personal Trading URLs

- **FreqUI Dashboard**: http://localhost:3000
- **Freqtrade API**: http://localhost:8080
- **Redis Database**: localhost:6379

---

*Your personal trading ecosystem is now ready!*
