//+------------------------------------------------------------------+
//|                                                 CandleEngine.mqh |
//|                             Deterministic Candle Analysis Engine |
//|                    No ML / Pure Mathematical & Structural Ratios |
//|                                  Copyright 2026, Quant Systems   |
//+------------------------------------------------------------------+
#property copyright "Quant Systems"
#property strict

#include "Defines.mqh"

class CCandleEngine
{
private:
   double            m_minBodyPercentStrong;
   double            m_minBodyPercentVeryStrong;
   double            m_minRefusalWickPercent;
   double            m_maxDojiBodyPercent;

public:
   CCandleEngine(double minBodyStrong = 55.0,
                 double minBodyVeryStrong = 75.0,
                 double minRefusalWick = 45.0,
                 double maxDojiBody = 15.0)
      : m_minBodyPercentStrong(minBodyStrong),
        m_minBodyPercentVeryStrong(minBodyVeryStrong),
        m_minRefusalWickPercent(minRefusalWick),
        m_maxDojiBodyPercent(maxDojiBody)
   {
   }

   ~CCandleEngine() {}

   //+------------------------------------------------------------------+
   //| Analyze a single closed or historical candle deterministically   |
   //+------------------------------------------------------------------+
   bool Analyze(const string symbol,
                const ENUM_TIMEFRAMES tf,
                const int shift,
                const double currentAtr,
                CandleMetrics &metrics)
   {
      MqlRates rates[];
      ArraySetAsSeries(rates, true);

      if(CopyRates(symbol, tf, shift, 1, rates) < 1)
         return false;

      metrics.time  = rates[0].time;
      metrics.open  = rates[0].open;
      metrics.high  = rates[0].high;
      metrics.low   = rates[0].low;
      metrics.close = rates[0].close;

      metrics.totalRange = metrics.high - metrics.low;
      if(metrics.totalRange <= 0.0)
         metrics.totalRange = SymbolInfoDouble(symbol, SYMBOL_POINT);

      metrics.bodySize = MathAbs(metrics.close - metrics.open);
      
      if(metrics.close >= metrics.open)
      {
         metrics.direction = DIR_BUY;
         metrics.upperWick = metrics.high - metrics.close;
         metrics.lowerWick = metrics.open - metrics.low;
      }
      else
      {
         metrics.direction = DIR_SELL;
         metrics.upperWick = metrics.high - metrics.open;
         metrics.lowerWick = metrics.close - metrics.low;
      }

      metrics.bodyPercent      = (metrics.bodySize / metrics.totalRange) * 100.0;
      metrics.upperWickPercent = (metrics.upperWick / metrics.totalRange) * 100.0;
      metrics.lowerWickPercent = (metrics.lowerWick / metrics.totalRange) * 100.0;

      metrics.atrRatio = (currentAtr > 0.0) ? (metrics.totalRange / currentAtr) : 1.0;

      // Classifications
      metrics.isDoji = (metrics.bodyPercent <= m_maxDojiBodyPercent);

      metrics.isStrongBull = (metrics.direction == DIR_BUY &&
                              metrics.bodyPercent >= m_minBodyPercentStrong &&
                              metrics.upperWickPercent <= 25.0 &&
                              metrics.atrRatio >= 0.70);

      metrics.isStrongBear = (metrics.direction == DIR_SELL &&
                              metrics.bodyPercent >= m_minBodyPercentStrong &&
                              metrics.lowerWickPercent <= 25.0 &&
                              metrics.atrRatio >= 0.70);

      metrics.isVeryStrongBull = (metrics.direction == DIR_BUY &&
                                  metrics.bodyPercent >= m_minBodyPercentVeryStrong &&
                                  metrics.upperWickPercent <= 15.0 &&
                                  metrics.atrRatio >= 1.10);

      metrics.isVeryStrongBear = (metrics.direction == DIR_SELL &&
                                  metrics.bodyPercent >= m_minBodyPercentVeryStrong &&
                                  metrics.lowerWickPercent <= 15.0 &&
                                  metrics.atrRatio >= 1.10);

      // Pinbars
      metrics.isPinbarBull = (metrics.lowerWickPercent >= 55.0 && metrics.bodyPercent <= 30.0);
      metrics.isPinbarBear = (metrics.upperWickPercent >= 55.0 && metrics.bodyPercent <= 30.0);

      // Refusal candle detection:
      // A refusal candle against Supply shows rejection via a long upper wick
      metrics.isRefusalNearSupply = (metrics.upperWickPercent >= m_minRefusalWickPercent &&
                                     metrics.close <= (metrics.high - (metrics.totalRange * 0.40)));

      // A refusal candle against Demand shows rejection via a long lower wick
      metrics.isRefusalNearDemand = (metrics.lowerWickPercent >= m_minRefusalWickPercent &&
                                     metrics.close >= (metrics.low + (metrics.totalRange * 0.40)));

      return true;
   }

   //+------------------------------------------------------------------+
   //| Check if candle crossed an EMA level deterministically           |
   //+------------------------------------------------------------------+
   bool IsCandleCrossingLevel(const CandleMetrics &candle, const double levelPrice, bool &crossedUp, bool &crossedDown)
   {
      crossedUp   = (candle.low <= levelPrice && candle.close > levelPrice && candle.direction == DIR_BUY);
      crossedDown = (candle.high >= levelPrice && candle.close < levelPrice && candle.direction == DIR_SELL);
      return (crossedUp || crossedDown);
   }

   //+------------------------------------------------------------------+
   //| Check if candle touched an EMA level (wick or body inside)       |
   //+------------------------------------------------------------------+
   bool IsCandleTouchingLevel(const CandleMetrics &candle, const double levelPrice, const double tolerancePoints = 0.0)
   {
      return (candle.high + tolerancePoints >= levelPrice && candle.low - tolerancePoints <= levelPrice);
   }
};
