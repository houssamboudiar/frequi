<script setup lang="ts">
import { ref, onMounted, onUnmounted, watch, nextTick } from 'vue';
import DraggableContainer from '@/components/layout/DraggableContainer.vue';
import DataTable from 'primevue/datatable';
import Column from 'primevue/column';
import Button from 'primevue/button';

// Volume analysis data
interface VolumeDataRow {
  id: number;
  timestamp: string;
  pair: string;
  price: string;
  open: string;
  high: string;
  low: string;
  close: string;
  volume: string;
  buyingVolume: string;
  sellingVolume: string;
  buyingPercentage: string;
  sellingPercentage: string;
  buyingVolumeAvg5: string;
  sellingVolumeAvg5: string;
  buyingVolumeAvg15: string;
  sellingVolumeAvg15: string;
  buyingVolumeAvg30: string;
  sellingVolumeAvg30: string;
  decision: string;
  totalVolumeDecision: string;
  openTime: number;
}

const volumeData = ref<VolumeDataRow[]>([]);
const selectedPair = ref('ETH/USDT:USDT');
const isLoading = ref(false);
const marketData = ref<any>(null);
const refreshInterval = ref<number | null>(null);
const lastUpdateTime = ref<string>('');

// Helper function to calculate volume averages
function calculateVolumeAverages(data: VolumeDataRow[], currentIndex: number, periods: number[]) {
  const result: any = {};
  
  periods.forEach(period => {
    let buyingSum = 0;
    let sellingSum = 0;
    let count = 0;
    
    // Calculate average using the X candles BEFORE the current candle
    // Since data is ordered newest first, we start from currentIndex + 1 and go forward
    // For example: if currentIndex is 0, we want to use candles at indices 1, 2, 3, 4, 5 for a 5-period average
    for (let i = currentIndex + 1; i < Math.min(data.length, currentIndex + 1 + period); i++) {
      if (data[i] && data[i].buyingVolume && data[i].sellingVolume) {
        buyingSum += parseFloat(data[i].buyingVolume);
        sellingSum += parseFloat(data[i].sellingVolume);
        count++;
      }
    }
    
    result[`buyingVolumeAvg${period}`] = count > 0 ? (buyingSum / count).toFixed(2) : '0.00';
    result[`sellingVolumeAvg${period}`] = count > 0 ? (sellingSum / count).toFixed(2) : '0.00';
  });
  
  return result;
}

// Helper function to calculate decision values
function calculateDecision(data: VolumeDataRow[], currentIndex: number): string {
  // Decision = ((current candle buying volume / previous candle buying volume) * 100) - 100
  // Since data is ordered newest first, previous candle is at currentIndex + 1
  
  if (currentIndex + 1 >= data.length) {
    // No previous candle available
    return '0.00';
  }
  
  const currentBuyingVolume = parseFloat(data[currentIndex].buyingVolume);
  const previousBuyingVolume = parseFloat(data[currentIndex + 1].buyingVolume);
  
  if (previousBuyingVolume === 0) {
    // Avoid division by zero
    return '0.00';
  }
  
  const decision = ((currentBuyingVolume / previousBuyingVolume) * 100) - 100;
  return decision.toFixed(2);
}

// Helper function to calculate total volume decision values
function calculateTotalVolumeDecision(data: VolumeDataRow[], currentIndex: number): string {
  // Total Volume Decision = ((current candle total volume / previous candle total volume) * 100) - 100
  // Since data is ordered newest first, previous candle is at currentIndex + 1
  
  if (currentIndex + 1 >= data.length) {
    // No previous candle available
    return '0.00';
  }
  
  const currentTotalVolume = parseFloat(data[currentIndex].volume);
  const previousTotalVolume = parseFloat(data[currentIndex + 1].volume);
  
  if (previousTotalVolume === 0) {
    // Avoid division by zero
    return '0.00';
  }
  
  const decision = ((currentTotalVolume / previousTotalVolume) * 100) - 100;
  return decision.toFixed(2);
}

