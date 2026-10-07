//+------------------------------------------------------------------+
//|                                                      Defines.mqh |
//|                             Deterministic Trading EA Architecture|
//|                    MM, SM (Stubborn Man), UniT Rule-Based System |
//|                                  Copyright 2026, Quant Systems   |
//+------------------------------------------------------------------+
#property copyright "Quant Systems"
#property link      "https://github.com/quant-systems/deterministic-ea"
#property strict

//+------------------------------------------------------------------+
//| Enumerations                                                     |
//+------------------------------------------------------------------+
enum ENUM_STRATEGY_TYPE
{
   STRATEGY_NONE         = 0,
   STRATEGY_MM           = 1,   // MM (Trend Following)
   STRATEGY_SM           = 2,   // SM / Stubborn Man (Range / S&D Rejection)
   STRATEGY_UNIT_CP      = 3,   // UniT CP (Spike & Pullback Retest)
   STRATEGY_UNIT_MOVING  = 4    // UniT Moving (EMA21 Dynamic Follow)
};

enum ENUM_TP_MODE
{
   TP_MODE_AUTO   = 0,  // Auto: Strategy determines TP (e.g. 1.5R, 1.8R, 2.0R, 2.5R per setup)
   TP_MODE_MANUAL = 1   // Manual: User chooses fixed R-multiple for all signals (e.g. 1R, 2R, 3R)
};

enum ENUM_SELF_OPT_MODE
{
   SELF_OPT_DISABLED  = 0,  // Self-optimization disabled: static configuration
   SELF_OPT_ADAPTIVE  = 1,  // Dynamic strategy weighting, ATR buffer scaling & TP optimization
   SELF_OPT_AGGRESSIVE= 2   // Accelerated response to regime shifts and strategy drawdowns
};

enum ENUM_OPTIMIZER_CORE
{
   OPT_CORE_CLASSIC  = 0, // Option 1: Classic Quant Optimization (Rolling attribution & statistical thresholds)
   OPT_CORE_NEURAL   = 1  // Option 2: Smart Neural Network Optimization (Multi-Layer Perceptron & online learning)
};

enum ENUM_SIGNAL_TYPE
{
   SIGNAL_NONE           = 0,
   // MM
   SIGNAL_MM_STANDARD_BUY      = 101,
   SIGNAL_MM_STANDARD_SELL     = 102,
   SIGNAL_MM_HIGHRISK_BUY      = 103,
   SIGNAL_MM_HIGHRISK_SELL     = 104,
   SIGNAL_MM_REVERSAL_BUY      = 105,
   SIGNAL_MM_REVERSAL_SELL     = 106,
   
   // SM (Stubborn Man)
   SIGNAL_SM_RANGE_BUY         = 201, // Buy at Demand / Range Low
   SIGNAL_SM_RANGE_SELL        = 202, // Sell at Supply / Range High
   
   // UniT CP
   SIGNAL_UNIT_CP_BUY          = 301, // Retest of Bullish Spike High
   SIGNAL_UNIT_CP_SELL         = 302, // Retest of Bearish Spike Low
   
   // UniT Moving
   SIGNAL_UNIT_MOVING_STD_BUY  = 401,
   SIGNAL_UNIT_MOVING_STD_SELL = 402,
   SIGNAL_UNIT_MOVING_HR_BUY   = 403,
   SIGNAL_UNIT_MOVING_HR_SELL  = 404
};

enum ENUM_DIRECTION
{
   DIR_NONE = 0,
   DIR_BUY  = 1,
   DIR_SELL = -1
};

enum ENUM_MARKET_TREND
{
   TREND_UNCLEAR    = 0,
   TREND_UP         = 1,
   TREND_DOWN       = -1,
   TREND_RANGE      = 2,
   TREND_TRANSITION = 3
};

enum ENUM_ZONE_TYPE
{
   ZONE_NONE   = 0,
   ZONE_DEMAND = 1,
   ZONE_SUPPLY = 2
};

