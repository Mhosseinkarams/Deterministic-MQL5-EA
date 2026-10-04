# Deterministic EA Troubleshooting & Diagnostics

## Common Issues & Diagnoses

### 1. "No trades are opening"
- **Check 1: Market State**. In `TREND_RANGE`, MM and UniT are blocked. In `TREND_UP`/`TREND_DOWN`, SM is blocked. Review the journal for `[JOURNAL][SIGNAL_REJECTED] Stage: CONFLICT_MANAGER`.
- **Check 2: Spread Filter**. If broker spread during session exceeds `InpMaxSpreadPoints` (default 35), trades will be rejected with `REJECT_SPREAD_TOO_HIGH`.
- **Check 3: Hard Kill / Daily Limit**. If daily drawdown reached 3.8% or 4.0%, check if `m_killSwitchTriggered` is active. It resets automatically at 00:00 server time.
- **Check 4: EOD Proximity**. If server time is after 23:45, all new entries are blocked by the EOD filter.

### 2. "Indicator Handle Invalid" in MT5 Experts Log
- Ensure the history on the strategy timeframe (`M5` or `M15`) is downloaded in the MT5 History Center. The slow EMA requires at least 800 bars of historical data.

### 3. "Lot Size Below Broker Minimum"
- If account equity is very low ($100) and Stop Loss is wide ($50 pips), 1% risk ($1.00) might result in a lot size below the broker's minimum (0.01 lots). The EA strictly rejects such trades rather than risking more than allowed.

### 4. "Compilation Error: Cannot open file"
- If compiling `DeterministicTradingEA.mq5`, ensure all files under `MQL5/Include/Deterministic/` are present in your MT5 directory.
- Alternatively, compile `DeterministicTradingEA_Standalone.mq5` which has zero include dependencies.
