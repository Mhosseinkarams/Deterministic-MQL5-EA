# Deterministic Market Structure Engine

## Overview
The `CMarketStructureEngine` identifies structural extremes and transitions in the market without lookahead bias. It eliminates naive pivot indicators that repaint or look into the future.

---

## 1. Confirmed vs Developing Structure
- **Candidate Extreme**: Bar $C$ has higher high (or lower low) than $L$ left bars.
- **Confirmation Delay**: Bar $C$ is **ONLY** marked as a confirmed Swing High/Low when $R$ subsequent closed bars have highs lower than $C$'s high (or lows higher than $C$'s low).
- **Default Parameters**: `InpSwingLeftBars = 3`, `InpSwingRightBars = 3`.
- **Lookahead Prevention**: When evaluating at shift 1, the most recent swing that can possibly be confirmed occurred at shift $1 + R = 4$. Historical swings are never modified retrospectively.

```
       [Candidate High] (Bar C)
             ▲
           /   \
  [L Bars]/     \[R Closed Bars Required]
         /       \
─────────────────────────────────────────────► Time
```

---

## 2. Structural Classifications
- **Higher High (HH)**: Confirmed Swing High whose price exceeds the prior confirmed Swing High.
- **Higher Low (HL)**: Confirmed Swing Low whose price exceeds the prior confirmed Swing Low.
- **Lower High (LH)**: Confirmed Swing High whose price is below the prior confirmed Swing High.
- **Lower Low (LL)**: Confirmed Swing Low whose price is below the prior confirmed Swing Low.

---

## 3. Break of Structure (BOS) vs Wick Sweep
A frequent flaw in automated systems is treating every wick through a level as a structural break. In this EA:
- **Wick Sweep**: A candle high or low briefly exceeds the swing level, but the candle close is back within the prior range. This is classified as liquidity absorption or failed break, **NOT** a BOS.
- **Decisive Structural Break (BOS)**: The candle **CLOSE** must exceed the confirmed swing extreme plus a configurable buffer:
$$\text{Break Level}_{\text{Bull}} = \text{Swing High} + (\text{ATR} \times \text{BufferMult})$$
$$\text{Break Level}_{\text{Bear}} = \text{Swing Low} - (\text{ATR} \times \text{BufferMult})$$
- Default `InpBosBufferAtrMult = 0.10` (10% of current ATR).

---

## 4. Change of Character (CHOCH)
A Change of Character indicates a structural trend reversal:
- **Bullish CHOCH**: In a confirmed downtrend, a candle closes decisively above the last confirmed Lower High ($\text{LH}$).
- **Bearish CHOCH**: In a confirmed uptrend, a candle closes decisively below the last confirmed Higher Low ($\text{HL}$).

---

## 5. Protected Highs and Lows
- In a confirmed **Uptrend**, the most recent confirmed Higher Low is marked as the **Protected Low**. A break of this level threatens the trend structure.
- In a confirmed **Downtrend**, the most recent confirmed Lower High is marked as the **Protected High**.
