<script setup lang="ts">
import { ref, onMounted, onUnmounted, watch, computed } from 'vue';
import DraggableContainer from '@/components/layout/DraggableContainer.vue';
import DataTable from 'primevue/datatable';
import Column from 'primevue/column';
import Button from 'primevue/button';
import ProgressBar from 'primevue/progressbar';
import Dropdown from 'primevue/dropdown';

interface TrendData {
  symbol: string;
  currentPrice: number;
  priceChange24h: number;
  priceChangePercent24h: number;
  timeframe: '1m' | '1h';
  ema15: number;
  ema25: number;
  ema50: number;
  ema99: number;
  ema200: number;
  isUptrend: boolean;
  trendStrength: string;
  trendDirection: 'bullish' | 'bearish' | 'neutral';
  lastAnalyzed: string;
}

interface CoinData {
  symbol: string;
  oneMinTrend: TrendData;
  oneHourTrend: TrendData;
  lastAnalyzed: string;
}

// State variables
const allCoins = ref<string[]>([]);
const coinsData = ref<Map<string, CoinData>>(new Map());
const selectedCoin = ref<string>('');
const isAnalyzing = ref(false);
const analysisProgress = ref(0);
const currentAnalyzingCoin = ref('');
const totalCoinsToAnalyze = ref(0);
const processedCoins = ref(0);
const oneMinInterval = ref<number | null>(null);
const oneHourInterval = ref<number | null>(null);
const activeCoins = ref<Set<string>>(new Set()); // Track coins that need refreshing

// Store candle data to avoid fetching everything on each update
const storedCandles = ref<{
  oneMin: { [key: string]: any[] };
  oneHour: { [key: string]: any[] };
}>({
  oneMin: {},
  oneHour: {}
});

// Auto-refresh intervals (in milliseconds)
const ONE_MIN_REFRESH = 60 * 1000; // 1 minute
const ONE_HOUR_REFRESH = 60 * 60 * 1000; // 1 hour

// Computed properties
const selectedCoinData = computed(() => {
  if (!selectedCoin.value || !coinsData.value.has(selectedCoin.value)) {
    return null;
  }
  return coinsData.value.get(selectedCoin.value);
});

const coinOptions = computed(() => {
  return allCoins.value.map(coin => ({
    label: coin,
    value: coin
  }));
});

// Fetch all available trading pairs
async function fetchAllCoins() {
  try {
    console.log('Fetching all trading pairs from Binance...');
    const response = await fetch('https://api.binance.com/api/v3/exchangeInfo');
    const data = await response.json();
    
    const usdtPairs = data.symbols
      .filter((symbol: any) => 
        symbol.quoteAsset === 'USDT' && 
        symbol.status === 'TRADING' &&
        !symbol.symbol.includes('UP') &&
        !symbol.symbol.includes('DOWN') &&
        !symbol.symbol.includes('BULL') &&
        !symbol.symbol.includes('BEAR')
      )
      .map((symbol: any) => symbol.symbol)
      .sort();
    
    allCoins.value = usdtPairs;
    
    if (usdtPairs.length > 0 && usdtPairs.includes('ETHUSDT')) {
      selectedCoin.value = 'ETHUSDT';
    } else if (usdtPairs.length > 0) {
      selectedCoin.value = usdtPairs[0];
    }
    
    console.log(`Found ${usdtPairs.length} USDT trading pairs`);
    return usdtPairs;
  } catch (error) {
    console.error('Error fetching trading pairs:', error);
    return [];
  }
}

// Calculate EMA (Exponential Moving Average)
function calculateEMA(prices: number[], period: number): number[] {
  const ema: number[] = [];
  const multiplier = 2 / (period + 1);
  
  // Start with SMA for the first value
  let sum = 0;
  for (let i = 0; i < period && i < prices.length; i++) {
    sum += prices[i];
  }
  ema[period - 1] = sum / period;
  
  // Calculate EMA for the rest
  for (let i = period; i < prices.length; i++) {
    ema[i] = (prices[i] - ema[i - 1]) * multiplier + ema[i - 1];
  }
  
  return ema;
}

