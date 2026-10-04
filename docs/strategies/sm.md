# Strategy 2: SM (Stubborn Man Range Strategy)

## Core Philosophy
**SM stands for STUBBORN MAN.**
It is strictly an institutional **range-boundary exploitation** strategy. It is NOT Smart Money Concepts (SMC) as an independent trend strategy.

### Primary Rule of Engagement
> **SM executes ONLY when the market is confirmed in `TREND_RANGE`.**
> It is strictly blocked during confirmed `TREND_UP` or `TREND_DOWN` by the Strategy Conflict Manager.

---

## 1. Range Identification
The range channel is recognized when:
1. Multiple CHOCH events occur without structural BOS continuation.
2. Price is bound between an unbroken Supply Zone and an unbroken Demand Zone.
3. Upper and lower boundaries are established with clear invalidation points.

---

## 2. Refusal Candle Definition
To eliminate discretionary interpretation, a **Refusal Candle** is mathematically defined:
- **Refusal at Supply (Bearish Rejection)**:
  - Upper Wick $\ge 45\%$ of total candle range.
  - Close $\le \text{High} - (0.40 \times \text{Total Range})$.
  - Candle close is bearish ($\text{Close} < \text{Open}$) or a Bearish Pinbar.
- **Refusal at Demand (Bullish Rejection)**:
  - Lower Wick $\ge 45\%$ of total candle range.
  - Close $\ge \text{Low} + (0.40 \times \text{Total Range})$.
  - Candle close is bullish ($\text{Close} > \text{Open}$) or a Bullish Pinbar.

---

## 3. Execution Rules
### SM Range Sell
- **Location**: Price approaches within $0.5 \times \text{ATR}$ of a reliable Supply Zone at the top of the Range Channel.
- **Trigger**: Candle touches the zone and closes as a confirmed Refusal Candle.
- **SL Placement**: Above the Supply Zone upper boundary $+ 0.15 \times \text{ATR}$.
- **TP Placement**: Near the opposing Demand boundary $+ 0.20 \times \text{ATR}$ (or Range Low).
- **R:R Check**: Must offer $\ge 1:1.5$ R:R.

### SM Range Buy
- **Location**: Price approaches within $0.5 \times \text{ATR}$ of a reliable Demand Zone at the bottom of the Range Channel.
- **Trigger**: Candle touches the zone and closes as a confirmed Refusal Candle.
- **SL Placement**: Below the Demand Zone lower boundary $- 0.15 \times \text{ATR}$.
- **TP Placement**: Near the opposing Supply boundary $- 0.20 \times \text{ATR}$ (or Range High).
