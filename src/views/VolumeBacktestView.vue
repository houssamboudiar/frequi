<script setup lang="ts">
import { ref, onMounted, watch, computed } from 'vue';
import DraggableContainer from '@/components/layout/DraggableContainer.vue';
import DataTable from 'primevue/datatable';
import Column from 'primevue/column';
import Button from 'primevue/button';
import ProgressBar from 'primevue/progressbar';
import Dropdown from 'primevue/dropdown';
import Calendar from 'primevue/calendar';
import InputNumber from 'primevue/inputnumber';

interface AnalysisResult {
  date: string;
  timestamp: number;
  symbol: string;
  currentVolume: number;
  previousVolume: number;
  volumeRatio: number;
  volumeIncrease: number;
  currentBuyingVolume: number;
  previousBuyingVolume: number;
  buyingVolumeRatio: number;
  buyingVolumeIncrease: number;
  currentSellingVolume: number;
  previousSellingVolume: number;
  sellingVolumeRatio: number;
  sellingVolumeIncrease: number;
  buyingPercentage: number;
  sellingPercentage: number;
  // Profile-specific data
  profileType: 'sudden-volume' | 'ema-analysis';
  profileData?: any; // Additional data specific to the profile
  minuteSpikes?: MinuteSpike[]; // Nested minute data
}

// Legacy alias for backward compatibility
interface VolumeSpike extends AnalysisResult {}

interface MinuteSpike {
  date: string;
  timestamp: number;
  currentVolume: number;
  previousVolume: number;
  volumeRatio: number;
  volumeIncrease: number;
  currentBuyingVolume: number;
  previousBuyingVolume: number;
  buyingVolumeRatio: number;
  buyingVolumeIncrease: number;
  currentSellingVolume: number;
  previousSellingVolume: number;
  sellingVolumeRatio: number;
  sellingVolumeIncrease: number;
  buyingPercentage: number;
  sellingPercentage: number;
  profileType: 'sudden-volume' | 'ema-analysis';
}

interface AnalysisProfile {
  id: string;
  name: string;
  description: string;
  icon: string;
  parameters: ProfileParameter[];
}

interface ProfileParameter {
  key: string;
  label: string;
  type: 'number' | 'select' | 'boolean';
  defaultValue: any;
  min?: number;
  max?: number;
  step?: number;
  suffix?: string;
  options?: { label: string; value: any }[];
}

interface EMAProfileData {
  ema7: number;
  ema25: number;
  ema50: number;
  ema99: number;
  ema200: number;
  priceAboveEMA7: boolean;
  priceAboveEMA25: boolean;
  priceAboveEMA50: boolean;
  priceAboveEMA99: boolean;
  priceAboveEMA200: boolean;
  emaAlignment: 'bullish' | 'bearish' | 'mixed';
  emaSignal: 'strong-bullish' | 'bullish' | 'neutral' | 'bearish' | 'strong-bearish';
}

interface CoinData {
  symbol: string;
  spikes: AnalysisResult[];
  totalSpikes: number;
  avgVolumeIncrease: number;
  maxVolumeIncrease: number;
  lastAnalyzed: string;
  profileType: string;
}

const allCoins = ref<string[]>([]);
const coinsData = ref<Map<string, CoinData>>(new Map());
const selectedCoin = ref<string>('');
const selectedProfile = ref<string>('sudden-volume');

// Define analysis profiles
const analysisProfiles: AnalysisProfile[] = [
  {
    id: 'sudden-volume',
    name: 'Sudden Volume',
    description: 'Detect sudden volume spikes based on percentage increase',
    icon: 'pi pi-chart-bar',
    parameters: [
      {
        key: 'minVolumeIncrease',
        label: 'Min Volume Increase',
        type: 'number',
        defaultValue: 200,
        min: 50,
        max: 1000,
        step: 25,
        suffix: '%'
      },
      {
        key: 'lookbackHours',
        label: 'Lookback Period',
        type: 'number',
        defaultValue: 4380,
        min: 24,
        max: 4380,
        step: 24,
        suffix: ' hours'
      }
    ]
  },
  {
    id: 'ema-analysis',
    name: 'EMA Analysis',
    description: 'Filter coins based on EMA alignment (7>25>50>99>200) and price action',
    icon: 'pi pi-chart-line',
    parameters: [
      {
        key: 'minVolumeIncrease',
        label: 'Min Volume Increase',
        type: 'number',
        defaultValue: 100,
        min: 25,
        max: 500,
        step: 25,
        suffix: '%'
      },
      {
        key: 'lookbackHours',
        label: 'Lookback Period',
        type: 'number',
        defaultValue: 168,
        min: 24,
        max: 4380,
        step: 24,
        suffix: ' hours'
      },
      {
        key: 'priceAboveEMA',
        label: 'Price Above EMA',
        type: 'select',
        defaultValue: 7,
        options: [
          { label: 'EMA 7', value: 7 },
          { label: 'EMA 25', value: 25 },
          { label: 'EMA 50', value: 50 },
          { label: 'EMA 99', value: 99 },
          { label: 'EMA 200', value: 200 }
        ]
      },
      {
        key: 'requireEMAAlignment',
        label: 'Require EMA Alignment (7>25>50>99>200)',
        type: 'boolean',
        defaultValue: true
      }
    ]
  }
];

const currentProfile = computed(() => {
  return analysisProfiles.find(p => p.id === selectedProfile.value) || analysisProfiles[0];
});

// Dynamic profile parameters
const profileParameters = ref<Record<string, any>>({});

// Initialize profile parameters with defaults
function initializeProfileParameters() {
  currentProfile.value.parameters.forEach(param => {
    profileParameters.value[param.key] = param.defaultValue;
  });
}

const selectedCoinData = computed(() => {
  if (!selectedCoin.value || !coinsData.value.has(selectedCoin.value)) {
    return null;
  }
  return coinsData.value.get(selectedCoin.value);
});

const volumeSpikes = computed(() => {
  return selectedCoinData.value?.spikes || [];
});

const isAnalyzing = ref(false);
const analysisProgress = ref(0);
const currentAnalyzingCoin = ref('');
const totalCoinsToAnalyze = ref(0);
const processedCoins = ref(0);
const expandedRows = ref(new Set<number>()); // Track expanded rows
const loadingMinuteData = ref(new Set<number>()); // Track loading state for minute data

// Legacy parameters for backward compatibility - now derived from profile parameters
const minVolumeIncrease = computed(() => profileParameters.value.minVolumeIncrease || 200);
const lookbackHours = computed(() => profileParameters.value.lookbackHours || 168);
const selectedDateRange = ref<Date[]>([]);

// Coin selection options
const coinOptions = computed(() => {
  return allCoins.value.map(coin => ({
    label: coin,
    value: coin
  }));
});

// Statistics
const totalSpikesFound = computed(() => {
  let total = 0;
  coinsData.value.forEach(data => {
    total += data.totalSpikes;
  });
  return total;
});

