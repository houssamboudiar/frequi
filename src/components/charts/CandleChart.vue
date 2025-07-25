<script setup lang="ts">
import type { ChartSliderPosition, IndicatorConfig, PairHistory, PlotConfig, Trade } from '@/types';
import { ChartType } from '@/types';

import ECharts from 'vue-echarts';

import type { EChartsOption, ScatterSeriesOption } from 'echarts';
import { BarChart, CandlestickChart, LineChart, ScatterChart } from 'echarts/charts';
import {
  AxisPointerComponent,
  CalendarComponent,
  DataZoomComponent,
  DatasetComponent,
  GridComponent,
  LegendComponent,
  TimelineComponent,
  TitleComponent,
  ToolboxComponent,
  TooltipComponent,
  VisualMapComponent,
  VisualMapPiecewiseComponent,
  MarkAreaComponent,
  MarkLineComponent,
  // MarkPointComponent,
  GraphicComponent,
} from 'echarts/components';
import { use } from 'echarts/core';
import { CanvasRenderer } from 'echarts/renderers';

use([
  AxisPointerComponent,
  CalendarComponent,
  DatasetComponent,
  DataZoomComponent,
  GridComponent,
  LegendComponent,
  TimelineComponent,
  TitleComponent,
  ToolboxComponent,
  TooltipComponent,
  VisualMapComponent,
  VisualMapPiecewiseComponent,
  MarkAreaComponent,
  MarkLineComponent,
  // MarkPointComponent,

  CandlestickChart,
  BarChart,
  LineChart,
  ScatterChart,
  CanvasRenderer,
  GraphicComponent,
]);

const props = defineProps<{
  trades: Trade[];
  dataset: PairHistory;
  heikinAshi: boolean;
  showMarkArea: boolean;
  useUTC: boolean;
  plotConfig: PlotConfig;
  theme: 'dark' | 'light';
  sliderPosition: ChartSliderPosition | undefined;
  colorUp: string;
  colorDown: string;
  labelSide: 'left' | 'right';
}>();

const isLabelLeft = computed(() => props.labelSide === 'left');
// Chart default options
const MARGINLEFT = isLabelLeft.value ? '5.5%' : '1%';
const MARGINRIGHT = isLabelLeft.value ? '1%' : '5.5%';
const NAMEGAP = 55;
const SUBPLOTHEIGHT = 8; // Value in %

// Candle Colors
const upColor = props.colorUp;
const upBorderColor = props.colorUp;
const downColor = props.colorDown;
const downBorderColor = props.colorDown;

// Buy / Sell Signal Colors
const buySignalColor = '#00ff26';
const shortEntrySignalColor = '#00ff26';
const sellSignalColor = '#faba25';
const shortexitSignalColor = '#faba25';

const candleChart = ref<InstanceType<typeof ECharts>>();
const chartOptions = ref<EChartsOption>({});

const strategy = computed(() => {
  return props.dataset ? props.dataset.strategy : '';
});

const pair = computed(() => {
  return props.dataset ? props.dataset.pair : '';
});

const timeframe = computed(() => {
  return props.dataset ? props.dataset.timeframe : '';
});

const hasData = computed(() => {
  return props.dataset !== null && typeof props.dataset === 'object';
});

const filteredTrades = computed(() => {
  return props.trades.filter((item: Trade) => item.pair === pair.value);
});

const chartTitle = computed(() => {
  return `${strategy.value} - ${pair.value} - ${timeframe.value}`;
});

const diffCols = computed(() => {
  return getDiffColumnsFromPlotConfig(props.plotConfig);
});

usePercentageTool(
  candleChart,
  toRef(() => props.theme),
  toRef(() => props.dataset.timeframe_ms),
);

