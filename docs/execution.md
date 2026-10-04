# Deterministic Trade Execution Layer

## Overview
The `CExecutionEngine` routes orders to the broker through MT5's `CTrade` interface with strict slippage bounds, volume normalization, and intelligent retcode handling.

---

## 1. Magic Number Architecture
To ensure each strategy and setup variant is identifiable in Strategy Tester reports and broker trade history:

| Strategy | Sub-Type | Magic Number Formula |
| :--- | :--- | :--- |
| **MM** | Standard Trend Signal | `BaseMagic + 101` (e.g. 90101) |
| **MM** | High-Risk Signal | `BaseMagic + 102` (e.g. 90102) |
| **MM** | Reversal Signal | `BaseMagic + 103` (e.g. 90103) |
| **SM** | Range Buy / Sell | `BaseMagic + 201` (e.g. 90201) |
| **UniT** | CP Spike & Retest | `BaseMagic + 301` (e.g. 90301) |
| **UniT** | Moving Standard | `BaseMagic + 401` (e.g. 90401) |
| **UniT** | Moving High-Risk | `BaseMagic + 402` (e.g. 90402) |

---

## 2. Execution Safeguards
- **Max Slippage**: Configured via `SetDeviationInPoints(10)` (1 pip on Forex).
- **Filling Type**: Defaults to `ORDER_FILLING_FOK` (Fill or Kill) with fallback handling.
- **Retry Mechanism**: Transient rejections (e.g. `TRADE_RETCODE_REQUOTE` or network hiccups) retry up to 3 times with a 200ms delay. Fatal errors (`INVALID_VOLUME`, `INVALID_STOPS`, `MARKET_CLOSED`) abort immediately and log to the journal.