// Fetch latest candle for a specific timeframe
async function fetchLatestCandle(symbol: string, interval: '1m' | '1h'): Promise<any[]> {
  try {
    const response = await fetch(
      `https://api.binance.com/api/v3/klines?symbol=${symbol}&interval=${interval}&limit=1`
    );
    
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    
    const data = await response.json();
    return data;
  } catch (error) {
    console.error(`Error fetching latest ${interval} candle for ${symbol}:`, error);
    return [];
  }
}

// Update stored candles with new data
function updateStoredCandles(symbol: string, interval: '1m' | '1h', newCandle: any) {
  const store = interval === '1m' ? storedCandles.value.oneMin : storedCandles.value.oneHour;
  
  if (!store[symbol]) {
    store[symbol] = [];
  }
  
  // If we already have this candle (same timestamp), replace it
  const index = store[symbol].findIndex(candle => candle[0] === newCandle[0]);
  if (index !== -1) {
    store[symbol][index] = newCandle;
  } else {
    // Remove oldest candle if we have 200
    if (store[symbol].length >= 200) {
      store[symbol] = store[symbol].slice(1);
    }
    // Add the new candle
    store[symbol].push(newCandle);
  }
  
  // Sort candles by timestamp to ensure proper order
  store[symbol].sort((a, b) => a[0] - b[0]);
}

// Fetch candle data for a specific timeframe
async function fetchCandleData(symbol: string, interval: '1m' | '1h', limit: number = 200): Promise<any[]> {
  try {
    // If we already have stored candles, fetch only the latest one and update
    const store = interval === '1m' ? storedCandles.value.oneMin : storedCandles.value.oneHour;
    if (store[symbol] && store[symbol].length > 0) {
      console.log(`Fetching latest ${interval} candle for ${symbol}`);
      const latestCandle = await fetchLatestCandle(symbol, interval);
      if (latestCandle.length > 0) {
        // Check if this is actually a new candle by comparing timestamps
        const lastStoredTime = store[symbol][store[symbol].length - 1][0];
        const newCandleTime = latestCandle[0][0];
        
        if (newCandleTime > lastStoredTime) {
          // Update stored candles with the new one
          updateStoredCandles(symbol, interval, latestCandle[0]);
          console.log(`Updated ${interval} candle for ${symbol} - New timestamp: ${new Date(newCandleTime).toLocaleString()}`);
        } else {
          console.log(`No new ${interval} candle for ${symbol} - Latest: ${new Date(lastStoredTime).toLocaleString()}`);
        }
      }
      return store[symbol];
    }
    
    // If no stored candles, fetch all 200 candles
    console.log(`Fetching initial ${interval} candles for ${symbol}`);
    const response = await fetch(
      `https://api.binance.com/api/v3/klines?symbol=${symbol}&interval=${interval}&limit=${limit}`
    );
    
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    
    const data = await response.json();
    
    // Store the fetched candles
    if (interval === '1m') {
      storedCandles.value.oneMin[symbol] = data;
    } else {
      storedCandles.value.oneHour[symbol] = data;
    }
    
    return data;
  } catch (error) {
    console.error(`Error fetching ${interval} candle data for ${symbol}:`, error);
    return [];
  }
}

