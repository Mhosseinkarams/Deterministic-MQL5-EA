//+------------------------------------------------------------------+
//|                                     DeterministicTradingEA.mq5   |
//|                    Pure Rule-Based MQL5 Expert Advisor           |
//|               Hard-coded Strategies: MM, SM, UniT (CP & Moving)  |
//|               ZERO ML / DL / RL / News / External Dependencies   |
//|                                  Copyright 2026, Quant Systems   |
//+------------------------------------------------------------------+
#property copyright "Quant Systems"
#property link      "https://github.com/quant-systems/deterministic-ea"
#property version   "1.00"
#property description "Deterministic Rule-Based Expert Advisor implementing MM, SM (Stubborn Man), and UniT."
#property strict

// Include Engine Modules
#include "..\Include\Deterministic\Defines.mqh"
#include "..\Include\Deterministic\CandleEngine.mqh"
#include "..\Include\Deterministic\Indicators.mqh"
#include "..\Include\Deterministic\MarketStructure.mqh"
#include "..\Include\Deterministic\SupplyDemand.mqh"
#include "..\Include\Deterministic\TrendEngine.mqh"
#include "..\Include\Deterministic\StrategyMM.mqh"
#include "..\Include\Deterministic\StrategySM.mqh"
#include "..\Include\Deterministic\StrategyUniT.mqh"
#include "..\Include\Deterministic\ConflictManager.mqh"
#include "..\Include\Deterministic\RiskEngine.mqh"
#include "..\Include\Deterministic\ExecutionEngine.mqh"
#include "..\Include\Deterministic\PositionManager.mqh"
#include "..\Include\Deterministic\Visualizer.mqh"
#include "..\Include\Deterministic\Journal.mqh"

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== Timeframe Configuration ==="
input ENUM_TIMEFRAMES   InpStrategyTimeframe    = PERIOD_M5;   // Strategy Primary Timeframe (M5 or M15)

input group "=== Market Structure & Zones ==="
input int               InpSwingLeftBars        = 3;           // Swing Left Confirmation Bars
input int               InpSwingRightBars       = 3;           // Swing Right Confirmation Bars (Zero-Lookahead)
input double            InpBosBufferAtrMult     = 0.10;        // BOS Close Buffer (x ATR)
input double            InpZoneDepartureAtrMult = 1.5;         // S/D Zone Departure Threshold (x ATR)

input group "=== Strategy 1: MM Settings ==="
input bool              InpEnableMM             = true;        // Enable MM Strategy
input bool              InpEnableMMStandard     = true;        // Enable MM Standard Trend Signal
input bool              InpEnableMMHighRisk     = true;        // Enable MM High-Risk Signal
input bool              InpEnableMMReversal     = true;        // Enable MM Reversal Signal
input double            InpMMMinSeparationAtr   = 0.50;        // Min EMA50/SlowEMA Separation (x ATR)
input double            InpMMRevSeparationAtr   = 2.50;        // Reversal Min Separation (x ATR)
input bool              InpMMTightEmaSl         = true;        // MM SL: Behind EMA50 / Bounce Low (Tight)
input double            InpMMTightEmaSlBufferAtr= 0.15;        // MM SL Buffer (x ATR)

input group "=== Strategy 2: SM (Stubborn Man) Settings ==="
input bool              InpEnableSM             = true;        // Enable SM (Stubborn Man Range Strategy)
input double            InpSMRefusalWickPercent = 45.0;        // Min Refusal Wick % (Upper for Supply, Lower for Demand)
input double            InpSMZoneApproachAtr    = 0.50;        // Proximity to Zone Boundary (x ATR)

input group "=== Strategy 3: UniT Settings ==="
input bool              InpEnableUniT_CP        = true;        // Enable UniT CP (Spike & Pullback Retest)
input bool              InpEnableUniT_Moving    = true;        // Enable UniT Moving (EMA21 Only)
input double            InpUniTBaseRiskPercent  = 1.0;         // UniT Base Risk %
input bool              InpUniTCP_LastPivotSL   = true;        // UniT CP SL: Last Pivot (Tight & Agile)
input double            InpUniTCP_PivotBufferAtr= 0.10;        // UniT CP SL Buffer Beyond Last Pivot (x ATR)
input bool              InpUniTMoving_BehindEmaSL= true;       // UniT Moving SL: Behind EMA 21 (Tight)
input double            InpUniTMoving_BehindEmaBuf= 0.10;      // UniT Moving SL Buffer Behind EMA 21 (x ATR)

input group "=== Take Profit Configuration ==="
input ENUM_TP_MODE      InpTpMode               = TP_MODE_AUTO;   // Take Profit Mode (Auto vs Manual)
input double            InpManualTpMultiple     = 2.0;            // Manual TP Size (R-Multiple: 1.0 = 1R, 2.0 = 2R, 3.0 = 3R)