const coinsWithSpikes = computed(() => {
  return Array.from(coinsData.value.values()).filter(data => data.totalSpikes > 0).length;
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
    
    // Set default selected coin
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

// Fetch minute-by-minute data for a specific hour
async function fetchMinuteData(symbol: string, hourTimestamp: number): Promise<MinuteSpike[]> {
  try {
    // Get 60 minutes of data starting from the hour
    const startTime = hourTimestamp;
    const endTime = hourTimestamp + (60 * 60 * 1000); // +1 hour
    
    const response = await fetch(
      `https://api.binance.com/api/v3/klines?symbol=${symbol}&interval=1m&startTime=${startTime}&endTime=${endTime}&limit=60`
    );
    
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    
    const candleData = await response.json();
    const minuteSpikes: MinuteSpike[] = [];
    
    // Analyze each minute candle (starting from index 1 to compare with previous)
    for (let i = 1; i < candleData.length; i++) {
      const currentCandle = candleData[i];
      const previousCandle = candleData[i - 1];
      
      const [
        openTime,
        open,
        high,
        low,
        close,
        volume,
        closeTime,
        quoteAssetVolume,
        numberOfTrades,
        takerBuyBaseAssetVolume,
        takerBuyQuoteAssetVolume
      ] = currentCandle;
      
      const [
        prevOpenTime,
        prevOpen,
        prevHigh,
        prevLow,
        prevClose,
        prevVolume,
        prevCloseTime,
        prevQuoteAssetVolume,
        prevNumberOfTrades,
        prevTakerBuyBaseAssetVolume,
        prevTakerBuyQuoteAssetVolume
      ] = previousCandle;
      
      const currentVolumeUSDT = parseFloat(quoteAssetVolume);
      const previousVolumeUSDT = parseFloat(prevQuoteAssetVolume);
      
      // Calculate buying and selling volumes
      const currentBuyingVolumeUSDT = parseFloat(takerBuyQuoteAssetVolume);
      const currentSellingVolumeUSDT = currentVolumeUSDT - currentBuyingVolumeUSDT;
      
      const previousBuyingVolumeUSDT = parseFloat(prevTakerBuyQuoteAssetVolume);
      const previousSellingVolumeUSDT = previousVolumeUSDT - previousBuyingVolumeUSDT;
      
      // Calculate volume increases
      const volumeRatio = previousVolumeUSDT > 0 ? currentVolumeUSDT / previousVolumeUSDT : 0;
      const volumeIncrease = ((volumeRatio - 1) * 100);
      
      const buyingVolumeRatio = previousBuyingVolumeUSDT > 0 ? currentBuyingVolumeUSDT / previousBuyingVolumeUSDT : 0;
      const buyingVolumeIncrease = ((buyingVolumeRatio - 1) * 100);
      
      const sellingVolumeRatio = previousSellingVolumeUSDT > 0 ? currentSellingVolumeUSDT / previousSellingVolumeUSDT : 0;
      const sellingVolumeIncrease = ((sellingVolumeRatio - 1) * 100);
      
      // Calculate percentages
      const buyingPercentage = currentVolumeUSDT > 0 ? (currentBuyingVolumeUSDT / currentVolumeUSDT) * 100 : 0;
      const sellingPercentage = currentVolumeUSDT > 0 ? (currentSellingVolumeUSDT / currentVolumeUSDT) * 100 : 0;
      
      // Only include if volume increase meets threshold
      if (volumeIncrease >= minVolumeIncrease.value) {
        minuteSpikes.push({
          date: new Date(openTime).toLocaleTimeString(),
          timestamp: openTime,
          currentVolume: currentVolumeUSDT,
          previousVolume: previousVolumeUSDT,
          volumeRatio,
          volumeIncrease,
          currentBuyingVolume: currentBuyingVolumeUSDT,
          previousBuyingVolume: previousBuyingVolumeUSDT,
          buyingVolumeRatio,
          buyingVolumeIncrease,
          currentSellingVolume: currentSellingVolumeUSDT,
          previousSellingVolume: previousSellingVolumeUSDT,
          sellingVolumeRatio,
          sellingVolumeIncrease,
          buyingPercentage,
          sellingPercentage,
          profileType: 'sudden-volume',
        });
      }
    }
    
    return minuteSpikes.sort((a, b) => b.timestamp - a.timestamp);
    
  } catch (error) {
    console.error(`Error fetching minute data for ${symbol} at ${new Date(hourTimestamp).toLocaleString()}:`, error);
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

// Analyze EMA alignment and signals
function analyzeEMAData(candleData: any[]): EMAProfileData[] {
  const closes = candleData.map(candle => parseFloat(candle[4])); // Close prices
  
  const ema7 = calculateEMA(closes, 7);
  const ema25 = calculateEMA(closes, 25);
  const ema50 = calculateEMA(closes, 50);
  const ema99 = calculateEMA(closes, 99);
  const ema200 = calculateEMA(closes, 200);
  
  const emaAnalysis: EMAProfileData[] = [];
  
  // Start analysis from index 200 to ensure all EMAs are calculated
  for (let i = 200; i < candleData.length; i++) {
    const currentPrice = closes[i];
    const currentEMA7 = ema7[i];
    const currentEMA25 = ema25[i];
    const currentEMA50 = ema50[i];
    const currentEMA99 = ema99[i];
    const currentEMA200 = ema200[i];
    
    const priceAboveEMA7 = currentPrice > currentEMA7;
    const priceAboveEMA25 = currentPrice > currentEMA25;
    const priceAboveEMA50 = currentPrice > currentEMA50;
    const priceAboveEMA99 = currentPrice > currentEMA99;
    const priceAboveEMA200 = currentPrice > currentEMA200;
    
    let emaAlignment: 'bullish' | 'bearish' | 'mixed' = 'mixed';
    if (currentEMA7 > currentEMA25 && currentEMA25 > currentEMA50 && currentEMA50 > currentEMA99 && currentEMA99 > currentEMA200) {
      emaAlignment = 'bullish';
    } else if (currentEMA7 < currentEMA25 && currentEMA25 < currentEMA50 && currentEMA50 < currentEMA99 && currentEMA99 < currentEMA200) {
      emaAlignment = 'bearish';
    }
    
    let emaSignal: 'strong-bullish' | 'bullish' | 'neutral' | 'bearish' | 'strong-bearish' = 'neutral';
    if (emaAlignment === 'bullish' && priceAboveEMA7 && priceAboveEMA25 && priceAboveEMA50 && priceAboveEMA99 && priceAboveEMA200) {
      emaSignal = 'strong-bullish';
    } else if (emaAlignment === 'bullish' && priceAboveEMA7) {
      emaSignal = 'bullish';
    } else if (emaAlignment === 'bearish' && !priceAboveEMA7 && !priceAboveEMA25 && !priceAboveEMA50 && !priceAboveEMA99 && !priceAboveEMA200) {
      emaSignal = 'strong-bearish';
    } else if (emaAlignment === 'bearish' && !priceAboveEMA7) {
      emaSignal = 'bearish';
    }
    
    emaAnalysis.push({
      ema7: currentEMA7,
      ema25: currentEMA25,
      ema50: currentEMA50,
      ema99: currentEMA99,
      ema200: currentEMA200,
      priceAboveEMA7,
      priceAboveEMA25,
      priceAboveEMA50,
      priceAboveEMA99,
      priceAboveEMA200,
      emaAlignment,
      emaSignal
    });
  }
  
  return emaAnalysis;
}

// Fetch historical hourly candles for EMA analysis
async function fetchHistoricalCandlesWithEMA(symbol: string, hours: number): Promise<AnalysisResult[]> {
  try {
    console.log(`Fetching ${hours} hours of data for ${symbol}...`);
    
    // Calculate start time (hours ago)
    const endTime = Date.now();
    const startTime = endTime - (hours * 60 * 60 * 1000);
    
    // Binance API limit is 1000 candles per request
    // For periods longer than 1000 hours, we need multiple requests
    let allCandleData: any[] = [];
    const maxCandlesPerRequest = 1000;
    const totalRequests = Math.ceil(hours / maxCandlesPerRequest);
    
    console.log(`Need ${totalRequests} API requests to fetch ${hours} hours of data`);
    
    for (let i = 0; i < totalRequests; i++) {
      const requestEndTime = endTime - (i * maxCandlesPerRequest * 60 * 60 * 1000);
      const requestStartTime = Math.max(startTime, requestEndTime - (maxCandlesPerRequest * 60 * 60 * 1000));
      
      console.log(`Request ${i + 1}/${totalRequests}: Fetching from ${new Date(requestStartTime).toLocaleString()} to ${new Date(requestEndTime).toLocaleString()}`);
      
      const response = await fetch(
        `https://api.binance.com/api/v3/klines?symbol=${symbol}&interval=1h&startTime=${requestStartTime}&endTime=${requestEndTime}&limit=${maxCandlesPerRequest}`
      );
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      
      const candleData = await response.json();
      console.log(`Received ${candleData.length} candles for request ${i + 1}`);
      
      // Prepend to maintain chronological order (oldest first)
      allCandleData = candleData.concat(allCandleData);
      
      // Add delay between requests to avoid rate limiting
      if (i < totalRequests - 1) {
        await new Promise(resolve => setTimeout(resolve, 100));
      }
    }
    
    console.log(`Total candles fetched: ${allCandleData.length} (expected: ~${hours})`);
    
    // Remove duplicates based on openTime
    const uniqueCandles = allCandleData.filter((candle, index, array) => 
      index === 0 || candle[0] !== array[index - 1][0]
    );
    
    console.log(`After removing duplicates: ${uniqueCandles.length} candles`);
    
    // Get EMA analysis
    const emaAnalysis = analyzeEMAData(uniqueCandles);
    console.log(`EMA analysis completed: ${emaAnalysis.length} data points`);
    
    const spikes: AnalysisResult[] = [];
    const profileParams = profileParameters.value;
    
    // Start from index where EMA analysis is available
    const startIndex = Math.max(1, uniqueCandles.length - emaAnalysis.length);
    
    for (let i = startIndex; i < uniqueCandles.length; i++) {
      const currentCandle = uniqueCandles[i];
      const previousCandle = uniqueCandles[i - 1];
      const emaIndex = i - startIndex;
      
      if (emaIndex >= emaAnalysis.length) continue;
      
      const emaData = emaAnalysis[emaIndex];
      
      const [
        openTime,
        open,
        high,
        low,
        close,
        volume,
        closeTime,
        quoteAssetVolume,
        numberOfTrades,
        takerBuyBaseAssetVolume,
        takerBuyQuoteAssetVolume
      ] = currentCandle;
      
      const [
        prevOpenTime,
        prevOpen,
        prevHigh,
        prevLow,
        prevClose,
        prevVolume,
        prevCloseTime,
        prevQuoteAssetVolume,
        prevNumberOfTrades,
        prevTakerBuyBaseAssetVolume,
        prevTakerBuyQuoteAssetVolume
      ] = previousCandle;
      
      const currentVolumeUSDT = parseFloat(quoteAssetVolume);
      const previousVolumeUSDT = parseFloat(prevQuoteAssetVolume);
      
      // Calculate volume metrics
      const currentBuyingVolumeUSDT = parseFloat(takerBuyQuoteAssetVolume);
      const currentSellingVolumeUSDT = currentVolumeUSDT - currentBuyingVolumeUSDT;
      const previousBuyingVolumeUSDT = parseFloat(prevTakerBuyQuoteAssetVolume);
      const previousSellingVolumeUSDT = previousVolumeUSDT - previousBuyingVolumeUSDT;
      
      const volumeRatio = previousVolumeUSDT > 0 ? currentVolumeUSDT / previousVolumeUSDT : 0;
      const volumeIncrease = ((volumeRatio - 1) * 100);
      
      const buyingVolumeRatio = previousBuyingVolumeUSDT > 0 ? currentBuyingVolumeUSDT / previousBuyingVolumeUSDT : 0;
      const buyingVolumeIncrease = ((buyingVolumeRatio - 1) * 100);
      
      const sellingVolumeRatio = previousSellingVolumeUSDT > 0 ? currentSellingVolumeUSDT / previousSellingVolumeUSDT : 0;
      const sellingVolumeIncrease = ((sellingVolumeRatio - 1) * 100);
      
      const buyingPercentage = currentVolumeUSDT > 0 ? (currentBuyingVolumeUSDT / currentVolumeUSDT) * 100 : 0;
      const sellingPercentage = currentVolumeUSDT > 0 ? (currentSellingVolumeUSDT / currentVolumeUSDT) * 100 : 0;
      
      // Apply EMA filters
      let passesEMAFilter = true;
      
      // Check if EMA alignment is required
      if (profileParams.requireEMAAlignment) {
        passesEMAFilter = emaData.emaAlignment === 'bullish';
      }
      
      // Check if price is above selected EMA
      if (passesEMAFilter && profileParams.priceAboveEMA) {
        switch (profileParams.priceAboveEMA) {
          case 7:
            passesEMAFilter = emaData.priceAboveEMA7;
            break;
          case 25:
            passesEMAFilter = emaData.priceAboveEMA25;
            break;
          case 50:
            passesEMAFilter = emaData.priceAboveEMA50;
            break;
          case 99:
            passesEMAFilter = emaData.priceAboveEMA99;
            break;
          case 200:
            passesEMAFilter = emaData.priceAboveEMA200;
            break;
        }
      }
      
      // Only include if volume increase meets threshold and passes EMA filter
      if (volumeIncrease >= minVolumeIncrease.value && passesEMAFilter) {
        spikes.push({
          date: new Date(openTime).toLocaleDateString('en-GB') + ' ' + new Date(openTime).toLocaleTimeString(),
          timestamp: openTime,
          symbol,
          currentVolume: currentVolumeUSDT,
          previousVolume: previousVolumeUSDT,
          volumeRatio,
          volumeIncrease,
          currentBuyingVolume: currentBuyingVolumeUSDT,
          previousBuyingVolume: previousBuyingVolumeUSDT,
          buyingVolumeRatio,
          buyingVolumeIncrease,
          currentSellingVolume: currentSellingVolumeUSDT,
          previousSellingVolume: previousSellingVolumeUSDT,
          sellingVolumeRatio,
          sellingVolumeIncrease,
          buyingPercentage,
          sellingPercentage,
          profileType: 'ema-analysis',
          profileData: emaData,
          minuteSpikes: [],
        });
      }
    }
    
    console.log(`Analysis complete: Found ${spikes.length} volume spikes over ${hours} hours`);
    if (spikes.length > 0) {
      const oldestSpike = new Date(Math.min(...spikes.map(s => s.timestamp)));
      const newestSpike = new Date(Math.max(...spikes.map(s => s.timestamp)));
      console.log(`Spike date range: ${oldestSpike.toLocaleString()} to ${newestSpike.toLocaleString()}`);
    }
    
    return spikes.sort((a, b) => b.timestamp - a.timestamp);
    
  } catch (error) {
    console.error(`Error fetching EMA historical data for ${symbol}:`, error);
    return [];
  }
}

// Original sudden volume analysis function
async function fetchHistoricalCandles(symbol: string, hours: number): Promise<AnalysisResult[]> {
  try {
    console.log(`Fetching ${hours} hours of data for ${symbol}...`);
    
    // Calculate start time (hours ago)
    const endTime = Date.now();
    const startTime = endTime - (hours * 60 * 60 * 1000);
    
    // Binance API limit is 1000 candles per request
    // For periods longer than 1000 hours, we need multiple requests
    let allCandleData: any[] = [];
    const maxCandlesPerRequest = 1000;
    const totalRequests = Math.ceil(hours / maxCandlesPerRequest);
    
    console.log(`Need ${totalRequests} API requests to fetch ${hours} hours of data`);
    
    for (let i = 0; i < totalRequests; i++) {
      const requestEndTime = endTime - (i * maxCandlesPerRequest * 60 * 60 * 1000);
      const requestStartTime = Math.max(startTime, requestEndTime - (maxCandlesPerRequest * 60 * 60 * 1000));
      
      console.log(`Request ${i + 1}/${totalRequests}: Fetching from ${new Date(requestStartTime).toLocaleString()} to ${new Date(requestEndTime).toLocaleString()}`);
      
      const response = await fetch(
        `https://api.binance.com/api/v3/klines?symbol=${symbol}&interval=1h&startTime=${requestStartTime}&endTime=${requestEndTime}&limit=${maxCandlesPerRequest}`
      );
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      
      const candleData = await response.json();
      console.log(`Received ${candleData.length} candles for request ${i + 1}`);
      
      // Prepend to maintain chronological order (oldest first)
      allCandleData = candleData.concat(allCandleData);
      
      // Add delay between requests to avoid rate limiting
      if (i < totalRequests - 1) {
        await new Promise(resolve => setTimeout(resolve, 100));
      }
    }
    
    console.log(`Total candles fetched: ${allCandleData.length} (expected: ~${hours})`);
    
    // Remove duplicates based on openTime
    const uniqueCandles = allCandleData.filter((candle, index, array) => 
      index === 0 || candle[0] !== array[index - 1][0]
    );
    
    console.log(`After removing duplicates: ${uniqueCandles.length} candles`);
    
    const spikes: VolumeSpike[] = [];
    
    // Analyze each candle (starting from index 1 to compare with previous)
    for (let i = 1; i < uniqueCandles.length; i++) {
      const currentCandle = uniqueCandles[i];
      const previousCandle = uniqueCandles[i - 1];
      
      const [
        openTime,
        open,
        high,
        low,
        close,
        volume,
        closeTime,
        quoteAssetVolume, // Volume in USDT
        numberOfTrades,
        takerBuyBaseAssetVolume,
        takerBuyQuoteAssetVolume
      ] = currentCandle;
      
      const [
        prevOpenTime,
        prevOpen,
        prevHigh,
        prevLow,
        prevClose,
        prevVolume,
        prevCloseTime,
        prevQuoteAssetVolume,
        prevNumberOfTrades,
        prevTakerBuyBaseAssetVolume,
        prevTakerBuyQuoteAssetVolume
      ] = previousCandle;
      
      const currentVolumeUSDT = parseFloat(quoteAssetVolume);
      const previousVolumeUSDT = parseFloat(prevQuoteAssetVolume);
      
      // Calculate buying and selling volumes
      const currentBuyingVolumeUSDT = parseFloat(takerBuyQuoteAssetVolume);
      const currentSellingVolumeUSDT = currentVolumeUSDT - currentBuyingVolumeUSDT;
      
      const previousBuyingVolumeUSDT = parseFloat(prevTakerBuyQuoteAssetVolume);
      const previousSellingVolumeUSDT = previousVolumeUSDT - previousBuyingVolumeUSDT;
      
      // Calculate total volume increase
      const volumeRatio = previousVolumeUSDT > 0 ? currentVolumeUSDT / previousVolumeUSDT : 0;
      const volumeIncrease = ((volumeRatio - 1) * 100);
      
      // Calculate buying volume increase
      const buyingVolumeRatio = previousBuyingVolumeUSDT > 0 ? currentBuyingVolumeUSDT / previousBuyingVolumeUSDT : 0;
      const buyingVolumeIncrease = ((buyingVolumeRatio - 1) * 100);
      
      // Calculate selling volume increase
      const sellingVolumeRatio = previousSellingVolumeUSDT > 0 ? currentSellingVolumeUSDT / previousSellingVolumeUSDT : 0;
      const sellingVolumeIncrease = ((sellingVolumeRatio - 1) * 100);
      
      // Calculate buying/selling percentages
      const buyingPercentage = currentVolumeUSDT > 0 ? (currentBuyingVolumeUSDT / currentVolumeUSDT) * 100 : 0;
      const sellingPercentage = currentVolumeUSDT > 0 ? (currentSellingVolumeUSDT / currentVolumeUSDT) * 100 : 0;
      
      // Only include if volume increase meets threshold
      if (volumeIncrease >= minVolumeIncrease.value) {
        spikes.push({
          date: new Date(openTime).toLocaleDateString('en-GB') + ' ' + new Date(openTime).toLocaleTimeString(),
          timestamp: openTime,
          symbol,
          currentVolume: currentVolumeUSDT,
          previousVolume: previousVolumeUSDT,
          volumeRatio,
          volumeIncrease,
          currentBuyingVolume: currentBuyingVolumeUSDT,
          previousBuyingVolume: previousBuyingVolumeUSDT,
          buyingVolumeRatio,
          buyingVolumeIncrease,
          currentSellingVolume: currentSellingVolumeUSDT,
          previousSellingVolume: previousSellingVolumeUSDT,
          sellingVolumeRatio,
          sellingVolumeIncrease,
          buyingPercentage,
          sellingPercentage,
          profileType: selectedProfile.value as 'sudden-volume' | 'ema-analysis',
          minuteSpikes: [], // Initialize empty, will be populated on demand
        });
      }
    }
    
    console.log(`Analysis complete: Found ${spikes.length} volume spikes over ${hours} hours`);
    if (spikes.length > 0) {
      const oldestSpike = new Date(Math.min(...spikes.map(s => s.timestamp)));
      const newestSpike = new Date(Math.max(...spikes.map(s => s.timestamp)));
      console.log(`Spike date range: ${oldestSpike.toLocaleString()} to ${newestSpike.toLocaleString()}`);
    }
    
    return spikes.sort((a, b) => b.timestamp - a.timestamp); // Most recent first
    
  } catch (error) {
    console.error(`Error fetching historical data for ${symbol}:`, error);
    return [];
  }
}

// Load minute data for a specific hourly spike
async function loadMinuteData(spike: VolumeSpike) {
  if (spike.minuteSpikes && spike.minuteSpikes.length > 0) {
    // Already loaded
    return;
  }
  
  console.log(`Loading minute data for ${spike.symbol} at ${spike.date}...`);
  
  try {
    const minuteData = await fetchMinuteData(spike.symbol, spike.timestamp);
    spike.minuteSpikes = minuteData;
    
    console.log(`Found ${minuteData.length} minute spikes within the hour`);
  } catch (error) {
    console.error('Error loading minute data:', error);
    spike.minuteSpikes = [];
  }
}
async function analyzeCoin(symbol: string): Promise<CoinData> {
  currentAnalyzingCoin.value = symbol;
  
  let spikes: AnalysisResult[];
  
  // Use different analysis based on selected profile
  if (selectedProfile.value === 'ema-analysis') {
    spikes = await fetchHistoricalCandlesWithEMA(symbol, lookbackHours.value);
  } else {
    spikes = await fetchHistoricalCandles(symbol, lookbackHours.value);
  }
  
  const totalSpikes = spikes.length;
  const avgVolumeIncrease = totalSpikes > 0 
    ? spikes.reduce((sum, spike) => sum + spike.volumeIncrease, 0) / totalSpikes 
    : 0;
  const maxVolumeIncrease = totalSpikes > 0 
    ? Math.max(...spikes.map(spike => spike.volumeIncrease)) 
    : 0;
  
  return {
    symbol,
    spikes,
    totalSpikes,
    avgVolumeIncrease,
    maxVolumeIncrease,
    lastAnalyzed: new Date().toLocaleString(),
    profileType: selectedProfile.value
  };
}

// Analyze all coins
async function analyzeAllCoins() {
  if (allCoins.value.length === 0) {
    console.log('No coins available. Fetching coin list first...');
    await fetchAllCoins();
  }
  
  isAnalyzing.value = true;
  analysisProgress.value = 0;
  processedCoins.value = 0;
  totalCoinsToAnalyze.value = allCoins.value.length;
  coinsData.value.clear();
  
  try {
    console.log(`Starting backtesting analysis for ${allCoins.value.length} coins over ${lookbackHours.value} hours...`);
    
    const batchSize = 5; // Smaller batch size for more reliable processing
    
    for (let i = 0; i < allCoins.value.length; i += batchSize) {
      const batch = allCoins.value.slice(i, i + batchSize);
      
      // Process batch sequentially to avoid overwhelming the API
      for (const symbol of batch) {
        try {
          const coinData = await analyzeCoin(symbol);
          coinsData.value.set(symbol, coinData);
          
          processedCoins.value++;
          analysisProgress.value = (processedCoins.value / totalCoinsToAnalyze.value) * 100;
          
          // Small delay between requests
          await new Promise(resolve => setTimeout(resolve, 50));
          
        } catch (error) {
          console.error(`Failed to analyze ${symbol}:`, error);
          processedCoins.value++;
          analysisProgress.value = (processedCoins.value / totalCoinsToAnalyze.value) * 100;
        }
      }
      
      // Longer delay between batches
      await new Promise(resolve => setTimeout(resolve, 200));
    }
    
    console.log(`Analysis completed! Found ${totalSpikesFound.value} volume spikes across ${coinsWithSpikes.value} coins`);
    
  } catch (error) {
    console.error('Error during analysis:', error);
  } finally {
    isAnalyzing.value = false;
    currentAnalyzingCoin.value = '';
  }
}

// Analyze selected coin only
async function analyzeSelectedCoin() {
  if (!selectedCoin.value) return;
  
  isAnalyzing.value = true;
  try {
    const coinData = await analyzeCoin(selectedCoin.value);
    coinsData.value.set(selectedCoin.value, coinData);
    console.log(`Analysis completed for ${selectedCoin.value}. Found ${coinData.totalSpikes} volume spikes.`);
  } catch (error) {
    console.error(`Error analyzing ${selectedCoin.value}:`, error);
  } finally {
    isAnalyzing.value = false;
  }
}

// Format volume for display
function formatVolume(volume: number): string {
  if (volume >= 1000000000) {
    return (volume / 1000000000).toFixed(2) + 'B';
  } else if (volume >= 1000000) {
    return (volume / 1000000).toFixed(2) + 'M';
  } else if (volume >= 1000) {
    return (volume / 1000).toFixed(2) + 'K';
  }
  return volume.toFixed(2);
}

// Handle row expansion
async function toggleRowExpansion(spike: VolumeSpike) {
  const isExpanded = expandedRows.value.has(spike.timestamp);
  
  if (isExpanded) {
    // Collapse row
    expandedRows.value.delete(spike.timestamp);
  } else {
    // Expand row and load minute data if not already loaded
    expandedRows.value.add(spike.timestamp);
    
    if (!spike.minuteSpikes || spike.minuteSpikes.length === 0) {
      loadingMinuteData.value.add(spike.timestamp);
      await loadMinuteData(spike);
      loadingMinuteData.value.delete(spike.timestamp);
    }
  }
}

// Check if row is expanded
function isRowExpanded(spike: VolumeSpike): boolean {
  return expandedRows.value.has(spike.timestamp);
}

// Check if minute data is loading
function isLoadingMinutes(spike: VolumeSpike): boolean {
  return loadingMinuteData.value.has(spike.timestamp);
}
function clearAllData() {
  coinsData.value.clear();
  processedCoins.value = 0;
  analysisProgress.value = 0;
}

// Export results to CSV
function exportToCSV() {
  if (volumeSpikes.value.length === 0) return;
  
  const headers = [
    'Date', 'Symbol', 'Current Volume (USDT)', 'Previous Volume (USDT)', 
    'Volume Ratio', 'Volume Increase (%)', 
    'Current Buying Volume (USDT)', 'Previous Buying Volume (USDT)', 'Buying Volume Increase (%)',
    'Current Selling Volume (USDT)', 'Previous Selling Volume (USDT)', 'Selling Volume Increase (%)',
    'Buying %', 'Selling %'
  ];
  
  const csvContent = [
    headers.join(','),
    ...volumeSpikes.value.map(spike => [
      spike.date,
      spike.symbol,
      spike.currentVolume.toFixed(2),
      spike.previousVolume.toFixed(2),
      spike.volumeRatio.toFixed(2),
      spike.volumeIncrease.toFixed(2),
      spike.currentBuyingVolume.toFixed(2),
      spike.previousBuyingVolume.toFixed(2),
      spike.buyingVolumeIncrease.toFixed(2),
      spike.currentSellingVolume.toFixed(2),
      spike.previousSellingVolume.toFixed(2),
      spike.sellingVolumeIncrease.toFixed(2),
      spike.buyingPercentage.toFixed(1),
      spike.sellingPercentage.toFixed(1)
    ].join(','))
  ].join('\n');
  
  const blob = new Blob([csvContent], { type: 'text/csv' });
  const url = window.URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `${selectedCoin.value}_volume_spikes_${lookbackHours.value}hours.csv`;
  a.click();
  window.URL.revokeObjectURL(url);
}

// Lifecycle
onMounted(() => {
  fetchAllCoins();
  initializeProfileParameters();
});

// Watch for profile changes to reinitialize parameters
watch(selectedProfile, () => {
  initializeProfileParameters();
  clearAllData(); // Clear existing data when switching profiles
});

// Watch for parameter changes to clear data
watch(profileParameters, () => {
  // You might want to debounce this or only clear on significant changes
}, { deep: true });
</script>

<template>
  <div class="container-fluid p-4">
    <h1 class="mb-4">Historical Volume Analysis - Multi-Profile Backtesting</h1>
    
    <div class="w-full mb-6">
      <DraggableContainer>
        <template #header>
          <span>📈 Advanced Backtesting - Profile-Based Analysis</span>
        </template>
        
        <div class="p-3">
          <!-- Profile Selection Row -->
          <div class="mb-4 p-4 border rounded profile-selector">
            <div class="profile-header mb-3">
              <h6 class="profile-title">📊 Analysis Profile Selection</h6>
            </div>
            <div class="d-flex flex-wrap align-items-center gap-3">
              <div class="d-flex align-items-center">
                <label class="form-label me-2 mb-0 fw-bold text-light">Profile:</label>
                <Dropdown
                  v-model="selectedProfile"
                  :options="analysisProfiles"
                  option-label="name"
                  option-value="id"
                  placeholder="Choose analysis profile"
                  class="w-64 profile-dropdown"
                >
                  <template #option="slotProps">
                    <div class="d-flex align-items-center p-2">
                      <i :class="slotProps.option.icon" class="me-2 text-primary"></i>
                      <div>
                        <div class="fw-bold">{{ slotProps.option.name }}</div>
                        <small class="text-muted">{{ slotProps.option.description }}</small>
                      </div>
                    </div>
                  </template>
                  <template #value="slotProps">
                    <div class="d-flex align-items-center" v-if="slotProps.value">
                      <i :class="currentProfile.icon" class="me-2 text-primary"></i>
                      <span class="fw-bold text-dark">{{ currentProfile.name }}</span>
                    </div>
                  </template>
                </Dropdown>
              </div>
              <div class="profile-description">
                <small class="text-light-gray">{{ currentProfile.description }}</small>
              </div>
            </div>
          </div>
          
          <!-- Dynamic Profile Parameters -->
          <div class="mb-4 p-4 border rounded parameters-section">
            <div class="parameters-header mb-3">
              <h6 class="parameters-title">⚙️ {{ currentProfile.name }} Parameters</h6>
            </div>
            <div class="row">
              <div 
                v-for="param in currentProfile.parameters" 
                :key="param.key"
                class="col-md-3 mb-3"
              >
                <label class="form-label mb-1 parameter-label">{{ param.label }}:</label>
                
                <!-- Number Input -->
                <InputNumber
                  v-if="param.type === 'number'"
                  v-model="profileParameters[param.key]"
                  :suffix="param.suffix"
                  :min="param.min"
                  :max="param.max"
                  :step="param.step"
                  class="w-100 parameter-input"
                />
                
                <!-- Select Dropdown -->
                <Dropdown
                  v-else-if="param.type === 'select'"
                  v-model="profileParameters[param.key]"
                  :options="param.options"
                  option-label="label"
                  option-value="value"
                  class="w-100 parameter-dropdown"
                />
                
                <!-- Boolean Checkbox -->
                <div v-else-if="param.type === 'boolean'" class="d-flex align-items-center">
                  <input
                    type="checkbox"
                    v-model="profileParameters[param.key]"
                    class="form-check-input me-2"
                  />
                  <span class="form-check-label parameter-label">Enabled</span>
                </div>
              </div>
            </div>
          </div>
          
          <!-- Controls Row 1 -->
          <div class="mb-3 d-flex flex-wrap align-items-center gap-3">
            <div class="d-flex align-items-center">
              <label class="form-label me-2 mb-0">Select Coin:</label>
              <Dropdown
                v-model="selectedCoin"
                :options="coinOptions"
                option-label="label"
                option-value="value"
                placeholder="Choose a coin"
                filter
                class="w-48"
                :loading="allCoins.length === 0"
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
              :disabled="!selectedCoin"
              icon="pi pi-chart-line"
              label="Analyze Selected Coin"
              class="p-button-sm p-button-info"
            />
            
            <Button 
              @click="analyzeAllCoins"
              :loading="isAnalyzing"
              :disabled="allCoins.length === 0"
              icon="pi pi-search"
              label="Analyze All Coins"
              class="p-button-sm p-button-primary"
            />
            
            <Button 
              @click="exportToCSV"
              :disabled="volumeSpikes.length === 0"
              icon="pi pi-download"
              label="Export CSV"
              class="p-button-sm p-button-success"
            />
            
            <Button 
              @click="clearAllData"
              :disabled="isAnalyzing"
              icon="pi pi-trash"
              label="Clear Data"
              class="p-button-sm p-button-danger"
            />
          </div>
          
          <!-- Status Information -->
          <div class="mb-3 p-3 border rounded status-section">
            <div class="row">
              <div class="col-md-2">
                <strong class="text-light">Profile:</strong> <span class="text-accent">{{ currentProfile.name }}</span>
              </div>
              <div class="col-md-2">
                <strong class="text-light">Total Coins:</strong> <span class="text-accent">{{ allCoins.length }}</span>
              </div>
              <div class="col-md-2">
                <strong class="text-light">Analyzed Coins:</strong> <span class="text-accent">{{ coinsData.size }}</span>
              </div>
              <div class="col-md-3">
                <strong class="text-light">Coins with Spikes:</strong> <span class="text-accent">{{ coinsWithSpikes }}</span>
              </div>
              <div class="col-md-3">
                <strong class="text-light">Total Spikes Found:</strong> <span class="text-accent">{{ totalSpikesFound }}</span>
              </div>
            </div>
            
            <div class="row mt-2" v-if="selectedCoinData">
              <div class="col-md-3">
                <strong class="text-light">{{ selectedCoin }} Spikes:</strong> <span class="text-accent">{{ selectedCoinData.totalSpikes }}</span>
              </div>
              <div class="col-md-3">
                <strong class="text-light">Avg Increase:</strong> <span class="text-accent">{{ selectedCoinData.avgVolumeIncrease.toFixed(1) }}%</span>
              </div>
              <div class="col-md-3">
                <strong class="text-light">Max Increase:</strong> <span class="text-accent">{{ selectedCoinData.maxVolumeIncrease.toFixed(1) }}%</span>
              </div>
              <div class="col-md-3">
                <strong class="text-light">Last Analyzed:</strong> <span class="text-light-gray">{{ selectedCoinData.lastAnalyzed }}</span>
              </div>
            </div>
            
            <!-- Profile-specific status -->
            <div class="row mt-2" v-if="selectedCoinData && selectedCoinData.profileType === 'ema-analysis'">
              <div class="col-12">
                <small class="text-info">
                  <i class="pi pi-info-circle me-1"></i>
                  EMA Analysis: Price above EMA {{ profileParameters.priceAboveEMA }}
                  <span v-if="profileParameters.requireEMAAlignment">, EMA alignment required (7>25>50>99>200)</span>
                  <span v-else>, EMA alignment not required</span>
                </small>
              </div>
            </div>
            
            <!-- Progress Bar -->
            <div class="mt-3" v-if="isAnalyzing">
              <div class="d-flex justify-content-between align-items-center mb-2">
                <span class="text-sm text-light">{{ currentAnalyzingCoin ? `Analyzing: ${currentAnalyzingCoin}` : 'Preparing analysis...' }}</span>
                <span class="text-sm text-light">{{ processedCoins }}/{{ totalCoinsToAnalyze }}</span>
              </div>
              <ProgressBar :value="analysisProgress" />
              <small class="text-light-gray">
                Analyzing with {{ currentProfile.name }} profile - Volume threshold: {{ minVolumeIncrease }}% over {{ lookbackHours }} hours
              </small>
            </div>
          </div>
          
          <!-- Results Table -->
          <DataTable 
            :value="volumeSpikes" 
            :paginator="true" 
            :rows="50"
            responsive-layout="scroll"
            class="volume-analysis-table"
            sortField="timestamp"
            :sortOrder="-1"
            :loading="isAnalyzing"
            :emptyMessage="`No volume spikes found for ${selectedCoin}. Try lowering the minimum volume increase or selecting a different coin.`"
          >
            <template #header>
              <div class="d-flex justify-content-between align-items-center">
                <span class="text-lg font-bold">
                  {{ currentProfile.name }} Results for {{ selectedCoin }} 
                  <span v-if="selectedCoinData" class="text-sm text-muted">
                    ({{ selectedCoinData.totalSpikes }} spikes found)
                  </span>
                </span>
                <span class="text-sm text-muted">
                  Volume threshold: {{ minVolumeIncrease }}% | {{ Math.round(lookbackHours / 24) }} days
                  <span v-if="selectedProfile === 'ema-analysis'" class="ms-2">
                    | Price > EMA{{ profileParameters.priceAboveEMA }}
                    <span v-if="profileParameters.requireEMAAlignment">, EMA Aligned</span>
                  </span>
                </span>
              </div>
            </template>
            
            <Column field="date" header="Date & Time" style="min-width: 140px">
              <template #body="{ data }">
                <div class="d-flex align-items-center justify-content-between">
                  <Button
                    @click="toggleRowExpansion(data)"
                    :icon="isRowExpanded(data) ? 'pi pi-chevron-down' : 'pi pi-chevron-right'"
                    :class="[
                      'p-button-text p-button-sm expand-button',
                      { 'expand-button-active': isRowExpanded(data) }
                    ]"
                    :loading="isLoadingMinutes(data)"
                  />
                  <span class="font-mono text-xs date-time-text-compact">{{ data.date }}</span>
                </div>
              </template>
            </Column>
            
            <Column field="currentVolume" header="Volume" style="min-width: 110px">
              <template #body="{ data }">
                <span class="font-mono text-primary text-sm">${{ formatVolume(data.currentVolume) }}</span>
              </template>
            </Column>
            
            <Column field="previousVolume" header="Prev Vol" style="min-width: 100px">
              <template #body="{ data }">
                <span class="font-mono text-muted text-xs">${{ formatVolume(data.previousVolume) }}</span>
              </template>
            </Column>
            
            <Column field="volumeRatio" header="Ratio" style="min-width: 70px">
              <template #body="{ data }">
                <span class="font-mono font-weight-bold text-info text-xs">{{ data.volumeRatio.toFixed(2) }}x</span>
              </template>
            </Column>
            
            <Column field="volumeIncrease" header="Vol %" style="min-width: 80px">
              <template #body="{ data }">
                <span 
                  class="font-mono font-weight-bold text-xs"
                  :class="{
                    'text-success': data.volumeIncrease > 500,
                    'text-warning': data.volumeIncrease > 300 && data.volumeIncrease <= 500,
                    'text-info': data.volumeIncrease <= 300
                  }"
                >
                  +{{ data.volumeIncrease.toFixed(1) }}%
                </span>
              </template>
            </Column>
            
            <Column field="currentBuyingVolume" header="Buy Vol" style="min-width: 110px">
              <template #body="{ data }">
                <span class="font-mono text-success text-sm">${{ formatVolume(data.currentBuyingVolume) }}</span>
              </template>
            </Column>
            
            <Column field="buyingVolumeIncrease" header="Buy %" style="min-width: 80px">
              <template #body="{ data }">
                <span 
                  class="font-mono font-weight-bold text-xs"
                  :class="{
                    'text-success': data.buyingVolumeIncrease > 300,
                    'text-warning': data.buyingVolumeIncrease > 100 && data.buyingVolumeIncrease <= 300,
                    'text-info': data.buyingVolumeIncrease > 0 && data.buyingVolumeIncrease <= 100,
                    'text-danger': data.buyingVolumeIncrease < 0
                  }"
                >
                  {{ data.buyingVolumeIncrease > 0 ? '+' : '' }}{{ data.buyingVolumeIncrease.toFixed(1) }}%
                </span>
              </template>
            </Column>
            
            <Column field="currentSellingVolume" header="Sell Vol" style="min-width: 110px">
              <template #body="{ data }">
                <span class="font-mono text-danger text-sm">${{ formatVolume(data.currentSellingVolume) }}</span>
              </template>
            </Column>
            
            <Column field="sellingVolumeIncrease" header="Sell %" style="min-width: 80px">
              <template #body="{ data }">
                <span 
                  class="font-mono font-weight-bold text-xs"
                  :class="{
                    'text-success': data.sellingVolumeIncrease > 300,
                    'text-warning': data.sellingVolumeIncrease > 100 && data.sellingVolumeIncrease <= 300,
                    'text-info': data.sellingVolumeIncrease > 0 && data.sellingVolumeIncrease <= 100,
                    'text-danger': data.sellingVolumeIncrease < 0
                  }"
                >
                  {{ data.sellingVolumeIncrease > 0 ? '+' : '' }}{{ data.sellingVolumeIncrease.toFixed(1) }}%
                </span>
              </template>
            </Column>
            
            <Column header="B/S %" style="min-width: 70px">
              <template #body="{ data }">
                <div class="text-center">
                  <div class="text-success font-mono text-2xs">{{ data.buyingPercentage.toFixed(0) }}%</div>
                  <div class="text-danger font-mono text-2xs">{{ data.sellingPercentage.toFixed(0) }}%</div>
                </div>
              </template>
            </Column>
            
            <!-- EMA Data Column (only shown for EMA analysis) -->
            <Column v-if="selectedProfile === 'ema-analysis'" header="EMA" style="min-width: 90px">
              <template #body="{ data }">
                <div v-if="data.profileData" class="text-center">
                  <div class="text-2xs">
                    <span :class="{
                      'text-success': data.profileData.emaSignal === 'strong-bullish',
                      'text-info': data.profileData.emaSignal === 'bullish',
                      'text-warning': data.profileData.emaSignal === 'neutral',
                      'text-danger': data.profileData.emaSignal === 'bearish' || data.profileData.emaSignal === 'strong-bearish'
                    }">
                      {{ data.profileData.emaSignal.split('-')[0].toUpperCase() }}
                    </span>
                  </div>
                  <div class="text-2xs text-muted">
                    {{ data.profileData.emaAlignment.charAt(0).toUpperCase() }}
                  </div>
                </div>
              </template>
            </Column>
          </DataTable>
          
          <!-- Expanded Row Content - Minute Data -->
          <div v-for="spike in volumeSpikes" :key="spike.timestamp">
            <div v-if="isRowExpanded(spike)" class="mt-3 mb-3 ms-4">
              <div class="p-3 border rounded bg-light">
                <h6 class="mb-3">
                  📊 Minute-by-Minute Analysis for {{ spike.symbol }} - {{ spike.date }}
                  <span class="text-muted ms-2">
                    ({{ spike.minuteSpikes?.length || 0 }} minute spikes found)
                  </span>
                </h6>
                
                <div v-if="isLoadingMinutes(spike)" class="text-center py-3">
                  <ProgressBar mode="indeterminate" />
                  <small class="text-muted">Loading minute data...</small>
                </div>
                
                <div v-else-if="!spike.minuteSpikes || spike.minuteSpikes.length === 0" class="text-center py-3 text-muted">
                  No minute-level volume spikes found for this hour.
                </div>
                
                <DataTable 
                  v-else
                  :value="spike.minuteSpikes" 
                  responsive-layout="scroll"
                  class="minute-analysis-table"
                  sortField="timestamp"
                  :sortOrder="-1"
                >
                  <Column field="date" header="Time" style="min-width: 80px">
                    <template #body="{ data }">
                      <span class="font-mono text-xs">{{ data.date }}</span>
                    </template>
                  </Column>
                  
                  <Column field="currentVolume" header="Volume" style="min-width: 100px">
                    <template #body="{ data }">
                      <span class="font-mono text-primary text-xs">${{ formatVolume(data.currentVolume) }}</span>
                    </template>
                  </Column>
                  
                  <Column field="volumeRatio" header="Ratio" style="min-width: 80px">
                    <template #body="{ data }">
                      <span class="font-mono font-weight-bold text-info text-xs">{{ data.volumeRatio.toFixed(2) }}x</span>
                    </template>
                  </Column>
                  
                  <Column field="volumeIncrease" header="Vol Increase" style="min-width: 100px">
                    <template #body="{ data }">
                      <span 
                        class="font-mono font-weight-bold text-xs"
                        :class="{
                          'text-success': data.volumeIncrease > 500,
                          'text-warning': data.volumeIncrease > 300 && data.volumeIncrease <= 500,
                          'text-info': data.volumeIncrease <= 300
                        }"
                      >
                        +{{ data.volumeIncrease.toFixed(1) }}%
                      </span>
                    </template>
                  </Column>
                  
                  <Column field="currentBuyingVolume" header="Buy Vol" style="min-width: 100px">
                    <template #body="{ data }">
                      <span class="font-mono text-success text-xs">${{ formatVolume(data.currentBuyingVolume) }}</span>
                    </template>
                  </Column>
                  
                  <Column field="buyingVolumeIncrease" header="Buy Increase" style="min-width: 100px">
                    <template #body="{ data }">
                      <span 
                        class="font-mono font-weight-bold text-xs"
                        :class="{
                          'text-success': data.buyingVolumeIncrease > 300,
                          'text-warning': data.buyingVolumeIncrease > 100 && data.buyingVolumeIncrease <= 300,
                          'text-info': data.buyingVolumeIncrease > 0 && data.buyingVolumeIncrease <= 100,
                          'text-danger': data.buyingVolumeIncrease < 0
                        }"
                      >
                        {{ data.buyingVolumeIncrease > 0 ? '+' : '' }}{{ data.buyingVolumeIncrease.toFixed(1) }}%
                      </span>
                    </template>
                  </Column>
                  
                  <Column field="currentSellingVolume" header="Sell Vol" style="min-width: 100px">
                    <template #body="{ data }">
                      <span class="font-mono text-danger text-xs">${{ formatVolume(data.currentSellingVolume) }}</span>
                    </template>
                  </Column>
                  
                  <Column field="sellingVolumeIncrease" header="Sell Increase" style="min-width: 100px">
                    <template #body="{ data }">
                      <span 
                        class="font-mono font-weight-bold text-xs"
                        :class="{
                          'text-success': data.sellingVolumeIncrease > 300,
                          'text-warning': data.sellingVolumeIncrease > 100 && data.sellingVolumeIncrease <= 300,
                          'text-info': data.sellingVolumeIncrease > 0 && data.sellingVolumeIncrease <= 100,
                          'text-danger': data.sellingVolumeIncrease < 0
                        }"
                      >
                        {{ data.sellingVolumeIncrease > 0 ? '+' : '' }}{{ data.sellingVolumeIncrease.toFixed(1) }}%
                      </span>
                    </template>
                  </Column>
                  
                  <Column header="Buy/Sell %" style="min-width: 80px">
                    <template #body="{ data }">
                      <div class="text-center">
                        <div class="text-success font-mono text-xs">{{ data.buyingPercentage.toFixed(1) }}%</div>
                        <div class="text-danger font-mono text-xs">{{ data.sellingPercentage.toFixed(1) }}%</div>
                      </div>
                    </template>
                  </Column>
                </DataTable>
              </div>
            </div>
          </div>
        </div>
      </DraggableContainer>
    </div>
  </div>