// Analyze trend for specific timeframe
async function analyzeTrendForTimeframe(
  symbol: string, 
  candleData: any[],
  timeframe: '1m' | '1h'
): Promise<TrendData> {
  const closes = candleData.map(candle => parseFloat(candle[4])); // Close prices
  const currentPrice = closes[closes.length - 1];
  
  // Calculate EMAs
  const ema15 = calculateEMA(closes, 15);
  const ema25 = calculateEMA(closes, 25);
  const ema50 = calculateEMA(closes, 50);
  const ema99 = calculateEMA(closes, 99);
  const ema200 = calculateEMA(closes, 200);
  
  // Get latest EMA values
  const latestEma15 = ema15[ema15.length - 1];
  const latestEma25 = ema25[ema25.length - 1];
  const latestEma50 = ema50[ema50.length - 1];
  const latestEma99 = ema99[ema99.length - 1];
  const latestEma200 = ema200[ema200.length - 1];
  
  // Check if price is above all EMAs and EMAs are properly aligned for uptrend
  const isUptrend = 
    currentPrice > latestEma15 &&
    latestEma15 > latestEma25 &&
    latestEma25 > latestEma50 &&
    latestEma50 > latestEma99 &&
    latestEma99 > latestEma200;
    
  // Check if price is below all EMAs and EMAs are properly aligned for downtrend
  const isDowntrend = 
    currentPrice < latestEma15 &&
    latestEma15 < latestEma25 &&
    latestEma25 < latestEma50 &&
    latestEma50 < latestEma99 &&
    latestEma99 < latestEma200;
  
  // Determine trend direction based on EMA alignments
  let trendDirection: 'bullish' | 'bearish' | 'neutral' = 'neutral';
  let trendStrength = 'Weak';
  
  if (isUptrend) {
    trendDirection = 'bullish';
    trendStrength = 'Strong';
  } else if (isDowntrend) {
    trendDirection = 'bearish';
    trendStrength = 'Strong';
  }
  
  // Calculate 24h price change
  const currentCandle = candleData[candleData.length - 1];
  const prevDayCandle = candleData[candleData.length - 24];
  const priceChange24h = currentPrice - parseFloat(prevDayCandle[4]);
  const priceChangePercent24h = (priceChange24h / parseFloat(prevDayCandle[4])) * 100;
  
  return {
    symbol,
    currentPrice,
    priceChange24h,
    priceChangePercent24h,
    timeframe,
    ema15: latestEma15,
    ema25: latestEma25,
    ema50: latestEma50,
    ema99: latestEma99,
    ema200: latestEma200,
    isUptrend,
    trendStrength,
    trendDirection,
    lastAnalyzed: new Date().toLocaleString()
  };
}

// Analyze trend for a single coin
async function analyzeCoin(symbol: string): Promise<CoinData> {
  currentAnalyzingCoin.value = symbol;
  
  // Fetch data for both timeframes
  const [oneMinData, oneHourData] = await Promise.all([
    fetchCandleData(symbol, '1m', 200),
    fetchCandleData(symbol, '1h', 200)
  ]);
  
  // Analyze trends for both timeframes
  const [oneMinTrend, oneHourTrend] = await Promise.all([
    analyzeTrendForTimeframe(symbol, oneMinData, '1m'),
    analyzeTrendForTimeframe(symbol, oneHourData, '1h')
  ]);
  
  return {
    symbol,
    oneMinTrend,
    oneHourTrend,
    lastAnalyzed: new Date().toLocaleString()
  };
}

// Analyze selected coin only
async function analyzeSelectedCoin() {
  if (!selectedCoin.value) return;
  
  isAnalyzing.value = true;
  try {
    const coinData = await analyzeCoin(selectedCoin.value);
    coinsData.value.set(selectedCoin.value, coinData);
    activeCoins.value.add(selectedCoin.value); // Add to active coins for refreshing
    startPolling(); // Start polling for the selected coin
    console.log(`Analysis completed for ${selectedCoin.value}`);
  } catch (error) {
    console.error(`Error analyzing ${selectedCoin.value}:`, error);
  } finally {
    isAnalyzing.value = false;
  }
}

// Analyze all coins
async function analyzeAllCoins() {
  if (allCoins.value.length === 0) {
    await fetchAllCoins();
  }
  
  // Stop any existing polling before starting analysis
  stopPolling();
  
  isAnalyzing.value = true;
  analysisProgress.value = 0;
  processedCoins.value = 0;
  totalCoinsToAnalyze.value = allCoins.value.length;
  coinsData.value.clear();
  activeCoins.value.clear(); // Clear active coins before analysis
  
  try {
    const batchSize = 5;
    
    for (let i = 0; i < allCoins.value.length; i += batchSize) {
      const batch = allCoins.value.slice(i, i + batchSize);
      
      for (const symbol of batch) {
        try {
          const coinData = await analyzeCoin(symbol);
          coinsData.value.set(symbol, coinData);
          activeCoins.value.add(symbol); // Add to active coins for refreshing
          
          processedCoins.value++;
          analysisProgress.value = (processedCoins.value / totalCoinsToAnalyze.value) * 100;
          
          await new Promise(resolve => setTimeout(resolve, 50));
        } catch (error) {
          console.error(`Failed to analyze ${symbol}:`, error);
          processedCoins.value++;
          analysisProgress.value = (processedCoins.value / totalCoinsToAnalyze.value) * 100;
        }
      }
      
      await new Promise(resolve => setTimeout(resolve, 200));
    }
    
    console.log(`Analysis completed. Monitoring ${activeCoins.value.size} coins for updates.`);
  } catch (error) {
    console.error('Error during analysis:', error);
  } finally {
    isAnalyzing.value = false;
    currentAnalyzingCoin.value = '';
    
    // Make sure polling starts even if no coin is selected
    if (activeCoins.value.size > 0) {
      console.log('Starting polling for all analyzed coins...');
      startPolling();
    }
  }
}