// Fetch 60 minutes of historical candle data
async function fetchHistoricalData() {
  isLoading.value = true;
  try {
    const binancePair = selectedPair.value.replace('/USDT:USDT', 'USDT').replace('/', '');
    console.log('Fetching 60 minutes of historical data for:', binancePair);
    
    // Get last 60 1-minute candles
    const response = await fetch(`https://api.binance.com/api/v3/klines?symbol=${binancePair}&interval=1m&limit=61`);
    const candleData = await response.json();
    
    console.log('Historical candle data received:', candleData.length, 'candles');
    
    // Remove the last candle since it's still forming (not completed)
    const completedCandles = candleData.slice(0, -1);
    console.log('Using completed candles only:', completedCandles.length, 'candles');
    
    // Transform candle data to table format
    const transformedData = completedCandles.map((candle: any[], index: number) => {
      const [
        openTime,
        open,
        high,
        low,
        close,
        volume,
        closeTime,
        quoteAssetVolume, // This is volume in USDT
        numberOfTrades,
        takerBuyBaseAssetVolume,
        takerBuyQuoteAssetVolume
      ] = candle;
      
      const timestamp = new Date(openTime);
      
      // Calculate buying and selling volumes
      const totalVolumeUSDT = parseFloat(quoteAssetVolume);
      const buyingVolumeUSDT = parseFloat(takerBuyQuoteAssetVolume); // Taker buy volume in USDT
      const sellingVolumeUSDT = totalVolumeUSDT - buyingVolumeUSDT; // Remaining is selling volume
      
      const buyingPercentage = totalVolumeUSDT > 0 ? (buyingVolumeUSDT / totalVolumeUSDT * 100) : 0;
      const sellingPercentage = totalVolumeUSDT > 0 ? (sellingVolumeUSDT / totalVolumeUSDT * 100) : 0;
      
      return {
        id: openTime,
        openTime: openTime,
        timestamp: timestamp.toLocaleDateString('en-GB', { 
          day: '2-digit', 
          month: '2-digit', 
          year: '2-digit' 
        }) + ' ' + timestamp.toLocaleTimeString(),
        pair: selectedPair.value,
        open: parseFloat(open).toFixed(6),
        high: parseFloat(high).toFixed(6),
        low: parseFloat(low).toFixed(6),
        close: parseFloat(close).toFixed(6),
        price: parseFloat(close).toFixed(6),
        volume: totalVolumeUSDT.toFixed(2),
        buyingVolume: buyingVolumeUSDT.toFixed(2),
        sellingVolume: sellingVolumeUSDT.toFixed(2),
        buyingPercentage: buyingPercentage.toFixed(1),
        sellingPercentage: sellingPercentage.toFixed(1),
        // Initialize averages - will be calculated after
        buyingVolumeAvg5: '0.00',
        sellingVolumeAvg5: '0.00',
        buyingVolumeAvg15: '0.00',
        sellingVolumeAvg15: '0.00',
        buyingVolumeAvg30: '0.00',
        sellingVolumeAvg30: '0.00',
        decision: '0.00',
        totalVolumeDecision: '0.00'
      };
    }).reverse(); // Show newest first
    
    // Calculate volume averages and decisions for each candle
    transformedData.forEach((candle, index) => {
      const averages = calculateVolumeAverages(transformedData, index, [5, 15, 30]);
      const decision = calculateDecision(transformedData, index);
      const totalVolumeDecision = calculateTotalVolumeDecision(transformedData, index);
      Object.assign(candle, averages);
      candle.decision = decision;
      candle.totalVolumeDecision = totalVolumeDecision;
    });
    
    volumeData.value = transformedData;
    console.log('Historical data loaded:', transformedData.length, 'candles');
    
  } catch (error) {
    console.error('Error fetching historical data:', error);
  } finally {
    isLoading.value = false;
  }
}

