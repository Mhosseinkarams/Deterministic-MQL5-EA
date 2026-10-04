# Deterministic Position Lifecycle Management

## Overview
The `CPositionManager` enforces position discipline without discretionary tampering.

---

## 1. Strict Boundary Against Arbitrary Management
> **Rule**: Trailing stops and premature break-even shifts are strictly prohibited unless explicitly defined in the strategy specification.
> Modifying stops without structural cause degrades expectancy in backtesting.

---

## 2. Automated Liquidation Triggers
1. **Hard Kill Liquidation**:
   - If account drawdown hits the $3.8\%$ threshold, `CPositionManager` executes an emergency market close on all open positions belonging to this EA.
2. **End-of-Day (EOD) Flat**:
   - At the configured time (`23:45` default), all open trades for the symbol are flattened to avoid triple-swap Wednesdays, overnight gap risk, and spread widening during rollover.
