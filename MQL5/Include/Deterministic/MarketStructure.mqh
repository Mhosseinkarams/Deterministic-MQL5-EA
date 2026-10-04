//+------------------------------------------------------------------+
//|                                              MarketStructure.mqh |
//|                       Deterministic Market Structure Engine      |
//|               Strict Zero-Lookahead Swings, BOS, CHOCH, HH/HL/LH |
//|                                  Copyright 2026, Quant Systems   |
//+------------------------------------------------------------------+
#property copyright "Quant Systems"
#property strict

#include "Defines.mqh"

class CMarketStructureEngine
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_leftBars;           // Bars to left of swing
   int               m_rightBars;          // Bars to right of swing required for confirmation
   double            m_bosBufferAtrMult;   // Buffer beyond swing in ATR terms to confirm break
   int               m_maxHistorySwings;

   SwingPoint        m_swingHighs[];
   SwingPoint        m_swingLows[];
   int               m_highCount;
   int               m_lowCount;

   ENUM_MARKET_TREND m_structuralTrend;
   SwingPoint        m_lastConfirmedHigh;
   SwingPoint        m_lastConfirmedLow;
   SwingPoint        m_protectedHigh;
   SwingPoint        m_protectedLow;

   ENUM_STRUCTURE_EVENT m_lastEvent;
   datetime          m_lastEventTime;
   int               m_recentChochCount;   // Track CHOCH frequency for range detection
   int               m_recentBosCount;

