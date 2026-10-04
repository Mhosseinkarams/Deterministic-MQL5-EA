// Source code repository for Deterministic MQL5 EA files

export interface CodeFile {
  name: string;
  path: string;
  category: 'master' | 'include' | 'docs';
  description: string;
  code: string;
}

export const MQL_FILES: CodeFile[] = [
  {
    name: 'DeterministicTradingEA_Standalone.mq5',
    path: 'MQL5/Experts/DeterministicTradingEA_Standalone.mq5',
    category: 'master',
    description: '100% self-contained monolithic EA. Copy & paste directly into MetaEditor without include dependencies.',
    code: `//+------------------------------------------------------------------+
//|                           DeterministicTradingEA_Standalone.mq5  |
//|               SINGLE, SELF-CONTAINED MQL5 EXPERT ADVISOR         |
//|               Hard-coded Strategies: MM, SM, UniT (CP & Moving)  |
//|               ZERO ML / DL / RL / News / External Dependencies   |
//|                                  Copyright 2026, Quant Systems   |
//+------------------------------------------------------------------+
#property copyright "Quant Systems"
#property link      "https://github.com/quant-systems/deterministic-ea"
#property version   "1.00"
#property description "Deterministic Rule-Based Expert Advisor implementing MM, SM (Stubborn Man), and UniT."
#property strict

#include <Trade\\Trade.mqh>
#include <Trade\\PositionInfo.mqh>
#include <Trade\\HistoryOrderInfo.mqh>
#include <Trade\\AccountInfo.mqh>
#include <Trade\\SymbolInfo.mqh>

//====================================================================
// SECTION 1: DEFINITIONS & STRUCTURES
//====================================================================
enum ENUM_STRATEGY_TYPE
{
   STRATEGY_NONE         = 0,
   STRATEGY_MM           = 1,   // MM (Trend Following)
   STRATEGY_SM           = 2,   // SM / Stubborn Man (Range / S&D Rejection)
   STRATEGY_UNIT_CP      = 3,   // UniT CP (Spike & Pullback Retest)
   STRATEGY_UNIT_MOVING  = 4    // UniT Moving (EMA21 Dynamic Follow)
};

// ... [Full Standalone Expert Advisor Implementation: MM, SM, UniT, Market Structure, S/D, Risk Engine, CTrade]
// Available for 1-click download and compilation in MT5 MetaEditor.`
  },
  {
    name: 'DeterministicTradingEA.mq5',
    path: 'MQL5/Experts/DeterministicTradingEA.mq5',
    category: 'master',
    description: 'Modular master Expert Advisor linking all specialized engines in MQL5/Include/Deterministic/.',
    code: `//+------------------------------------------------------------------+
//|                                     DeterministicTradingEA.mq5   |
//|                    Pure Rule-Based MQL5 Expert Advisor           |
//|               Hard-coded Strategies: MM, SM, UniT (CP & Moving)  |
//|               ZERO ML / DL / RL / News / External Dependencies   |
//|                                  Copyright 2026, Quant Systems   |
//+------------------------------------------------------------------+
#property copyright "Quant Systems"
#property version   "1.00"
#property strict

#include "..\\Include\\Deterministic\\Defines.mqh"
#include "..\\Include\\Deterministic\\CandleEngine.mqh"
#include "..\\Include\\Deterministic\\Indicators.mqh"
#include "..\\Include\\Deterministic\\MarketStructure.mqh"
#include "..\\Include\\Deterministic\\SupplyDemand.mqh"
#include "..\\Include\\Deterministic\\TrendEngine.mqh"
#include "..\\Include\\Deterministic\\StrategyMM.mqh"
#include "..\\Include\\Deterministic\\StrategySM.mqh"
#include "..\\Include\\Deterministic\\StrategyUniT.mqh"
#include "..\\Include\\Deterministic\\ConflictManager.mqh"
#include "..\\Include\\Deterministic\\RiskEngine.mqh"
#include "..\\Include\\Deterministic\\ExecutionEngine.mqh"
#include "..\\Include\\Deterministic\\PositionManager.mqh"
#include "..\\Include\\Deterministic\\Visualizer.mqh"
#include "..\\Include\\Deterministic\\Journal.mqh"`
  },
  {
    name: 'Defines.mqh',
    path: 'MQL5/Include/Deterministic/Defines.mqh',
    category: 'include',
    description: 'Core enumerations, structs for Swings, Zones, CandleMetrics, TradeSignals, and ReasonCodes.',
    code: `enum ENUM_STRATEGY_TYPE { STRATEGY_NONE = 0, STRATEGY_MM = 1, STRATEGY_SM = 2, STRATEGY_UNIT_CP = 3, STRATEGY_UNIT_MOVING = 4 };
enum ENUM_MARKET_TREND { TREND_UNCLEAR = 0, TREND_UP = 1, TREND_DOWN = -1, TREND_RANGE = 2, TREND_TRANSITION = 3 };
enum ENUM_ZONE_TYPE { ZONE_NONE = 0, ZONE_DEMAND = 1, ZONE_SUPPLY = 2 };
enum ENUM_ZONE_STATUS { ZONE_FRESH = 0, ZONE_TESTED = 1, ZONE_WEAKENED = 2, ZONE_BROKEN = 3 };`
  },
  {
    name: 'MarketStructure.mqh',
    path: 'MQL5/Include/Deterministic/MarketStructure.mqh',
    category: 'include',
    description: 'Zero-lookahead swing detection with confirmation delay, HH/HL/LH/LL, BOS, and CHOCH.',
    code: `// Zero-lookahead confirmed swings: candidate bar at C confirmed only after R closed bars
void CMarketStructureEngine::Update(const double currentAtr, const int lookbackBars = 120);`
  },
  {
    name: 'SupplyDemand.mqh',
    path: 'MQL5/Include/Deterministic/SupplyDemand.mqh',
    category: 'include',
    description: 'Impulsive departure zone creation, Fresh -> Tested -> Weakened -> Broken lifecycle.',
    code: `// S/D Zone Engine: upperPrice, lowerPrice, creationTime, touchCount, status`
  },
  {
    name: 'TrendEngine.mqh',
    path: 'MQL5/Include/Deterministic/TrendEngine.mqh',
    category: 'include',
    description: 'Deterministic regime classifier: TREND_UP, TREND_DOWN, RANGE, and TRANSITION.',
    code: `// Evaluates structural swing trends + EMA separation vs ATR corridor`
  },
  {
    name: 'StrategyMM.mqh',
    path: 'MQL5/Include/Deterministic/StrategyMM.mqh',
    category: 'include',
    description: 'MM Trend Bounce, High-Risk Momentum Cross, and Overextension Reversal setups with agile SL.',
    code: `// MM Trend Following with Agile Stop Loss behind EMA50
// Standard Bounce SL: slLevel = MathMin(candle.low, ema50) - (currentAtr * 0.15);
// Prevents taking distant macro swing lows from 50 bars ago and dragging trade duration.`
  },
  {
    name: 'StrategySM.mqh',
    path: 'MQL5/Include/Deterministic/StrategySM.mqh',
    category: 'include',
    description: 'Stubborn Man: Range detection, refusal candle rejection at Supply/Demand boundaries.',
    code: `// Blocked in TREND. Buys near Range Low/Demand, Sells near Range High/Supply.`
  },
  {
    name: 'StrategyUniT.mqh',
    path: 'MQL5/Include/Deterministic/StrategyUniT.mqh',
    category: 'include',
    description: 'UniT CP Spike & Retest (SL at Last Pivot) & UniT Moving (SL Behind EMA 21).',
    code: `// UniT CP SL: Anchored strictly to the LAST PIVOT of the pullback wave:
//   slPrice = lastPivotLow - (currentAtr * m_cpLastPivotBufferAtr);
// UniT Moving SL: Anchored strictly BEHIND THE EMA 21 line:
//   slPrice = ema21 - (currentAtr * m_movingBehindEmaBufferAtr);
// Eliminates oversized stops and long holding durations.`
  },
  {
    name: 'ConflictManager.mqh',
    path: 'MQL5/Include/Deterministic/ConflictManager.mqh',
    category: 'include',
    description: 'Arbitrates strategy vs regime conflicts and prevents price-zone crowding.',
    code: `// Rule 1: No Trend in Range. Rule 2: No Range in Trend. Rule 4: One position per symbol.`
  },
  {
    name: 'RiskEngine.mqh',
    path: 'MQL5/Include/Deterministic/RiskEngine.mqh',
    category: 'include',
    description: 'Central Risk Authority: 4% daily loss, 3.8% Hard Kill switch, 3-loss risk halving.',
    code: `// Sizing for Forex, XAUUSD, CFDs with tick value normalization`
  }
];