input group "=== Risk & Capital Protection ==="
input double            InpBaseRiskPercent      = 1.0;         // Base Risk Per Trade (%)
input double            InpMaxDailyLossPercent  = 4.0;         // Max Daily Loss (%)
input double            InpHardKillThreshold    = 3.8;         // Hard Kill Switch (%)
input double            InpMinRiskRewardRatio   = 1.5;         // Minimum Acceptable R:R
input int               InpMaxSpreadPoints      = 35;          // Max Allowed Spread (Points)
input bool              InpEnableEODFlat        = true;        // Close All Positions EOD
input int               InpEODCloseHour         = 23;          // EOD Close Hour
input int               InpEODCloseMinute       = 45;          // EOD Close Minute

input group "=== System & Debug ==="
input ulong             InpBaseMagicNumber      = 90000;       // Base Magic Number
input bool              InpEnableDebugVisuals   = true;        // Enable Chart Debug Visuals
input bool              InpVerboseJournal       = true;        // Verbose Logging to MT5 Journal

//+------------------------------------------------------------------+
//| GLOBAL ENGINE INSTANCES                                          |
//+------------------------------------------------------------------+
CCandleEngine           g_candleEngine;
CIndicatorEngine        g_indicators;
CMarketStructureEngine  g_structure;
CSupplyDemandEngine     g_sdEngine;
CTrendEngine            g_trendEngine;
CStrategyMM             g_strategyMM;
CStrategySM             g_strategySM;
CStrategyUniT           g_strategyUniT;
CStrategyConflictManager g_conflictManager;
CRiskEngine             g_riskEngine;
CExecutionEngine        g_execution;
CPositionManager        g_positionManager;
CVisualizer             g_visualizer;
CJournal                g_journal;

datetime                g_lastBarTime = 0;