</template>

<style scoped>
.volume-analysis-table .font-mono {
  font-family: 'Courier New', monospace;
  font-size: 0.9em;
}

.volume-analysis-table :deep(.p-datatable-thead th) {
  font-size: 0.75em;
  padding: 0.5rem;
}

.minute-analysis-table .font-mono {
  font-family: 'Courier New', monospace;
  font-size: 0.8em;
}

.minute-analysis-table :deep(.p-datatable-thead th) {
  font-size: 0.7em;
  padding: 0.4rem;
}

.minute-analysis-table :deep(.p-datatable-tbody td) {
  padding: 0.3rem;
}

.text-success {
  color: #28a745;
}

.text-danger {
  color: #dc3545;
}

.text-warning {
  color: #ffc107;
}

.text-info {
  color: #17a2b8;
}

.text-primary {
  color: #007bff;
}

.text-muted {
  color: #6c757d;
}

.font-weight-bold {
  font-weight: bold;
}

.text-sm {
  font-size: 0.8em;
}

.text-xs {
  font-size: 0.7em;
}

.text-lg {
  font-size: 1.1em;
}

.w-32 {
  width: 8rem;
}

.w-36 {
  width: 9rem;
}

.w-48 {
  width: 12rem;
}

.w-64 {
  width: 16rem;
}

