//+------------------------------------------------------------------+
//|                                DeterministicTradingEA_v2.0.mq5   |
//|               Deterministic Rule-Based Expert Advisor ver2.0     |
//|               Stabilized Multi-Symbol Engine & Dual Optimization |
//|               Hard-coded Strategies: MM, SM, UniT (CP & Moving)  |
//|               Option 1: Classic Quant | Option 2: Smart Neural   |
//|                                  Copyright 2026, Quant Systems   |
//+------------------------------------------------------------------+
#property copyright "Quant Systems"
#property link      "https://github.com/quant-systems/deterministic-ea"
#property version   "2.00"
#property description "Deterministic EA ver2.0 - Multi-Symbol Stabilized Engine with <10% Drawdown Protection, Dynamic Volatility Corridor, and Dual Optimization Cores."
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
#include "..\Include\Deterministic\SelfOptimizer.mqh"
#include "..\Include\Deterministic\ExecutionEngine.mqh"
#include "..\Include\Deterministic\PositionManager.mqh"
#include "..\Include\Deterministic\Visualizer.mqh"
#include "..\Include\Deterministic\Journal.mqh"

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - ver2.0 STABILIZED CONFIGURATION               |
//+------------------------------------------------------------------+
input group "=== ver2.0 Core Optimization Engine ==="
input ENUM_OPTIMIZER_CORE InpSelfOptCore        = OPT_CORE_NEURAL;   // Optimization Core (Option 2: Smart Neural Active by Default)
input ENUM_SELF_OPT_MODE InpSelfOptMode         = SELF_OPT_ADAPTIVE; // Self-Optimization Mode (Disabled/Adaptive/Aggressive)
input double            InpNeuralLearningRate   = 0.05;              // Neural Online SGD Learning Rate (0.01 - 0.10)
input int               InpSelfOptRollingTrades = 25;                // Rolling Attribution Window (Trades)
input int               InpSelfOptMinEvalTrades = 3;                 // Min Trades for Strategy Weight Calibration
input bool              InpSelfOptAdaptiveVol   = true;              // Dynamic Volatility Corridor Buffer Scaling
input bool              InpSelfOptAdaptiveWeight= true;              // Adaptive Strategy Risk Weighting (0.20x - 1.50x)
input bool              InpSelfOptAdaptiveTp    = true;              // Adaptive Take Profit R-Multiple Optimization

input group "=== ver2.0 Drawdown & Capital Protection ==="
input bool              InpDynamicDrawdownProtection = true;         // Enable ver2.0 Drawdown Dampener (<10% Max DD Guard)
input double            InpMaxDrawdownCeilingPct     = 9.5;          // Strict Max Drawdown Ceiling (%)
input bool              InpConsecLossThrottle        = true;         // Progressive Risk Throttle on Consecutive Losses
input double            InpBaseRiskPercent           = 1.0;          // Base Risk Per Trade (%)
input double            InpMaxDailyLossPercent       = 3.5;          // Max Daily Loss (%)
input double            InpHardKillThreshold         = 3.2;          // Sovereign Hard Kill Switch (%)
input double            InpMinRiskRewardRatio        = 1.5;          // Minimum Acceptable R:R
input int               InpMaxSpreadPoints           = 30;           // Max Allowed Spread (Points)
input bool              InpEnableEODFlat             = true;         // Close All Positions EOD
input int               InpEODCloseHour              = 23;           // EOD Close Hour
input int               InpEODCloseMinute            = 45;           // EOD Close Minute

input group "=== Timeframe Configuration ==="
input ENUM_TIMEFRAMES   InpStrategyTimeframe    = PERIOD_M5;         // Strategy Primary Timeframe (M5 or M15)

input group "=== Market Structure & Zones ==="
input int               InpSwingLeftBars        = 3;                 // Swing Left Confirmation Bars
input int               InpSwingRightBars       = 3;                 // Swing Right Confirmation Bars (Zero-Lookahead)
input double            InpBosBufferAtrMult     = 0.10;              // BOS Close Buffer (x ATR)
input double            InpZoneDepartureAtrMult = 1.5;               // S/D Zone Departure Threshold (x ATR)