public:
   CMarketStructureEngine()
      : m_leftBars(3),
        m_rightBars(3),
        m_bosBufferAtrMult(0.10),
        m_maxHistorySwings(50),
        m_highCount(0),
        m_lowCount(0),
        m_structuralTrend(TREND_UNCLEAR),
        m_lastEvent(EVENT_NONE),
        m_lastEventTime(0),
        m_recentChochCount(0),
        m_recentBosCount(0)
   {
      ArrayResize(m_swingHighs, m_maxHistorySwings);
      ArrayResize(m_swingLows, m_maxHistorySwings);
      ZeroMemory(m_lastConfirmedHigh);
      ZeroMemory(m_lastConfirmedLow);
      ZeroMemory(m_protectedHigh);
      ZeroMemory(m_protectedLow);
   }

   ~CMarketStructureEngine() {}

   //+------------------------------------------------------------------+
   //| Initialization                                                   |
   //+------------------------------------------------------------------+
   bool Init(const string symbol,
             const ENUM_TIMEFRAMES tf,
             const int leftBars = 3,
             const int rightBars = 3,
             const double bosBufferAtrMult = 0.10)
   {
      m_symbol           = symbol;
      m_timeframe        = tf;
      m_leftBars         = leftBars;
      m_rightBars        = rightBars;
      m_bosBufferAtrMult = bosBufferAtrMult;

      Reset();
      return true;
   }

   void Reset()
   {
      m_highCount = 0;
      m_lowCount  = 0;
      m_structuralTrend = TREND_UNCLEAR;
      m_lastEvent = EVENT_NONE;
      m_lastEventTime = 0;
      m_recentChochCount = 0;
      m_recentBosCount = 0;
      ZeroMemory(m_lastConfirmedHigh);
      ZeroMemory(m_lastConfirmedLow);
      ZeroMemory(m_protectedHigh);
      ZeroMemory(m_protectedLow);
   }

   //+------------------------------------------------------------------+
   //| Update Structure on closed candle (Shift 1 = latest closed)      |
   //| ZERO-LOOKAHEAD: A swing at bar K is only confirmed when          |
   //| bar K - rightBars has closed. So if rightBars=3, the swing at    |
   //| shift 4 is evaluated and confirmed at shift 1.                   |
   //+------------------------------------------------------------------+
   void Update(const double currentAtr, const int lookbackBars = 120)
   {
      MqlRates rates[];
      ArraySetAsSeries(rates, true);

      int neededBars = lookbackBars + m_leftBars + m_rightBars + 5;
      if(CopyRates(m_symbol, m_timeframe, 1, neededBars, rates) < neededBars)
         return;

      // Scan backwards from oldest candidate to newest candidate
      // Candidate bar index is 'c'. It has 'm_leftBars' before it and 'm_rightBars' after it.
      // Since rates are series (0 = latest closed bar), 'm_rightBars' are shifts (c - 1 down to c - m_rightBars).
      // 'm_leftBars' are shifts (c + 1 up to c + m_leftBars).
      for(int c = lookbackBars; c >= m_rightBars + 1; c--)
      {
         datetime candidateTime = rates[c].time;
         
         // 1. Check Swing High
         bool isHigh = true;
         for(int l = 1; l <= m_leftBars; l++)
         {
            if(rates[c + l].high >= rates[c].high) { isHigh = false; break; }
         }
         if(isHigh)
         {
            for(int r = 1; r <= m_rightBars; r++)
            {
               if(rates[c - r].high >= rates[c].high) { isHigh = false; break; }
            }
         }

         if(isHigh && !IsSwingHighAlreadyRegistered(candidateTime))
         {
            RegisterSwingHigh(c, rates[c].high, candidateTime);
         }

         // 2. Check Swing Low
         bool isLow = true;
         for(int l = 1; l <= m_leftBars; l++)
         {
            if(rates[c + l].low <= rates[c].low) { isLow = false; break; }
         }
         if(isLow)
         {
            for(int r = 1; r <= m_rightBars; r++)
            {
               if(rates[c - r].low <= rates[c].low) { isLow = false; break; }
            }
         }

         if(isLow && !IsSwingLowAlreadyRegistered(candidateTime))
         {
            RegisterSwingLow(c, rates[c].low, candidateTime);
         }
      }

      // 3. Evaluate BOS and CHOCH on the latest closed candle (rates[0])
      EvaluateStructuralBreaks(rates[0], currentAtr);
   }

   //+------------------------------------------------------------------+
   //| Register a Confirmed Swing High                                  |
   //+------------------------------------------------------------------+
   void RegisterSwingHigh(const int barIndex, const double price, const datetime time)
   {
      SwingPoint sp;
      sp.barIndex    = barIndex;
      sp.price       = price;
      sp.time        = time;
      sp.type        = SWING_HIGH;
      sp.isConfirmed = true;
      sp.isProtected = false;
      sp.isBroken    = false;
      sp.brokenTime  = 0;

      // Determine HH vs LH
      if(m_highCount > 0)
      {
         if(sp.price > m_swingHighs[0].price)
            m_lastEvent = EVENT_HH;
         else
            m_lastEvent = EVENT_LH;
         m_lastEventTime = time;
      }

      // Shift existing array
      for(int i = MathMin(m_highCount, m_maxHistorySwings - 1); i > 0; i--)
      {
         m_swingHighs[i] = m_swingHighs[i - 1];
      }
      m_swingHighs[0] = sp;
      if(m_highCount < m_maxHistorySwings) m_highCount++;

      m_lastConfirmedHigh = sp;
      UpdateProtectedLevels();
   }

   //+------------------------------------------------------------------+
   //| Register a Confirmed Swing Low                                   |
   //+------------------------------------------------------------------+
   void RegisterSwingLow(const int barIndex, const double price, const datetime time)
   {
      SwingPoint sp;
      sp.barIndex    = barIndex;
      sp.price       = price;
      sp.time        = time;
      sp.type        = SWING_LOW;
      sp.isConfirmed = true;
      sp.isProtected = false;
      sp.isBroken    = false;
      sp.brokenTime  = 0;

      // Determine HL vs LL
      if(m_lowCount > 0)
      {
         if(sp.price > m_swingLows[0].price)
            m_lastEvent = EVENT_HL;
         else
            m_lastEvent = EVENT_LL;
         m_lastEventTime = time;
      }

      // Shift existing array
      for(int i = MathMin(m_lowCount, m_maxHistorySwings - 1); i > 0; i--)
      {
         m_swingLows[i] = m_swingLows[i - 1];
      }
      m_swingLows[0] = sp;
      if(m_lowCount < m_maxHistorySwings) m_lowCount++;

      m_lastConfirmedLow = sp;
      UpdateProtectedLevels();
   }

   //+------------------------------------------------------------------+
   //| Evaluate BOS and CHOCH deterministically                         |
   //+------------------------------------------------------------------+
   void EvaluateStructuralBreaks(const MqlRates &closedBar, const double currentAtr)
   {
      double buffer = currentAtr * m_bosBufferAtrMult;

      // Check Bullish Breaks (Price closes above last confirmed High)
      if(m_highCount > 0 && !m_swingHighs[0].isBroken)
      {
         double breakLevel = m_swingHighs[0].price + buffer;
         
         // Strict rule: Candle CLOSE must exceed breakLevel (Wick sweep alone is NOT a BOS)
         if(closedBar.close > breakLevel)
         {
            m_swingHighs[0].isBroken = true;
            m_swingHighs[0].brokenTime = closedBar.time;

            if(m_structuralTrend == TREND_DOWN)
            {
               // CHOCH: Downtrend broken to the upside
               m_structuralTrend = TREND_UP;
               m_lastEvent = EVENT_CHOCH_BULLISH;
               m_recentChochCount++;
            }
            else
            {
               // Continuation BOS
               m_structuralTrend = TREND_UP;
               m_lastEvent = EVENT_BOS_BULLISH;
               m_recentBosCount++;
            }
            m_lastEventTime = closedBar.time;
            UpdateProtectedLevels();
         }
      }

      // Check Bearish Breaks (Price closes below last confirmed Low)
      if(m_lowCount > 0 && !m_swingLows[0].isBroken)
      {
         double breakLevel = m_swingLows[0].price - buffer;

         // Strict rule: Candle CLOSE must be below breakLevel
         if(closedBar.close < breakLevel)
         {
            m_swingLows[0].isBroken = true;
            m_swingLows[0].brokenTime = closedBar.time;

            if(m_structuralTrend == TREND_UP)
            {
               // CHOCH: Uptrend broken to the downside
               m_structuralTrend = TREND_DOWN;
               m_lastEvent = EVENT_CHOCH_BEARISH;
               m_recentChochCount++;
            }
            else
            {
               // Continuation BOS
               m_structuralTrend = TREND_DOWN;
               m_lastEvent = EVENT_BOS_BEARISH;
               m_recentBosCount++;
            }
            m_lastEventTime = closedBar.time;
            UpdateProtectedLevels();
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Update Protected Highs and Lows                                  |
   //+------------------------------------------------------------------+
   void UpdateProtectedLevels()
   {
      if(m_structuralTrend == TREND_UP && m_lowCount > 0)
      {
         m_protectedLow = m_swingLows[0];
         m_protectedLow.isProtected = true;
      }
      else if(m_structuralTrend == TREND_DOWN && m_highCount > 0)
      {
         m_protectedHigh = m_swingHighs[0];
         m_protectedHigh.isProtected = true;
      }
   }

   // Helpers
   bool IsSwingHighAlreadyRegistered(const datetime t) const
   {
      for(int i = 0; i < m_highCount; i++)
         if(m_swingHighs[i].time == t) return true;
      return false;
   }

   bool IsSwingLowAlreadyRegistered(const datetime t) const
   {
      for(int i = 0; i < m_lowCount; i++)
         if(m_swingLows[i].time == t) return true;
      return false;
   }

   // Getters
   ENUM_MARKET_TREND GetStructuralTrend() const { return m_structuralTrend; }
   ENUM_STRUCTURE_EVENT GetLastEvent() const { return m_lastEvent; }
   datetime GetLastEventTime() const { return m_lastEventTime; }
   int GetRecentChochCount() const { return m_recentChochCount; }
   int GetRecentBosCount() const { return m_recentBosCount; }

   bool GetLastHigh(SwingPoint &high) const
   {
      if(m_highCount == 0) return false;
      high = m_swingHighs[0];
      return true;
   }

   bool GetLastLow(SwingPoint &low) const
   {
      if(m_lowCount == 0) return false;
      low = m_swingLows[0];
      return true;
   }

   bool GetProtectedHigh(SwingPoint &high) const
   {
      if(!m_protectedHigh.isProtected) return false;
      high = m_protectedHigh;
      return true;
   }

   bool GetProtectedLow(SwingPoint &low) const
   {
      if(!m_protectedLow.isProtected) return false;
      low = m_protectedLow;
      return true;
   }

   int GetHighCount() const { return m_highCount; }
   int GetLowCount() const { return m_lowCount; }
   bool GetHighByIndex(const int idx, SwingPoint &sp) const
   {
      if(idx < 0 || idx >= m_highCount) return false;
      sp = m_swingHighs[idx];
      return true;
   }
   bool GetLowByIndex(const int idx, SwingPoint &sp) const
   {
      if(idx < 0 || idx >= m_lowCount) return false;
      sp = m_swingLows[idx];
      return true;
   }
};