.fw-bold {
  font-weight: bold;
}

/* Dark Theme Profile Selector */
.profile-selector {
  background: linear-gradient(135deg, #2d3748 0%, #1a202c 100%);
  border: 1px solid #4a5568 !important;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
  position: relative;
  overflow: hidden;
}

.profile-selector::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: linear-gradient(45deg, rgba(255,255,255,0.05) 25%, transparent 25%), 
              linear-gradient(-45deg, rgba(255,255,255,0.05) 25%, transparent 25%), 
              linear-gradient(45deg, transparent 75%, rgba(255,255,255,0.05) 75%), 
              linear-gradient(-45deg, transparent 75%, rgba(255,255,255,0.05) 75%);
  background-size: 20px 20px;
  background-position: 0 0, 0 10px, 10px -10px, -10px 0px;
  opacity: 0.3;
  pointer-events: none;
}

.profile-header {
  position: relative;
  z-index: 1;
}

.profile-title {
  color: #e2e8f0;
  font-weight: 600;
  font-size: 1.1rem;
  margin: 0;
  text-shadow: 0 2px 4px rgba(0,0,0,0.5);
}

.profile-description {
  position: relative;
  z-index: 1;
}

.text-light {
  color: #e2e8f0 !important;
}

.text-light-gray {
  color: #a0aec0 !important;
}