input group "=== Strategy 1: MM Settings ==="
input bool              InpEnableMM             = true;              // Enable MM Strategy
input bool              InpEnableMMStandard     = true;              // Enable MM Standard Trend Signal
input bool              InpEnableMMHighRisk     = true;              // Enable MM High-Risk Signal
input bool              InpEnableMMReversal     = true;              // Enable MM Reversal Signal
input double            InpMMMinSeparationAtr   = 0.50;              // Min EMA50/SlowEMA Separation (x ATR)
input double            InpMMRevSeparationAtr   = 2.50;              // Reversal Min Separation (x ATR)
input bool              InpMMTightEmaSl         = true;              // MM SL: Behind EMA50 / Bounce Low (Tight)
input double            InpMMTightEmaSlBufferAtr= 0.15;              // MM SL Buffer (x ATR)

input group "=== Strategy 2: SM (Stubborn Man) Settings ==="
input bool              InpEnableSM             = true;              // Enable SM (Stubborn Man Range Strategy)
input double            InpSMRefusalWickPercent = 45.0;              // Min Refusal Wick % (Upper for Supply, Lower for Demand)
input double            InpSMZoneApproachAtr    = 0.50;              // Proximity to Zone Boundary (x ATR)

input group "=== Strategy 3: UniT Settings ==="
input bool              InpEnableUniT_CP        = true;              // Enable UniT CP (Spike & Pullback Retest)
input bool              InpEnableUniT_Moving    = true;              // Enable UniT Moving (EMA21 Only)
input double            InpUniTBaseRiskPercent  = 1.0;               // UniT Base Risk %
input bool              InpUniTCP_LastPivotSL   = true;              // UniT CP SL: Last Pivot (Tight & Agile)
input double            InpUniTCP_PivotBufferAtr= 0.10;              // UniT CP SL Buffer Beyond Last Pivot (x ATR)
input bool              InpUniTMoving_BehindEmaSL= true;             // UniT Moving SL: Behind EMA 21 (Tight)
input double            InpUniTMoving_BehindEmaBuf= 0.10;            // UniT Moving SL Buffer Behind EMA 21 (x ATR)

input group "=== Take Profit Configuration ==="
input ENUM_TP_MODE      InpTpMode               = TP_MODE_AUTO;      // Take Profit Mode (Auto vs Manual)
input double            InpManualTpMultiple     = 2.0;               // Manual TP Size (R-Multiple: 1.0 = 1R, 2.0 = 2R, 3.0 = 3R)

input group "=== System & Debug ==="
input ulong             InpBaseMagicNumber      = 90000;             // Base Magic Number
input bool              InpEnableDebugVisuals   = true;              // Enable Chart Debug Visuals
input bool              InpVerboseJournal       = true;              // Verbose Logging to MT5 Journal

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
CSelfOptimizer          g_selfOptimizer;
CExecutionEngine        g_execution;
CPositionManager        g_positionManager;
CVisualizer             g_visualizer;
CJournal                g_journal;