enum ENUM_ZONE_STATUS
{
   ZONE_FRESH    = 0,
   ZONE_TESTED   = 1,
   ZONE_WEAKENED = 2,
   ZONE_BROKEN   = 3
};

enum ENUM_SWING_TYPE
{
   SWING_NONE = 0,
   SWING_HIGH = 1,
   SWING_LOW  = -1
};

enum ENUM_STRUCTURE_EVENT
{
   EVENT_NONE         = 0,
   EVENT_HH           = 1,   // Higher High
   EVENT_HL           = 2,   // Higher Low
   EVENT_LH           = 3,   // Lower High
   EVENT_LL           = 4,   // Lower Low
   EVENT_BOS_BULLISH  = 5,   // Break of Structure Up
   EVENT_BOS_BEARISH  = 6,   // Break of Structure Down
   EVENT_CHOCH_BULLISH= 7,   // Change of Character Bullish
   EVENT_CHOCH_BEARISH= 8    // Change of Character Bearish
};

enum ENUM_REJECTION_REASON
{
   REJECT_NONE = 0,
   REJECT_TREND_CONFLICT,
   REJECT_RANGE_CONFLICT,
   REJECT_MARKET_UNCLEAR,
   REJECT_PRICE_ZONE_OCCUPIED,
   REJECT_ALREADY_OPEN_SYMBOL,
   REJECT_DAILY_DRAWDOWN_LIMIT,
   REJECT_HARD_KILL_REACHED,
   REJECT_INVALID_RR,
   REJECT_SPREAD_TOO_HIGH,
   REJECT_SLIPPAGE_TOO_HIGH,
   REJECT_OUTSIDE_TRADING_HOURS,
   REJECT_EOD_APPROACHING,
   REJECT_CONSECUTIVE_LOSS_RESTRICTION,
   REJECT_INVALID_SL_PLACEMENT,
   REJECT_INVALID_TP_PLACEMENT,
   REJECT_VOLUME_OUT_OF_BOUNDS
};

//+------------------------------------------------------------------+
//| Structures                                                       |
//+------------------------------------------------------------------+
struct SwingPoint
{
   int               barIndex;         // Bar index where swing occurred (confirmed)
   datetime          time;             // Time of swing bar
   double            price;            // Price of swing extreme
   ENUM_SWING_TYPE   type;             // High or Low
   bool              isConfirmed;      // Confirmed after right-side bars closed
   bool              isProtected;      // Protected structural swing
   bool              isBroken;         // Has price closed beyond this level
   datetime          brokenTime;       // When it was broken
};

struct SupplyDemandZone
{
   int               id;
   ENUM_ZONE_TYPE    type;             // Supply or Demand
   ENUM_ZONE_STATUS  status;           // Fresh, Tested, Weakened, Broken
   double            upperPrice;       // Zone High
   double            lowerPrice;       // Zone Low
   datetime          creationTime;     // Candle time that formed zone
   int               sourceBarIndex;   // Source bar index
   int               touchCount;       // Number of retests
   double            strength;         // Deterministic score based on initial departure
   bool              isBroken;         // Invalidation flag
   datetime          lastTouchTime;    // Last interaction time
};

struct CandleMetrics
{
   datetime          time;
   double            open;
   double            high;
   double            low;
   double            close;
   double            bodySize;
   double            totalRange;
   double            upperWick;
   double            lowerWick;
   double            bodyPercent;      // Body / Range (0.0 to 100.0)
   double            upperWickPercent; // Upper Wick / Range (0.0 to 100.0)
   double            lowerWickPercent; // Lower Wick / Range (0.0 to 100.0)
   ENUM_DIRECTION    direction;        // DIR_BUY if close > open, DIR_SELL if close < open
   double            atrRatio;         // totalRange / ATR(14)
   bool              isStrongBull;     // Close in top quartile, body >= 60%, range >= 0.8 ATR
   bool              isStrongBear;     // Close in bottom quartile, body >= 60%, range >= 0.8 ATR
   bool              isVeryStrongBull; // Body >= 75%, range >= 1.2 ATR
   bool              isVeryStrongBear; // Body >= 75%, range >= 1.2 ATR
   bool              isPinbarBull;     // Lower wick >= 60%, small body
   bool              isPinbarBear;     // Upper wick >= 60%, small body
   bool              isDoji;           // Body <= 15%
   bool              isRefusalNearSupply; // Long upper wick (>= 50%), rejection from zone
   bool              isRefusalNearDemand; // Long lower wick (>= 50%), rejection from zone
};