.text-accent {
  color: #63b3ed !important;
  font-weight: 500;
}

.text-dark {
  color: #2d3748 !important;
}

.profile-dropdown {
  position: relative;
  z-index: 1;
}

/* Dark Theme Parameters Section */
.parameters-section {
  background: linear-gradient(135deg, #4a5568 0%, #2d3748 100%);
  border: 1px solid #4a5568 !important;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
  position: relative;
  overflow: hidden;
}

.parameters-section::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: linear-gradient(45deg, rgba(255,255,255,0.03) 25%, transparent 25%), 
              linear-gradient(-45deg, rgba(255,255,255,0.03) 25%, transparent 25%), 
              linear-gradient(45deg, transparent 75%, rgba(255,255,255,0.03) 75%), 
              linear-gradient(-45deg, transparent 75%, rgba(255,255,255,0.03) 75%);
  background-size: 15px 15px;
  background-position: 0 0, 0 7.5px, 7.5px -7.5px, -7.5px 0px;
  opacity: 0.2;
  pointer-events: none;
}

.parameters-header {
  position: relative;
  z-index: 1;
}

.parameters-title {
  color: #e2e8f0;
  font-weight: 600;
  font-size: 1.1rem;
  margin: 0;
  text-shadow: 0 2px 4px rgba(0,0,0,0.5);
}