// Clear all data
function clearAllData() {
  coinsData.value.clear();
  processedCoins.value = 0;
  analysisProgress.value = 0;
  storedCandles.value = { oneMin: {}, oneHour: {} }; // Clear stored candles
  activeCoins.value.clear(); // Clear active coins
  stopPolling(); // Stop polling since we cleared everything
  
  // If a coin is selected, re-add it to active coins
  if (selectedCoin.value) {
    activeCoins.value.add(selectedCoin.value);
    startPolling();
  }
}

// Calculate time until next candle close
function getTimeUntilNextClose(interval: '1m' | '1h'): number {
  const now = new Date();
  let nextClose: Date;
  
  if (interval === '1m') {
    // For 1-minute candles, next close is at the start of next minute
    nextClose = new Date(now);
    nextClose.setSeconds(0, 0); // Reset seconds and milliseconds
    nextClose.setMinutes(nextClose.getMinutes() + 1); // Move to next minute
  } else {
    // For 1-hour candles, next close is at the start of next hour
    nextClose = new Date(now);
    nextClose.setMinutes(0, 0, 0); // Reset minutes, seconds and milliseconds
    nextClose.setHours(nextClose.getHours() + 1); // Move to next hour
  }
  
  // Return milliseconds until next close
  return nextClose.getTime() - now.getTime();
}

// Schedule next update at candle close
function scheduleNextUpdate(interval: '1m' | '1h') {
  const timeUntilClose = getTimeUntilNextClose(interval);
  console.log(`Next ${interval} update scheduled in ${Math.round(timeUntilClose/1000)} seconds`);
  
  const updateFunction = async () => {
    if (!isAnalyzing.value && activeCoins.value.size > 0) {
      const now = new Date().toLocaleString();
      console.log(`[${now}] Refreshing ${interval} data for ${activeCoins.value.size} coins at candle close`);
      
      // Process coins in smaller batches to avoid overwhelming the API
      const batchSize = 10;
      const coins = Array.from(activeCoins.value);
      
      for (let i = 0; i < coins.length; i += batchSize) {
        const batch = coins.slice(i, i + batchSize);
        console.log(`Processing batch ${Math.floor(i/batchSize) + 1}/${Math.ceil(coins.length/batchSize)} for ${interval} update`);
        
        // Process each batch in parallel
        await Promise.all(batch.map(async (symbol) => {
          try {
            // This will now only fetch the latest candle and update stored data
            const allCandles = await fetchCandleData(symbol, interval);
            if (allCandles.length > 0) {
              const trend = await analyzeTrendForTimeframe(symbol, allCandles, interval);
              
              // Update the appropriate trend data
              const existingData = coinsData.value.get(symbol);
              if (existingData) {
                coinsData.value.set(symbol, {
                  ...existingData,
                  [interval === '1m' ? 'oneMinTrend' : 'oneHourTrend']: trend,
                  lastAnalyzed: new Date().toLocaleString()
                });
              }
            }
          } catch (error) {
            console.error(`Error updating ${interval} data for ${symbol}:`, error);
          }
        }));
        
        // Add a small delay between batches
        if (i + batchSize < coins.length) {
          await new Promise(resolve => setTimeout(resolve, 100));
        }
      }
    } else {
      console.log(`Skipping ${interval} update - ${isAnalyzing.value ? 'Analysis in progress' : 'No active coins'}`);
    }
    
    // Schedule next update
    const nextUpdateTime = getTimeUntilNextClose(interval);
    console.log(`Scheduling next ${interval} update in ${Math.round(nextUpdateTime/1000)} seconds`);
    
    if (interval === '1m') {
      oneMinInterval.value = window.setTimeout(updateFunction, nextUpdateTime + 500);
    } else {
      oneHourInterval.value = window.setTimeout(updateFunction, nextUpdateTime + 1000);
    }
  };
  
  // Start the first update
  if (interval === '1m') {
    oneMinInterval.value = window.setTimeout(updateFunction, timeUntilClose + 500);
  } else {
    oneHourInterval.value = window.setTimeout(updateFunction, timeUntilClose + 1000);
  }
}

