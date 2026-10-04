//+------------------------------------------------------------------+
//|                                                  StrategySM.mqh  |
//|                 SM (Stubborn Man) Range Trading Strategy         |
//|            Supply/Demand Boundary Trading with Refusal Candles   |
//|                                  Copyright 2026, Quant Systems   |
//+------------------------------------------------------------------+
#property copyright "Quant Systems"
#property strict

#include "Defines.mqh"
#include "CandleEngine.mqh"
#include "SupplyDemand.mqh"
#include "MarketStructure.mqh"
#include "TrendEngine.mqh"

enum ENUM_SM_STATE
{
   SM_STATE_IDLE = 0,
   SM_STATE_RANGE_CONFIRMED,
   SM_STATE_ZONE_APPROACH,
   SM_STATE_ZONE_TOUCH,
   SM_STATE_REFUSAL_DETECTED,
   SM_STATE_SIGNAL_READY
};

class CStrategySM
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   ENUM_SM_STATE     m_state;
   
   double            m_riskPercent;
   double            m_zoneApproachAtrMult; // Proximity to consider approaching boundary
   double            m_minRefusalWickPercent;

public:
   CStrategySM()
      : m_state(SM_STATE_IDLE),
        m_riskPercent(1.0),
        m_zoneApproachAtrMult(0.50),
        m_minRefusalWickPercent(45.0)
   {
   }

   ~CStrategySM() {}

   bool Init(const string symbol,
             const ENUM_TIMEFRAMES tf,
             const double riskPercent = 1.0,
             const double approachAtr = 0.50)
   {
      m_symbol              = symbol;
      m_timeframe           = tf;
      m_riskPercent         = riskPercent;
      m_zoneApproachAtrMult = approachAtr;
      m_state               = SM_STATE_IDLE;
      return true;
   }

   //+------------------------------------------------------------------+
   //| Evaluate Stubborn Man Range Strategy                             |
   //+------------------------------------------------------------------+
   bool Evaluate(const CandleMetrics &candle,
                 const CTrendEngine &trendEngine,
                 const CSupplyDemandEngine &sdEngine,
                 const CMarketStructureEngine &structure,
                 const double currentAtr,
                 TradeSignal &signal)
   {
      ZeroMemory(signal);
      signal.strategy   = STRATEGY_SM;
      signal.symbol     = m_symbol;
      signal.timeframe  = m_timeframe;
      signal.timestamp  = candle.time;
      signal.marketTrend= trendEngine.GetCurrentTrend();
      signal.isValid    = false;

      // RULE: SM is strictly a RANGE strategy. It must NOT trigger during confirmed TREND!
      if(trendEngine.GetCurrentTrend() == TREND_UP || trendEngine.GetCurrentTrend() == TREND_DOWN)
      {
         signal.rejectionReason = REJECT_TREND_CONFLICT;
         signal.rejectionDetail = "SM blocked: Market is in confirmed TREND state";
         return false;
      }

      if(!trendEngine.IsRangeActive())
      {
         m_state = SM_STATE_IDLE;
         return false;
      }

      m_state = SM_STATE_RANGE_CONFIRMED;
      RangeChannel channel = trendEngine.GetRangeChannel();

      // Find relevant Supply and Demand zones around range boundaries
      SupplyDemandZone supplyZone, demandZone;
      bool hasSupply = sdEngine.FindNearestSupply(channel.midPoint, supplyZone, true);
      bool hasDemand = sdEngine.FindNearestDemand(channel.midPoint, demandZone, true);

      //-----------------------------------------------------------------
      // 1. SM SELL SETUP (Range High / Supply Rejection)
      //-----------------------------------------------------------------
      if(hasSupply && !supplyZone.isBroken)
      {
         // Price approaches or touches the supply boundary
         bool nearSupply = (candle.high >= (supplyZone.lowerPrice - (currentAtr * m_zoneApproachAtrMult)) &&
                            candle.low <= supplyZone.upperPrice);

         if(nearSupply)
         {
            m_state = SM_STATE_ZONE_APPROACH;

            // Price touched supply
            if(candle.high >= supplyZone.lowerPrice)
            {
               m_state = SM_STATE_ZONE_TOUCH;

               // Check Refusal Candle (upper wick rejection or pinbar bear)
               if(candle.isRefusalNearSupply || candle.isPinbarBear || 
                  (candle.upperWickPercent >= m_minRefusalWickPercent && candle.close < candle.open))
               {
                  m_state = SM_STATE_REFUSAL_DETECTED;

                  // Invalidation is above supply zone
                  double slPrice = supplyZone.upperPrice + (currentAtr * 0.15);
                  // Target is before opposing demand or range low
                  double tpPrice = hasDemand ? (demandZone.upperPrice + (currentAtr * 0.20)) : (channel.rangeLow + (currentAtr * 0.20));

                  if(candle.close > tpPrice && (candle.close - tpPrice) >= (slPrice - candle.close))
                  {
                     signal.signalType   = SIGNAL_SM_RANGE_SELL;
                     signal.direction    = DIR_SELL;
                     signal.entryPrice   = candle.close;
                     signal.stopLoss     = slPrice;
                     signal.takeProfit   = tpPrice;
                     signal.riskPercent  = m_riskPercent;
                     signal.riskRewardRatio = (signal.entryPrice - signal.takeProfit) / (signal.stopLoss - signal.entryPrice);
                     signal.relevantLevel= supplyZone.lowerPrice;
                     signal.reasonCode   = "SM_SELL|RANGE_CONFIRMED|SUPPLY_TOUCH|REFUSAL_UPPER_WICK|NO_BOS";
                     signal.deterministicStrength = 85.0;
                     signal.isValid      = true;
                     m_state = SM_STATE_SIGNAL_READY;
                     return true;
                  }
               }
            }
         }
      }

      //-----------------------------------------------------------------
      // 2. SM BUY SETUP (Range Low / Demand Rejection)
      //-----------------------------------------------------------------
      if(hasDemand && !demandZone.isBroken)
      {
         bool nearDemand = (candle.low <= (demandZone.upperPrice + (currentAtr * m_zoneApproachAtrMult)) &&
                            candle.high >= demandZone.lowerPrice);

         if(nearDemand)
         {
            m_state = SM_STATE_ZONE_APPROACH;

            if(candle.low <= demandZone.upperPrice)
            {
               m_state = SM_STATE_ZONE_TOUCH;

               // Check Refusal Candle (lower wick rejection or pinbar bull)
               if(candle.isRefusalNearDemand || candle.isPinbarBull ||
                  (candle.lowerWickPercent >= m_minRefusalWickPercent && candle.close > candle.open))
               {
                  m_state = SM_STATE_REFUSAL_DETECTED;

                  double slPrice = demandZone.lowerPrice - (currentAtr * 0.15);
                  double tpPrice = hasSupply ? (supplyZone.lowerPrice - (currentAtr * 0.20)) : (channel.rangeHigh - (currentAtr * 0.20));

                  if(candle.close < tpPrice && (tpPrice - candle.close) >= (candle.close - slPrice))
                  {
                     signal.signalType   = SIGNAL_SM_RANGE_BUY;
                     signal.direction    = DIR_BUY;
                     signal.entryPrice   = candle.close;
                     signal.stopLoss     = slPrice;
                     signal.takeProfit   = tpPrice;
                     signal.riskPercent  = m_riskPercent;
                     signal.riskRewardRatio = (signal.takeProfit - signal.entryPrice) / (signal.entryPrice - signal.stopLoss);
                     signal.relevantLevel= demandZone.upperPrice;
                     signal.reasonCode   = "SM_BUY|RANGE_CONFIRMED|DEMAND_TOUCH|REFUSAL_LOWER_WICK|NO_BOS";
                     signal.deterministicStrength = 85.0;
                     signal.isValid      = true;
                     m_state = SM_STATE_SIGNAL_READY;
                     return true;
                  }
               }
            }
         }
      }

      m_state = SM_STATE_IDLE;
      return false;
   }

   ENUM_SM_STATE GetState() const { return m_state; }
};
