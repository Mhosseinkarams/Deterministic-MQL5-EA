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
- Consecutive-Loss Rule: 3 consecutive losses halve risk to 0.5% until 50% recovery.`
  }
];