// Start polling for updates
function startPolling() {
  console.log(`Starting polling for ${activeCoins.value.size} coins...`);
  
  // Clear any existing intervals
  stopPolling();
  
  // Schedule initial updates for both timeframes
  scheduleNextUpdate('1m');
  scheduleNextUpdate('1h');
  
  console.log('Polling scheduled to sync with candle closes');
}

// Stop polling
function stopPolling() {
  if (oneMinInterval.value) {
    console.log('Stopping 1m polling interval');
    clearTimeout(oneMinInterval.value);
    oneMinInterval.value = null;
  }
  if (oneHourInterval.value) {
    console.log('Stopping 1h polling interval');
    clearTimeout(oneHourInterval.value);
    oneHourInterval.value = null;
  }
}

// Watch for changes in selected coin
watch(selectedCoin, (newValue) => {
  if (newValue) {
    // Only add new coin to active coins if it's not already being tracked
    if (!activeCoins.value.has(newValue)) {
      activeCoins.value.add(newValue);
    }
    
    // Start polling if not already running
    if (!oneMinInterval.value || !oneHourInterval.value) {
      startPolling();
    }
  } else {
    // Only stop polling if we're not monitoring multiple coins
    if (activeCoins.value.size <= 1) {
      stopPolling();
      activeCoins.value.clear();
    }
  }
});

// Lifecycle
onMounted(() => {
  fetchAllCoins();
});

// Clean up intervals when component is unmounted
onUnmounted(() => {
  stopPolling();
});
</script>