// Fetch the previous completed candle when a new one opens
async function fetchLatestCandle() {
  try {
    const binancePair = selectedPair.value.replace('/USDT:USDT', 'USDT').replace('/', '');
    console.log('Fetching just completed candle for:', binancePair, 'at', new Date().toLocaleTimeString());
    
    // Get the last 1 candle - this will be the just completed candle
    const response = await fetch(`https://api.binance.com/api/v3/klines?symbol=${binancePair}&interval=1m&limit=1&endTime=${Date.now() - 60000}`);
    const candleData = await response.json();
    
    console.log('Received candle data:', candleData.length, 'candles');
    
    if (candleData && candleData.length >= 1) {
      // Take the candle that just completed
      const justCompletedCandle = candleData[0];
      const [
        openTime,
        open,
        high,
        low,
        close,
        volume,
        closeTime,
        quoteAssetVolume, // This is volume in USDT
        numberOfTrades,
        takerBuyBaseAssetVolume,
        takerBuyQuoteAssetVolume
      ] = justCompletedCandle;
      
      const timestamp = new Date(openTime);
      
      console.log('Processing just completed candle with openTime:', openTime, 'timestamp:', timestamp.toLocaleTimeString());
      console.log('Current volumeData has', volumeData.value.length, 'candles');
      if (volumeData.value.length > 0) {
        console.log('First candle in current data:', new Date(volumeData.value[0].openTime).toLocaleTimeString());
      }
      
      // Calculate buying and selling volumes
      const totalVolumeUSDT = parseFloat(quoteAssetVolume);
      const buyingVolumeUSDT = parseFloat(takerBuyQuoteAssetVolume); // Taker buy volume in USDT
      const sellingVolumeUSDT = totalVolumeUSDT - buyingVolumeUSDT; // Remaining is selling volume
      
      const buyingPercentage = totalVolumeUSDT > 0 ? (buyingVolumeUSDT / totalVolumeUSDT * 100) : 0;
      const sellingPercentage = totalVolumeUSDT > 0 ? (sellingVolumeUSDT / totalVolumeUSDT * 100) : 0;
      
      const newCandleData = {
        id: openTime,
        openTime: openTime,
        timestamp: timestamp.toLocaleDateString('en-GB', { 
          day: '2-digit', 
          month: '2-digit', 
          year: '2-digit' 
        }) + ' ' + timestamp.toLocaleTimeString(),
        pair: selectedPair.value,
        open: parseFloat(open).toFixed(6),
        high: parseFloat(high).toFixed(6),
        low: parseFloat(low).toFixed(6),
        close: parseFloat(close).toFixed(6),
        price: parseFloat(close).toFixed(6),
        volume: totalVolumeUSDT.toFixed(2),
        buyingVolume: buyingVolumeUSDT.toFixed(2),
        sellingVolume: sellingVolumeUSDT.toFixed(2),
        buyingPercentage: buyingPercentage.toFixed(1),
        sellingPercentage: sellingPercentage.toFixed(1),
        // Initialize averages - will be calculated after adding to array
        buyingVolumeAvg5: '0.00',
        sellingVolumeAvg5: '0.00',
        buyingVolumeAvg15: '0.00',
        sellingVolumeAvg15: '0.00',
        buyingVolumeAvg30: '0.00',
        sellingVolumeAvg30: '0.00',
        decision: '0.00',
        totalVolumeDecision: '0.00'
      };
      
      // Check if this candle already exists (by openTime)
      const existingIndex = volumeData.value.findIndex(candle => candle.openTime === openTime);
      
      if (existingIndex >= 0) {
        // Update existing candle - use Vue's reactivity system properly
        volumeData.value.splice(existingIndex, 1, newCandleData);
        console.log('Updated existing completed candle:', timestamp.toLocaleTimeString());
      } else {
        // Add new completed candle to the beginning
        volumeData.value.unshift(newCandleData);
        // Keep last 200 candles to maintain more history
        if (volumeData.value.length > 200) {
          volumeData.value = volumeData.value.slice(0, 200);
        }
        console.log('Added new completed candle:', timestamp.toLocaleTimeString());
      }
      
      // Recalculate averages and decisions for all candles after adding new data
      volumeData.value.forEach((candle, index) => {
        const averages = calculateVolumeAverages(volumeData.value, index, [5, 15, 30]);
        const decision = calculateDecision(volumeData.value, index);
        const totalVolumeDecision = calculateTotalVolumeDecision(volumeData.value, index);
        Object.assign(candle, averages);
        candle.decision = decision;
        candle.totalVolumeDecision = totalVolumeDecision;
      });
      
      lastUpdateTime.value = new Date().toLocaleTimeString();
      
      // Force Vue reactivity update
      await nextTick();
      
      console.log('Vue data updated, current volumeData length:', volumeData.value.length);
      console.log('First candle timestamp:', volumeData.value[0]?.timestamp);
      console.log('Table should now show updated data');
      
    } else {
      console.log('No completed candle data received');
    }
    
  } catch (error) {
    console.error('Error fetching latest candle:', error);
  }
}