function updateChart(initial = false) {
  if (!hasData.value) {
    return;
  }
  if (chartOptions.value?.title) {
    chartOptions.value.title[0].text = chartTitle.value;
  }
  // Avoid mutation of dataset.columns array
  const columns = props.dataset.columns.slice();

  const colDate = columns.findIndex((el) => el === '__date_ts');
  const colOpen = columns.findIndex((el) => el === 'open');
  const colHigh = columns.findIndex((el) => el === 'high');
  const colLow = columns.findIndex((el) => el === 'low');
  const colClose = columns.findIndex((el) => el === 'close');
  const colVolume = columns.findIndex((el) => el === 'volume');
  const colEnterTag = columns.findIndex((el) => el === 'enter_tag');
  const colExitTag = columns.findIndex((el) => el === 'exit_tag');

  const colEntryData = columns.findIndex(
    (el) => el === '_buy_signal_close' || el === '_enter_long_signal_close',
  );
  const colExitData = columns.findIndex(
    (el) => el === '_sell_signal_close' || el === '_exit_long_signal_close',
  );

  const colShortEntryData = columns.findIndex((el) => el === '_enter_short_signal_close');
  const colShortExitData = columns.findIndex((el) => el === '_exit_short_signal_close');

  const subplotCount =
    'subplots' in props.plotConfig ? Object.keys(props.plotConfig.subplots).length + 1 : 1;

  if (Array.isArray(chartOptions.value?.dataZoom)) {
    // Only set zoom once ...
    if (initial) {
      const startingZoom = (1 - 250 / props.dataset.length) * 100;
      chartOptions.value.dataZoom.forEach((el, i) => {
        if (chartOptions.value && chartOptions.value.dataZoom) {
          chartOptions.value.dataZoom[i].start = startingZoom;
        }
      });
    } else {
      // Remove start/end settings after chart initialization to avoid chart resetting
      chartOptions.value.dataZoom.forEach((el, i) => {
        if (chartOptions.value && chartOptions.value.dataZoom) {
          delete chartOptions.value.dataZoom[i].start;
          delete chartOptions.value.dataZoom[i].end;
        }
      });
    }
  }
  let dataset = props.heikinAshi
    ? heikinAshiDataset(columns, props.dataset.data)
    : props.dataset.data.slice();

  diffCols.value.forEach(([colFrom, colTo]) => {
    // Enhance dataset with diff columns for area plots
    dataset = calculateDiff(columns, dataset, colFrom, colTo);
  });
  // Add new rows to end to allow slight "scroll past"
  const newArray = Array(dataset.length > 0 ? dataset[dataset.length - 2].length : 0);
  newArray[colDate] = dataset[dataset.length - 1][colDate] + props.dataset.timeframe_ms * 3;
  dataset.push(newArray);

  const options: EChartsOption = {
    dataset: {
      source: dataset,
    },
    grid: [
      {
        left: MARGINLEFT,
        right: MARGINRIGHT,
        // Grid Layout from bottom to top
        bottom: `${subplotCount * SUBPLOTHEIGHT + 2}%`,
      },
      {
        // Volume
        left: MARGINLEFT,
        right: MARGINRIGHT,
        // Grid Layout from bottom to top
        bottom: `${subplotCount * SUBPLOTHEIGHT}%`,
        height: `${SUBPLOTHEIGHT}%`,
      },
    ],

    series: [
      {
        name: 'Candles',
        type: 'candlestick',
        barWidth: '80%',
        itemStyle: {
          color: upColor,
          color0: downColor,
          borderColor: upBorderColor,
          borderColor0: downBorderColor,
        },
        encode: {
          x: colDate,
          // open, close, low, high
          y: [colOpen, colClose, colLow, colHigh],
        },
        ...generateMarkArea(props.dataset, props.showMarkArea),
      },
      {
        name: 'Volume',
        type: 'bar',
        xAxisIndex: 1,
        yAxisIndex: 1,
        itemStyle: {
          color: '#777777',
        },
        large: true,
        encode: {
          x: colDate,
          y: colVolume,
        },
      },
    ],
  };

  if (Array.isArray(options.series)) {
    const signalConfigs = [
      {
        colData: colEntryData,
        name: 'Entry',
        symbol: 'triangle',
        symbolSize: 10,
        color: buySignalColor,
        tooltipPrefix: 'Long entry',
        colTooltip: colEnterTag,
      },
      {
        colData: colExitData,
        name: 'Exit',
        symbol: 'diamond',
        symbolSize: 8,
        color: sellSignalColor,
        tooltipPrefix: 'Long exit',
        colTooltip: colExitTag,
      },
      {
        colData: colShortEntryData,
        name: 'Entry',
        symbol: 'triangle',
        symbolSize: 10,
        symbolRotate: 180,
        color: shortEntrySignalColor,
        tooltipPrefix: 'Short entry',
        colTooltip: colEnterTag,
      },
      {
        colData: colShortExitData,
        name: 'Exit',
        symbol: 'pin',
        symbolSize: 8,
        color: shortexitSignalColor,
        tooltipPrefix: 'Short exit',
        colTooltip: colExitTag,
      },
    ];

    for (const config of signalConfigs) {
      if (config.colData >= 0) {
        options.series.push({
          name: config.name,
          type: 'scatter',
          symbol: config.symbol,
          symbolSize: config.symbolSize,
          symbolRotate: config.symbolRotate ?? 0,
          xAxisIndex: 0,
          yAxisIndex: 0,
          itemStyle: {
            color: config.color,
          },
          tooltip: {
            valueFormatter: (value) => {
              if (Array.isArray(value)) {
                // Show both value and tag
                return value.length > 0 && value[0]
                  ? `${config.tooltipPrefix} ${value[0]} ${value[1]?.toString().substring(0, 100) ? `(${value[1]})` : ''}`
                  : '';
              }
              // Fallback for single value
              return value ? `${config.tooltipPrefix} ${value}` : '';
            },
          },
          encode: {
            x: colDate,
            y: config.colData,
            tooltip:
              config.colTooltip >= 0 ? [config.colData, config.colTooltip] : [config.colData],
          },
        });
      }
    }
  }

  // Merge this into original data
  Object.assign(chartOptions.value, options);

  if ('main_plot' in props.plotConfig) {
    Object.entries(props.plotConfig.main_plot).forEach(([key, value]) => {
      const col = columns.findIndex((el) => el === key);
      if (col > 0) {
        if (!Array.isArray(chartOptions.value?.legend) && chartOptions.value?.legend?.data) {
          chartOptions.value.legend.data.push(key);
        }
        if (Array.isArray(chartOptions.value?.series)) {
          chartOptions.value?.series.push(generateCandleSeries(colDate, col, key, value));

          if (value.fill_to) {
            // Assign
            const fillColKey = `${key}-${value.fill_to}`;
            const fillCol = columns.findIndex((el) => el === fillColKey);
            const fillValue: IndicatorConfig = {
              color: value.color,
              type: ChartType.line,
            };
            const areaSeries = generateAreaCandleSeries(colDate, fillCol, key, fillValue, 0);

            chartOptions.value.series[chartOptions.value.series.length - 1]['stack'] = key;
            chartOptions.value.series.push(areaSeries);
          }
          chartOptions.value?.series.splice(chartOptions.value?.series.length - 1, 0);
        }
      } else {
        console.log(`element ${key} for main plot not found in columns.`);
      }
    });
  }

  // START Subplots
  if ('subplots' in props.plotConfig) {
    let plotIndex = 2;
    Object.entries(props.plotConfig.subplots).forEach(([key, value]) => {
      // define yaxis

      // Subplots are added from bottom to top - only the "bottom-most" plot stays at the bottom.
      // const currGridIdx = totalSubplots - plotIndex > 1 ? totalSubplots - plotIndex : plotIndex;
      const currGridIdx = plotIndex;
      if (Array.isArray(chartOptions.value.yAxis) && chartOptions.value.yAxis.length <= plotIndex) {
        chartOptions.value.yAxis.push({
          scale: true,
          gridIndex: currGridIdx,
          name: key,
          position: props.labelSide,
          nameLocation: 'middle',
          nameGap: NAMEGAP,
          axisLabel: {
            show: true,
            hideOverlap: true,
          },
          axisLine: { show: false },
          axisTick: { show: false },
          splitLine: { show: false },
        });
      }
      if (Array.isArray(chartOptions.value.xAxis) && chartOptions.value.xAxis.length <= plotIndex) {
        chartOptions.value.xAxis.push({
          type: 'time',
          gridIndex: currGridIdx,
          axisLine: { onZero: false },
          axisTick: { show: false },
          axisLabel: { show: false },
          axisPointer: {
            label: { show: false },
          },
          splitLine: { show: false },
          splitNumber: 20,
        });
      }
      if (Array.isArray(chartOptions.value.dataZoom)) {
        chartOptions.value.dataZoom.forEach((el) =>
          el.xAxisIndex && Array.isArray(el.xAxisIndex) ? el.xAxisIndex.push(plotIndex) : null,
        );
      }
      if (chartOptions.value.grid && Array.isArray(chartOptions.value.grid)) {
        chartOptions.value.grid.push({
          left: MARGINLEFT,
          right: MARGINRIGHT,
          bottom: `${(subplotCount - plotIndex + 1) * SUBPLOTHEIGHT}%`,
          height: `${SUBPLOTHEIGHT}%`,
        });
      }
      Object.entries(value).forEach(([sk, sv]) => {
        // entries per subplot
        const col = columns.findIndex((el) => el === sk);
        if (col > 0) {
          if (!Array.isArray(chartOptions.value.legend) && chartOptions.value.legend?.data) {
            chartOptions.value.legend.data.push(sk);
          }
          if (chartOptions.value.series && Array.isArray(chartOptions.value.series)) {
            chartOptions.value.series.push(generateCandleSeries(colDate, col, sk, sv, plotIndex));
            if (sv.fill_to) {
              // Assign
              const fillColKey = `${sk}-${sv.fill_to}`;
              const fillCol = columns.findIndex((el) => el === fillColKey);
              const fillValue: IndicatorConfig = {
                color: sv.color,
                type: ChartType.line,
              };
              const areaSeries = generateAreaCandleSeries(
                colDate,
                fillCol,
                sk,
                fillValue,
                plotIndex,
              );

              chartOptions.value.series[chartOptions.value.series.length - 1]['stack'] = sk;
              chartOptions.value.series.push(areaSeries);
            }
            chartOptions.value?.series.splice(chartOptions.value?.series.length - 1, 0);
          }
        } else {
          console.log(`element ${sk} was not found in the columns.`);
        }
      });

      plotIndex += 1;
    });
  }
  // END Subplots
  // Last subplot should show xAxis labels
  // if (options.xAxis && Array.isArray(options.xAxis)) {
  //   options.xAxis[options.xAxis.length - 1].axisLabel.show = true;
  //   options.xAxis[options.xAxis.length - 1].axisTick.show = true;
  // }
  if (Array.isArray(chartOptions.value.grid)) {
    // Last subplot is bottom
    chartOptions.value.grid[chartOptions.value.grid.length - 1].bottom = '50px';
    delete chartOptions.value.grid[chartOptions.value.grid.length - 1].top;
  }

  const nameTrades = 'Trades';
  if (!Array.isArray(chartOptions.value.legend) && chartOptions.value.legend?.data) {
    // Insert trades into legend, after the default columns
    chartOptions.value.legend.data.splice(4, 0, nameTrades);
  }
  const tradesSeries: ScatterSeriesOption = generateTradeSeries(
    nameTrades,
    props.theme,
    props.dataset,
    filteredTrades.value,
  );
  if (Array.isArray(chartOptions.value.series)) {
    chartOptions.value.series.push(tradesSeries);
  }

  // console.log('chartOptions', chartOptions.value);
  candleChart.value?.setOption(chartOptions.value, {
    replaceMerge: ['series', 'grid', 'yAxis', 'xAxis', 'legend'],
    notMerge: initial,
  });
}