.parameter-label {
  color: #e2e8f0 !important;
  font-weight: 500;
  text-shadow: 0 1px 2px rgba(0,0,0,0.3);
}

.parameter-input, .parameter-dropdown {
  position: relative;
  z-index: 1;
  background: rgba(255, 255, 255, 0.95) !important;
  border: 1px solid rgba(255, 255, 255, 0.2) !important;
  border-radius: 8px !important;
  box-shadow: 0 4px 15px rgba(0,0,0,0.2);
}

.parameter-input:focus, .parameter-dropdown:focus {
  box-shadow: 0 0 0 3px rgba(99, 179, 237, 0.4), 0 4px 15px rgba(0,0,0,0.3) !important;
  border-color: rgba(99, 179, 237, 0.6) !important;
}

/* Dark Theme Status Section */
.status-section {
  background: linear-gradient(135deg, #1a202c 0%, #2d3748 100%) !important;
  border: 1px solid #4a5568 !important;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3);
}

/* Enhanced button styling for dark theme */
.p-button-sm {
  border-radius: 8px;
  font-weight: 500;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  transition: all 0.3s ease;
  box-shadow: 0 4px 15px rgba(0,0,0,0.2);
}

.p-button-sm:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 20px rgba(0,0,0,0.3);
}

/* Dark theme for data tables */
.volume-analysis-table {
  background: #2d3748;
  color: #e2e8f0;
}

