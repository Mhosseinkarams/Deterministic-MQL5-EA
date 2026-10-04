//+------------------------------------------------------------------+
//|                                                StrategyUniT.mqh  |
//|               UniT Strategy Implementation (CP & Moving)         |
//|         CP: Spike & Pullback Retest (Exact Pullback Definition)  |
//|         CP SL: Anchored to Last Pivot Low/High for Agile Sizing  |
//|         Moving: EMA21 Follower (SL Behind EMA 21)                |
//|                     NO REVERSAL SETUP IN UniT                    |
//|                                  Copyright 2026, Quant Systems   |
//+------------------------------------------------------------------+
#property copyright "Quant Systems"
#property strict

#include "Defines.mqh"
#include "CandleEngine.mqh"
#include "Indicators.mqh"
#include "MarketStructure.mqh"

enum ENUM_CP_STATE
{
   CP_STATE_IDLE = 0,
   CP_STATE_SPIKE_DETECTED,
   CP_STATE_WAIT_PULLBACK,
   CP_STATE_PULLBACK_CONFIRMED,
   CP_STATE_WAIT_RETEST,
   CP_STATE_SIGNAL_READY
};

enum ENUM_MOVING_STATE
{
   MOVING_STATE_IDLE = 0,
   MOVING_STATE_TREND_CONFIRMED,
   MOVING_STATE_EMA21_PROXIMITY,
   MOVING_STATE_CANDLE_VALIDATED,
   MOVING_STATE_SIGNAL_READY
};

class CStrategyUniT
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   
   // Sub-strategy state machines
   ENUM_CP_STATE     m_cpState;
   ENUM_MOVING_STATE m_movingState;

   bool              m_enableCP;
   bool              m_enableMoving;
   
   // CP Tracker Variables
   ENUM_DIRECTION    m_spikeDir;
   double            m_spikeExtremePrice;  // High of bull spike or Low of bear spike
   datetime          m_spikeTime;
   double            m_pullbackExtremePrice; // Low of pullback in bull spike or High in bear spike
   datetime          m_pullbackTime;
   int               m_barsSinceSpike;
   int               m_barsSincePullback;

   // Risk multipliers & SL parameters
   double            m_cpBaseRiskPercent;
   double            m_movingRiskPercent;
   double            m_ema21ProximityAtrMult;
   
   // Agile SL parameters
   bool              m_useLastPivotForCP;         // Place CP SL at the last local pivot
   double            m_cpLastPivotBufferAtr;      // Buffer beyond last pivot (x ATR)
   bool              m_movingBehindEmaSL;         // Place Moving SL strictly behind EMA 21
   double            m_movingBehindEmaBufferAtr;  // Buffer behind EMA 21 (x ATR)