function initializeChartOptions() {
  // Ensure we start empty.
  candleChart.value?.setOption({}, { notMerge: true });

  chartOptions.value = {
    title: [
      {
        // text: this.chartTitle,
        show: false,
      },
    ],
    backgroundColor: 'rgba(0, 0, 0, 0)',
    useUTC: props.useUTC,
    animation: false,
    legend: {
      // Initial legend, further entries are pushed to the below list
      data: ['Candles', 'Volume', 'Entry', 'Exit'],
      right: '1%',
      type: 'scroll',
      pageTextStyle: {
        color: props.theme === 'dark' ? '#dedede' : '#333',
      },
      pageIconColor: props.theme === 'dark' ? '#aaa' : '#2f4554',
      pageIconInactiveColor: props.theme === 'dark' ? '#2f4554' : '#aaa',
    },
    tooltip: {
      show: true,
      trigger: 'axis',
      renderMode: 'richText',
      backgroundColor: 'rgba(80,80,80,0.7)',
      borderWidth: 0,
      textStyle: {
        color: '#fff',
      },
      axisPointer: {
        type: 'cross',
        lineStyle: {
          color: '#cccccc',
          width: 1,
          opacity: 1,
        },
      },
      // positioning copied from https://echarts.apache.org/en/option.html#tooltip.position
      position(pos, params, dom, rect, size) {
        // tooltip will be fixed on the right if mouse hovering on the left,
        // and on the left if hovering on the right.
        const obj = { top: 60 };
        const mouseIsLeft = pos[0] < size.viewSize[0] / 2;
        obj[['left', 'right'][+mouseIsLeft]] = mouseIsLeft ? 5 : 60;
        return obj;
      },
    },
    axisPointer: {
      link: [{ xAxisIndex: 'all' }],
      label: {
        backgroundColor: '#777',
      },
    },
    xAxis: [
      {
        type: 'time',
        axisLine: { onZero: false },
        axisTick: { show: true },
        axisLabel: { show: true },
        axisPointer: {
          label: { show: false },
        },
        position: 'top',
        splitLine: { show: false },
        splitNumber: 20,
        min: 'dataMin',
        max: 'dataMax',
      },
      {
        type: 'time',
        gridIndex: 1,
        axisLine: { onZero: false },
        axisTick: { show: false },
        axisLabel: { show: false },
        axisPointer: {
          label: { show: false },
        },
        splitLine: { show: false },
        splitNumber: 20,
        min: 'dataMin',
        max: 'dataMax',
      },
    ],
    yAxis: [
      {
        scale: true,
        max: (value) => {
          return value.max + (value.max - value.min) * 0.02;
        },
        min: (value) => {
          return value.min - (value.max - value.min) * 0.04;
        },
        position: props.labelSide,
      },
      {
        scale: true,
        gridIndex: 1,
        splitNumber: 2,
        name: 'volume',
        nameLocation: 'middle',
        position: props.labelSide,
        nameGap: NAMEGAP,
        axisLabel: { show: false },
        axisLine: { show: false },
        axisTick: { show: false },
        splitLine: { show: false },
      },
    ],
    dataZoom: [
      // Start values are recalculated once the data is known
      {
        type: 'inside',
        xAxisIndex: [0, 1],
        start: 80,
        end: 100,
      },
      {
        xAxisIndex: [0, 1],
        bottom: 10,
        start: 80,
        end: 100,
        ...dataZoomPartial,
      },
    ],
    // visualMap: {
    //   //  TODO: this would allow to colorize volume bars (if we'd want this)
    //   //  Needs green / red indicator column in data.
    //   show: true,
    //   seriesIndex: 1,
    //   dimension: 5,
    //   pieces: [
    //     {
    //       max: 500000.0,
    //       color: downColor,
    //     },
    //     {
    //       min: 500000.0,
    //       color: upColor,
    //     },
    //   ],
    // },
  };

  console.log('Initialized');
  updateChart(true);
}

