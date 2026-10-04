# Strategy 1: MM (Trend & Dynamic EMA Strategy)

## Core Philosophy
MM is a **trend-following** strategy operating on M5 and M15 timeframes. It relies on the dynamic relationship between **EMA50** and the **Slow EMA**:
- **M5 Timeframe**: EMA 50 & EMA 600.
- **M15 Timeframe**: EMA 50 & EMA 800.

### Critical Rule on Slow EMA
> **The Slow EMA (EMA600 / EMA800) does NOT independently trigger entries.**
> Crossing the Slow EMA never generates a signal by itself. It serves exclusively for trend orientation, slope alignment, separation measurement, and risk boundaries.

---

## 1. MM Standard Signal
- **Market State**: `TREND_UP` (for Buy) or `TREND_DOWN` (for Sell).
- **EMA Position**:
  - Buy: $\text{EMA50} > \text{SlowEMA}$ with separation $\ge 0.5 \times \text{ATR}$.
  - Sell: $\text{EMA50} < \text{SlowEMA}$ with separation $\ge 0.5 \times \text{ATR}$.
- **Interaction**: Candle pulls back and touches/interacts with EMA50 ($\pm 0.1 \times \text{ATR}$).
- **Candle Validation**:
  - Buy: Closed Strong Bullish candle ($\text{Body} \ge 55\%$) closing above EMA50.
  - Sell: Closed Strong Bearish candle ($\text{Body} \ge 55\%$) closing below EMA50.
- **Stop Loss**: Placed below the interaction low and recent confirmed structural swing low.
- **Take Profit**: $2.0 \times \text{Risk Distance}$ ($1:2$ R:R).
- **Reason Code**: `MM_BUY_STANDARD|TREND_UP|EMA50_BOUNCE` / `MM_SELL_STANDARD|TREND_DOWN|EMA50_BOUNCE`.

---

## 2. MM High-Risk Signal
- **Context**: Rapid momentum shift re-aligning with higher-timeframe trend.
- **Trigger**: Candle crosses through EMA50 with high displacement.
- **Candle Requirement**: Very Strong candle ($\text{Body} \ge 75\%$, Range $\ge 1.1 \times \text{ATR}$).
- **Risk Allocation**: Scaled to $0.5\%$ (half of standard risk).
- **Target**: $1.5 \times \text{Risk Distance}$.

---

## 3. MM Reversal Signal
- **Context**: Overextension away from the Slow EMA.
- **Separation Condition**: Distance between EMA50 and Slow EMA $\ge 2.5 \times \text{ATR}$.
- **Trigger**:
  - Bullish Reversal: After an extended downtrend ($\text{EMA50} < \text{SlowEMA}$), price forms a Strong Bullish candle that crosses above EMA50.
  - Bearish Reversal: After an extended uptrend ($\text{EMA50} > \text{SlowEMA}$), price forms a Strong Bearish candle that crosses below EMA50.
- **Structural Validation**: A recent confirmed swing extreme must be available for invalidation stop placement.
- **Risk Allocation**: $0.5\%$ risk.