// Start auto-refresh every minute to get previous completed candle
function startAutoRefresh() {
  // Clear any existing interval
  if (refreshInterval.value) {
    clearInterval(refreshInterval.value);
  }
  
  // Calculate time until next minute starts (when new candle opens)
  const now = new Date();
  const msUntilNextMinute = (60 - now.getSeconds()) * 1000 - now.getMilliseconds();
  
  console.log(`Starting auto-refresh in ${Math.round(msUntilNextMinute / 1000)} seconds for pair: ${selectedPair.value}`);
  console.log('Will fetch just completed candle when new candle opens');
  
  // Start refreshing at the beginning of each new minute (when new candle opens)
  setTimeout(() => {
    console.log('Auto-refresh timer triggered - fetching latest candle');
    fetchLatestCandle(); // Get the previous completed candle
    // Then refresh every 60 seconds
    refreshInterval.value = setInterval(() => {
      console.log('Auto-refresh interval triggered - fetching latest candle');
      fetchLatestCandle();
    }, 60000);
    console.log('Auto-refresh started - fetching just completed candle every minute for', selectedPair.value);
  }, msUntilNextMinute);
}

// Stop auto-refresh
function stopAutoRefresh() {
  if (refreshInterval.value) {
    clearInterval(refreshInterval.value);
    refreshInterval.value = null;
    console.log('Auto-refresh stopped');
  }
}

// Execute fetch market data function
async function executeMarketDataFetch() {
  isLoading.value = true;
  try {
    const result = await fetchMinuteCandle(selectedPair.value);
    marketData.value = result;
    console.log('Market data fetched:', result);
  } catch (error) {
    console.error('Error executing market data fetch:', error);
  } finally {
    isLoading.value = false;
  }
}
// Fetch candlestick data for the last minute
async function fetchMinuteCandle(pair: string) {
  try {
    const binancePair = pair.replace('/USDT:USDT', 'USDT').replace('/', '');
    const response = await fetch(
      `https://api.binance.com/api/v3/klines?symbol=${binancePair}&interval=1m&limit=1`
    );
    const data = await response.json();

    const [openTime, open, high, low, close, volume, closeTime, quoteAssetVolume, numberOfTrades, takerBuyBaseAssetVolume, takerBuyQuoteAssetVolume] = data[0];

    // Calculate buying and selling volumes
    const totalVolumeUSDT = parseFloat(quoteAssetVolume);
    const buyingVolumeUSDT = parseFloat(takerBuyQuoteAssetVolume);
    const sellingVolumeUSDT = totalVolumeUSDT - buyingVolumeUSDT;

    return {
      open: parseFloat(open),
      high: parseFloat(high),
      low: parseFloat(low),
      close: parseFloat(close),
      volume: totalVolumeUSDT,
      buyingVolume: buyingVolumeUSDT,
      sellingVolume: sellingVolumeUSDT,
      timestamp: openTime
    };
  } catch (error) {
    console.error('Error fetching candle data:', error);
    return null;
  }
}

// Lifecycle hooks
onMounted(() => {
  // Load initial historical data
  fetchHistoricalData().then(() => {
    // Start auto-refresh after initial load
    startAutoRefresh();
  });
});

onUnmounted(() => {
  // Clean up interval when component is destroyed
  stopAutoRefresh();
});

// Watch for selectedPair changes and restart auto-refresh with new data
watch(selectedPair, (newPair, oldPair) => {
  if (newPair !== oldPair) {
    console.log('Selected pair changed from', oldPair, 'to', newPair);
    // Stop current auto-refresh
    stopAutoRefresh();
    // Fetch new historical data for the new pair
    fetchHistoricalData().then(() => {
      // Start auto-refresh for the new pair
      startAutoRefresh();
    });
  }
});
</script>