datetime                g_lastBarTime = 0;
double                  g_peakEquity = 0.0;

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
   Print("   INITIALIZING DETERMINISTIC TRADING SYSTEM EA ver2.0   ");
   Print("   Dual Optimization: Option 1 (Classic) | Option 2 (Neural)");
   Print("   Stabilized Multi-Symbol Core with Drawdown Guard <10% ");
   Print("=========================================================");

   // Validate Timeframe (M5 or M15)
   if(InpStrategyTimeframe != PERIOD_M5 && InpStrategyTimeframe != PERIOD_M15)
   {
      PrintFormat("[WARNING] Strategy timeframe %s selected. Recommended: M5 or M15.", EnumToString(InpStrategyTimeframe));
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
   
   // 6. Initialize Self-Optimization Engine (Option 1: Classic Quant vs Option 2: Smart Neural Network)
   g_selfOptimizer.Init(_Symbol, InpStrategyTimeframe, InpSelfOptCore, InpSelfOptMode, InpSelfOptRollingTrades, InpSelfOptMinEvalTrades, InpSelfOptAdaptiveVol, InpSelfOptAdaptiveWeight, InpSelfOptAdaptiveTp);
   g_riskEngine.SetSelfOptimizer(&g_selfOptimizer);

   // 7. Initialize Visualizer & Journal
   g_visualizer.Init(InpEnableDebugVisuals);
   g_journal.SetVerbose(InpVerboseJournal);

   g_peakEquity = AccountInfoDouble(ACCOUNT_EQUITY);

   PrintFormat("[INIT SUCCESS] Attached to %s. Strategy TF: %s. OptCore: %s. DD Ceiling: %.1f%%",
               _Symbol, EnumToString(InpStrategyTimeframe),
               (InpSelfOptCore == OPT_CORE_NEURAL) ? "OPT_CORE_NEURAL (ver2.0 Smart MLP)" : "OPT_CORE_CLASSIC (Rolling Buffer)",
               InpMaxDrawdownCeilingPct);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   PrintFormat("[DEINIT] Deterministic EA ver2.0 removed. Reason code: %d", reason);
   g_indicators.Release();
   g_visualizer.CleanObjects();
   Comment("");
}

