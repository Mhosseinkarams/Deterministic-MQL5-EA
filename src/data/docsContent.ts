// Documentation registry for the web app reader

export interface DocArticle {
  id: string;
  title: string;
  category: string;
  filename: string;
  content: string;
}

export const DOCS_ARTICLES: DocArticle[] = [
  {
    id: 'architecture',
    title: 'System Architecture',
    category: 'Core System',
    filename: 'docs/architecture.md',
    content: `# Deterministic MQL5 EA System Architecture

## Executive Overview
The **Deterministic Trading Expert Advisor (EA)** is a 100% rule-based, quantitative algorithmic trading system engineered for MetaTrader 5 (MT5). It unifies three distinct strategies:
1. **MM**: Trend-following and mean-reversion using EMA50 and slow EMA (EMA600 on M5, EMA800 on M15).
2. **SM (Stubborn Man)**: Structural range trading capitalizing on confirmed supply and demand boundaries and refusal candle price action.
3. **UniT**: Momentum spike and pullback retest (**UniT CP**) and dynamic EMA21 trend following (**UniT Moving**).

---

## Absolute Determinism Constraint
This system strictly prohibits:
- Machine Learning (ML), Deep Learning (DL), Neural Networks, and Reinforcement Learning (RL).
- Large Language Models (LLMs) and sentiment analysis (Twitter/X, Reddit, news scraping).
- Economic calendars, fundamental events, and external API predictions.
- Python runtime dependencies or ONNX models.

Every single decision is mathematically and structurally derived from:
- Closed OHLCV candle bars and Tick Volume.
- Zero-lookahead confirmed swing highs and lows.
- Verified Break of Structure (BOS) and Change of Character (CHOCH).
- Dynamic, strictly validated Supply & Demand zones.
- Exponential Moving Averages (EMA 21, 50, 600, 800) and ATR(14).
- A centralized, non-bypassable Risk & Capital Protection Engine.`
  },
  {
    id: 'market_structure',
    title: 'Market Structure Engine',
    category: 'Engines',
    filename: 'docs/market_structure.md',
    content: `# Deterministic Market Structure Engine

## Overview
The \`CMarketStructureEngine\` identifies structural extremes and transitions in the market without lookahead bias. It eliminates naive pivot indicators that repaint or look into the future.

### Confirmed vs Developing Structure
- **Candidate Extreme**: Bar C has higher high than L left bars.
- **Confirmation Delay**: Bar C is ONLY marked as a confirmed Swing High/Low when R subsequent closed bars have closed lower.
- **Default Parameters**: \`InpSwingLeftBars = 3\`, \`InpSwingRightBars = 3\`.
- **Lookahead Prevention**: When evaluating at shift 1, the most recent swing that can possibly be confirmed occurred at shift 4.`
  },
  {
    id: 'supply_demand',
    title: 'Supply & Demand Engine',
    category: 'Engines',
    filename: 'docs/supply_demand.md',
    content: `# Deterministic Supply & Demand Engine

## Overview
The \`CSupplyDemandEngine\` manages institutional order blocks and imbalance zones with a strict, state-machine-driven lifecycle.

### Zone Lifecycle States
- **ZONE_FRESH**: Zone has never been retested since departure. Highest strength.
- **ZONE_TESTED**: Price has wicked into the zone once and reversed out. Reliable for Stubborn Man trades.
- **ZONE_WEAKENED**: Zone has absorbed 2 or more touches. Institutional liquidity is depleted.
- **ZONE_BROKEN**: A closed candle penetrates completely through the zone boundary.`
  },
  {
    id: 'trend_engine',
    title: 'Trend & Range Engine',
    category: 'Engines',
    filename: 'docs/trend_engine.md',
    content: `# Deterministic Trend & Range Engine

## Overview
The \`CTrendEngine\` acts as the master regime classifier. It categorizes market conditions into four mutually exclusive states without probabilistic estimation:
1. \`TREND_UP\`
2. \`TREND_DOWN\`
3. \`TREND_RANGE\`
4. \`TREND_TRANSITION\` (or \`UNCLEAR\`)`
  },
  {
    id: 'strategy_mm',
    title: 'Strategy 1: MM',
    category: 'Strategies',
    filename: 'docs/strategies/mm.md',
    content: `# Strategy 1: MM (Trend & Dynamic EMA Strategy)

## Core Philosophy
MM is a **trend-following** strategy operating on M5 and M15 timeframes. It relies on the dynamic relationship between **EMA50** and the **Slow EMA**:
- **M5 Timeframe**: EMA 50 & EMA 600.
- **M15 Timeframe**: EMA 50 & EMA 800.

### Critical Rule on Slow EMA
> **The Slow EMA (EMA600 / EMA800) does NOT independently trigger entries.**
> Crossing the Slow EMA never generates a signal by itself. It serves exclusively for trend orientation, slope alignment, separation measurement, and risk boundaries.`
  },
  {
    id: 'strategy_sm',
    title: 'Strategy 2: SM (Stubborn Man)',
    category: 'Strategies',
    filename: 'docs/strategies/sm.md',
    content: `# Strategy 2: SM (Stubborn Man Range Strategy)

## Core Philosophy
**SM stands for STUBBORN MAN.**
It is strictly an institutional **range-boundary exploitation** strategy. It is NOT Smart Money Concepts (SMC) as an independent trend strategy.

### Primary Rule of Engagement
> **SM executes ONLY when the market is confirmed in \`TREND_RANGE\`.**
> It is strictly blocked during confirmed \`TREND_UP\` or \`TREND_DOWN\` by the Strategy Conflict Manager.`
  },
  {
    id: 'strategy_unit',
    title: 'Strategy 3: UniT (CP & Moving)',
    category: 'Strategies',
    filename: 'docs/strategies/unit.md',
    content: `# Strategy 3: UniT (CP & Moving Signals)

## Overview
The UniT system consists of two distinct components:
1. **UniT CP**: Spike & Pullback Retest.
2. **UniT Moving**: EMA21 Dynamic Follower.

> **ABSOLUTE RULE**: UniT does **NOT** contain a reversal signal.

### Exact Pullback Definition
> *"A candle constitutes a pullback if it sees beyond the high/low of the candle immediately before it."*

### Agile Stop Loss Architecture
- **UniT CP Stop Loss**: Placed strictly at the **Last Pivot** (the local pivot low for Buy, local pivot high for Sell) rather than a deep, distant pullback origin, preventing excessive holding duration.
- **UniT Moving Stop Loss**: Placed strictly **behind the EMA 21** line (plus tight buffer), keeping risk tight and trade velocity high.`
  },
  {
    id: 'risk_management',
    title: 'Risk & Capital Protection',
    category: 'Risk',
    filename: 'docs/risk_management.md',
    content: `# Deterministic Risk & Capital Protection Engine

## Sovereign Authority
The \`CRiskEngine\` exercises absolute, non-bypassable authority over the execution pipeline. No strategy can execute an order without passing every risk constraint:
- Max Risk Per Trade: 1.0%
- Max Daily Drawdown: 4.0%
- Hard Kill Switch: 3.8% (liquidates all open trades and halts trading)
- Consecutive-Loss Rule: 3 consecutive losses halve risk to 0.5% until 50% recovery.

## Dual Take Profit Modes (Auto vs Manual)
- **Auto Mode (\`TP_MODE_AUTO\`)**: The EA dynamically assigns the TP size per strategy (e.g. 2R for MM Trend and UniT CP, 1.8R for UniT Moving, 1.5R for High-Risk, 2.5R for Reversals).
- **Manual Mode (\`TP_MODE_MANUAL\`)**: The user selects a fixed target multiple (\`InpManualTpMultiple\`, e.g. 1.0 = 1R, 2.0 = 2R, 3.0 = 3R) which is applied uniformly across all signals.`
  },
  {
    id: 'self_optimization',
    title: 'Self-Optimization Engine',
    category: 'Optimization',
    filename: 'docs/self_optimization.md',
    content: `# Self-Optimization & Attribution Core: Dual-Engine Architecture

## Executive Overview
The **Self-Optimization Engine** (\`CSelfOptimizer\`) equips the Expert Advisor with adaptive mathematical self-tuning to overcome market regime shifts. To cater to different quantitative trading styles, the EA provides two distinct optimization modes:

1. **Option 1: Classic Quant Optimization** (\`OPT_CORE_CLASSIC\`)
   - Pure statistical trade attribution, discrete volatility corridor regimes, rolling win rate and profit factor thresholds, and rule-based dynamic TP calibration.
   - 100% deterministic, zero curve-fitting, highly transparent, and fully audit-trail compliant.

2. **Option 2: Smart Neural Network Optimization** (\`OPT_CORE_NEURAL\`)
   - Native on-device Deep Multi-Layer Perceptron (MLP) with online backpropagation learning directly executed in pure MQL5 without any external Python servers, cloud calls, or DLLs.
   - 6 Input features -> 8 Hidden-1 (Tanh) -> 6 Hidden-2 (Tanh) -> 4 Continuous Outputs (Sigmoid).
   - Continuously adapts risk weights (0.30x-1.40x), setup win confidence (0-100%), dynamic TP multiples (1.4R-3.0R), and continuous volatility buffer scaling (0.80x-1.35x).

---

## 1. Option 1: Classic Quant Optimization Details
- **Attribution Memory**: Ring buffer tracking the last N closed trades per strategy.
- **Probation Trigger**: PF < 0.80 OR WR < 35.0% OR >= 3 consecutive losses. Strategy risk halved to **0.50x** (or **0.35x** in Aggressive mode).
- **High-Edge Boost**: PF >= 1.60 AND WR >= 58.0%. Strategy risk elevated to **1.20x** (or **1.30x** in Aggressive mode).
- **Discrete Volatility Corridors**:
  - Volatility Ratio = ATR(14) / ATR(100)
  - Compression (< 0.75): Buffer Scalar = **0.85x**
  - Normal (0.75 - 1.35): Buffer Scalar = **1.00x**
  - Expansion (> 1.35): Buffer Scalar = **1.25x** (or 1.35x aggressive)
- **Auto-TP Calibration**: Runners boosted by +0.4R (up to 3.0R); stalls tightened by -0.3R (down to 1.4R).

---

## 2. Option 2: Smart Neural Network Optimization Details
- **Topology**: 6 Input Features -> 8 Hidden-1 (Tanh) -> 6 Hidden-2 (Tanh) -> 4 Domain-Scaled Outputs (Sigmoid).
- **6 Real-Time Inputs**:
  1. Normalized Volatility Ratio (ATR14 / ATR100 - 1.0)
  2. Structural Regime Alignment (+0.8 Bull/Expansion, -0.8 Bear/Compression, 0.0 Normal)
  3. Strategy Win Rate Momentum (WR / 50.0 - 1.0)
  4. Normalized Profit Factor (min(PF, 3.0) / 1.5 - 1.0)
  5. Consecutive Loss Penalty (min(Losses, 5) / 2.5 - 1.0)
  6. Average Realized R Momentum (avgR / 1.5 - 1.0)
- **4 Continuous Predictions**:
  - **Risk Weight**: 0.30x to 1.40x
  - **Win Confidence**: 0.0% to 100.0%
  - **Dynamic TP Target**: 1.4R to 3.0R
  - **Volatility Buffer Scalar**: 0.80x to 1.35x
- **Supervised Online Backpropagation**:
  - Upon each closed trade (\`OnTradeClosed\`), executes an online gradient descent pass with learning rate eta=0.05 and momentum alpha=0.10.
  - Zero lag: weights adapt immediately to live broker conditions without waiting for weekend offline re-training.

---

## 3. Input Parameter Configuration
\`\`\`mql5
input group "=== Self-Optimization Engine ==="
input ENUM_OPTIMIZER_CORE InpSelfOptCore        = OPT_CORE_CLASSIC;  // Option 1: Classic Quant vs Option 2: Smart Neural Network
input ENUM_SELF_OPT_MODE InpSelfOptMode         = SELF_OPT_ADAPTIVE; // Mode (Disabled/Adaptive/Aggressive)
input int               InpSelfOptRollingTrades = 30;                // Rolling Attribution Window (Trades)
input int               InpSelfOptMinEvalTrades = 4;                 // Min Trades for Strategy Weight Calibration
input bool              InpSelfOptAdaptiveVol   = true;              // Adaptive Volatility Buffer Scaling
input bool              InpSelfOptAdaptiveWeight= true;              // Adaptive Strategy Risk Weighting
input bool              InpSelfOptAdaptiveTp    = true;              // Adaptive Take Profit R-Multiple Optimization
\`\`\`

---

## 4. Central Sovereign Safeguards
Regardless of which optimization core is chosen:
1. **Hard Kill Authority Prevails**: Risk Engine limits (4.0% daily loss, 3.8% Hard Kill, 0.5% consecutive-loss throttle) maintain sovereign authority.
2. **Deterministic Bounded Domains**: Neural network outputs are strictly bounded via hard clamped affine domain mappings to prevent runaway model states.
3. **Live MT5 Chart Telemetry**: Active engine state is rendered continuously on chart comments and the MT5 terminal journal.`
  }
];
