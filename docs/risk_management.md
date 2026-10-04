# Deterministic Risk & Capital Protection Engine

## Sovereign Authority
The `CRiskEngine` exercises absolute, non-bypassable authority over the execution pipeline. No strategy can execute an order without passing every risk constraint.

---

## 1. Core Constraints & Guardrails

| Constraint | Value | Description |
| :--- | :--- | :--- |
| **Max Risk Per Trade** | $1.0\%$ | Maximum capital exposed on any single position. |
| **Max Daily Drawdown** | $4.0\%$ | Trading halted if equity drops $\ge 4.0\%$ from the day's starting balance. |
| **Hard Kill Switch** | $3.8\%$ | Immediate liquidation trigger: closes all positions and blocks entries for the day. |
| **One Position Per Symbol** | Enforced | Prevents stacking correlated exposure on a single instrument. |
| **Minimum Acceptable R:R** | $1.5$ | Rejects any trade where anticipated reward is $< 1.5 \times$ risk. |
| **Max Allowed Spread** | $35$ points | Rejects entries during liquidity vacuums and rollover hours. |
| **End of Day (EOD) Flat** | 23:45 | Automatically closes all open positions before broker swap and rollover. |

---

## 2. Consecutive-Loss Protection Rule
To preserve capital during hostile regime transitions:
1. **Trigger**: If the EA records **3 consecutive losses**:
2. **Action**: Acceptable risk is automatically reduced to **$0.5\%$**.
3. **Recovery Mandate**: The risk remains throttled at $0.5\%$ until **$50\%$ of the drawdown** accumulated during those 3 losses has been recovered through verified wins.
4. **Restoration**: Normal $1.0\%$ risk sizing is only restored once the $50\%$ benchmark is met.

---

## 3. Multi-Asset Position Sizing Math
Position size is dynamically computed to normalize risk across Forex, Commodities (Gold/XAUUSD), and CFD Indices:

$$\text{Risk Money} = \text{Account Equity} \times \frac{\text{Risk \%}}{100}$$

$$\text{Loss Per Lot} = \left(\frac{|\text{Entry} - \text{StopLoss}|}{\text{Tick Size}}\right) \times \text{Tick Value}$$

$$\text{Raw Lots} = \frac{\text{Risk Money}}{\text{Loss Per Lot}}$$

The raw volume is then quantized to the broker's `LotsStep`, bounded by `LotsMin` and `LotsMax`. If the computed size is smaller than `LotsMin`, the trade is rejected to avoid over-risking.
