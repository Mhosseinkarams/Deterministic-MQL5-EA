//+------------------------------------------------------------------+
//|                                                  StrategyMM.mqh  |
//|                         MM Strategy Implementation (M5 / M15)    |
//|               Trend-Following with EMA50 & Slow EMA (600/800)    |
//|                 Slow EMA is Trend Context ONLY - NEVER a Trigger |
//|                                  Copyright 2026, Quant Systems   |
//+------------------------------------------------------------------+
#property copyright "Quant Systems"
#property strict

#include "Defines.mqh"
#include "CandleEngine.mqh"
#include "Indicators.mqh"
#include "MarketStructure.mqh"

enum ENUM_MM_STATE
{
   MM_STATE_IDLE = 0,
   MM_STATE_TREND_CONFIRMED,
   MM_STATE_EMA50_INTERACTION,
   MM_STATE_CANDLE_VALIDATED,
   MM_STATE_SIGNAL_READY
};

class CStrategyMM
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   ENUM_MM_STATE     m_state;
   
   bool              m_enableStandard;
   bool              m_enableHighRisk;
   bool              m_enableReversal;
   
   double            m_minEmaSeparationAtr;
   double            m_reversalMinSeparationAtr;
   double            m_riskStandard;
   double            m_riskHighRisk;
   double            m_riskReversal;

   bool              m_useTightEmaSl;         // Anchor SL tightly behind EMA50/bounce candle
   double            m_tightEmaSlBufferAtr;   // Buffer behind EMA50 (x ATR)