function updateSliderPosition() {
  if (!props.sliderPosition) return;

  const start = props.sliderPosition.startValue - props.dataset.timeframe_ms * 40;
  const end = props.sliderPosition.endValue
    ? props.sliderPosition.endValue + props.dataset.timeframe_ms * 40
    : props.sliderPosition.startValue + props.dataset.timeframe_ms * 80;
  if (candleChart.value) {
    candleChart.value.dispatchAction({
      type: 'dataZoom',
      dataZoomIndex: 0,
      startValue: start,
      endValue: end,
    });
  }
}

// const buyData = ref<number[][]>([]);
// const sellData = ref<number[][]>([]);
// createSignalData(colDate: number, colOpen: number, colBuy: number, colSell: number): void {
// Calculate Buy and sell Series
// if (!this.signalsCalculated) {
//   // Generate Buy and sell array (using open rate to display marker)
//   for (let i = 0, len = this.dataset.data.length; i < len; i += 1) {
//     if (this.dataset.data[i][colBuy] === 1) {
//       this.buyData.push([this.dataset.data[i][colDate], this.dataset.data[i][colOpen]]);
//     }
//     if (this.dataset.data[i][colSell] === 1) {
//       this.sellData.push([this.dataset.data[i][colDate], this.dataset.data[i][colOpen]]);
//     }
//   }
//   this.signalsCalculated = true;
// }
// }

onMounted(() => {
  initializeChartOptions();
});

watch([() => props.useUTC, () => props.theme, () => props.plotConfig], () =>
  initializeChartOptions(),
);

watch([() => props.dataset, () => props.heikinAshi, () => props.showMarkArea], () => updateChart());

watch(
  () => props.sliderPosition,
  () => updateSliderPosition(),
);
</script>

<template>
  <div class="h-full w-full">
    <ECharts v-if="hasData" ref="candleChart" :theme="theme" autoresize manual-update />
  </div>
</template>

<style scoped lang="css">
.echarts {
  width: 100%;
  min-height: 200px;
  /* TODO: height calculation is not working correctly - uses min-height for now */
  /* height: 600px; */
  height: 100%;
}
</style>
