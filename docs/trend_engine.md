# Deterministic Trend & Range Engine

## Overview
The `CTrendEngine` acts as the master regime classifier. It categorizes market conditions into four mutually exclusive states without probabilistic estimation:

1. `TREND_UP`
2. `TREND_DOWN`
3. `TREND_RANGE`
4. `TREND_TRANSITION` (or `UNCLEAR`)

---

## 1. Classification Matrix

| Market State | Market Structure | EMA 50 vs Slow EMA | Price vs EMA 50 | Range Criteria |
| :--- | :--- | :--- | :--- | :--- |
| **`TREND_UP`** | Higher Highs / Bullish BOS | $\text{EMA50} > \text{SlowEMA} + 0.5\,\text{ATR}$ | $\text{Price} > \text{EMA50}$ | No active Range Channel |
| **`TREND_DOWN`** | Lower Lows / Bearish BOS | $\text{EMA50} < \text{SlowEMA} - 0.5\,\text{ATR}$ | $\text{Price} < \text{EMA50}$ | No active Range Channel |
| **`TREND_RANGE`**| Indecisive Swings / Choch | Intertwined or Flat | Oscillating around EMA50 | Active Range Channel |
| **`TREND_TRANSITION`**| Disagreement / CHOCH | Disagreement with Structure | Divergent | Indeterminate |

---

## 2. Deterministic Range Detection
To satisfy Section 11 of the system specifications, Range is not detected via arbitrary oscillators, but rather via structural evidence:
1. **Repeated CHOCH without BOS**: Two or more recent Change of Character events within 40 bars without a sustained trend-continuation BOS.
2. **Corridor Oscillation**: Price is trapped between a verified, unbroken Supply Zone and an unbroken Demand Zone whose distance is between $1.5 \times \text{ATR}$ and $8.0 \times \text{ATR}$.
3. **Range Channel Construction**:
   - `RangeHigh`: Upper price of the supply zone (or recent confirmed swing high).
   - `RangeLow`: Lower price of the demand zone (or recent confirmed swing low).
   - `MidPoint`: $(\text{RangeHigh} + \text{RangeLow}) / 2.0$.

When `TREND_RANGE` is confirmed, all trend-following strategies (MM, UniT) are strictly blocked by the Conflict Manager.