public:
   CStrategyMM()
      : m_state(MM_STATE_IDLE),
        m_enableStandard(true),
        m_enableHighRisk(true),
        m_enableReversal(true),
        m_minEmaSeparationAtr(0.50),
        m_reversalMinSeparationAtr(2.50),
        m_riskStandard(1.0),
        m_riskHighRisk(0.50),
        m_riskReversal(0.50),
        m_useTightEmaSl(true),
        m_tightEmaSlBufferAtr(0.15)
   {
   }

   ~CStrategyMM() {}

   bool Init(const string symbol,
             const ENUM_TIMEFRAMES tf,
             const bool enableStd = true,
             const bool enableHR = true,
             const bool enableRev = true,
             const double minSepAtr = 0.50,
             const double revSepAtr = 2.50,
             const bool useTightEmaSl = true,
             const double tightEmaSlBufferAtr = 0.15)
   {
      m_symbol                   = symbol;
      m_timeframe                = tf;
      m_enableStandard           = enableStd;
      m_enableHighRisk           = enableHR;
      m_enableReversal           = enableRev;
      m_minEmaSeparationAtr      = minSepAtr;
      m_reversalMinSeparationAtr = revSepAtr;
      m_useTightEmaSl            = useTightEmaSl;
      m_tightEmaSlBufferAtr      = tightEmaSlBufferAtr;
      m_state                    = MM_STATE_IDLE;
      return true;
   }

   //+------------------------------------------------------------------+
   //| Evaluate MM Strategy on closed candle (Shift 1)                  |
   //+------------------------------------------------------------------+
   bool Evaluate(const CandleMetrics &candle,
                 const CIndicatorEngine &indicators,
                 const CMarketStructureEngine &structure,
                 const ENUM_MARKET_TREND marketTrend,
                 const double currentAtr,
                 TradeSignal &signal)
   {
      ZeroMemory(signal);
      signal.strategy   = STRATEGY_MM;
      signal.symbol     = m_symbol;
      signal.timeframe  = m_timeframe;
      signal.timestamp  = candle.time;
      signal.marketTrend= marketTrend;
      signal.isValid    = false;

      // MM is strictly a TREND strategy. If market is confirmed RANGE, signal is blocked by rule.
      if(marketTrend == TREND_RANGE)
      {
         signal.rejectionReason = REJECT_RANGE_CONFLICT;
         signal.rejectionDetail = "MM blocked: Market is in confirmed RANGE state";
         return false;
      }

      double ema50   = indicators.GetEMA50(1);
      double slowEma = indicators.GetSlowEMA(1);
      double emaSep  = MathAbs(ema50 - slowEma);
      double minSep  = currentAtr * m_minEmaSeparationAtr;

      //-----------------------------------------------------------------
      // 1. REVERSAL SETUP
      //-----------------------------------------------------------------
      if(m_enableReversal && emaSep >= (currentAtr * m_reversalMinSeparationAtr))
      {
         // Bullish Reversal: Market was in downtrend (EMA50 < SlowEMA), but price was overextended,
         // and candle produces a strong bullish cross of EMA50 with structural rejection
         if(ema50 < slowEma && candle.isStrongBull && candle.close > ema50 && candle.open <= ema50)
         {
            // Verify structural swing low exists to place invalidation
            SwingPoint lastLow;
            if(structure.GetLastLow(lastLow))
            {
               signal.signalType   = SIGNAL_MM_REVERSAL_BUY;
               signal.direction    = DIR_BUY;
               signal.entryPrice   = candle.close;
               signal.stopLoss     = MathMin(candle.low, lastLow.price) - (currentAtr * 0.15);
               signal.takeProfit   = signal.entryPrice + ((signal.entryPrice - signal.stopLoss) * 2.0);
               signal.riskPercent  = m_riskReversal;
               signal.riskRewardRatio = (signal.takeProfit - signal.entryPrice) / (signal.entryPrice - signal.stopLoss);
               signal.relevantLevel= ema50;
               signal.reasonCode   = "MM_REVERSAL_BUY|LARGE_EMA_SEP|STRONG_BULL_CROSS_EMA50|STRUCTURE_LOW_SL";
               signal.deterministicStrength = 80.0;
               signal.isValid      = true;
               m_state = MM_STATE_SIGNAL_READY;
               return true;
            }
         }
         // Bearish Reversal: Market was in uptrend (EMA50 > SlowEMA), price was overextended,
         // candle produces a strong bearish cross of EMA50 down
         else if(ema50 > slowEma && candle.isStrongBear && candle.close < ema50 && candle.open >= ema50)
         {
            SwingPoint lastHigh;
            if(structure.GetLastHigh(lastHigh))
            {
               signal.signalType   = SIGNAL_MM_REVERSAL_SELL;
               signal.direction    = DIR_SELL;
               signal.entryPrice   = candle.close;
               signal.stopLoss     = MathMax(candle.high, lastHigh.price) + (currentAtr * 0.15);
               signal.takeProfit   = signal.entryPrice - ((signal.stopLoss - signal.entryPrice) * 2.0);
               signal.riskPercent  = m_riskReversal;
               signal.riskRewardRatio = (signal.entryPrice - signal.takeProfit) / (signal.stopLoss - signal.entryPrice);
               signal.relevantLevel= ema50;
               signal.reasonCode   = "MM_REVERSAL_SELL|LARGE_EMA_SEP|STRONG_BEAR_CROSS_EMA50|STRUCTURE_HIGH_SL";
               signal.deterministicStrength = 80.0;
               signal.isValid      = true;
               m_state = MM_STATE_SIGNAL_READY;
               return true;
            }
         }
      }

      //-----------------------------------------------------------------
      // 2. STANDARD & HIGH-RISK TREND SETUPS
      //-----------------------------------------------------------------
      // Requires EMA separation and trend alignment
      if(emaSep < minSep)
      {
         signal.rejectionReason = REJECT_MARKET_UNCLEAR;
         signal.rejectionDetail = "MM: EMA50 and Slow EMA separation below minimum ATR threshold";
         return false;
      }

      // BULLISH TREND
      if(ema50 > slowEma && marketTrend == TREND_UP)
      {
         m_state = MM_STATE_TREND_CONFIRMED;

         // Check interaction with EMA50
         // Candle must touch or interact with EMA50
         bool touchesEma50 = (candle.low <= (ema50 + (currentAtr * 0.10)) && candle.high >= (ema50 - (currentAtr * 0.10)));
         
         if(touchesEma50)
         {
            m_state = MM_STATE_EMA50_INTERACTION;

            // Check A: Standard Signal (Candle bounces off EMA50 and closes strong bullish above EMA50)
            if(m_enableStandard && candle.isStrongBull && candle.close > ema50)
            {
               double slLevel = 0.0;
               if(m_useTightEmaSl)
               {
                  // Agile Stop Loss: Anchored behind EMA50 / bounce low to avoid holding for too long
                  slLevel = MathMin(candle.low, ema50) - (currentAtr * m_tightEmaSlBufferAtr);
               }
               else
               {
                  // Macro swing low
                  SwingPoint lastLow;
                  slLevel = candle.low - (currentAtr * 0.15);
                  if(structure.GetLastLow(lastLow) && lastLow.price < candle.close)
                     slLevel = MathMin(slLevel, lastLow.price);
               }

               if(slLevel >= candle.close)
                  slLevel = candle.close - (currentAtr * 0.30);

               signal.signalType   = SIGNAL_MM_STANDARD_BUY;
               signal.direction    = DIR_BUY;
               signal.entryPrice   = candle.close;
               signal.stopLoss     = slLevel;
               signal.takeProfit   = signal.entryPrice + ((signal.entryPrice - signal.stopLoss) * 2.0);
               signal.riskPercent  = m_riskStandard;
               signal.riskRewardRatio = (signal.takeProfit - signal.entryPrice) / (signal.entryPrice - signal.stopLoss);
               signal.relevantLevel= ema50;
               signal.reasonCode   = "MM_BUY_STANDARD|TREND_UP|EMA50_BOUNCE|STRONG_BULL_CANDLE";
               signal.deterministicStrength = 90.0;
               signal.isValid      = true;
               m_state = MM_STATE_SIGNAL_READY;
               return true;
            }

            // Check B: High-Risk Signal (Candle crossed up through EMA50 with very high momentum)
            if(m_enableHighRisk && candle.isVeryStrongBull && candle.open < ema50 && candle.close > ema50)
            {
               double slLevel = m_useTightEmaSl ? (MathMin(candle.low, ema50) - (currentAtr * m_tightEmaSlBufferAtr))
                                                : (candle.low - (currentAtr * 0.20));

               signal.signalType   = SIGNAL_MM_HIGHRISK_BUY;
               signal.direction    = DIR_BUY;
               signal.entryPrice   = candle.close;
               signal.stopLoss     = slLevel;
               signal.takeProfit   = signal.entryPrice + ((signal.entryPrice - signal.stopLoss) * 1.5);
               signal.riskPercent  = m_riskHighRisk;
               signal.riskRewardRatio = (signal.takeProfit - signal.entryPrice) / (signal.entryPrice - signal.stopLoss);
               signal.relevantLevel= ema50;
               signal.reasonCode   = "MM_BUY_HIGHRISK|TREND_UP|EMA50_MOMENTUM_CROSS|VERY_STRONG_BULL";
               signal.deterministicStrength = 75.0;
               signal.isValid      = true;
               m_state = MM_STATE_SIGNAL_READY;
               return true;
            }
         }
      }
      // BEARISH TREND
      else if(ema50 < slowEma && marketTrend == TREND_DOWN)
      {
         m_state = MM_STATE_TREND_CONFIRMED;

         bool touchesEma50 = (candle.high >= (ema50 - (currentAtr * 0.10)) && candle.low <= (ema50 + (currentAtr * 0.10)));

         if(touchesEma50)
         {
            m_state = MM_STATE_EMA50_INTERACTION;

            // Check A: Standard Signal (Candle bounces off EMA50 down with strong bearish close)
            if(m_enableStandard && candle.isStrongBear && candle.close < ema50)
            {
               double slLevel = 0.0;
               if(m_useTightEmaSl)
               {
                  // Agile Stop Loss: Anchored behind EMA50 / bounce high
                  slLevel = MathMax(candle.high, ema50) + (currentAtr * m_tightEmaSlBufferAtr);
               }
               else
               {
                  SwingPoint lastHigh;
                  slLevel = candle.high + (currentAtr * 0.15);
                  if(structure.GetLastHigh(lastHigh) && lastHigh.price > candle.close)
                     slLevel = MathMax(slLevel, lastHigh.price);
               }

               if(slLevel <= candle.close)
                  slLevel = candle.close + (currentAtr * 0.30);

               signal.signalType   = SIGNAL_MM_STANDARD_SELL;
               signal.direction    = DIR_SELL;
               signal.entryPrice   = candle.close;
               signal.stopLoss     = slLevel;
               signal.takeProfit   = signal.entryPrice - ((signal.stopLoss - signal.entryPrice) * 2.0);
               signal.riskPercent  = m_riskStandard;
               signal.riskRewardRatio = (signal.entryPrice - signal.takeProfit) / (signal.stopLoss - signal.entryPrice);
               signal.relevantLevel= ema50;
               signal.reasonCode   = "MM_SELL_STANDARD|TREND_DOWN|EMA50_BOUNCE|STRONG_BEAR_CANDLE";
               signal.deterministicStrength = 90.0;
               signal.isValid      = true;
               m_state = MM_STATE_SIGNAL_READY;
               return true;
            }

            // Check B: High-Risk Signal (Candle crossed down through EMA50 with very high bearish momentum)
            if(m_enableHighRisk && candle.isVeryStrongBear && candle.open > ema50 && candle.close < ema50)
            {
               double slLevel = m_useTightEmaSl ? (MathMax(candle.high, ema50) + (currentAtr * m_tightEmaSlBufferAtr))
                                                : (candle.high + (currentAtr * 0.20));

               signal.signalType   = SIGNAL_MM_HIGHRISK_SELL;
               signal.direction    = DIR_SELL;
               signal.entryPrice   = candle.close;
               signal.stopLoss     = slLevel;
               signal.takeProfit   = signal.entryPrice - ((signal.stopLoss - signal.entryPrice) * 1.5);
               signal.riskPercent  = m_riskHighRisk;
               signal.riskRewardRatio = (signal.entryPrice - signal.takeProfit) / (signal.stopLoss - signal.entryPrice);
               signal.relevantLevel= ema50;
               signal.reasonCode   = "MM_SELL_HIGHRISK|TREND_DOWN|EMA50_MOMENTUM_CROSS|VERY_STRONG_BEAR";
               signal.deterministicStrength = 75.0;
               signal.isValid      = true;
               m_state = MM_STATE_SIGNAL_READY;
               return true;
            }
         }
      }

      m_state = MM_STATE_IDLE;
      return false;
   }

   ENUM_MM_STATE GetState() const { return m_state; }
};