<template>
  <div class="container-fluid p-4">
    <h1 class="mb-4">Analyse Tables</h1>
    
    <!-- Volume Analysis Section -->
    <div class="w-full mb-6">
      <DraggableContainer>
        <template #header>
          <span>📊 Table Analysis</span>
        </template>
        
        <div class="p-3">
          <div class="mb-3">
            <select v-model="selectedPair" class="form-select" style="width: auto; display: inline-block; margin-right: 10px;">
              <option value="ETH/USDT:USDT">ETH/USDT:USDT</option>
              <option value="BTC/USDT">BTC/USDT</option>
              <option value="BNB/USDT">BNB/USDT</option>
              <option value="USUAL/USDT">USUAL/USDT</option>
            </select>
            <Button 
              @click="executeMarketDataFetch"
              :loading="isLoading"
              icon="pi pi-refresh"
              label="Fetch Market Data"
              class="p-button-sm"
              style="margin-right: 10px;"
            />
            <Button 
              @click="fetchHistoricalData"
              :loading="isLoading"
              icon="pi pi-history"
              label="Load 60m History"
              class="p-button-sm p-button-secondary"
              style="margin-right: 10px;"
            />
            <Button 
              @click="startAutoRefresh"
              :disabled="refreshInterval !== null"
              icon="pi pi-play"
              label="Start Auto-Refresh"
              class="p-button-sm p-button-success"
              style="margin-right: 10px;"
            />
            <Button 
              @click="stopAutoRefresh"
              :disabled="refreshInterval === null"
              icon="pi pi-stop"
              label="Stop Auto-Refresh"
              class="p-button-sm p-button-warning"
            />
            <span v-if="lastUpdateTime" class="text-muted ms-3 small">
              Last update: {{ lastUpdateTime }}
            </span>
            <span v-if="refreshInterval !== null" class="text-success ms-2 small">
              🟢 Auto-refresh active
            </span>
            <span class="text-info ms-2 small">
              📊 {{ volumeData.length }} candles loaded
            </span>
          </div>
          
          <!-- Display Market Data Results -->
          <div v-if="marketData" class="mb-3 p-3 border rounded bg-light">
            <h6>Live Market Data for {{ selectedPair }}:</h6>
            <div class="row">
              <div class="col-md-3">
                <strong>Price:</strong> ${{ marketData.price?.toFixed(6) }}
              </div>
              <div class="col-md-3">
                <strong>Volume:</strong> {{ marketData.volume?.toFixed(2) }}
              </div>
              <div class="col-md-3">
                <strong>Price Change:</strong> {{ marketData.priceChange?.toFixed(6) }}
              </div>
              <div class="col-md-3">
                <strong>Change %:</strong> {{ marketData.priceChangePercent?.toFixed(2) }}%
              </div>
            </div>
            <small class="text-muted">Fetched at: {{ new Date(marketData.timestamp).toLocaleString() }}</small>
          </div>
          
          <DataTable 
            :value="volumeData" 
            :key="volumeData.length"
            :paginator="true" 
            :rows="20"
            responsive-layout="scroll"
            class="table-skeleton"
            sortField="openTime"
            :sortOrder="-1"
          >
            <Column field="timestamp" header="Time" style="min-width: 140px">
              <template #body="{ data }">
                <span class="font-mono">{{ data.timestamp }}</span>
              </template>
            </Column>
            
            <Column field="pair" header="Pair" style="min-width: 100px">
              <template #body="{ data }">
                <span>{{ data.pair }}</span>
              </template>
            </Column>
            
            <Column field="open" header="Open" style="min-width: 100px">
              <template #body="{ data }">
                <span class="font-mono">${{ data.open }}</span>
              </template>
            </Column>
            
            <Column field="high" header="High" style="min-width: 100px">
              <template #body="{ data }">
                <span class="font-mono text-success">${{ data.high }}</span>
              </template>
            </Column>
            
            <Column field="low" header="Low" style="min-width: 100px">
              <template #body="{ data }">
                <span class="font-mono text-danger">${{ data.low }}</span>
              </template>
            </Column>
            
            <Column field="close" header="Close" style="min-width: 100px">
              <template #body="{ data }">
                <span class="font-mono font-weight-bold">${{ data.close }}</span>
              </template>
            </Column>
            
            <Column field="volume" header="Volume (USDT)" style="min-width: 120px">
              <template #body="{ data }">
                <span class="font-mono">${{ data.volume }}</span>
              </template>
            </Column>
            
            <Column field="buyingVolume" header="Buying Volume" style="min-width: 120px">
              <template #body="{ data }">
                <span class="font-mono text-success">${{ data.buyingVolume }}</span>
              </template>
            </Column>
            
            <Column field="sellingVolume" header="Selling Volume" style="min-width: 120px">
              <template #body="{ data }">
                <span class="font-mono text-danger">${{ data.sellingVolume }}</span>
              </template>
            </Column>
            
            <Column header="Buy/Sell %" style="min-width: 100px">
              <template #body="{ data }">
                <div class="text-center">
                  <div class="text-success font-mono text-sm">{{ data.buyingPercentage }}%</div>
                  <div class="text-danger font-mono text-sm">{{ data.sellingPercentage }}%</div>
                </div>
              </template>
            </Column>
            
            <Column header="Buy Avg (5)" style="min-width: 100px">
              <template #body="{ data }">
                <span class="font-mono text-success text-sm">${{ data.buyingVolumeAvg5 }}</span>
              </template>
            </Column>
            
            <Column header="Sell Avg (5)" style="min-width: 100px">
              <template #body="{ data }">
                <span class="font-mono text-danger text-sm">${{ data.sellingVolumeAvg5 }}</span>
              </template>
            </Column>
            
            <Column header="Buy Avg (15)" style="min-width: 100px">
              <template #body="{ data }">
                <span class="font-mono text-success text-sm">${{ data.buyingVolumeAvg15 }}</span>
              </template>
            </Column>
            
            <Column header="Sell Avg (15)" style="min-width: 100px">
              <template #body="{ data }">
                <span class="font-mono text-danger text-sm">${{ data.sellingVolumeAvg15 }}</span>
              </template>
            </Column>
            
            <Column header="Buy Avg (30)" style="min-width: 100px">
              <template #body="{ data }">
                <span class="font-mono text-success text-sm">${{ data.buyingVolumeAvg30 }}</span>
              </template>
            </Column>
            
            <Column header="Sell Avg (30)" style="min-width: 100px">
              <template #body="{ data }">
                <span class="font-mono text-danger text-sm">${{ data.sellingVolumeAvg30 }}</span>
              </template>
            </Column>
            
            <Column header="Buy Volume Decision" style="min-width: 120px">
              <template #body="{ data }">
                <span 
                  class="font-mono text-sm font-weight-bold"
                  :class="{
                    'text-success': parseFloat(data.decision) > 0,
                    'text-danger': parseFloat(data.decision) < 0,
                    'text-muted': parseFloat(data.decision) === 0
                  }"
                >
                  {{ parseFloat(data.decision) > 0 ? '+' + data.decision + '%' : parseFloat(data.decision) < 0 ? '-' : data.decision + '%' }}
                </span>
              </template>
            </Column>
            
            <Column header="Total Volume Decision" style="min-width: 120px">
              <template #body="{ data }">
                <span 
                  class="font-mono text-sm font-weight-bold"
                  :class="{
                    'text-success': parseFloat(data.totalVolumeDecision) > 0,
                    'text-danger': parseFloat(data.totalVolumeDecision) < 0,
                    'text-muted': parseFloat(data.totalVolumeDecision) === 0
                  }"
                >
                  {{ parseFloat(data.totalVolumeDecision) > 0 ? '+' + data.totalVolumeDecision + '%' : parseFloat(data.totalVolumeDecision) < 0 ? '-' : data.totalVolumeDecision + '%' }}
                </span>
              </template>
            </Column>
          </DataTable>
        </div>
      </DraggableContainer>
    </div>
  </div>
</template>

<style scoped>
.table-skeleton .font-mono {
  font-family: 'Courier New', monospace;
  font-size: 0.9em;
}

/* Make column headers smaller */
.table-skeleton :deep(.p-datatable-thead th) {
  font-size: 0.75em;
  padding: 0.5rem;
}

.text-success {
  color: #28a745;
}

.text-danger {
  color: #dc3545;
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

.volume-bar {
  width: 80px;
  height: 20px;
  background-color: #f0f0f0;
  border-radius: 10px;
  position: relative;
  overflow: hidden;
  margin: 0 auto;
}

.volume-bar-fill {
  height: 100%;
  position: absolute;
  top: 0;
}

.bg-success {
  background-color: #28a745;
}

.bg-danger {
  background-color: #dc3545;
}
</style>
