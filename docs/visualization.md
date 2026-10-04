# Deterministic Visualization & Debug Engine

## Purpose
`CVisualizer` provides visual telemetry on the MT5 chart for developer auditing, strategy sanity checks, and visual backtesting.

---

## 1. Visual Objects Rendered
- **Confirmed Swing Extremes**: Red downward arrows on confirmed Swing Highs; Green upward arrows on confirmed Swing Lows.
- **Supply Zones**: Semi-transparent IndianRed rectangles spanning the zone's upper and lower boundaries.
- **Demand Zones**: MediumSeaGreen rectangles spanning the zone boundaries.
- **Broken Zones**: Recycled and shaded Gray upon invalidation.
- **Range Boundaries**: Dashed orange-red line for Range High; dashed dodger-blue line for Range Low.
- **Trade Signals**: Buy/Sell arrows with dotted Stop Loss (Red) and Take Profit (LimeGreen) projection lines.

---

## 2. Inviolable Rule of Visualization
> **Visualization NEVER influences strategy execution.**
> If `InpEnableDebugVisuals` is turned off, the trading logic, signal timing, and execution results are 100% mathematically identical.
> All objects are created with a designated prefix (`D_EA_`) and are purged upon EA deinitialization (`OnDeinit`).
