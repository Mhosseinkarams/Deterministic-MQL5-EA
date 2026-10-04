# Strategy 3: UniT (CP & Moving Signals)

## Overview
The UniT system consists of two distinct components:
1. **UniT CP**: Spike & Pullback Retest.
2. **UniT Moving**: EMA21 Dynamic Follower.

> **ABSOLUTE RULE**: UniT does **NOT** contain a reversal signal.

---

## 1. UniT CP (Counter/Continuous Spike & Retest)

### A. Spike Detection
A spike move represents sharp directional aggression without pullbacks:
- **Bull Spike**: 3 consecutive closed bullish candles with consecutive Higher Highs and Higher Lows, covering $\ge 1.5 \times \text{ATR}$.
- **Bear Spike**: 3 consecutive closed bearish candles with consecutive Lower Lows and Lower Highs, covering $\ge 1.5 \times \text{ATR}$.

### B. Pullback Definition (Strictly Preserved)
The system strictly enforces the authentic CP definition:
> *"A candle constitutes a pullback if it sees beyond the high/low of the candle immediately before it."*
- **In a Bull Spike**: The pullback is confirmed when a candle's **Low** prints lower than the **Low** of the candle immediately preceding it.
- **In a Bear Spike**: The pullback is confirmed when a candle's **High** prints higher than the **High** of the candle immediately preceding it.
- No arbitrary retracement percentages or Fibonacci ratios are used.

### C. Entry Trigger & Last-Pivot Stop Loss (Agile Sizing)
- Following the pullback confirmation, the system monitors price returning to retest the Spike Extreme (Spike High for Buy, Spike Low for Sell).
- Entry triggers on closed candle confirmation upon reaching or breaking the spike level.
- **Stop Loss Placement (Last Pivot)**:
  - Rather than using an excessively wide or ancient pullback extreme that forces positions to stay open for days, the Stop Loss is anchored strictly to the **Last Pivot**:
    - **For Buy**: Placed at the last local pivot low formed during the pullback turn minus a tight buffer ($\text{Last Pivot Low} - 0.10 \times \text{ATR}$).
    - **For Sell**: Placed at the last local pivot high formed during the pullback turn plus a tight buffer ($\text{Last Pivot High} + 0.10 \times \text{ATR}$).
- **Take Profit**: $2.0 \times \text{Risk Distance}$ ($1:2$ R:R).

### D. Dynamic Risk Multipliers (Configurable Halving)
- Base Risk: $1.0\%$.
- For each adverse or higher-risk condition detected, risk is deterministically halved:
  - Factor 1: Overall market trend disagrees with spike direction ($\times 0.5 \rightarrow 0.5\%$).
  - Factor 2: Entry price is on the wrong side of EMA21 ($\times 0.5 \rightarrow 0.25\%$).

---

## 2. UniT Moving Signals (EMA21 Only)
UniT Moving relies exclusively on **EMA 21**.
> **Note**: EMA21 slope is NOT a required condition.

### Stop Loss Rule: Behind the EMA 21
To eliminate oversized holding times and prevent wide stops anchored to distant historical swings:
- **Buy Signals**: Stop Loss is placed **behind the EMA 21** ($\text{EMA21} - 0.10 \times \text{ATR}$, or below the candle low if it pierced EMA 21).
- **Sell Signals**: Stop Loss is placed **behind the EMA 21** ($\text{EMA21} + 0.10 \times \text{ATR}$, or above the candle high if it pierced EMA 21).

### A. Standard Moving Signal
- **Regime**: Confirmed `TREND_UP` or `TREND_DOWN`.
- **Location**: Candle touches or trades within proximity of EMA21 ($\pm 0.35 \times \text{ATR}$).
- **Candle**: Strong candle closing in alignment with the trend.
- **Stop Loss**: Placed strictly behind the EMA 21 line.
- **Risk**: Standard ($1.0\%$).
- **Target**: $1.8 \times \text{Risk Distance}$.

### B. High-Risk Moving Signal
- **Trigger**: Candle crosses EMA21 with high momentum displacement ($\text{Body} \ge 75\%$).
- **Stop Loss**: Placed strictly behind the EMA 21 line.
- **Risk**: Scaled to $0.5\%$.
- **Target**: $1.5 \times \text{Risk Distance}$.
