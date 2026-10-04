// Simulated candle sequences demonstrating deterministic logic

export interface SimCandle {
  index: number;
  time: string;
  open: number;
  high: number;
  low: number;
  close: number;
  ema21: number;
  ema50: number;
  slowEma: number;
  atr: number;
  structureEvent?: string;
  swingType?: 'HIGH' | 'LOW';
  zoneEvent?: string;
  signalEvent?: string;
  signalDetails?: {
    strategy: string;
    type: string;
    dir: 'BUY' | 'SELL';
    entry: number;
    sl: number;
    tp: number;
    riskPct: number;
    reason: string;
    status: 'EXECUTED' | 'BLOCKED_BY_CONFLICT' | 'BLOCKED_BY_RISK';
  };
}

export interface Scenario {
  id: string;
  title: string;
  strategy: 'MM' | 'SM' | 'UniT_CP' | 'UniT_Moving' | 'Conflict' | 'Risk';
  timeframe: 'M5' | 'M15';
  symbol: string;
  description: string;
  expectedOutcome: string;
  candles: SimCandle[];
}

export const SCENARIOS: Scenario[] = [
  {
    id: 'mm_trend_bounce',
    title: 'MM Standard Trend Bounce (M5)',
    strategy: 'MM',
    timeframe: 'M5',
    symbol: 'EURUSD',
    description: 'Uptrend confirmed with EMA50 > EMA600 (separation > 0.5 ATR). Price pulls back to touch EMA50 and prints a Strong Bullish candle closing above EMA50. SL is placed tightly behind EMA50/bounce candle to avoid prolonged holding times.',
    expectedOutcome: 'MM Standard Buy executed with SL behind EMA50 (1.0811) and TP at 1:2 R:R (1.0883).',
    candles: [
      { index: 1, time: '10:00', open: 1.0820, high: 1.0835, low: 1.0818, close: 1.0832, ema21: 1.0815, ema50: 1.0805, slowEma: 1.0760, atr: 0.0012, structureEvent: 'HH' },
      { index: 2, time: '10:05', open: 1.0832, high: 1.0845, low: 1.0830, close: 1.0842, ema21: 1.0820, ema50: 1.0808, slowEma: 1.0762, atr: 0.0012, structureEvent: 'BOS_BULL' },
      { index: 3, time: '10:10', open: 1.0842, high: 1.0844, low: 1.0825, close: 1.0828, ema21: 1.0822, ema50: 1.0812, slowEma: 1.0764, atr: 0.0012 },
      { index: 4, time: '10:15', open: 1.0828, high: 1.0830, low: 1.0814, close: 1.0816, ema21: 1.0821, ema50: 1.0815, slowEma: 1.0766, atr: 0.0012, zoneEvent: 'EMA50_TOUCH' },
      { 
        index: 5, time: '10:20', open: 1.0816, high: 1.0838, low: 1.0813, close: 1.0835, ema21: 1.0823, ema50: 1.0818, slowEma: 1.0768, atr: 0.0012,
        structureEvent: 'CONFIRMED_HL',
        signalEvent: 'MM_BUY_STANDARD',
        signalDetails: {
          strategy: 'MM',
          type: 'SIGNAL_MM_STANDARD_BUY',
          dir: 'BUY',
          entry: 1.0835,
          sl: 1.0811,
          tp: 1.0883,
          riskPct: 1.0,
          reason: 'MM_BUY_STANDARD|TREND_UP|EMA50_BOUNCE|SL_AGILE',
          status: 'EXECUTED'
        }
      }
    ]
  },
  {
    id: 'sm_supply_refusal',
    title: 'SM Stubborn Man Supply Refusal (M15)',
    strategy: 'SM',
    timeframe: 'M15',
    symbol: 'XAUUSD',
    description: 'Market is in confirmed TREND_RANGE between Demand ($2710) and Supply ($2745). Price tests Supply zone and forms an undeniable Refusal Candle with a 58% upper wick.',
    expectedOutcome: 'SM Range Sell executed. SL strictly above Supply Zone invalidation level; TP near opposing Demand boundary.',
    candles: [
      { index: 1, time: '14:00', open: 2728.5, high: 2736.0, low: 2726.0, close: 2734.0, ema21: 2727.0, ema50: 2726.5, slowEma: 2725.0, atr: 4.5, structureEvent: 'RANGE_OSCILLATION' },
      { index: 2, time: '14:15', open: 2734.0, high: 2742.0, low: 2732.5, close: 2740.0, ema21: 2729.0, ema50: 2727.5, slowEma: 2725.2, atr: 4.6, zoneEvent: 'SUPPLY_ZONE_TEST' },
      { 
        index: 3, time: '14:30', open: 2740.0, high: 2746.5, low: 2736.0, close: 2737.5, ema21: 2730.5, ema50: 2728.0, slowEma: 2725.5, atr: 4.8,
        structureEvent: 'REFUSAL_CANDLE_58%_WICK',
        signalEvent: 'SM_SELL_RANGE',
        signalDetails: {
          strategy: 'SM',
          type: 'SIGNAL_SM_RANGE_SELL',
          dir: 'SELL',
          entry: 2737.5,
          sl: 2747.5,
          tp: 2715.0,
          riskPct: 1.0,
          reason: 'SM_SELL|RANGE_CONFIRMED|SUPPLY_TOUCH|REFUSAL_UPPER_WICK',
          status: 'EXECUTED'
        }
      }
    ]
  },
  {
    id: 'unit_cp_spike',
    title: 'UniT CP Spike & Last-Pivot SL (M5)',
    strategy: 'UniT_CP',
    timeframe: 'M5',
    symbol: 'GBPUSD',
    description: 'Impulsive 3-bar spike move up without pullbacks. Pullback candle breaches previous bar low. When price retests Spike High, SL is placed strictly at the LAST PIVOT (1.2982), avoiding oversized risk and prolonged holding times.',
    expectedOutcome: 'UniT CP Buy executed with agile SL placed at the Last Pivot (1.2982) rather than deep macro origin.',
    candles: [
      { index: 1, time: '09:00', open: 1.2950, high: 1.2975, low: 1.2948, close: 1.2972, ema21: 1.2940, ema50: 1.2930, slowEma: 1.2900, atr: 0.0015, structureEvent: 'SPIKE_BAR_1' },
      { index: 2, time: '09:05', open: 1.2972, high: 1.2995, low: 1.2970, close: 1.2990, ema21: 1.2948, ema50: 1.2935, slowEma: 1.2902, atr: 0.0015, structureEvent: 'SPIKE_BAR_2' },
      { index: 3, time: '09:10', open: 1.2990, high: 1.3015, low: 1.2988, close: 1.3010, ema21: 1.2958, ema50: 1.2940, slowEma: 1.2905, atr: 0.0015, structureEvent: 'SPIKE_HIGH_1.3015' },
      { index: 4, time: '09:15', open: 1.3010, high: 1.3012, low: 1.2980, close: 1.2985, ema21: 1.2965, ema50: 1.2945, slowEma: 1.2908, atr: 0.0015, structureEvent: 'PULLBACK_CANDLE' },
      { 
        index: 5, time: '09:20', open: 1.2985, high: 1.3018, low: 1.2982, close: 1.3016, ema21: 1.2972, ema50: 1.2950, slowEma: 1.2910, atr: 0.0015,
        structureEvent: 'LAST_PIVOT_AT_1.2982',
        signalEvent: 'UNIT_CP_BUY',
        signalDetails: {
          strategy: 'UniT_CP',
          type: 'SIGNAL_UNIT_CP_BUY',
          dir: 'BUY',
          entry: 1.3016,
          sl: 1.2980,
          tp: 1.3088,
          riskPct: 1.0,
          reason: 'UNIT_CP_BUY|SPIKE_RETEST|LAST_PIVOT_SL_1.2980|RISK_FACTORS_0',
          status: 'EXECUTED'
        }
      }
    ]
  },
  {
    id: 'unit_moving_behind_ema',
    title: 'UniT Moving: SL Behind EMA21 (M5)',
    strategy: 'UniT_Moving',
    timeframe: 'M5',
    symbol: 'DAXEUR',
    description: 'Price pulls back into EMA21 on DAX M5 in a confirmed trend. Signal fires and Stop Loss is placed strictly behind the EMA 21 line, preventing the SL from stretching to distant swings from 50 bars ago!',
    expectedOutcome: 'UniT Moving Buy executed with tight SL anchored behind EMA21 (24835.0 vs entry 24860.0).',
    candles: [
      { index: 1, time: '11:00', open: 24820.0, high: 24845.0, low: 24815.0, close: 24840.0, ema21: 24820.0, ema50: 24780.0, slowEma: 24650.0, atr: 25.0, structureEvent: 'TREND_UP' },
      { index: 2, time: '11:05', open: 24840.0, high: 24870.0, low: 24835.0, close: 24865.0, ema21: 24830.0, ema50: 24790.0, slowEma: 24655.0, atr: 26.0, structureEvent: 'HH' },
      { index: 3, time: '11:10', open: 24865.0, high: 24868.0, low: 24840.0, close: 24842.0, ema21: 24838.0, ema50: 24800.0, slowEma: 24660.0, atr: 25.0, zoneEvent: 'EMA21_TEST' },
      { 
        index: 4, time: '11:15', open: 24842.0, high: 24875.0, low: 24838.0, close: 24870.0, ema21: 24842.0, ema50: 24805.0, slowEma: 24665.0, atr: 25.0,
        structureEvent: 'EMA21_BOUNCE',
        signalEvent: 'UNIT_MOVING_BUY',
        signalDetails: {
          strategy: 'UniT_Moving',
          type: 'SIGNAL_UNIT_MOVING_STD_BUY',
          dir: 'BUY',
          entry: 24870.0,
          sl: 24839.5, // Placed strictly behind EMA 21!
          tp: 24925.0,
          riskPct: 1.0,
          reason: 'UNIT_MOVING_STD_BUY|TREND_UP|EMA21_TOUCH_BOUNCE|SL_BEHIND_EMA21',
          status: 'EXECUTED'
        }
      }
    ]
  },
  {
    id: 'conflict_block',
    title: 'Conflict Manager: Block MM in Range',
    strategy: 'Conflict',
    timeframe: 'M5',
    symbol: 'EURUSD',
    description: 'Market has formed 2 consecutive CHOCHs and is classified as TREND_RANGE. An intra-day bounce occurs at EMA50 that mimics MM conditions.',
    expectedOutcome: 'Conflict Manager RULE 1 intercepts the candidate signal and strictly BLOCKS execution.',
    candles: [
      { index: 1, time: '11:00', open: 1.0850, high: 1.0860, low: 1.0845, close: 1.0848, ema21: 1.0850, ema50: 1.0852, slowEma: 1.0850, atr: 0.0011, structureEvent: 'CHOCH_BEAR' },
      { index: 2, time: '11:05', open: 1.0848, high: 1.0862, low: 1.0846, close: 1.0860, ema21: 1.0851, ema50: 1.0852, slowEma: 1.0850, atr: 0.0011, structureEvent: 'CHOCH_BULL_RANGE' },
      { 
        index: 3, time: '11:10', open: 1.0850, high: 1.0868, low: 1.0849, close: 1.0866, ema21: 1.0853, ema50: 1.0852, slowEma: 1.0850, atr: 0.0011,
        signalEvent: 'MM_CANDIDATE_ATTEMPT',
        signalDetails: {
          strategy: 'MM',
          type: 'SIGNAL_MM_STANDARD_BUY',
          dir: 'BUY',
          entry: 1.0866,
          sl: 1.0848,
          tp: 1.0902,
          riskPct: 1.0,
          reason: 'REJECT_RANGE_CONFLICT: Conflict Manager Rule 1 blocked trend strategy during confirmed RANGE regime',
          status: 'BLOCKED_BY_CONFLICT'
        }
      }
    ]
  },
  {
    id: 'hard_kill_switch',
    title: 'Risk Engine: 3.8% Hard Kill Emergency Halt',
    strategy: 'Risk',
    timeframe: 'M5',
    symbol: 'EURUSD',
    description: 'Unusual black-swan market volatility causes cumulative daily drawdown to cross 3.8%.',
    expectedOutcome: 'Hard Kill switch trips immediately on tick. Position Manager liquidates all positions and halts all new orders for the remainder of the calendar day.',
    candles: [
      { index: 1, time: '16:00', open: 1.0800, high: 1.0805, low: 1.0750, close: 1.0755, ema21: 1.0800, ema50: 1.0810, slowEma: 1.0830, atr: 0.0025, structureEvent: 'DRAWDOWN_3.2%' },
      { 
        index: 2, time: '16:05', open: 1.0755, high: 1.0760, low: 1.0720, close: 1.0725, ema21: 1.0785, ema50: 1.0805, slowEma: 1.0830, atr: 0.0030,
        structureEvent: 'DRAWDOWN_3.85%_TRIPPED',
        signalEvent: 'HARD_KILL_ACTIVATED',
        signalDetails: {
          strategy: 'RiskEngine',
          type: 'SIGNAL_NONE',
          dir: 'BUY',
          entry: 0,
          sl: 0,
          tp: 0,
          riskPct: 0,
          reason: 'CRITICAL: Hard kill switch triggered! Daily Drawdown: 3.85% >= 3.80%. All open positions liquidated at market.',
          status: 'BLOCKED_BY_RISK'
        }
      }
    ]
  }
];