//+------------------------------------------------------------------+
//| Check Drawdown Ceiling Guard (ver2.0 Capital Protection)         |
//+------------------------------------------------------------------+
bool IsDrawdownCeilingBreached()
{
   if(!InpDynamicDrawdownProtection) return false;

   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(currentEquity > g_peakEquity) g_peakEquity = currentEquity;

   if(g_peakEquity > 0.0)
   {
      double currentDrawdown = ((g_peakEquity - currentEquity) / g_peakEquity) * 100.0;
      if(currentDrawdown >= InpMaxDrawdownCeilingPct)
      {
         return true; // Throttle all new trade admissions
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 1. Monitor Open Positions (EOD flat, Hard Kill switch, Stop-loss management)
   g_positionManager.MonitorPositions(g_riskEngine, _Symbol);

   // 2. Only execute on newly closed bar to prevent intrabar repainting
   if(!IsNewClosedBar())
      return;

   // 3. Get Current Market Context & Volatility Buffers
   double currentAtr = g_indicators.GetATR(1);
   if(currentAtr <= 0.0) currentAtr = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 20.0;

   // 4. Update Self-Optimizer Volatility Regime
   g_selfOptimizer.UpdateRegime(g_indicators);

   // 5. Check Drawdown Ceiling Guard
   if(IsDrawdownCeilingBreached())
   {
      string ddMsg = StringFormat("[D-EA v2.0] DRAWDOWN GUARD ACTIVE: Current DD near %.1f%% ceiling. New entries paused.", InpMaxDrawdownCeilingPct);
      Comment(ddMsg + "\n" + g_selfOptimizer.GetTelemetryString());
      return;
   }

   double effectiveAtr = currentAtr * g_selfOptimizer.GetBufferScalar();

   // 6. Display Real-time Telemetry Comment
   Comment(StringFormat("[D-EA ver2.0 | Peak: $%.2f | DD Guard: %.1f%%]\n%s", 
                        g_peakEquity, InpMaxDrawdownCeilingPct, g_selfOptimizer.GetTelemetryString()));

   // 7. Extract Closed Candle Metrics
   CandleMetrics closedCandle;
   if(!g_candleEngine.Analyze(_Symbol, InpStrategyTimeframe, 1, currentAtr, closedCandle))
      return;

   // 8. Update Structural Engines
   g_structure.Update(effectiveAtr, 120);
   g_sdEngine.Update(effectiveAtr, g_candleEngine);

   // 9. Evaluate Market Trend Regime
   ENUM_MARKET_TREND marketTrend = g_trendEngine.Evaluate(_Symbol, InpStrategyTimeframe, g_indicators, g_structure, g_sdEngine, currentAtr);

   // 10. Generate Candidate Signals from Active Strategies
   TradeSignal candidates[3];
   int count = 0;

   // Strategy 1: MM (Trend Following)
   if(InpEnableMM)
   {
      TradeSignal s;
      if(g_strategyMM.Evaluate(closedCandle, g_indicators, g_structure, marketTrend, currentAtr, s))
         candidates[count++] = s;
   }

   // Strategy 2: SM (Stubborn Man Range Rejection)
   if(InpEnableSM)
   {
      TradeSignal s;
      if(g_strategySM.Evaluate(closedCandle, g_trendEngine, g_sdEngine, g_structure, currentAtr, s))
         candidates[count++] = s;
   }

   // Strategy 3: UniT (CP Spike Retest & Moving Follow)
   if(InpEnableUniT_CP || InpEnableUniT_Moving)
   {
      TradeSignal s;
      if(g_strategyUniT.Evaluate(closedCandle, g_indicators, g_structure, marketTrend, currentAtr, s))
         candidates[count++] = s;
   }

   // 11. Pipeline Processing: Conflict Resolution, Risk Sizing, and Order Execution
   for(int i = 0; i < count; i++)
   {
      TradeSignal sig = candidates[i];
      g_journal.LogSignalGenerated(sig);

      // A. Conflict Filter
      string conflictErr = "";
      if(!g_conflictManager.ValidateSignal(sig, marketTrend, currentAtr, conflictErr))
      {
         g_journal.LogSignalRejected(sig, "CONFLICT_MANAGER", conflictErr);
         continue;
      }

      // B. Risk Sovereign Check
      string riskErr = "";
      if(!g_riskEngine.ValidateSignal(sig, riskErr))
      {
         g_journal.LogSignalRejected(sig, "RISK_ENGINE", riskErr);
         continue;
      }

      // C. Consecutive Loss Throttle (ver2.0 Drawdown Mitigation)
      if(InpConsecLossThrottle)
      {
         StrategyPerformanceMetrics perf;
         if(g_selfOptimizer.GetPerformanceMetrics(sig.strategy, perf))
         {
            if(perf.consecutiveLosses >= 2) sig.riskPercent *= 0.60;
            if(perf.consecutiveLosses >= 4) sig.riskPercent *= 0.30;
         }
      }

      // D. Lot Size Calculation
      string lotErr = "";
      double lots = g_riskEngine.CalculateLotSize(_Symbol, sig.entryPrice, sig.stopLoss, sig.riskPercent, lotErr);
      if(lots <= 0.0)
      {
         g_journal.LogSignalRejected(sig, "POSITION_SIZING", lotErr);
         continue;
      }

      // E. Execution Engine
      ulong ticket = 0;
      string execErr = "";
      if(g_execution.ExecuteSignal(sig, lots, ticket, execErr))
      {
         g_journal.LogOrderExecuted(ticket, sig, lots);
         g_visualizer.DrawSignal(sig);
         break; // Enforce single position admission per bar
      }
      else
      {
         g_journal.LogSignalRejected(sig, "EXECUTION_ROUTING", execErr);
      }
   }
}

//+------------------------------------------------------------------+
//| Trade transaction listener for closed deals & online learning    |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      ulong dealTicket = trans.deal;
      if(HistoryDealSelect(dealTicket))
      {
         long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
         if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT)
         {
            double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
            g_riskEngine.OnTradeClosed(profit, MathAbs(profit));

            // Update peak equity for drawdown monitoring
            double currentEq = AccountInfoDouble(ACCOUNT_EQUITY);
            if(currentEq > g_peakEquity) g_peakEquity = currentEq;

            // Route trade outcome to SelfOptimizer
            long magic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
            ENUM_STRATEGY_TYPE strat = STRATEGY_NONE;
            if((ulong)magic >= InpBaseMagicNumber && (ulong)magic <= InpBaseMagicNumber + 500)
            {
               int stratId = (int)((magic - InpBaseMagicNumber) / 100);
               if(stratId >= 1 && stratId <= 4)
                  strat = (ENUM_STRATEGY_TYPE)stratId;
            }

            double riskDollars = MathMax(1.0, AccountInfoDouble(ACCOUNT_EQUITY) * (InpBaseRiskPercent / 100.0));
            double rMult = (profit >= 0.0) ? (profit / riskDollars) : -1.0;
            g_selfOptimizer.OnTradeClosed(strat, profit, rMult);
         }
      }
   }
}
