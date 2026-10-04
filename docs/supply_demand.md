# Deterministic Supply & Demand Engine

## Overview
The `CSupplyDemandEngine` manages institutional order blocks and imbalance zones with a strict, state-machine-driven lifecycle.

---

## 1. Zone Creation Rules (Zero Lookahead)
Zones are **never** created speculatively. A zone is initialized at bar $B$ (base candle) **only when** bar $B-1$ (departure candle) exhibits an impulsive displacement:
- **Demand Zone**: Created at the base candle when the following candle is a Strong Bullish candle ($\text{Body} \ge 55\%$) and $\text{Total Range} \ge \text{ATR} \times \text{InpZoneDepartureAtrMult}$ (default $1.5 \times \text{ATR}$).
  - `UpperPrice`: High of base candle.
  - `LowerPrice`: Low of base candle.
- **Supply Zone**: Created at the base candle when the following candle is a Strong Bearish candle ($\text{Body} \ge 55\%$) and $\text{Total Range} \ge \text{ATR} \times 1.5$.
  - `UpperPrice`: High of base candle.
  - `LowerPrice`: Low of base candle.

---

## 2. Zone Lifecycle States
Zones transition deterministically through four distinct states:

```
[FRESH] (0 touches)
   │
   ▼ Price interacts & respects boundary
[TESTED] (1 touch)
   │
   ▼ Price re-tests boundary
[WEAKENED] (≥ 2 touches)
   │
   ▼ Price closes beyond boundary
[BROKEN / INVALIDATED]
```

- **ZONE_FRESH**: Zone has never been retested since departure. Highest probabilistic strength.
- **ZONE_TESTED**: Price has wicked into the zone once and reversed out. Reliable for Stubborn Man range trades.
- **ZONE_WEAKENED**: Zone has absorbed 2 or more touches. Institutional liquidity is depleted; rejected by conservative filters.
- **ZONE_BROKEN**: A closed candle penetrates completely through the zone:
  - For Supply: $\text{Close} > \text{UpperPrice}$
  - For Demand: $\text{Close} < \text{LowerPrice}$
  - Once broken, the zone is deactivated from trading signal generation.
