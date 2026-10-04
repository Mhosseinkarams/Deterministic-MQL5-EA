# Deterministic MQL5 Expert Advisor (MM, SM, UniT)

A quantitative, pure rule-based MQL5 Expert Advisor for MetaTrader 5 implementing three distinct strategies:
1. **MM**: Trend-Following with EMA50 and Slow EMA (EMA600 on M5, EMA800 on M15).
2. **SM (Stubborn Man)**: Structural Range Boundary Exploitation with Refusal Candles.
3. **UniT**: Momentum Spike & First Pullback Retest (UniT CP) and Dynamic EMA21 Following (UniT Moving).

---

## 🚫 Absolute Constraint: Zero AI / ML / News
This codebase is 100% deterministic and mathematically auditable:
- **NO** Machine Learning, Deep Learning, or Neural Networks
- **NO** Large Language Models or AI APIs
- **NO** Sentiment analysis or news feeds
- **NO** Python or ONNX model files

Every entry, stop loss, take profit, and risk decision is derived exclusively from closed candle price action, verified market structure, supply/demand boundaries, and technical indicators.

---

## 📂 Repository Structure

```
├── MQL5/
│   ├── Experts/
│   │   ├── DeterministicTradingEA.mq5           # Modular Master EA
│   │   └── DeterministicTradingEA_Standalone.mq5# Single-File Monolithic EA (1-Click Compile)
│   └── Include/Deterministic/
│       ├── Defines.mqh                          # Enums, Signals, State Machines
│       ├── CandleEngine.mqh                     # Math metrics & Refusal Candle Detection
│       ├── Indicators.mqh                       # EMA 21/50/600/800 & ATR Handles
│       ├── MarketStructure.mqh                  # Zero-Lookahead Swings, BOS, CHOCH
│       ├── SupplyDemand.mqh                     # S/D Zones & Freshness Lifecycle
│       ├── TrendEngine.mqh                      # UP, DOWN, RANGE, TRANSITION Classifier
│       ├── StrategyMM.mqh                       # MM Trend, High-Risk, Reversal
│       ├── StrategySM.mqh                       # Stubborn Man Range Strategy
│       ├── StrategyUniT.mqh                     # UniT CP & UniT Moving
│       ├── ConflictManager.mqh                  # Regime Conflict & Zone Collision Filter
│       ├── RiskEngine.mqh                       # 4% Daily Max, 3.8% Hard Kill, Lot Sizing
│       ├── ExecutionEngine.mqh                  # CTrade wrapper, Slippage & Magic Numbers
│       ├── PositionManager.mqh                  # EOD Flat & Emergency Close
│       ├── Visualizer.mqh                       # Chart Debug Graphics
│       └── Journal.mqh                          # Auditable Reason Code Logger
├── docs/                                        # Comprehensive Technical Documentation
│   ├── architecture.md
│   ├── market_structure.md
│   ├── supply_demand.md
│   ├── trend_engine.md
│   ├── strategies/
│   │   ├── mm.md
│   │   ├── sm.md
│   │   └── unit.md
│   ├── risk_management.md
│   ├── execution.md
│   ├── position_management.md
│   ├── visualization.md
│   ├── testing.md
│   └── troubleshooting.md
└── src/                                         # Interactive Web Studio & Backtest Simulator
```

---

## 🚀 Quick Start in MetaTrader 5

### Option A: Standalone Single File (Recommended for quick testing)
1. Open **MetaEditor 5** in MetaTrader 5.
2. Create a new Expert Advisor in `MQL5/Experts/`.
3. Copy the entire contents of `MQL5/Experts/DeterministicTradingEA_Standalone.mq5`.
4. Press **F7** (Compile). Output: `0 errors, 0 warnings`.
5. Attach to an **EURUSD**, **GBPUSD**, or **XAUUSD** chart on **M5** or **M15**.

### Option B: Modular Architecture
1. Copy the folder `MQL5/Include/Deterministic/` into your MT5 terminal's `MQL5/Include/` directory.
2. Copy `MQL5/Experts/DeterministicTradingEA.mq5` into `MQL5/Experts/`.
3. Compile with **F7**.

---

## ⚙️ Key Strategy Configurations

- **MM Strategy**:
  - `InpEnableMMStandard`: Standard bounce off EMA50 aligned with Slow EMA.
  - `InpEnableMMHighRisk`: High-momentum candle cross of EMA50.
  - `InpEnableMMReversal`: Mean reversion when EMA separation $> 2.5 \times \text{ATR}$.
- **SM Strategy**:
  - `InpSMRefusalWickPercent`: Minimum wick percentage (45%) on refusal candles.
  - Activated only in verified `TREND_RANGE`.
- **UniT Strategy**:
  - `InpEnableUniT_CP`: Spike and first pullback retest with exact candle breach logic.
  - `InpEnableUniT_Moving`: Trend following using EMA21.
- **Capital Protection**:
  - Base Risk: 1.0%
  - Hard Kill Switch: 3.8% (liquidates all open trades and halts trading for the day)
  - Daily Loss Max: 4.0%
  - EOD Flat: Closes all positions at 23:45 server time.
