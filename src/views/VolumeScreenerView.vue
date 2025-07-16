<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue';
import DraggableContainer from '@/components/layout/DraggableContainer.vue';
import DataTable from 'primevue/datatable';
import Column from 'primevue/column';
import Button from 'primevue/button';
import ProgressBar from 'primevue/progressbar';

interface CoinVolumeData {
  symbol: string;
  currentVolume: number;
  previousVolume: number;
  volumeRatio: number;
  volumeIncrease: number;
  currentPrice: number;
  priceChange24h: number;
  priceChangePercent24h: number;
  lastUpdate: string;
}

const allCoins = ref<string[]>([]);
const volumeScreenerData = ref<CoinVolumeData[]>([]);
const isLoading = ref(false);
const scanProgress = ref(0);
const totalCoins = ref(0);
const processedCoins = ref(0);
const refreshInterval = ref<number | null>(null);
const lastScanTime = ref<string>('');
const autoRefreshEnabled = ref(false);

// Minimum volume increase percentage (200% = 3x volume)
const minVolumeIncrease = ref(200);

// Fetch all available trading pairs from Binance
async function fetchAllCoins() {
  try {
    console.log('Fetching all trading pairs from Binance...');
    const response = await fetch('https://api.binance.com/api/v3/exchangeInfo');
    const data = await response.json();
    
    // Filter for USDT pairs only and active symbols
    const usdtPairs = data.symbols
      .filter((symbol: any) => 
        symbol.quoteAsset === 'USDT' && 
        symbol.status === 'TRADING' &&
        !symbol.symbol.includes('UP') &&
        !symbol.symbol.includes('DOWN') &&
        !symbol.symbol.includes('BULL') &&
        !symbol.symbol.includes('BEAR')
      )
      .map((symbol: any) => symbol.symbol);
    
    allCoins.value = usdtPairs;
    totalCoins.value = usdtPairs.length;
    console.log(`Found ${usdtPairs.length} USDT trading pairs`);
    
    return usdtPairs;
  } catch (error) {
    console.error('Error fetching trading pairs:', error);
    return [];
  }
}

// Fetch daily candle data for a specific coin
async function fetchDailyCandle(symbol: string) {
  try {
    // Get last 2 daily candles to compare volumes
    const response = await fetch(
      `https://api.binance.com/api/v3/klines?symbol=${symbol}&interval=1d&limit=2`
    );
    const data = await response.json();
    
    if (data.length >= 2) {
      const [previousCandle, currentCandle] = data;
      
      // Extract volume data (index 5 is volume, index 7 is quote asset volume in USDT)
      const previousVolume = parseFloat(previousCandle[7]); // Previous day volume in USDT
      const currentVolume = parseFloat(currentCandle[7]);   // Current day volume in USDT
      
      // Calculate current price and 24h change
      const currentPrice = parseFloat(currentCandle[4]); // Close price
      const previousPrice = parseFloat(previousCandle[4]);
      const priceChange24h = currentPrice - previousPrice;
      const priceChangePercent24h = previousPrice > 0 ? (priceChange24h / previousPrice) * 100 : 0;
      
      // Calculate volume ratio and increase percentage
      const volumeRatio = previousVolume > 0 ? currentVolume / previousVolume : 0;
      const volumeIncrease = ((volumeRatio - 1) * 100);
      
      return {
        symbol,
        currentVolume,
        previousVolume,
        volumeRatio,
        volumeIncrease,
        currentPrice,
        priceChange24h,
        priceChangePercent24h,
        lastUpdate: new Date().toLocaleTimeString()
      };
    }
    
    return null;
  } catch (error) {
    console.error(`Error fetching data for ${symbol}:`, error);
    return null;
  }
}

