# Deterministic Verification & Testing Suite

## Overview
This document specifies the verification matrix covering the 26 critical validation test procedures required by Section 33 of the specification.

---

## The 26 Deterministic Test Procedures

| # | Test Item | Verification Scenario | Expected Deterministic Result |
| :--- | :--- | :--- | :--- |
| **1** | MM Standard Buy/Sell | Closed candle bounces off EMA50 in confirmed trend with EMA separation $> 0.5$ ATR. | Signal emitted with exact structural SL and $1:2$ RR. |
| **2** | MM High-Risk | Candle crosses EMA50 with body $\ge 75\%$ aligned with Slow EMA. | Emits high-risk signal with scaled $0.5\%$ risk. |
| **3** | MM Reversal | EMA separation $> 2.5$ ATR, candle crosses back through EMA50 against Slow EMA. | Emits reversal signal; stops placed at prior structural swing. |
| **4** | SM Range Detection | Repeated CHOCH without BOS or price oscillating between S/D boundaries. | Regime transitions from Trend to `TREND_RANGE`. |
| **5** | SM Supply Rejection | Price enters Supply zone at Range High and forms refusal candle (upper wick $\ge 45\%$). | Emits SM Sell signal with SL above Supply Zone. |
| **6** | SM Demand Rejection | Price enters Demand zone at Range Low and forms refusal candle (lower wick $\ge 45\%$). | Emits SM Buy signal with SL below Demand Zone. |
| **7** | UniT CP Spike & Retest | 3-bar spike move, first candle seeing beyond previous bar low/high, retest of spike level. | Emits CP signal with SL at pullback extreme. |
| **8** | UniT Moving Standard | Strong candle touches EMA21 in confirmed trend direction. | Emits Moving Standard signal with $1:1.8$ RR. |
| **9** | UniT Moving High-Risk | Candle crosses EMA21 with body $\ge 75\%$. | Emits Moving HR signal with $0.5\%$ scaled risk. |
| **10** | BOS Verification | Candle closes beyond confirmed swing level by $\ge \text{ATR} \times 0.10$. | Confirmed BOS registered; wick sweep rejected. |
| **11** | CHOCH Verification | In uptrend, candle closes below confirmed Higher Low. | Trend changes to Bearish; CHOCH event logged. |
| **12** | Swing Detection | Candidate bar surrounded by $L=3$ left and $R=3$ right lower bars. | Confirmed swing registered only after shift 4 closes. |
| **13** | Supply & Demand Creation | Impulsive candle with range $\ge 1.5 \times \text{ATR}$ away from base candle. | Zone created with upper/lower bounds of base bar. |
| **14** | Trend Engine Classification | Compare structure swings against EMA50 vs Slow EMA. | Deterministically outputs UP, DOWN, RANGE, or TRANSITION. |
| **15** | Structural SL Calculation | Buy signal SL placed at structural swing low or zone bottom. | SL never placed arbitrarily; invalidation protected. |
| **16** | TP Calculation | Target derived from opposing zone or strategy RR multiple. | TP always placed on favorable side of market. |
| **17** | Position Sizing Accuracy | Compare calculated lots on EURUSD, GBPUSD, XAUUSD. | Normalized lots risk exactly target percentage. |
| **18** | Daily Loss Limit (4%) | Cumulative daily loss reaches $4.0\%$. | All subsequent entries blocked for the rest of day. |
| **19** | Hard Kill Switch (3.8%) | Open position floating loss triggers $3.8\%$ drawdown. | Emergency market close of all positions; trading halted. |
| **20** | Consecutive Loss Protection | 3 consecutive closed trade losses occur. | Risk halved to $0.5\%$ until $50\%$ recovery target met. |
| **21** | One Position Per Symbol | Strategy emits signal while another position is active on symbol. | Conflict manager blocks duplicate trade. |
| **22** | EOD Flattening | Current time reaches 23:45 server time. | All active trades closed; new entries blocked. |
| **23** | Strategy Conflict | MM signal attempts to trigger while market is in `TREND_RANGE`. | Signal strictly blocked by Conflict Manager Rule 1. |
| **24** | Price-Zone Conflict | Signal entry price is within $1.0$ ATR of existing position. | Signal blocked to prevent position clustering. |
| **25** | MTF Synchronization | Evaluating M5 strategy while EA attached to M15 or H1 chart. | Copies data strictly from requested timeframe buffer. |
| **26** | Zero-Lookahead Proof | Compare signals generated in real-time vs historical bar replay. | Identical signals emitted at identical bar timestamps. |