.volume-analysis-table :deep(.p-datatable-header) {
  background: #1a202c;
  color: #e2e8f0;
  border-bottom: 1px solid #4a5568;
}

.volume-analysis-table :deep(.p-datatable-thead th) {
  background: #2d3748;
  color: #e2e8f0;
  border-bottom: 1px solid #4a5568;
}

.volume-analysis-table :deep(.p-datatable-tbody tr) {
  background: #2d3748;
  color: #e2e8f0;
  border-bottom: 1px solid #4a5568;
}

.volume-analysis-table :deep(.p-datatable-tbody tr:nth-child(even)) {
  background: #374151;
}

.volume-analysis-table :deep(.p-datatable-tbody tr:hover) {
  background: #4a5568 !important;
}

/* Expand button and date-time separation */
.expand-button {
  min-width: 32px !important;
  width: 32px !important;
  height: 32px !important;
  margin-right: 0 !important;
  flex-shrink: 0;
  border-radius: 6px !important;
  background: rgba(99, 179, 237, 0.1) !important;
  border: 1px solid rgba(99, 179, 237, 0.3) !important;
}

.expand-button:hover {
  background: rgba(99, 179, 237, 0.2) !important;
  border: 1px solid rgba(99, 179, 237, 0.5) !important;
}

.expand-button-active {
  background: linear-gradient(135deg, #63b3ed 0%, #4299e1 100%) !important;
  border: 1px solid #63b3ed !important;
  color: #ffffff !important;
  box-shadow: 0 4px 15px rgba(99, 179, 237, 0.3);
}

.expand-button-active:hover {
  background: linear-gradient(135deg, #4299e1 0%, #3182ce 100%) !important;
  border: 1px solid #4299e1 !important;
  color: #ffffff !important;
  box-shadow: 0 6px 20px rgba(99, 179, 237, 0.4);
}

.date-time-text {
  flex: 1;
  text-align: left;
  margin-left: 12px;
  color: #e2e8f0 !important;
  font-size: 0.85rem;
  line-height: 1.3;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.date-time-text-compact {
  flex: 1;
  text-align: left;
  margin-left: 8px;
  color: #e2e8f0 !important;
  font-size: 0.7rem;
  line-height: 1.2;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

/* Responsive text sizes */
.text-2xs {
  font-size: 0.65rem;
  line-height: 1.1;
}

/* Table responsive improvements */
.volume-analysis-table :deep(.p-datatable-thead th) {
  font-size: 0.7rem;
  padding: 0.4rem 0.3rem;
  white-space: nowrap;
}

.volume-analysis-table :deep(.p-datatable-tbody td) {
  padding: 0.5rem 0.3rem;
  white-space: nowrap;
}

/* Mobile responsive adjustments */
@media (max-width: 768px) {
  .date-time-text-compact {
    font-size: 0.65rem;
    margin-left: 4px;
  }
  
  .volume-analysis-table :deep(.p-datatable-thead th) {
    font-size: 0.65rem;
    padding: 0.3rem 0.2rem;
  }
  
  .volume-analysis-table :deep(.p-datatable-tbody td) {
    padding: 0.4rem 0.2rem;
  }
  
  .text-xs {
    font-size: 0.65rem;
  }
  
  .text-2xs {
    font-size: 0.6rem;
  }
}

.minute-analysis-table {
  background: #374151;
  color: #e2e8f0;
}

.minute-analysis-table :deep(.p-datatable-thead th) {
  background: #2d3748;
  color: #e2e8f0;
  border-bottom: 1px solid #4a5568;
}

.minute-analysis-table :deep(.p-datatable-tbody tr) {
  background: #374151;
  color: #e2e8f0;
  border-bottom: 1px solid #4a5568;
}

.minute-analysis-table :deep(.p-datatable-tbody tr:nth-child(even)) {
  background: #4a5568;
}

.gap-3 > * {
  margin-right: 0.75rem;
}

.gap-3 > *:last-child {
  margin-right: 0;
}
</style>