// Scan all coins and find those with high volume increase
async function scanAllCoins() {
  isLoading.value = true;
  scanProgress.value = 0;
  processedCoins.value = 0;
  volumeScreenerData.value = [];
  
  try {
    console.log(`Starting volume scan for ${allCoins.value.length} coins...`);
    const startTime = Date.now();
    
    const highVolumeCoins: CoinVolumeData[] = [];
    const batchSize = 10; // Process coins in batches to avoid rate limits
    
    for (let i = 0; i < allCoins.value.length; i += batchSize) {
      const batch = allCoins.value.slice(i, i + batchSize);
      
      // Process batch in parallel
      const batchPromises = batch.map(symbol => fetchDailyCandle(symbol));
      const batchResults = await Promise.all(batchPromises);
      
      // Filter results and add to high volume coins
      batchResults.forEach(result => {
        if (result && result.volumeIncrease >= minVolumeIncrease.value) {
          highVolumeCoins.push(result);
        }
      });
      
      // Update progress
      processedCoins.value = Math.min(i + batchSize, allCoins.value.length);
      scanProgress.value = (processedCoins.value / allCoins.value.length) * 100;
      
      // Add small delay between batches to respect rate limits
      if (i + batchSize < allCoins.value.length) {
        await new Promise(resolve => setTimeout(resolve, 100));
      }
    }
    
    // Sort by volume increase (highest first)
    highVolumeCoins.sort((a, b) => b.volumeIncrease - a.volumeIncrease);
    
    volumeScreenerData.value = highVolumeCoins;
    lastScanTime.value = new Date().toLocaleTimeString();
    
    const endTime = Date.now();
    const scanDuration = ((endTime - startTime) / 1000).toFixed(1);
    
    console.log(`Scan completed in ${scanDuration} seconds`);
    console.log(`Found ${highVolumeCoins.length} coins with volume increase >= ${minVolumeIncrease.value}%`);
    
  } catch (error) {
    console.error('Error during coin scan:', error);
  } finally {
    isLoading.value = false;
    scanProgress.value = 100;
  }
}

// Start auto-refresh every 30 minutes
function startAutoRefresh() {
  if (refreshInterval.value) {
    clearInterval(refreshInterval.value);
  }
  
  autoRefreshEnabled.value = true;
  console.log('Starting auto-refresh every 30 minutes...');
  
  // Refresh every 30 minutes (1800000 ms)
  refreshInterval.value = setInterval(() => {
    console.log('Auto-refresh triggered - scanning coins...');
    scanAllCoins();
  }, 1800000);
}

// Stop auto-refresh
function stopAutoRefresh() {
  if (refreshInterval.value) {
    clearInterval(refreshInterval.value);
    refreshInterval.value = null;
  }
  autoRefreshEnabled.value = false;
  console.log('Auto-refresh stopped');
}

// Format volume for display
function formatVolume(volume: number): string {
  if (volume >= 1000000) {
    return (volume / 1000000).toFixed(2) + 'M';
  } else if (volume >= 1000) {
    return (volume / 1000).toFixed(2) + 'K';
  }
  return volume.toFixed(2);
}

// Format price for display
function formatPrice(price: number): string {
  if (price >= 1) {
    return price.toFixed(4);
  } else if (price >= 0.01) {
    return price.toFixed(6);
  } else {
    return price.toFixed(8);
  }
}

// Lifecycle hooks
onMounted(async () => {
  console.log('Volume Screener mounted - fetching coin list...');
  await fetchAllCoins();
});

onUnmounted(() => {
  stopAutoRefresh();
});
</script>