<template>
  <div class="container-fluid p-4">
    <h1 class="mb-4">Trend Analysis - Market Scanner</h1>
    
    <div class="w-full mb-6">
      <DraggableContainer>
        <template #header>
          <span>📈 Trend Scanner</span>
        </template>
        
        <div class="p-3">
          <!-- Controls Row 1 -->
          <div class="mb-3 d-flex flex-wrap align-items-center gap-3">
            <div class="d-flex align-items-center">
              <label class="form-label me-2 mb-0">Select Coin:</label>
              <Dropdown
                v-model="selectedCoin"
                :options="coinOptions"
                optionLabel="label"
                optionValue="value"
                :loading="allCoins.length === 0"
                class="w-64"
                placeholder="Select a coin"
                :filter="true"
                filterPlaceholder="Search coin..."
                filterBy="label,value"
                :showClear="true"
              />
            </div>
          </div>
          
          <!-- Controls Row 2 -->
          <div class="mb-3 d-flex flex-wrap align-items-center gap-2">
            <Button 
              @click="fetchAllCoins"
              :loading="isAnalyzing"
              icon="pi pi-download"
              label="Fetch Coin List"
              class="p-button-sm p-button-secondary"
            />
            
            <Button 
              @click="analyzeSelectedCoin"
              :loading="isAnalyzing"
              icon="pi pi-search"
              label="Analyze Selected"
              class="p-button-sm p-button-primary"
            />
            
            <Button 
              @click="analyzeAllCoins"
              :loading="isAnalyzing"
              icon="pi pi-server"
              label="Analyze All"
              class="p-button-sm p-button-success"
            />
            
            <Button 
              @click="clearAllData"
              :loading="isAnalyzing"
              icon="pi pi-trash"
              label="Clear Data"
              class="p-button-sm p-button-danger"
            />
          </div>
          
          <!-- Progress and Status -->
          <div v-if="isAnalyzing" class="mb-3">
            <ProgressBar :value="analysisProgress" />
            <small class="text-muted">
              Analyzing {{ currentAnalyzingCoin }} ({{ processedCoins }}/{{ totalCoinsToAnalyze }})
            </small>
          </div>
          
          <!-- Results Table -->
          <DataTable
            :value="Array.from(coinsData.values())"
            :paginator="true"
            :rows="10"
            :rowsPerPageOptions="[10, 25, 50]"
            class="p-datatable-sm"
          >
            <Column field="symbol" header="Symbol" sortable>
              <template #body="{ data }">
                <span class="font-mono font-semibold">{{ data.symbol }}</span>
              </template>
            </Column>

            <Column field="oneMinTrend.currentPrice" header="Price" sortable>
              <template #body="{ data }">
                <span class="font-semibold">{{ data.oneMinTrend.currentPrice.toFixed(8) }}</span>
              </template>
            </Column>

            <Column field="oneMinTrend.priceChangePercent24h" header="24h Change % (1m)" sortable>
              <template #body="{ data }">
                <span :class="{
                  'px-2 py-1 rounded font-medium': true,
                  'bg-green-100 text-green-800': data.oneMinTrend.priceChangePercent24h > 0,
                  'bg-red-100 text-red-800': data.oneMinTrend.priceChangePercent24h < 0,
                  'bg-gray-100 text-gray-600': data.oneMinTrend.priceChangePercent24h === 0
                }">
                  {{ data.oneMinTrend.priceChangePercent24h > 0 ? '+' : '' }}{{ data.oneMinTrend.priceChangePercent24h.toFixed(2) }}%
                </span>
              </template>
            </Column>

            <Column field="oneMinTrend.trendDirection" header="Trend (1m)" sortable>
              <template #body="{ data }">
                <span :class="{
                  'px-2 py-1 rounded font-semibold': true,
                  'bg-green-500 text-white': data.oneMinTrend.trendDirection === 'bullish',
                  'bg-red-500 text-white': data.oneMinTrend.trendDirection === 'bearish',
                  'bg-gray-200 text-gray-700': data.oneMinTrend.trendDirection === 'neutral'
                }">
                  {{ data.oneMinTrend.trendDirection.toUpperCase() }}
                  {{ data.oneMinTrend.trendDirection === 'bullish' ? '⬆' : data.oneMinTrend.trendDirection === 'bearish' ? '⬇' : '➡' }}
                </span>
              </template>
            </Column>

            <Column field="oneMinTrend.trendStrength" header="Strength (1m)" sortable>
              <template #body="{ data }">
                <span :class="{
                  'px-2 py-1 rounded font-medium': true,
                  'bg-emerald-100 text-emerald-800': data.oneMinTrend.trendStrength === 'Strong',
                  'bg-gray-100 text-gray-600': data.oneMinTrend.trendStrength === 'Weak'
                }">
                  {{ data.oneMinTrend.trendStrength }}
                  {{ data.oneMinTrend.trendStrength === 'Strong' ? '💪' : '⚡' }}
                </span>
              </template>
            </Column>

            <Column field="oneHourTrend.priceChangePercent24h" header="24h Change % (1h)" sortable>
              <template #body="{ data }">
                <span :class="{
                  'px-2 py-1 rounded font-medium': true,
                  'bg-green-100 text-green-800': data.oneHourTrend.priceChangePercent24h > 0,
                  'bg-red-100 text-red-800': data.oneHourTrend.priceChangePercent24h < 0,
                  'bg-gray-100 text-gray-600': data.oneHourTrend.priceChangePercent24h === 0
                }">
                  {{ data.oneHourTrend.priceChangePercent24h > 0 ? '+' : '' }}{{ data.oneHourTrend.priceChangePercent24h.toFixed(2) }}%
                </span>
              </template>
            </Column>

            <Column field="oneHourTrend.trendDirection" header="Trend (1h)" sortable>
              <template #body="{ data }">
                <span :class="{
                  'px-2 py-1 rounded font-semibold': true,
                  'bg-green-500 text-white': data.oneHourTrend.trendDirection === 'bullish',
                  'bg-red-500 text-white': data.oneHourTrend.trendDirection === 'bearish',
                  'bg-gray-200 text-gray-700': data.oneHourTrend.trendDirection === 'neutral'
                }">
                  {{ data.oneHourTrend.trendDirection.toUpperCase() }}
                  {{ data.oneHourTrend.trendDirection === 'bullish' ? '⬆' : data.oneHourTrend.trendDirection === 'bearish' ? '⬇' : '➡' }}
                </span>
              </template>
            </Column>

            <Column field="oneHourTrend.trendStrength" header="Strength (1h)" sortable>
              <template #body="{ data }">
                <span :class="{
                  'px-2 py-1 rounded font-medium': true,
                  'bg-emerald-100 text-emerald-800': data.oneHourTrend.trendStrength === 'Strong',
                  'bg-gray-100 text-gray-600': data.oneHourTrend.trendStrength === 'Weak'
                }">
                  {{ data.oneHourTrend.trendStrength }}
                  {{ data.oneHourTrend.trendStrength === 'Strong' ? '💪' : '⚡' }}
                </span>
              </template>
            </Column>

            <Column field="lastAnalyzed" header="Last Updated" sortable>
              <template #body="{ data }">
                <span class="text-gray-600 text-sm">{{ data.lastAnalyzed }}</span>
              </template>
            </Column>
          </DataTable>
        </div>
      </DraggableContainer>
    </div>
  </div>