struct TradeSignal
{
   ENUM_STRATEGY_TYPE   strategy;
   ENUM_SIGNAL_TYPE     signalType;
   ENUM_DIRECTION       direction;
   string               symbol;
   ENUM_TIMEFRAMES      timeframe;
   datetime             timestamp;
   double               entryPrice;
   double               stopLoss;
   double               takeProfit;
   double               riskPercent;      // Final approved risk % (e.g. 1.0, 0.5, 0.25)
   double               riskRewardRatio;  // Expected TP distance / SL distance
   ENUM_MARKET_TREND    marketTrend;
   double               relevantLevel;    // Structural or S/D level tied to setup
   string               reasonCode;       // Detailed deterministic trace
   double               deterministicStrength; // 0-100 deterministic rule compliance score
   bool                 isValid;
   ENUM_REJECTION_REASON rejectionReason;
   string               rejectionDetail;
};

struct RangeChannel
{
   bool              isActive;
   double            rangeHigh;
   double            rangeLow;
   double            midPoint;
   datetime          detectedTime;
   int               supplyZoneId;
   int               demandZoneId;
   int               consecutiveChochCount;
   int               barsInOscillation;
};

struct AccountRiskState
{
   double            initialDailyBalance;
   double            dailyHighWaterMark;
   double            currentEquity;
   double            dailyDrawdownPercent;
   bool              isKillSwitchTriggered; // True if daily drawdown >= 3.8%
   int               consecutiveLosses;
   double            lossRecoveryTarget;
   double            recoveredAmount;
   bool              isReducedRiskMode;     // True if 3 consecutive losses
 };

struct StrategyPerformanceMetrics
{
   ENUM_STRATEGY_TYPE strategy;
   string             name;
   int                totalTrades;
   int                winningTrades;
   int                losingTrades;
   double             winRate;             // 0.0 to 100.0%
   double             grossProfit;
   double             grossLoss;
   double             profitFactor;        // grossProfit / grossLoss
   double             avgRMultiple;        // Average realized R-multiple
   double             currentRiskWeight;   // Multiplier on base risk (0.25 to 1.25)
   bool               isOnProbation;       // True if win rate < 35% or PF < 0.80
   int                consecutiveLosses;
   double             performanceScore;    // Composite ranking score (WR * PF)
};

struct VolatilityRegimeMetrics
{
   double             currentAtr;
   double             baselineAtr;         // 100-period baseline ATR
   double             volatilityRatio;     // currentAtr / baselineAtr
   double             bufferScalar;        // 0.85 (compressed) to 1.25 (expansion)
   bool               isExpansionRegime;   // Ratio > 1.35
   bool               isCompressionRegime; // Ratio < 0.75
};

struct SelfOptimizerReport
{
   datetime           lastOptimizationTime;
   ENUM_OPTIMIZER_CORE coreType;
   int                evalTradeCount;
   double             bestPerformingWeight;
   ENUM_STRATEGY_TYPE topStrategy;
   double             globalBufferScalar;
   double             recommendedTpMultiple;
   string             optimizationNotes;
};

struct NeuralNetworkMetrics
{
   double             predictedRiskWeight;    // 0.25 to 1.50
   double             winConfidence;          // 0.0 to 1.0 (win probability)
   double             predictedRMultiple;     // 1.2 to 3.0
   double             neuralBufferScalar;     // 0.80 to 1.40
   double             currentLoss;            // MSE loss from recent online step
   int                trainingEpochs;         // Cumulative online backpropagation updates
   datetime           lastInferenceTime;
};