<template>
  <div class="container-fluid p-4">
    <h1 class="mb-4">Volume Screener - High Volume Coins</h1>
    
    <div class="w-full mb-6">
      <DraggableContainer>
        <template #header>
          <span>🔍 Volume Scanner (Daily Candles)</span>
        </template>
        
        <div class="p-3">
          <!-- Controls -->
          <div class="mb-3 d-flex flex-wrap align-items-center gap-2">
            <div class="me-3">
              <label class="form-label me-2">Min Volume Increase:</label>
              <input 
                v-model.number="minVolumeIncrease" 
                type="number" 
                class="form-control d-inline-block"
                style="width: 100px;"
                min="50"
                max="1000"
                step="25"
              />
              <span class="ms-1">%</span>
            </div>
            
            <Button 
              @click="fetchAllCoins"
              :loading="isLoading"
              icon="pi pi-download"
              label="Fetch Coin List"
              class="p-button-sm p-button-secondary"
            />
            
            <Button 
              @click="scanAllCoins"
              :loading="isLoading"
              :disabled="allCoins.length === 0"
              icon="pi pi-search"
              label="Scan All Coins"
              class="p-button-sm p-button-primary"
            />
            
            <Button 
              @click="startAutoRefresh"
              :disabled="autoRefreshEnabled || allCoins.length === 0"
              icon="pi pi-play"
              label="Start Auto-Scan"
              class="p-button-sm p-button-success"
            />
            
            <Button 
              @click="stopAutoRefresh"
              :disabled="!autoRefreshEnabled"
              icon="pi pi-stop"
              label="Stop Auto-Scan"
              class="p-button-sm p-button-warning"
            />
          </div>
          
          <!-- Status Information -->
          <div class="mb-3 p-3 border rounded bg-light">
            <div class="row">
              <div class="col-md-3">
                <strong>Total Coins:</strong> {{ totalCoins }}
              </div>
              <div class="col-md-3">
                <strong>Processed:</strong> {{ processedCoins }}
              </div>
              <div class="col-md-3">
                <strong>High Volume Found:</strong> {{ volumeScreenerData.length }}
              </div>
              <div class="col-md-3">
                <strong>Auto-Scan:</strong> 
                <span :class="autoRefreshEnabled ? 'text-success' : 'text-muted'">
                  {{ autoRefreshEnabled ? '🟢 Active' : '⚫ Inactive' }}
                </span>
              </div>
            </div>
            <div class="row mt-2" v-if="lastScanTime">
              <div class="col-12">
                <small class="text-muted">
                  Last scan: {{ lastScanTime }} | 
                  Scanning for coins with volume ≥ {{ minVolumeIncrease }}% of previous day
                  {{ autoRefreshEnabled ? ' | Next scan in ~30 minutes' : '' }}
                </small>
              </div>
            </div>
            
            <!-- Progress Bar -->
            <div class="mt-2" v-if="isLoading">
              <ProgressBar :value="scanProgress" />
              <small class="text-muted">Scanning... {{ processedCoins }}/{{ totalCoins }} coins processed</small>
            </div>
          </div>
          
          <!-- Results Table -->
          <DataTable 
            :value="volumeScreenerData" 
            :paginator="true" 
            :rows="25"
            responsive-layout="scroll"
            class="volume-screener-table"
            sortField="volumeIncrease"
            :sortOrder="-1"
            :loading="isLoading"
          >
            <Column field="symbol" header="Symbol" style="min-width: 120px">
              <template #body="{ data }">
                <span class="font-weight-bold">{{ data.symbol }}</span>
              </template>
            </Column>
            
            <Column field="currentPrice" header="Price (USDT)" style="min-width: 120px">
              <template #body="{ data }">
                <span class="font-mono">${{ formatPrice(data.currentPrice) }}</span>
              </template>
            </Column>
            
            <Column field="priceChangePercent24h" header="24h Price Change" style="min-width: 130px">
              <template #body="{ data }">
                <span 
                  class="font-mono font-weight-bold"
                  :class="{
                    'text-success': data.priceChangePercent24h > 0,
                    'text-danger': data.priceChangePercent24h < 0,
                    'text-muted': data.priceChangePercent24h === 0
                  }"
                >
                  {{ data.priceChangePercent24h > 0 ? '+' : '' }}{{ data.priceChangePercent24h.toFixed(2) }}%
                </span>
              </template>
            </Column>
            
            <Column field="currentVolume" header="Current Volume (USDT)" style="min-width: 150px">
              <template #body="{ data }">
                <span class="font-mono text-primary">${{ formatVolume(data.currentVolume) }}</span>
              </template>
            </Column>
            
            <Column field="previousVolume" header="Previous Volume (USDT)" style="min-width: 150px">
              <template #body="{ data }">
                <span class="font-mono text-muted">${{ formatVolume(data.previousVolume) }}</span>
              </template>
            </Column>
            
            <Column field="volumeRatio" header="Volume Ratio" style="min-width: 120px">
              <template #body="{ data }">
                <span class="font-mono font-weight-bold text-info">{{ data.volumeRatio.toFixed(2) }}x</span>
              </template>
            </Column>
            
            <Column field="volumeIncrease" header="Volume Increase" style="min-width: 130px">
              <template #body="{ data }">
                <span 
                  class="font-mono font-weight-bold"
                  :class="{
                    'text-success': data.volumeIncrease > 300,
                    'text-warning': data.volumeIncrease > 200 && data.volumeIncrease <= 300,
                    'text-info': data.volumeIncrease <= 200
                  }"
                >
                  +{{ data.volumeIncrease.toFixed(1) }}%
                </span>
              </template>
            </Column>
            
            <Column field="lastUpdate" header="Last Update" style="min-width: 100px">
              <template #body="{ data }">
                <span class="font-mono text-sm">{{ data.lastUpdate }}</span>
              </template>
            </Column>
          </DataTable>
        </div>
      </DraggableContainer>
    </div>
  </div>
</template>

<style scoped>
.volume-screener-table .font-mono {
  font-family: 'Courier New', monospace;
  font-size: 0.9em;
}

.volume-screener-table :deep(.p-datatable-thead th) {
  font-size: 0.75em;
  padding: 0.5rem;
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

.gap-2 > * {
  margin-right: 0.5rem;
}

.gap-2 > *:last-child {
  margin-right: 0;
}
</style>