</template>

<style scoped>
/* Base styles */
.container-fluid {
  max-width: 1800px;
  margin: 0 auto;
  padding: 0 1rem;
}

h1 {
  font-size: 1.5rem;
  font-weight: 600;
  color: #333;
  margin-bottom: 1rem;
}

.mb-4 {
  margin-bottom: 1.5rem !important;
}

.mb-3 {
  margin-bottom: 1rem !important;
}

.p-button-sm {
  padding: 0.5rem 1rem;
  font-size: 0.875rem;
  border-radius: 0.375rem;
  transition: background-color 0.3s, transform 0.3s;
}

.p-button-secondary {
  background-color: #4b5563;
  color: #fff;
}

.p-button-primary {
  background-color: #3b82f6;
  color: #fff;
}

.p-button-success {
  background-color: #10b981;
  color: #fff;
}

.p-button-danger {
  background-color: #ef4444;
  color: #fff;
}

.p-button-sm:hover {
  transform: translateY(-2px);
}

.p-button-sm:active {
  transform: translateY(0);
}

/* Draggable container */
.draggable-container {
  background-color: #fff;
  border-radius: 0.375rem;
  box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
  padding: 1.5rem;
}

/* Dropdown */
.p-dropdown {
  width: 100%;
}

/* Data table */
.p-datatable-sm {
  font-size: 0.875rem;
  width: 100%;
  min-width: 1400px;
}

.p-datatable-thead {
  background-color: #f9fafb;
}

.p-datatable-thead th {
  padding: 0.75rem 1rem !important;
  white-space: nowrap;
}

.p-datatable-tbody {
  background-color: #fff;
}

.p-datatable-tbody td {
  padding: 0.75rem 1rem !important;
}

.p-datatable-tbody tr:hover {
  background-color: #f1f5f9;
}

/* Add horizontal scroll for smaller screens */
.p-datatable-wrapper {
  overflow-x: auto;
  padding-bottom: 0.5rem;
}

/* Ensure consistent column widths */
.p-column-title {
  white-space: nowrap;
}

/* Progress bar */
.p-progressbar {
  height: 0.5rem;
  border-radius: 0.375rem;
}

.p-progressbar .p-progressbar-value {
  border-radius: 0.375rem;
}

/* Responsive adjustments */
@media (max-width: 768px) {
  .container-fluid {
    padding: 0 0.5rem;
  }
  
  h1 {
    font-size: 1.25rem;
  }
  
  .p-button-sm {
    width: 100%;
    margin-bottom: 0.5rem;
  }
}
</style>