//+------------------------------------------------------------------+
//| Check for New Closed Bar on Strategy Timeframe                   |
//+------------------------------------------------------------------+
bool IsNewClosedBar()
{
   datetime currentBarTime = iTime(_Symbol, InpStrategyTimeframe, 0);
   if(currentBarTime == 0) return false;

   if(g_lastBarTime != currentBarTime)
   {
      g_lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("=========================================================");
   Print("   INITIALIZING DETERMINISTIC TRADING SYSTEM EA          ");
   Print("   Strategies: MM (Trend), SM (Range), UniT (CP/Moving)  ");
   Print("   Pure Rule-Based / Zero AI/ML / Zero External APIs     ");
   Print("=========================================================");

   // Validate Timeframe (M5 or M15)
   if(InpStrategyTimeframe != PERIOD_M5 && InpStrategyTimeframe != PERIOD_M15)
   {
      PrintFormat("[WARNING] Strategy timeframe %s selected. MM / Slow EMA optimized for M5 & M15.", EnumToString(InpStrategyTimeframe));
   }

   // 1. Initialize Indicator Engine
   if(!g_indicators.Init(_Symbol, InpStrategyTimeframe, 14))
   {
      Print("[FATAL] Failed to initialize indicator handles.");
      return INIT_FAILED;
   }

   // 2. Initialize Market Structure Engine
   g_structure.Init(_Symbol, InpStrategyTimeframe, InpSwingLeftBars, InpSwingRightBars, InpBosBufferAtrMult);

   // 3. Initialize Supply & Demand Engine
   g_sdEngine.Init(_Symbol, InpStrategyTimeframe, InpZoneDepartureAtrMult, 30);

   // 4. Initialize Strategies
   g_strategyMM.Init(_Symbol, InpStrategyTimeframe, InpEnableMMStandard, InpEnableMMHighRisk, InpEnableMMReversal, InpMMMinSeparationAtr, InpMMRevSeparationAtr, InpMMTightEmaSl, InpMMTightEmaSlBufferAtr);
   g_strategySM.Init(_Symbol, InpStrategyTimeframe, InpBaseRiskPercent, InpSMZoneApproachAtr);
   g_strategyUniT.Init(_Symbol, InpStrategyTimeframe, InpEnableUniT_CP, InpEnableUniT_Moving, InpUniTBaseRiskPercent, InpUniTCP_LastPivotSL, InpUniTCP_PivotBufferAtr, InpUniTMoving_BehindEmaSL, InpUniTMoving_BehindEmaBuf);

   // 5. Initialize Risk & Execution
   g_riskEngine.Init(InpBaseRiskPercent, InpMaxDailyLossPercent, InpHardKillThreshold, InpMinRiskRewardRatio, InpMaxSpreadPoints, InpEnableEODFlat, InpEODCloseHour, InpEODCloseMinute, InpTpMode, InpManualTpMultiple);
   
   // 6. Initialize Visualizer & Journal
   g_visualizer.Init(InpEnableDebugVisuals);
   g_journal.SetVerbose(InpVerboseJournal);

   PrintFormat("[INIT SUCCESS] Attached to %s. Strategy TF: %s. Slow EMA: %d",
               _Symbol, EnumToString(InpStrategyTimeframe), g_indicators.GetSlowEmaPeriod());

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   PrintFormat("[DEINIT] Deterministic Trading EA shutting down. Reason code: %d", reason);
   g_indicators.Release();
   g_visualizer.CleanObjects();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 1. High-Priority Continuous Risk Monitoring (Emergency Kill & EOD Flattening)
   g_positionManager.MonitorPositions(g_riskEngine, _Symbol);

   // 2. Controlled Candle-Event Execution Model
   // Only evaluate strategy rules on a NEW closed bar to prevent repeated intra-bar signals
   if(!IsNewClosedBar())
      return;

   // 3. Get Current Market Context
   double currentAtr = g_indicators.GetATR(1);
   if(currentAtr <= 0.0) currentAtr = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 20.0;

   // 4. Analyze latest closed candle (Shift 1)
   CandleMetrics closedCandle;
   if(!g_candleEngine.Analyze(_Symbol, InpStrategyTimeframe, 1, currentAtr, closedCandle))
      return;

   // 5. Update Market Structure (Swings, BOS, CHOCH) - Zero-Lookahead
   g_structure.Update(currentAtr, 120);

   // 6. Update Supply & Demand Zones (Creation, Touches, Invalidation)
   g_sdEngine.Update(currentAtr, g_candleEngine);

   // 7. Evaluate Trend & Range Classification
   ENUM_MARKET_TREND marketTrend = g_trendEngine.Evaluate(_Symbol, InpStrategyTimeframe, g_indicators, g_structure, g_sdEngine, currentAtr);

   // Log State
   g_journal.LogMarketState(_Symbol, InpStrategyTimeframe, marketTrend, g_indicators.GetEMA50(1), g_indicators.GetSlowEMA(1), currentAtr);

   // 8. Update Chart Visualization (if debug enabled)
   g_visualizer.UpdateChart(g_structure, g_sdEngine, g_trendEngine.GetRangeChannel());

   // 9. Evaluate Active Strategies
   TradeSignal candidates[3];
   int candidateCount = 0;

   // Evaluate Strategy 1: MM
   if(InpEnableMM)
   {
      TradeSignal mmSignal;
      if(g_strategyMM.Evaluate(closedCandle, g_indicators, g_structure, marketTrend, currentAtr, mmSignal))
      {
         candidates[candidateCount++] = mmSignal;
      }
   }

   // Evaluate Strategy 2: SM (Stubborn Man)
   if(InpEnableSM)
   {
      TradeSignal smSignal;
      if(g_strategySM.Evaluate(closedCandle, g_trendEngine, g_sdEngine, g_structure, currentAtr, smSignal))
      {
         candidates[candidateCount++] = smSignal;
      }
   }

   // Evaluate Strategy 3: UniT (CP & Moving)
   if(InpEnableUniT_CP || InpEnableUniT_Moving)
   {
      TradeSignal unitSignal;
      if(g_strategyUniT.Evaluate(closedCandle, g_indicators, g_structure, marketTrend, currentAtr, unitSignal))
      {
         candidates[candidateCount++] = unitSignal;
      }
   }

   // 10. Process Candidates through Conflict Manager & Risk Engine
   for(int i = 0; i < candidateCount; i++)
   {
      TradeSignal sig = candidates[i];
      g_journal.LogSignalGenerated(sig);

      // A. Conflict Resolution (State Conflict & Price-Zone Collision)
      string conflictReason = "";
      if(!g_conflictManager.ValidateSignal(sig, marketTrend, currentAtr, conflictReason))
      {
         g_journal.LogSignalRejected(sig, "CONFLICT_MANAGER", conflictReason);
         continue;
      }

      // B. Risk Authority Validation (Daily loss, R:R, Spread, Hard Kill)
      string riskReason = "";
      if(!g_riskEngine.ValidateSignal(sig, riskReason))
      {
         g_journal.LogSignalRejected(sig, "RISK_ENGINE", riskReason);
         continue;
      }

      // C. Calculate Normalized Volume based on exact broker specifications
      string lotError = "";
      double lotSize = g_riskEngine.CalculateLotSize(_Symbol, sig.entryPrice, sig.stopLoss, sig.riskPercent, lotError);
      if(lotSize <= 0.0)
      {
         g_journal.LogSignalRejected(sig, "POSITION_SIZING", lotError);
         continue;
      }

      // D. Dispatch Execution to Broker
      ulong ticket = 0;
      string execError = "";
      if(g_execution.ExecuteSignal(sig, lotSize, ticket, execError))
      {
         g_journal.LogOrderExecuted(ticket, sig, lotSize);
         g_visualizer.DrawSignal(sig);
         break; // One order executed per bar sequence
      }
      else
      {
         g_journal.LogSignalRejected(sig, "EXECUTION_ROUTING", execError);
      }
   }
}

//+------------------------------------------------------------------+
//| Trade Transaction Event (Track Closed PnL for Consecutive Losses)|
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      ulong dealTicket = trans.deal;
      if(HistoryDealSelect(dealTicket))
      {
         long dealEntry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
         if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT)
         {
            double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
            g_riskEngine.OnTradeClosed(profit, MathAbs(profit));
            PrintFormat("[OnTradeTransaction] Deal #%d closed with PnL: %.2f. Consecutive losses: %d",
                        dealTicket, profit, g_riskEngine.GetConsecutiveLosses());
         }
      }
   }
}
