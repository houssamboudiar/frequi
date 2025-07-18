<script setup lang="ts">
import { ref, onMounted } from 'vue';
import DataTable from 'primevue/datatable';
import Column from 'primevue/column';
import Button from 'primevue/button';

interface DailyVolumeRow {
  date: string;
  symbol: string;
  totalVolume: number;
  buyingVolume: number;
  sellingVolume: number;
}

const coins = ref<string[]>([]);

interface CoinVolumeRow {
  symbol: string;
  date: string;
  totalVolume: number;
  totalVolumeAvg3: number;
  totalVolumeAvg5: number;
  totalVolumeAvg15: number;
  buyingVolume: number;
  buyingVolumeAvg3: number;
  buyingVolumeAvg5: number;
  buyingVolumeAvg15: number;
  sellingVolume: number;
  sellingVolumeAvg3: number;
  sellingVolumeAvg5: number;
  sellingVolumeAvg15: number;
}


const tableData = ref<CoinVolumeRow[]>([]);
const loading = ref(false);
const search = ref('');

const filteredData = computed(() => {
  if (!search.value.trim()) return tableData.value;
  return tableData.value.filter(row =>
    row.symbol.toLowerCase().includes(search.value.trim().toLowerCase())
  );
});


async function fetchAllCoinsVolume() {
  loading.value = true;
  try {
    // If coins list is empty, fetch all symbols from Binance
    if (coins.value.length === 0) {
      const infoResp = await fetch('https://api.binance.com/api/v3/exchangeInfo');
      const info = await infoResp.json();
      // Filter for spot USDT pairs only, status TRADING
      coins.value = info.symbols
        .filter((s: any) => s.status === 'TRADING' && s.quoteAsset === 'USDT' && !s.symbol.includes('UPUSDT') && !s.symbol.includes('DOWNUSDT') && !s.symbol.includes('BULLUSDT') && !s.symbol.includes('BEARUSDT'))
        .map((s: any) => s.symbol);
    }
    const results: CoinVolumeRow[] = [];
    await Promise.all(
      coins.value.map(async (symbol) => {
        try {
          const response = await fetch(
            `https://api.binance.com/api/v3/klines?symbol=${symbol}&interval=1d&limit=30`
          );
          const candles = await response.json();
          if (!Array.isArray(candles) || candles.length === 0) return;
          // Sort by openTime ascending
          candles.sort((a, b) => a[0] - b[0]);

          // Use the latest fully closed daily candle (not in-progress)
          let lastIdx = candles.length - 1;
          const now = Date.now();
          if (candles[lastIdx][6] > now) {
            lastIdx -= 1;
          }
          // Use quote asset volume (field 7, USDT) for all calculations
          const candle = candles[lastIdx];
          console.log('DEBUG', symbol, 'candle:', candle);
          const totalVolume = parseFloat(candle[7]); // field 7
          // For buying/selling, use taker buy quote asset volume (field 10, USDT) if available, else fallback to 0
          // See Binance API: field 10 is taker buy quote asset volume
          const buyingVolume = candle[10] !== undefined ? parseFloat(candle[10]) : 0;
          const sellingVolume = totalVolume - buyingVolume;
          const openTime = candle[0];

          // Helper to compute rolling average for quote asset volume (field 7), EXCLUDING the latest day
          function avgQuoteVol(days: number) {
            if (lastIdx - days < 0) return 0;
            let sum = 0;
            for (let i = lastIdx - days; i < lastIdx; i++) {
              sum += parseFloat(candles[i][7]);
            }
            return sum / days;
          }
          // Helper for buying volume in quote asset (field 10, USDT)
          function avgBuyingVol(days: number) {
            if (lastIdx - days < 0) return 0;
            let sum = 0;
            for (let i = lastIdx - days; i < lastIdx; i++) {
              sum += candles[i][10] !== undefined ? parseFloat(candles[i][10]) : 0;
            }
            return sum / days;
          }
          function avgSellingVol(days: number) {
            if (lastIdx - days < 0) return 0;
            let sum = 0;
            for (let i = lastIdx - days; i < lastIdx; i++) {
              const quoteVol = parseFloat(candles[i][7]);
              const buyVol = candles[i][10] !== undefined ? parseFloat(candles[i][10]) : 0;
              sum += quoteVol - buyVol;
            }
            return sum / days;
          }

          const totalVolumeAvg3 = avgQuoteVol(3);
          const totalVolumeAvg5 = avgQuoteVol(5);
          const totalVolumeAvg15 = avgQuoteVol(15);
          const buyingVolumeAvg3 = avgBuyingVol(3);
          const buyingVolumeAvg5 = avgBuyingVol(5);
          const buyingVolumeAvg15 = avgBuyingVol(15);
          const sellingVolumeAvg3 = avgSellingVol(3);
          const sellingVolumeAvg5 = avgSellingVol(5);
          const sellingVolumeAvg15 = avgSellingVol(15);

          results.push({
            symbol,
            date: new Date(openTime).toLocaleDateString(),
            totalVolume,
            totalVolumeAvg3,
            totalVolumeAvg5,
            totalVolumeAvg15,
            buyingVolume,
            buyingVolumeAvg3,
            buyingVolumeAvg5,
            buyingVolumeAvg15,
            sellingVolume,
            sellingVolumeAvg3,
            sellingVolumeAvg5,
            sellingVolumeAvg15,
          });
        } catch (err) {
          // skip failed symbol
        }
      })
    );
    tableData.value = results;
  } catch (e) {
    tableData.value = [];
  } finally {
    loading.value = false;
  }
}

