# Deterministic MQL5 EA System Architecture

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
- A centralized, non-bypassable Risk & Capital Protection Engine.

---

## Core Decision Pipeline
```
                  Market Data (M5 / M15 Closed Candles)
                                    ↓
                       Indicator Engine (iMA, iATR)
                                    ↓
                   Market Structure Engine (Zero-Lookahead)
                                    ↓
                         Supply / Demand Engine
                                    ↓
                       Trend / Range Classifier
                                    ↓
             ┌──────────────────────┼──────────────────────┐
             ↓                      ↓                      ↓
         MM Strategy           SM Strategy           UniT Strategy
        (Trend/Bounce)           (Range)             (CP & Moving)
             └──────────────────────┼──────────────────────┘
                                    ↓
                        Strategy Conflict Manager
                                    ↓
                      Central Risk Authority Engine
                                    ↓
                       Trade Execution Layer (CTrade)
                                    ↓
                         Position Lifecycle Manager
                                    ↓
                         Auditable Journal & Logger
                                    ↓
                        Chart Debug & Visualizer
```

---

## Engine Modules Breakdown

| Module | File | Purpose |
| :--- | :--- | :--- |
| `Defines.mqh` | Shared definitions | Enums, state machines, trade signal objects, and reason codes. |
| `CandleEngine.mqh` | Candle analysis | Mathematical metrics (body/wick ratios, ATR ratio, pinbars, refusal candles). |
| `Indicators.mqh` | Indicator handles | Managed iMA (21, 50, 600, 800) and iATR handles for M5 and M15. |
| `MarketStructure.mqh`| Structural pivots | Confirmed swings (left/right confirmation delay), HH/HL/LH/LL, BOS, and CHOCH. |
| `SupplyDemand.mqh` | S/D zones | Dynamic zone creation, freshness (Fresh, Tested, Weakened, Broken), and invalidation. |
| `TrendEngine.mqh` | Regime classification| Deterministic classification: `TREND_UP`, `TREND_DOWN`, `TREND_RANGE`, `TREND_TRANSITION`. |
| `StrategyMM.mqh` | MM Strategy | Standard Trend Bounce, High-Risk Momentum Cross, and Reversal setups. |
| `StrategySM.mqh` | Stubborn Man | Range Channel detection, Supply/Demand boundaries, refusal rejection candles. |
| `StrategyUniT.mqh` | UniT Suite | CP spike & first pullback retest (exact high/low breach rule), Moving EMA21. |
| `ConflictManager.mqh`| Arbitration | Prevents regime conflicts (no trend trades in range; no range trades in trend). |
| `RiskEngine.mqh` | Capital protection | 4.0% daily max loss, 3.8% hard kill switch, consecutive loss halving, lot sizing. |
| `ExecutionEngine.mqh`| Order routing | OrderSend / CTrade abstraction, slippage control, volume normalization, retries. |
| `PositionManager.mqh`| Trade lifecycle | EOD liquidation, emergency hard-kill closure, stop-loss / take-profit tracking. |
| `Visualizer.mqh` | Debug graphics | Renders swings, BOS/CHOCH labels, S/D zones, entry/SL/TP lines on chart. |
| `Journal.mqh` | Auditing | Structured log prints with complete deterministic reason codes. |

---

## Event Model & Temporal Integrity
To eliminate intra-bar false positives and over-trading:
- **Candle Evaluation**: High-level strategy decisions only occur on `IsNewClosedBar()` when bar index 0 opens and bar index 1 has definitively closed.
- **Tick Evaluation**: `OnTick()` is reserved exclusively for high-priority risk management: checking the 3.8% Hard Kill threshold and monitoring the scheduled End-of-Day (EOD) liquidation time.
- **Zero Lookahead**: Swing points require a configurable right-side confirmation window ($R$ bars). A swing at bar $K$ is registered only after bar $K - R$ has closed.