public:
   CStrategyUniT()
      : m_cpState(CP_STATE_IDLE),
        m_movingState(MOVING_STATE_IDLE),
        m_enableCP(true),
        m_enableMoving(true),
        m_spikeDir(DIR_NONE),
        m_spikeExtremePrice(0.0),
        m_pullbackExtremePrice(0.0),
        m_barsSinceSpike(0),
        m_barsSincePullback(0),
        m_cpBaseRiskPercent(1.0),
        m_movingRiskPercent(1.0),
        m_ema21ProximityAtrMult(0.35),
        m_useLastPivotForCP(true),
        m_cpLastPivotBufferAtr(0.10),
        m_movingBehindEmaSL(true),
        m_movingBehindEmaBufferAtr(0.10)
   {
   }

   ~CStrategyUniT() {}

   bool Init(const string symbol,
             const ENUM_TIMEFRAMES tf,
             const bool enableCP = true,
             const bool enableMoving = true,
             const double baseRisk = 1.0,
             const bool useLastPivotForCP = true,
             const double cpPivotBufferAtr = 0.10,
             const bool movingBehindEmaSL = true,
             const double movingBehindEmaBufferAtr = 0.10)
   {
      m_symbol                    = symbol;
      m_timeframe                 = tf;
      m_enableCP                  = enableCP;
      m_enableMoving              = enableMoving;
      m_cpBaseRiskPercent         = baseRisk;
      m_movingRiskPercent         = baseRisk;
      m_useLastPivotForCP         = useLastPivotForCP;
      m_cpLastPivotBufferAtr      = cpPivotBufferAtr;
      m_movingBehindEmaSL         = movingBehindEmaSL;
      m_movingBehindEmaBufferAtr  = movingBehindEmaBufferAtr;
      Reset();
      return true;
   }

   void Reset()
   {
      m_cpState              = CP_STATE_IDLE;
      m_movingState          = MOVING_STATE_IDLE;
      m_spikeDir             = DIR_NONE;
      m_spikeExtremePrice    = 0.0;
      m_pullbackExtremePrice = 0.0;
      m_barsSinceSpike       = 0;
      m_barsSincePullback    = 0;
   }

   //+------------------------------------------------------------------+
   //| Evaluate UniT Strategies on closed candle (Shift 1)              |
   //+------------------------------------------------------------------+
   bool Evaluate(const CandleMetrics &candle,
                 const CIndicatorEngine &indicators,
                 const CMarketStructureEngine &structure,
                 const ENUM_MARKET_TREND marketTrend,
                 const double currentAtr,
                 TradeSignal &signal)
   {
      ZeroMemory(signal);
      signal.strategy   = STRATEGY_UNIT_CP;
      signal.symbol     = m_symbol;
      signal.timeframe  = m_timeframe;
      signal.timestamp  = candle.time;
      signal.marketTrend= marketTrend;
      signal.isValid    = false;

      // Rule: UniT trend setups are blocked if market is confirmed RANGE
      if(marketTrend == TREND_RANGE)
      {
         signal.rejectionReason = REJECT_RANGE_CONFLICT;
         signal.rejectionDetail = "UniT blocked: Market is in confirmed RANGE state";
         return false;
      }

      // 1. Evaluate UniT CP first if enabled
      if(m_enableCP)
      {
         if(EvaluateCP(candle, indicators, structure, marketTrend, currentAtr, signal))
            return true;
      }

      // 2. Evaluate UniT Moving if enabled
      if(m_enableMoving)
      {
         if(EvaluateMoving(candle, indicators, structure, marketTrend, currentAtr, signal))
            return true;
      }

      return false;
   }