onMounted(() => {
  fetchAllCoinsVolume();
});

function formatVolume(v: number) {
  if (v >= 1e9) return (v / 1e9).toFixed(2) + 'B';
  if (v >= 1e6) return (v / 1e6).toFixed(2) + 'M';
  if (v >= 1e3) return (v / 1e3).toFixed(2) + 'K';
  return v.toFixed(2);
}
</script>

<template>
  <div class="container-fluid p-4">
    <h1 class="mb-4">Daily Volume Overview</h1>
    <div class="mb-3 d-flex align-items-center gap-3">
      <input
        v-model="search"
        type="text"
        class="form-control w-auto"
        placeholder="Search symbol..."
        style="min-width: 180px;"
      />
      <Button :loading="loading" icon="pi pi-refresh" label="Refresh" class="p-button-sm" @click="fetchAllCoinsVolume" />
    </div>
    <DataTable :value="filteredData" :loading="loading" class="volume-analysis-table" :rows="tableData.length" :sortMode="'multiple'">
      <Column field="symbol" header="Symbol" style="min-width: 100px; font-family: 'Inter', 'Segoe UI', Arial, sans-serif; font-weight: 600; font-size: 1.1em; letter-spacing: 0.5px;" sortable>
        <template #body="{ data }">
          <span class="coin-symbol">{{ data.symbol }}</span>
        </template>
      </Column>
      <Column field="totalVolume" header="Total Volume" style="min-width: 120px" sortable>
        <template #body="{ data }">
          <span class="number-cell text-primary">${{ formatVolume(data.totalVolume) }}</span>
        </template>
      </Column>
      <Column field="totalVolumeAvg3" header="Total Vol Avg (3d)" style="min-width: 120px" sortable>
        <template #body="{ data }">
          <span class="number-cell">${{ formatVolume(data.totalVolumeAvg3) }}</span>
        </template>
      </Column>
      <Column field="totalVolumeAvg5" header="Total Vol Avg (5d)" style="min-width: 120px" sortable>
        <template #body="{ data }">
          <span class="number-cell">${{ formatVolume(data.totalVolumeAvg5) }}</span>
        </template>
      </Column>
      <Column field="totalVolumeAvg15" header="Total Vol Avg (15d)" style="min-width: 120px" sortable>
        <template #body="{ data }">
          <span class="number-cell">${{ formatVolume(data.totalVolumeAvg15) }}</span>
        </template>
      </Column>
      <Column field="buyingVolume" header="Buying Volume" style="min-width: 120px" sortable>
        <template #body="{ data }">
          <span class="number-cell text-success">${{ formatVolume(data.buyingVolume) }}</span>
        </template>
      </Column>
      <Column field="buyingVolumeAvg3" header="Buying Vol Avg (3d)" style="min-width: 120px" sortable>
        <template #body="{ data }">
          <span class="number-cell">${{ formatVolume(data.buyingVolumeAvg3) }}</span>
        </template>
      </Column>
      <Column field="buyingVolumeAvg5" header="Buying Vol Avg (5d)" style="min-width: 120px" sortable>
        <template #body="{ data }">
          <span class="number-cell">${{ formatVolume(data.buyingVolumeAvg5) }}</span>
        </template>
      </Column>
      <Column field="buyingVolumeAvg15" header="Buying Vol Avg (15d)" style="min-width: 120px" sortable>
        <template #body="{ data }">
          <span class="number-cell">${{ formatVolume(data.buyingVolumeAvg15) }}</span>
        </template>
      </Column>
      <Column field="sellingVolume" header="Selling Volume" style="min-width: 120px" sortable>
        <template #body="{ data }">
          <span class="number-cell text-danger">${{ formatVolume(data.sellingVolume) }}</span>
        </template>
      </Column>
      <Column field="sellingVolumeAvg3" header="Selling Vol Avg (3d)" style="min-width: 120px" sortable>
        <template #body="{ data }">
          <span class="number-cell">${{ formatVolume(data.sellingVolumeAvg3) }}</span>
        </template>
      </Column>
      <Column field="sellingVolumeAvg5" header="Selling Vol Avg (5d)" style="min-width: 120px" sortable>
        <template #body="{ data }">
          <span class="number-cell">${{ formatVolume(data.sellingVolumeAvg5) }}</span>
        </template>
      </Column>
      <Column field="sellingVolumeAvg15" header="Selling Vol Avg (15d)" style="min-width: 120px" sortable>
        <template #body="{ data }">
          <span class="number-cell">${{ formatVolume(data.sellingVolumeAvg15) }}</span>
        </template>
      </Column>
    </DataTable>
  </div>
</template>

<style scoped>
.number-cell {
  font-family: 'JetBrains Mono', 'Fira Mono', 'Menlo', 'Consolas', monospace;
  font-size: 1.08em;
  font-variant-numeric: tabular-nums;
}
.coin-symbol {
  font-family: 'Inter', 'Segoe UI', Arial, sans-serif;
  font-weight: 600;
  font-size: 1.1em;
  letter-spacing: 0.5px;
}
.text-success { color: #28a745; }
.text-danger { color: #dc3545; }
.text-primary { color: #007bff; }
</style>
