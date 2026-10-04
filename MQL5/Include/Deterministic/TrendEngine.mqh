//+------------------------------------------------------------------+
//|                                                  TrendEngine.mqh |
//|                     Deterministic Trend & Range Detection Engine |
//|               Strict Classification: UP, DOWN, RANGE, TRANSITION |
//|                                  Copyright 2026, Quant Systems   |
//+------------------------------------------------------------------+
#property copyright "Quant Systems"
#property strict

#include "Defines.mqh"
#include "Indicators.mqh"
#include "MarketStructure.mqh"
#include "SupplyDemand.mqh"

class CTrendEngine
{
private:
   ENUM_MARKET_TREND m_currentTrend;
   RangeChannel      m_rangeChannel;
   double            m_minEmaSeparationAtrMult; // Minimum EMA50 vs Slow EMA separation to confirm strong trend
   int               m_maxBarsWithoutBosForRange;

public:
   CTrendEngine(double minEmaSep = 0.50, int maxBarsNoBos = 25)
      : m_currentTrend(TREND_UNCLEAR),
        m_minEmaSeparationAtrMult(minEmaSep),
        m_maxBarsWithoutBosForRange(maxBarsNoBos)
   {
      ZeroMemory(m_rangeChannel);
   }

   ~CTrendEngine() {}

   //+------------------------------------------------------------------+
   //| Evaluate Trend and Range State deterministically                |
   //+------------------------------------------------------------------+
   ENUM_MARKET_TREND Evaluate(const string symbol,
                              const ENUM_TIMEFRAMES tf,
                              const CIndicatorEngine &indicators,
                              const CMarketStructureEngine &structure,
                              const CSupplyDemandEngine &sdEngine,
                              const double currentAtr)
   {
      double ema50   = indicators.GetEMA50(1);
      double slowEma = indicators.GetSlowEMA(1);
      double closePrice = 0.0;
      
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      if(CopyRates(symbol, tf, 1, 1, rates) >= 1)
         closePrice = rates[0].close;
      else
         return TREND_UNCLEAR;

      ENUM_MARKET_TREND structTrend = structure.GetStructuralTrend();
      int chochCount = structure.GetRecentChochCount();
      int bosCount   = structure.GetRecentBosCount();

      // 1. Check for Confirmed RANGE condition:
      // Condition A: Multiple CHOCHs with low BOS count (indecisive chopping)
      // Condition B: Price bouncing between identified supply and demand
      bool rangeConditionA = (chochCount >= 2 && bosCount <= 1);

      // Check oscillation between reliable Supply and Demand
      SupplyDemandZone supZone, demZone;
      bool hasSupply = sdEngine.FindNearestSupply(closePrice, supZone, true);
      bool hasDemand = sdEngine.FindNearestDemand(closePrice, demZone, true);
      bool rangeConditionB = false;

      if(hasSupply && hasDemand)
      {
         double zoneSpan = supZone.lowerPrice - demZone.upperPrice;
         // If span is between 1.5 ATR and 6.0 ATR and price is inside this corridor
         if(zoneSpan >= (currentAtr * 1.5) && zoneSpan <= (currentAtr * 8.0))
         {
            if(closePrice >= demZone.lowerPrice && closePrice <= supZone.upperPrice)
            {
               rangeConditionB = true;
            }
         }
      }

      if(rangeConditionA || rangeConditionB)
      {
         m_currentTrend = TREND_RANGE;
         m_rangeChannel.isActive = true;
         m_rangeChannel.rangeHigh = hasSupply ? supZone.upperPrice : (closePrice + currentAtr * 2.0);
         m_rangeChannel.rangeLow  = hasDemand ? demZone.lowerPrice : (closePrice - currentAtr * 2.0);
         m_rangeChannel.midPoint  = (m_rangeChannel.rangeHigh + m_rangeChannel.rangeLow) / 2.0;
         m_rangeChannel.detectedTime = rates[0].time;
         m_rangeChannel.supplyZoneId = hasSupply ? supZone.id : 0;
         m_rangeChannel.demandZoneId = hasDemand ? demZone.id : 0;
         return m_currentTrend;
      }

      m_rangeChannel.isActive = false;

      // 2. Trend Classification
      double emaDistance = ema50 - slowEma;
      double minSeparation = currentAtr * m_minEmaSeparationAtrMult;

      // TREND_UP: Structure is UP, EMA50 > SlowEMA, Price > EMA50
      if(structTrend == TREND_UP && emaDistance > minSeparation && closePrice > ema50)
      {
         m_currentTrend = TREND_UP;
      }
      // TREND_DOWN: Structure is DOWN, EMA50 < SlowEMA, Price < EMA50
      else if(structTrend == TREND_DOWN && emaDistance < -minSeparation && closePrice < ema50)
      {
         m_currentTrend = TREND_DOWN;
      }
      // TRANSITION / UNCLEAR: Structure and EMAs disagree or insufficient separation
      else
      {
         m_currentTrend = TREND_TRANSITION;
      }

      return m_currentTrend;
   }

   ENUM_MARKET_TREND GetCurrentTrend() const { return m_currentTrend; }
   bool IsRangeActive() const { return (m_currentTrend == TREND_RANGE && m_rangeChannel.isActive); }
   RangeChannel GetRangeChannel() const { return m_rangeChannel; }
};