private:
   //+------------------------------------------------------------------+
   //| UniT CP (Spike & Pullback Retest) Implementation                 |
   //| Strict adherence to exact pullback definition:                   |
   //| "A candle constitutes a pullback if it sees beyond the           |
   //|  high/low of the candle immediately before it"                   |
   //| SL is placed at the LAST PIVOT for agile, non-oversized risk.    |
   //+------------------------------------------------------------------+
   bool EvaluateCP(const CandleMetrics &candle,
                   const CIndicatorEngine &indicators,
                   const CMarketStructureEngine &structure,
                   const ENUM_MARKET_TREND marketTrend,
                   const double currentAtr,
                   TradeSignal &signal)
   {
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      // Need last 20 candles to evaluate spike sequence & last pivot
      if(CopyRates(m_symbol, m_timeframe, 1, 20, rates) < 20)
         return false;

      // Update bar counters
      if(m_cpState != CP_STATE_IDLE)
      {
         m_barsSinceSpike++;
         if(m_cpState >= CP_STATE_PULLBACK_CONFIRMED)
            m_barsSincePullback++;

         // Timeout if spike/pullback setup takes more than 20 bars
         if(m_barsSinceSpike > 20)
         {
            Reset();
         }
      }

      // Step 1: Detect Spike if IDLE
      if(m_cpState == CP_STATE_IDLE)
      {
         // Check Bullish Spike: 3 consecutive bars with higher highs and higher lows, total range >= 1.5 ATR
         bool isBullSpike = (rates[3].close > rates[3].open &&
                             rates[2].close > rates[2].open &&
                             rates[1].close > rates[1].open &&
                             rates[1].high > rates[2].high && rates[2].high > rates[3].high &&
                             rates[1].low > rates[2].low && rates[2].low > rates[3].low);

         if(isBullSpike && (rates[1].high - rates[3].low) >= (currentAtr * 1.5))
         {
            m_spikeDir             = DIR_BUY;
            m_spikeExtremePrice    = rates[1].high;
            m_spikeTime            = rates[1].time;
            m_barsSinceSpike       = 1;
            m_cpState              = CP_STATE_WAIT_PULLBACK;
            return false;
         }

         // Check Bearish Spike: 3 consecutive bars with lower lows and lower highs, total range >= 1.5 ATR
         bool isBearSpike = (rates[3].close < rates[3].open &&
                             rates[2].close < rates[2].open &&
                             rates[1].close < rates[1].open &&
                             rates[1].low < rates[2].low && rates[2].low < rates[3].low &&
                             rates[1].high < rates[2].high && rates[2].high < rates[3].high);

         if(isBearSpike && (rates[3].high - rates[1].low) >= (currentAtr * 1.5))
         {
            m_spikeDir             = DIR_SELL;
            m_spikeExtremePrice    = rates[1].low;
            m_spikeTime            = rates[1].time;
            m_barsSinceSpike       = 1;
            m_cpState              = CP_STATE_WAIT_PULLBACK;
            return false;
         }
      }

      // Step 2: Check for First Pullback
      // "A candle constitutes a pullback if it sees beyond the high/low of the candle immediately before it"
      if(m_cpState == CP_STATE_WAIT_PULLBACK)
      {
         // Current candle under test is rates[0] (shift 1). Candle immediately before is rates[1] (shift 2).
         if(m_spikeDir == DIR_BUY)
         {
            // Pullback in bull move: candle sees beyond the LOW of candle immediately before it
            if(rates[0].low < rates[1].low)
            {
               m_pullbackExtremePrice = rates[0].low;
               m_pullbackTime         = rates[0].time;
               m_barsSincePullback    = 0;
               m_cpState              = CP_STATE_WAIT_RETEST;
               return false;
            }
         }
         else if(m_spikeDir == DIR_SELL)
         {
            // Pullback in bear move: candle sees beyond the HIGH of candle immediately before it
            if(rates[0].high > rates[1].high)
            {
               m_pullbackExtremePrice = rates[0].high;
               m_pullbackTime         = rates[0].time;
               m_barsSincePullback    = 0;
               m_cpState              = CP_STATE_WAIT_RETEST;
               return false;
            }
         }
      }

      // Step 3: Wait for price to return and retest/break the spike extreme
      if(m_cpState == CP_STATE_WAIT_RETEST)
      {
         double ema21 = indicators.GetEMA21(1);

         if(m_spikeDir == DIR_BUY)
         {
            // Update lowest pullback price if ongoing
            if(rates[0].low < m_pullbackExtremePrice)
               m_pullbackExtremePrice = rates[0].low;

            // Retest trigger: candle reaches or closes near/above spike high
            bool retestReached = (rates[0].high >= m_spikeExtremePrice);

            if(retestReached && candle.direction == DIR_BUY && candle.isStrongBull)
            {
               double entryPrice = candle.close;
               double slPrice    = 0.0;

               // SL at LAST PIVOT:
               // Find the most recent local pivot low formed during the pullback turn
               double lastPivotLow = rates[1].low;
               int lookback = MathMin(m_barsSinceSpike + 2, 14);

               // Scan from shift 1 backwards to find the immediate last pivot low
               for(int k = 1; k < lookback - 1; k++)
               {
                  if(rates[k].low <= rates[k - 1].low && rates[k].low <= rates[k + 1].low)
                  {
                     lastPivotLow = rates[k].low;
                     break; // Most recent pivot low
                  }
               }

               slPrice = lastPivotLow - (currentAtr * m_cpLastPivotBufferAtr);

               // Sanity check: Ensure SL is below entry and not negative
               if(slPrice >= entryPrice)
                  slPrice = entryPrice - (currentAtr * 0.30);

               double tpPrice = entryPrice + ((entryPrice - slPrice) * 2.0);

               // Calculate CP deterministic risk scaling:
               // 1% base risk. Each risk-increasing condition reduces risk: 1 condition -> 0.5%, 2 -> 0.25%
               int riskFactors = 0;
               if(marketTrend != TREND_UP) riskFactors++;
               if(entryPrice < ema21) riskFactors++;

               double finalRisk = m_cpBaseRiskPercent;
               for(int r = 0; r < riskFactors; r++)
                  finalRisk *= 0.50;

               signal.strategy     = STRATEGY_UNIT_CP;
               signal.signalType   = SIGNAL_UNIT_CP_BUY;
               signal.direction    = DIR_BUY;
               signal.entryPrice   = entryPrice;
               signal.stopLoss     = slPrice;
               signal.takeProfit   = tpPrice;
               signal.riskPercent  = finalRisk;
               signal.riskRewardRatio = (tpPrice - entryPrice) / (entryPrice - slPrice);
               signal.relevantLevel= m_spikeExtremePrice;
               signal.reasonCode   = StringFormat("UNIT_CP_BUY|SPIKE_RETEST|LAST_PIVOT_SL_%.5f|RISK_FACTORS_%d|RISK_PCT_%.2f", slPrice, riskFactors, finalRisk);
               signal.deterministicStrength = 85.0 - (riskFactors * 15.0);
               signal.isValid      = true;

               Reset();
               return true;
            }
         }
         else if(m_spikeDir == DIR_SELL)
         {
            if(rates[0].high > m_pullbackExtremePrice)
               m_pullbackExtremePrice = rates[0].high;

            bool retestReached = (rates[0].low <= m_spikeExtremePrice);

            if(retestReached && candle.direction == DIR_SELL && candle.isStrongBear)
            {
               double entryPrice = candle.close;
               double slPrice    = 0.0;

               // SL at LAST PIVOT:
               // Find the most recent local pivot high formed during the pullback turn
               double lastPivotHigh = rates[1].high;
               int lookback = MathMin(m_barsSinceSpike + 2, 14);

               for(int k = 1; k < lookback - 1; k++)
               {
                  if(rates[k].high >= rates[k - 1].high && rates[k].high >= rates[k + 1].high)
                  {
                     lastPivotHigh = rates[k].high;
                     break;
                  }
               }

               slPrice = lastPivotHigh + (currentAtr * m_cpLastPivotBufferAtr);

               if(slPrice <= entryPrice)
                  slPrice = entryPrice + (currentAtr * 0.30);

               double tpPrice = entryPrice - ((slPrice - entryPrice) * 2.0);

               int riskFactors = 0;
               if(marketTrend != TREND_DOWN) riskFactors++;
               if(entryPrice > ema21) riskFactors++;

               double finalRisk = m_cpBaseRiskPercent;
               for(int r = 0; r < riskFactors; r++)
                  finalRisk *= 0.50;

               signal.strategy     = STRATEGY_UNIT_CP;
               signal.signalType   = SIGNAL_UNIT_CP_SELL;
               signal.direction    = DIR_SELL;
               signal.entryPrice   = entryPrice;
               signal.stopLoss     = slPrice;
               signal.takeProfit   = tpPrice;
               signal.riskPercent  = finalRisk;
               signal.riskRewardRatio = (entryPrice - tpPrice) / (slPrice - entryPrice);
               signal.relevantLevel= m_spikeExtremePrice;
               signal.reasonCode   = StringFormat("UNIT_CP_SELL|SPIKE_RETEST|LAST_PIVOT_SL_%.5f|RISK_FACTORS_%d|RISK_PCT_%.2f", slPrice, riskFactors, finalRisk);
               signal.deterministicStrength = 85.0 - (riskFactors * 15.0);
               signal.isValid      = true;

               Reset();
               return true;
            }
         }
      }

      return false;
   }

   //+------------------------------------------------------------------+
   //| UniT Moving Signals (EMA21 Only) Implementation                  |
   //| Standard & High-Risk. NO Reversal Setup in UniT Moving.          |
   //| SL is placed BEHIND THE EMA 21 to prevent oversized hold time.   |
   //+------------------------------------------------------------------+
   bool EvaluateMoving(const CandleMetrics &candle,
                       const CIndicatorEngine &indicators,
                       const CMarketStructureEngine &structure,
                       const ENUM_MARKET_TREND marketTrend,
                       const double currentAtr,
                       TradeSignal &signal)
   {
      double ema21 = indicators.GetEMA21(1);
      if(ema21 <= 0.0) return false;

      double proximityTol = currentAtr * m_ema21ProximityAtrMult;

      // BULLISH TREND
      if(marketTrend == TREND_UP)
      {
         bool touchesEma21 = (candle.low <= (ema21 + proximityTol) && candle.high >= (ema21 - proximityTol));
         
         // 1. UniT Moving Standard Buy:
         // Strong bullish candle, agrees with trend, near EMA21 (preferably touches)
         if(touchesEma21 && candle.isStrongBull && candle.close > ema21)
         {
            // SL placed strictly behind EMA 21
            double slPrice = ema21 - (currentAtr * m_movingBehindEmaBufferAtr);

            signal.strategy     = STRATEGY_UNIT_MOVING;
            signal.signalType   = SIGNAL_UNIT_MOVING_STD_BUY;
            signal.direction    = DIR_BUY;
            signal.entryPrice   = candle.close;
            signal.stopLoss     = slPrice;
            signal.takeProfit   = signal.entryPrice + ((signal.entryPrice - signal.stopLoss) * 1.8);
            signal.riskPercent  = m_movingRiskPercent;
            signal.riskRewardRatio = (signal.takeProfit - signal.entryPrice) / (signal.entryPrice - signal.stopLoss);
            signal.relevantLevel= ema21;
            signal.reasonCode   = "UNIT_MOVING_STD_BUY|TREND_UP|EMA21_TOUCH_BOUNCE|SL_BEHIND_EMA21";
            signal.deterministicStrength = 85.0;
            signal.isValid      = true;
            return true;
         }

         // 2. UniT Moving High-Risk Buy:
         // Candle crosses EMA21 with high bullish momentum
         if(candle.isVeryStrongBull && candle.open < ema21 && candle.close > ema21)
         {
            // SL placed strictly behind EMA 21
            double slPrice = ema21 - (currentAtr * m_movingBehindEmaBufferAtr);

            signal.strategy     = STRATEGY_UNIT_MOVING;
            signal.signalType   = SIGNAL_UNIT_MOVING_HR_BUY;
            signal.direction    = DIR_BUY;
            signal.entryPrice   = candle.close;
            signal.stopLoss     = slPrice;
            signal.takeProfit   = signal.entryPrice + ((signal.entryPrice - signal.stopLoss) * 1.5);
            signal.riskPercent  = m_movingRiskPercent * 0.50; // Scaled risk for high-risk
            signal.riskRewardRatio = (signal.takeProfit - signal.entryPrice) / (signal.entryPrice - signal.stopLoss);
            signal.relevantLevel= ema21;
            signal.reasonCode   = "UNIT_MOVING_HR_BUY|TREND_UP|EMA21_MOMENTUM_CROSS|SL_BEHIND_EMA21";
            signal.deterministicStrength = 70.0;
            signal.isValid      = true;
            return true;
         }
      }
      // BEARISH TREND
      else if(marketTrend == TREND_DOWN)
      {
         bool touchesEma21 = (candle.high >= (ema21 - proximityTol) && candle.low <= (ema21 + proximityTol));

         // 1. UniT Moving Standard Sell
         if(touchesEma21 && candle.isStrongBear && candle.close < ema21)
         {
            // SL placed strictly behind EMA 21
            double slPrice = ema21 + (currentAtr * m_movingBehindEmaBufferAtr);

            signal.strategy     = STRATEGY_UNIT_MOVING;
            signal.signalType   = SIGNAL_UNIT_MOVING_STD_SELL;
            signal.direction    = DIR_SELL;
            signal.entryPrice   = candle.close;
            signal.stopLoss     = slPrice;
            signal.takeProfit   = signal.entryPrice - ((signal.stopLoss - signal.entryPrice) * 1.8);
            signal.riskPercent  = m_movingRiskPercent;
            signal.riskRewardRatio = (signal.entryPrice - signal.takeProfit) / (signal.stopLoss - signal.entryPrice);
            signal.relevantLevel= ema21;
            signal.reasonCode   = "UNIT_MOVING_STD_SELL|TREND_DOWN|EMA21_TOUCH_BOUNCE|SL_BEHIND_EMA21";
            signal.deterministicStrength = 85.0;
            signal.isValid      = true;
            return true;
         }

         // 2. UniT Moving High-Risk Sell
         if(candle.isVeryStrongBear && candle.open > ema21 && candle.close < ema21)
         {
            // SL placed strictly behind EMA 21
            double slPrice = ema21 + (currentAtr * m_movingBehindEmaBufferAtr);

            signal.strategy     = STRATEGY_UNIT_MOVING;
            signal.signalType   = SIGNAL_UNIT_MOVING_HR_SELL;
            signal.direction    = DIR_SELL;
            signal.entryPrice   = candle.close;
            signal.stopLoss     = slPrice;
            signal.takeProfit   = signal.entryPrice - ((signal.stopLoss - signal.entryPrice) * 1.5);
            signal.riskPercent  = m_movingRiskPercent * 0.50;
            signal.riskRewardRatio = (signal.entryPrice - signal.takeProfit) / (signal.stopLoss - signal.entryPrice);
            signal.relevantLevel= ema21;
            signal.reasonCode   = "UNIT_MOVING_HR_SELL|TREND_DOWN|EMA21_MOMENTUM_CROSS|SL_BEHIND_EMA21";
            signal.deterministicStrength = 70.0;
            signal.isValid      = true;
            return true;
         }
      }

      return false;
   }
};
