//+------------------------------------------------------------------+
//|                                                 SupplyDemand.mqh |
//|                     Deterministic Supply & Demand Zone Engine    |
//|               Strict Lifecycle: Fresh, Tested, Weakened, Broken  |
//|                                  Copyright 2026, Quant Systems   |
//+------------------------------------------------------------------+
#property copyright "Quant Systems"
#property strict

#include "Defines.mqh"
#include "CandleEngine.mqh"

class CSupplyDemandEngine
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_maxZones;
   double            m_minDepartureAtrMult; // Multiplier of ATR required for impulsive departure
   int               m_maxZoneAgeBars;

   SupplyDemandZone  m_zones[];
   int               m_zoneCount;
   int               m_nextZoneId;

public:
   CSupplyDemandEngine()
      : m_maxZones(30),
        m_minDepartureAtrMult(1.5),
        m_maxZoneAgeBars(300),
        m_zoneCount(0),
        m_nextZoneId(1)
   {
      ArrayResize(m_zones, m_maxZones);
   }

   ~CSupplyDemandEngine() {}

   //+------------------------------------------------------------------+
   //| Init                                                             |
   //+------------------------------------------------------------------+
   bool Init(const string symbol,
             const ENUM_TIMEFRAMES tf,
             const double minDepartureAtr = 1.5,
             const int maxZones = 30)
   {
      m_symbol              = symbol;
      m_timeframe           = tf;
      m_minDepartureAtrMult = minDepartureAtr;
      m_maxZones            = maxZones;
      ArrayResize(m_zones, m_maxZones);
      Reset();
      return true;
   }

   void Reset()
   {
      m_zoneCount  = 0;
      m_nextZoneId = 1;
      for(int i = 0; i < m_maxZones; i++)
         ZeroMemory(m_zones[i]);
   }

   //+------------------------------------------------------------------+
   //| Update Zones on Closed Candle (Zero-Lookahead)                   |
   //| Evaluates if a new zone was created at shift 2 by an impulsive   |
   //| departure at shift 1, and updates touch / broken status of all   |
   //| existing active zones based on shift 1 bar.                      |
   //+------------------------------------------------------------------+
   void Update(const double currentAtr, CCandleEngine &candleEngine)
   {
      MqlRates rates[];
      ArraySetAsSeries(rates, true);

      // Need shift 1 (latest closed) and shift 2 (base candidate)
      if(CopyRates(m_symbol, m_timeframe, 1, 4, rates) < 4)
         return;

      // 1. Detect New Zone from departure
      // Base candle is rates[1] (shift 2). Departure candle is rates[0] (shift 1).
      CandleMetrics depMetrics;
      candleEngine.Analyze(m_symbol, m_timeframe, 1, currentAtr, depMetrics);

      // Impulsive Bullish Departure -> Creates Demand Zone at the base
      if(depMetrics.isStrongBull && depMetrics.totalRange >= (currentAtr * m_minDepartureAtrMult))
      {
         // Verify base is not already registered
         if(!IsZoneAtTime(rates[1].time))
         {
            CreateZone(ZONE_DEMAND, rates[1].high, rates[1].low, rates[1].time, 2, depMetrics.atrRatio * 20.0);
         }
      }
      // Impulsive Bearish Departure -> Creates Supply Zone at the base
      else if(depMetrics.isStrongBear && depMetrics.totalRange >= (currentAtr * m_minDepartureAtrMult))
      {
         if(!IsZoneAtTime(rates[1].time))
         {
            CreateZone(ZONE_SUPPLY, rates[1].high, rates[1].low, rates[1].time, 2, depMetrics.atrRatio * 20.0);
         }
      }

      // 2. Update lifecycle of existing zones against latest closed bar (rates[0])
      UpdateZoneLifecycles(rates[0]);
   }

   //+------------------------------------------------------------------+
   //| Create a new Supply or Demand Zone                               |
   //+------------------------------------------------------------------+
   void CreateZone(const ENUM_ZONE_TYPE type,
                   const double upper,
                   const double lower,
                   const datetime creationTime,
                   const int sourceBar,
                   const double strength)
   {
      SupplyDemandZone zone;
      zone.id             = m_nextZoneId++;
      zone.type           = type;
      zone.status         = ZONE_FRESH;
      zone.upperPrice     = upper;
      zone.lowerPrice     = lower;
      zone.creationTime   = creationTime;
      zone.sourceBarIndex = sourceBar;
      zone.touchCount     = 0;
      zone.strength       = MathMin(strength, 100.0);
      zone.isBroken       = false;
      zone.lastTouchTime  = 0;

      // Add to array (shift down)
      for(int i = MathMin(m_zoneCount, m_maxZones - 1); i > 0; i--)
         m_zones[i] = m_zones[i - 1];

      m_zones[0] = zone;
      if(m_zoneCount < m_maxZones) m_zoneCount++;
   }

   //+------------------------------------------------------------------+
   //| Update status of existing zones based on candle interaction      |
   //+------------------------------------------------------------------+
   void UpdateZoneLifecycles(const MqlRates &bar)
   {
      for(int i = 0; i < m_zoneCount; i++)
      {
         if(m_zones[i].isBroken) continue;

         // Check Supply Invalidation (Candle closes above zone upper limit)
         if(m_zones[i].type == ZONE_SUPPLY)
         {
            if(bar.close > m_zones[i].upperPrice)
            {
               m_zones[i].isBroken = true;
               m_zones[i].status   = ZONE_BROKEN;
               continue;
            }

            // Check Interaction / Touch (High penetrated into zone)
            if(bar.high >= m_zones[i].lowerPrice && bar.high <= m_zones[i].upperPrice)
            {
               m_zones[i].touchCount++;
               m_zones[i].lastTouchTime = bar.time;
               if(m_zones[i].touchCount == 1)
                  m_zones[i].status = ZONE_TESTED;
               else if(m_zones[i].touchCount >= 2)
                  m_zones[i].status = ZONE_WEAKENED;
            }
         }
         // Check Demand Invalidation (Candle closes below zone lower limit)
         else if(m_zones[i].type == ZONE_DEMAND)
         {
            if(bar.close < m_zones[i].lowerPrice)
            {
               m_zones[i].isBroken = true;
               m_zones[i].status   = ZONE_BROKEN;
               continue;
            }

            // Check Interaction / Touch (Low penetrated into zone)
            if(bar.low <= m_zones[i].upperPrice && bar.low >= m_zones[i].lowerPrice)
            {
               m_zones[i].touchCount++;
               m_zones[i].lastTouchTime = bar.time;
               if(m_zones[i].touchCount == 1)
                  m_zones[i].status = ZONE_TESTED;
               else if(m_zones[i].touchCount >= 2)
                  m_zones[i].status = ZONE_WEAKENED;
            }
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Find Nearest Valid Supply Zone above price                       |
   //+------------------------------------------------------------------+
   bool FindNearestSupply(const double currentPrice, SupplyDemandZone &outZone, const bool onlyReliable = true) const
   {
      double minDistance = DBL_MAX;
      int foundIndex = -1;

      for(int i = 0; i < m_zoneCount; i++)
      {
         if(m_zones[i].type != ZONE_SUPPLY || m_zones[i].isBroken)
            continue;

         if(onlyReliable && m_zones[i].status == ZONE_WEAKENED)
            continue; // Skip heavily weakened zones if requested

         if(m_zones[i].lowerPrice >= currentPrice)
         {
            double dist = m_zones[i].lowerPrice - currentPrice;
            if(dist < minDistance)
            {
               minDistance = dist;
               foundIndex  = i;
            }
         }
      }

      if(foundIndex >= 0)
      {
         outZone = m_zones[foundIndex];
         return true;
      }
      return false;
   }

   //+------------------------------------------------------------------+
   //| Find Nearest Valid Demand Zone below price                       |
   //+------------------------------------------------------------------+
   bool FindNearestDemand(const double currentPrice, SupplyDemandZone &outZone, const bool onlyReliable = true) const
   {
      double minDistance = DBL_MAX;
      int foundIndex = -1;

      for(int i = 0; i < m_zoneCount; i++)
      {
         if(m_zones[i].type != ZONE_DEMAND || m_zones[i].isBroken)
            continue;

         if(onlyReliable && m_zones[i].status == ZONE_WEAKENED)
            continue;

         if(m_zones[i].upperPrice <= currentPrice)
         {
            double dist = currentPrice - m_zones[i].upperPrice;
            if(dist < minDistance)
            {
               minDistance = dist;
               foundIndex  = i;
            }
         }
      }

      if(foundIndex >= 0)
      {
         outZone = m_zones[foundIndex];
         return true;
      }
      return false;
   }

   //+------------------------------------------------------------------+
   //| Check if price is currently inside a valid Zone                  |
   //+------------------------------------------------------------------+
   bool IsPriceInZone(const double price, const ENUM_ZONE_TYPE zoneType, SupplyDemandZone &outZone) const
   {
      for(int i = 0; i < m_zoneCount; i++)
      {
         if(m_zones[i].type == zoneType && !m_zones[i].isBroken)
         {
            if(price >= m_zones[i].lowerPrice && price <= m_zones[i].upperPrice)
            {
               outZone = m_zones[i];
               return true;
            }
         }
      }
      return false;
   }

   bool IsZoneAtTime(const datetime t) const
   {
      for(int i = 0; i < m_zoneCount; i++)
         if(m_zones[i].creationTime == t) return true;
      return false;
   }

   int GetZoneCount() const { return m_zoneCount; }
   bool GetZoneByIndex(const int idx, SupplyDemandZone &zone) const
   {
      if(idx < 0 || idx >= m_zoneCount) return false;
      zone = m_zones[idx];
      return true;
   }
};
