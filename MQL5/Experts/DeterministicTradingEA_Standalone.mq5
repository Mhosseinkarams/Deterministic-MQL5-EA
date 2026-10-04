//+------------------------------------------------------------------+
//|                           DeterministicTradingEA_Standalone.mq5  |
//|               SINGLE, SELF-CONTAINED MQL5 EXPERT ADVISOR         |
//|               Hard-coded Strategies: MM, SM, UniT (CP & Moving)  |
//|               ZERO ML / DL / RL / News / External Dependencies   |
//|                                  Copyright 2026, Quant Systems   |
//+------------------------------------------------------------------+
#property copyright "Quant Systems"
#property link      "https://github.com/quant-systems/deterministic-ea"
#property version   "1.00"
#property description "Deterministic Rule-Based Expert Advisor implementing MM, SM (Stubborn Man), and UniT."
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\SymbolInfo.mqh>

//====================================================================
// SECTION 1: DEFINITIONS & STRUCTURES
//====================================================================
enum ENUM_STRATEGY_TYPE
{
   STRATEGY_NONE         = 0,
   STRATEGY_MM           = 1,   // MM (Trend Following)
   STRATEGY_SM           = 2,   // SM / Stubborn Man (Range / S&D Rejection)
   STRATEGY_UNIT_CP      = 3,   // UniT CP (Spike & Pullback Retest)
   STRATEGY_UNIT_MOVING  = 4    // UniT Moving (EMA21 Dynamic Follow)
};

enum ENUM_SIGNAL_TYPE
{
   SIGNAL_NONE           = 0,
   SIGNAL_MM_STANDARD_BUY      = 101,
   SIGNAL_MM_STANDARD_SELL     = 102,
   SIGNAL_MM_HIGHRISK_BUY      = 103,
   SIGNAL_MM_HIGHRISK_SELL     = 104,
   SIGNAL_MM_REVERSAL_BUY      = 105,
   SIGNAL_MM_REVERSAL_SELL     = 106,
   
   SIGNAL_SM_RANGE_BUY         = 201,
   SIGNAL_SM_RANGE_SELL        = 202,
   
   SIGNAL_UNIT_CP_BUY          = 301,
   SIGNAL_UNIT_CP_SELL         = 302,
   
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
   EVENT_HH           = 1,
   EVENT_HL           = 2,
   EVENT_LH           = 3,
   EVENT_LL           = 4,
   EVENT_BOS_BULLISH  = 5,
   EVENT_BOS_BEARISH  = 6,
   EVENT_CHOCH_BULLISH= 7,
   EVENT_CHOCH_BEARISH= 8
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

struct SwingPoint
{
   int               barIndex;
   datetime          time;
   double            price;
   ENUM_SWING_TYPE   type;
   bool              isConfirmed;
   bool              isProtected;
   bool              isBroken;
   datetime          brokenTime;
};

struct SupplyDemandZone
{
   int               id;
   ENUM_ZONE_TYPE    type;
   ENUM_ZONE_STATUS  status;
   double            upperPrice;
   double            lowerPrice;
   datetime          creationTime;
   int               sourceBarIndex;
   int               touchCount;
   double            strength;
   bool              isBroken;
   datetime          lastTouchTime;
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
   double            bodyPercent;
   double            upperWickPercent;
   double            lowerWickPercent;
   ENUM_DIRECTION    direction;
   double            atrRatio;
   bool              isStrongBull;
   bool              isStrongBear;
   bool              isVeryStrongBull;
   bool              isVeryStrongBear;
   bool              isPinbarBull;
   bool              isPinbarBear;
   bool              isDoji;
   bool              isRefusalNearSupply;
   bool              isRefusalNearDemand;
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
   double               riskPercent;
   double               riskRewardRatio;
   ENUM_MARKET_TREND    marketTrend;
   double               relevantLevel;
   string               reasonCode;
   double               deterministicStrength;
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

//====================================================================
// SECTION 2: CANDLE ENGINE
//====================================================================
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

      metrics.isPinbarBull = (metrics.lowerWickPercent >= 55.0 && metrics.bodyPercent <= 30.0);
      metrics.isPinbarBear = (metrics.upperWickPercent >= 55.0 && metrics.bodyPercent <= 30.0);

      metrics.isRefusalNearSupply = (metrics.upperWickPercent >= m_minRefusalWickPercent &&
                                     metrics.close <= (metrics.high - (metrics.totalRange * 0.40)));

      metrics.isRefusalNearDemand = (metrics.lowerWickPercent >= m_minRefusalWickPercent &&
                                     metrics.close >= (metrics.low + (metrics.totalRange * 0.40)));

      return true;
   }
};

//====================================================================
// SECTION 3: INDICATOR ENGINE
//====================================================================
class CIndicatorEngine
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_handleEma21;
   int               m_handleEma50;
   int               m_handleSlowEma;
   int               m_handleAtr;
   int               m_slowEmaPeriod;
   int               m_atrPeriod;

public:
   CIndicatorEngine()
      : m_handleEma21(INVALID_HANDLE),
        m_handleEma50(INVALID_HANDLE),
        m_handleSlowEma(INVALID_HANDLE),
        m_handleAtr(INVALID_HANDLE),
        m_slowEmaPeriod(600),
        m_atrPeriod(14)
   {
   }

   ~CIndicatorEngine() { Release(); }

   bool Init(const string symbol, const ENUM_TIMEFRAMES tf, const int atrPeriod = 14)
   {
      m_symbol    = symbol;
      m_timeframe = tf;
      m_atrPeriod = atrPeriod;

      if(m_timeframe == PERIOD_M5)
         m_slowEmaPeriod = 600;
      else
         m_slowEmaPeriod = 800;

      Release();

      m_handleEma21   = iMA(m_symbol, m_timeframe, 21, 0, MODE_EMA, PRICE_CLOSE);
      m_handleEma50   = iMA(m_symbol, m_timeframe, 50, 0, MODE_EMA, PRICE_CLOSE);
      m_handleSlowEma = iMA(m_symbol, m_timeframe, m_slowEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
      m_handleAtr     = iATR(m_symbol, m_timeframe, m_atrPeriod);

      return (m_handleEma21 != INVALID_HANDLE &&
              m_handleEma50 != INVALID_HANDLE &&
              m_handleSlowEma != INVALID_HANDLE &&
              m_handleAtr != INVALID_HANDLE);
   }

   void Release()
   {
      if(m_handleEma21 != INVALID_HANDLE)   { IndicatorRelease(m_handleEma21);   m_handleEma21 = INVALID_HANDLE; }
      if(m_handleEma50 != INVALID_HANDLE)   { IndicatorRelease(m_handleEma50);   m_handleEma50 = INVALID_HANDLE; }
      if(m_handleSlowEma != INVALID_HANDLE) { IndicatorRelease(m_handleSlowEma); m_handleSlowEma = INVALID_HANDLE; }
      if(m_handleAtr != INVALID_HANDLE)     { IndicatorRelease(m_handleAtr);     m_handleAtr = INVALID_HANDLE; }
   }

   double GetEMA21(const int shift = 1) const
   {
      if(m_handleEma21 == INVALID_HANDLE) return 0.0;
      double buffer[];
      ArraySetAsSeries(buffer, true);
      if(CopyBuffer(m_handleEma21, 0, shift, 1, buffer) < 1) return 0.0;
      return buffer[0];
   }

   double GetEMA50(const int shift = 1) const
   {
      if(m_handleEma50 == INVALID_HANDLE) return 0.0;
      double buffer[];
      ArraySetAsSeries(buffer, true);
      if(CopyBuffer(m_handleEma50, 0, shift, 1, buffer) < 1) return 0.0;
      return buffer[0];
   }

   double GetSlowEMA(const int shift = 1) const
   {
      if(m_handleSlowEma == INVALID_HANDLE) return 0.0;
      double buffer[];
      ArraySetAsSeries(buffer, true);
      if(CopyBuffer(m_handleSlowEma, 0, shift, 1, buffer) < 1) return 0.0;
      return buffer[0];
   }

   double GetATR(const int shift = 1) const
   {
      if(m_handleAtr == INVALID_HANDLE) return 0.0;
      double buffer[];
      ArraySetAsSeries(buffer, true);
      if(CopyBuffer(m_handleAtr, 0, shift, 1, buffer) < 1) return 0.0;
      return buffer[0];
   }

   int GetSlowEmaPeriod() const { return m_slowEmaPeriod; }
};

//====================================================================
// SECTION 4: MARKET STRUCTURE ENGINE (ZERO LOOK-AHEAD)
//====================================================================
class CMarketStructureEngine
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_leftBars;
   int               m_rightBars;
   double            m_bosBufferAtrMult;
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
   int               m_recentChochCount;
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
   }

   bool Init(const string symbol, const ENUM_TIMEFRAMES tf, const int leftBars = 3, const int rightBars = 3, const double bosBufferAtr = 0.10)
   {
      m_symbol           = symbol;
      m_timeframe        = tf;
      m_leftBars         = leftBars;
      m_rightBars        = rightBars;
      m_bosBufferAtrMult = bosBufferAtr;
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

   void Update(const double currentAtr, const int lookbackBars = 120)
   {
      MqlRates rates[];
      ArraySetAsSeries(rates, true);

      int neededBars = lookbackBars + m_leftBars + m_rightBars + 5;
      if(CopyRates(m_symbol, m_timeframe, 1, neededBars, rates) < neededBars)
         return;

      for(int c = lookbackBars; c >= m_rightBars + 1; c--)
      {
         datetime candidateTime = rates[c].time;
         
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
            RegisterSwingHigh(c, rates[c].high, candidateTime);

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
            RegisterSwingLow(c, rates[c].low, candidateTime);
      }

      EvaluateStructuralBreaks(rates[0], currentAtr);
   }

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

      if(m_highCount > 0)
      {
         m_lastEvent = (sp.price > m_swingHighs[0].price) ? EVENT_HH : EVENT_LH;
         m_lastEventTime = time;
      }

      for(int i = MathMin(m_highCount, m_maxHistorySwings - 1); i > 0; i--)
         m_swingHighs[i] = m_swingHighs[i - 1];
      m_swingHighs[0] = sp;
      if(m_highCount < m_maxHistorySwings) m_highCount++;

      m_lastConfirmedHigh = sp;
      UpdateProtectedLevels();
   }

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

      if(m_lowCount > 0)
      {
         m_lastEvent = (sp.price > m_swingLows[0].price) ? EVENT_HL : EVENT_LL;
         m_lastEventTime = time;
      }

      for(int i = MathMin(m_lowCount, m_maxHistorySwings - 1); i > 0; i--)
         m_swingLows[i] = m_swingLows[i - 1];
      m_swingLows[0] = sp;
      if(m_lowCount < m_maxHistorySwings) m_lowCount++;

      m_lastConfirmedLow = sp;
      UpdateProtectedLevels();
   }

   void EvaluateStructuralBreaks(const MqlRates &closedBar, const double currentAtr)
   {
      double buffer = currentAtr * m_bosBufferAtrMult;

      if(m_highCount > 0 && !m_swingHighs[0].isBroken)
      {
         double breakLevel = m_swingHighs[0].price + buffer;
         if(closedBar.close > breakLevel)
         {
            m_swingHighs[0].isBroken = true;
            m_swingHighs[0].brokenTime = closedBar.time;

            if(m_structuralTrend == TREND_DOWN)
            {
               m_structuralTrend = TREND_UP;
               m_lastEvent = EVENT_CHOCH_BULLISH;
               m_recentChochCount++;
            }
            else
            {
               m_structuralTrend = TREND_UP;
               m_lastEvent = EVENT_BOS_BULLISH;
               m_recentBosCount++;
            }
            m_lastEventTime = closedBar.time;
            UpdateProtectedLevels();
         }
      }

      if(m_lowCount > 0 && !m_swingLows[0].isBroken)
      {
         double breakLevel = m_swingLows[0].price - buffer;
         if(closedBar.close < breakLevel)
         {
            m_swingLows[0].isBroken = true;
            m_swingLows[0].brokenTime = closedBar.time;

            if(m_structuralTrend == TREND_UP)
            {
               m_structuralTrend = TREND_DOWN;
               m_lastEvent = EVENT_CHOCH_BEARISH;
               m_recentChochCount++;
            }
            else
            {
               m_structuralTrend = TREND_DOWN;
               m_lastEvent = EVENT_BOS_BEARISH;
               m_recentBosCount++;
            }
            m_lastEventTime = closedBar.time;
            UpdateProtectedLevels();
         }
      }
   }

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

   bool IsSwingHighAlreadyRegistered(const datetime t) const
   {
      for(int i = 0; i < m_highCount; i++) if(m_swingHighs[i].time == t) return true;
      return false;
   }

   bool IsSwingLowAlreadyRegistered(const datetime t) const
   {
      for(int i = 0; i < m_lowCount; i++) if(m_swingLows[i].time == t) return true;
      return false;
   }

   ENUM_MARKET_TREND GetStructuralTrend() const { return m_structuralTrend; }
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

//====================================================================
// SECTION 5: SUPPLY & DEMAND ENGINE
//====================================================================
class CSupplyDemandEngine
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_maxZones;
   double            m_minDepartureAtrMult;
   SupplyDemandZone  m_zones[];
   int               m_zoneCount;
   int               m_nextZoneId;

public:
   CSupplyDemandEngine()
      : m_maxZones(30),
        m_minDepartureAtrMult(1.5),
        m_zoneCount(0),
        m_nextZoneId(1)
   {
      ArrayResize(m_zones, m_maxZones);
   }

   bool Init(const string symbol, const ENUM_TIMEFRAMES tf, const double minDepartureAtr = 1.5, const int maxZones = 30)
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
      m_zoneCount = 0;
      m_nextZoneId = 1;
      for(int i = 0; i < m_maxZones; i++) ZeroMemory(m_zones[i]);
   }

   void Update(const double currentAtr, CCandleEngine &candleEngine)
   {
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      if(CopyRates(m_symbol, m_timeframe, 1, 4, rates) < 4) return;

      CandleMetrics depMetrics;
      candleEngine.Analyze(m_symbol, m_timeframe, 1, currentAtr, depMetrics);

      if(depMetrics.isStrongBull && depMetrics.totalRange >= (currentAtr * m_minDepartureAtrMult))
      {
         if(!IsZoneAtTime(rates[1].time))
            CreateZone(ZONE_DEMAND, rates[1].high, rates[1].low, rates[1].time, 2, depMetrics.atrRatio * 20.0);
      }
      else if(depMetrics.isStrongBear && depMetrics.totalRange >= (currentAtr * m_minDepartureAtrMult))
      {
         if(!IsZoneAtTime(rates[1].time))
            CreateZone(ZONE_SUPPLY, rates[1].high, rates[1].low, rates[1].time, 2, depMetrics.atrRatio * 20.0);
      }

      UpdateZoneLifecycles(rates[0]);
   }

   void CreateZone(const ENUM_ZONE_TYPE type, const double upper, const double lower, const datetime creationTime, const int sourceBar, const double strength)
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

      for(int i = MathMin(m_zoneCount, m_maxZones - 1); i > 0; i--)
         m_zones[i] = m_zones[i - 1];

      m_zones[0] = zone;
      if(m_zoneCount < m_maxZones) m_zoneCount++;
   }

   void UpdateZoneLifecycles(const MqlRates &bar)
   {
      for(int i = 0; i < m_zoneCount; i++)
      {
         if(m_zones[i].isBroken) continue;

         if(m_zones[i].type == ZONE_SUPPLY)
         {
            if(bar.close > m_zones[i].upperPrice)
            {
               m_zones[i].isBroken = true;
               m_zones[i].status   = ZONE_BROKEN;
               continue;
            }
            if(bar.high >= m_zones[i].lowerPrice && bar.high <= m_zones[i].upperPrice)
            {
               m_zones[i].touchCount++;
               m_zones[i].lastTouchTime = bar.time;
               if(m_zones[i].touchCount == 1) m_zones[i].status = ZONE_TESTED;
               else if(m_zones[i].touchCount >= 2) m_zones[i].status = ZONE_WEAKENED;
            }
         }
         else if(m_zones[i].type == ZONE_DEMAND)
         {
            if(bar.close < m_zones[i].lowerPrice)
            {
               m_zones[i].isBroken = true;
               m_zones[i].status   = ZONE_BROKEN;
               continue;
            }
            if(bar.low <= m_zones[i].upperPrice && bar.low >= m_zones[i].lowerPrice)
            {
               m_zones[i].touchCount++;
               m_zones[i].lastTouchTime = bar.time;
               if(m_zones[i].touchCount == 1) m_zones[i].status = ZONE_TESTED;
               else if(m_zones[i].touchCount >= 2) m_zones[i].status = ZONE_WEAKENED;
            }
         }
      }
   }

   bool FindNearestSupply(const double currentPrice, SupplyDemandZone &outZone, const bool onlyReliable = true) const
   {
      double minDistance = DBL_MAX;
      int foundIndex = -1;
      for(int i = 0; i < m_zoneCount; i++)
      {
         if(m_zones[i].type != ZONE_SUPPLY || m_zones[i].isBroken) continue;
         if(onlyReliable && m_zones[i].status == ZONE_WEAKENED) continue;
         if(m_zones[i].lowerPrice >= currentPrice)
         {
            double dist = m_zones[i].lowerPrice - currentPrice;
            if(dist < minDistance) { minDistance = dist; foundIndex = i; }
         }
      }
      if(foundIndex >= 0) { outZone = m_zones[foundIndex]; return true; }
      return false;
   }

   bool FindNearestDemand(const double currentPrice, SupplyDemandZone &outZone, const bool onlyReliable = true) const
   {
      double minDistance = DBL_MAX;
      int foundIndex = -1;
      for(int i = 0; i < m_zoneCount; i++)
      {
         if(m_zones[i].type != ZONE_DEMAND || m_zones[i].isBroken) continue;
         if(onlyReliable && m_zones[i].status == ZONE_WEAKENED) continue;
         if(m_zones[i].upperPrice <= currentPrice)
         {
            double dist = currentPrice - m_zones[i].upperPrice;
            if(dist < minDistance) { minDistance = dist; foundIndex = i; }
         }
      }
      if(foundIndex >= 0) { outZone = m_zones[foundIndex]; return true; }
      return false;
   }

   bool IsZoneAtTime(const datetime t) const
   {
      for(int i = 0; i < m_zoneCount; i++) if(m_zones[i].creationTime == t) return true;
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

//====================================================================
// SECTION 6: TREND & RANGE ENGINE
//====================================================================
class CTrendEngine
{
private:
   ENUM_MARKET_TREND m_currentTrend;
   RangeChannel      m_rangeChannel;
   double            m_minEmaSeparationAtrMult;

public:
   CTrendEngine(double minEmaSep = 0.50)
      : m_currentTrend(TREND_UNCLEAR),
        m_minEmaSeparationAtrMult(minEmaSep)
   {
      ZeroMemory(m_rangeChannel);
   }

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

      bool rangeConditionA = (chochCount >= 2 && bosCount <= 1);

      SupplyDemandZone supZone, demZone;
      bool hasSupply = sdEngine.FindNearestSupply(closePrice, supZone, true);
      bool hasDemand = sdEngine.FindNearestDemand(closePrice, demZone, true);
      bool rangeConditionB = false;

      if(hasSupply && hasDemand)
      {
         double zoneSpan = supZone.lowerPrice - demZone.upperPrice;
         if(zoneSpan >= (currentAtr * 1.5) && zoneSpan <= (currentAtr * 8.0))
         {
            if(closePrice >= demZone.lowerPrice && closePrice <= supZone.upperPrice)
               rangeConditionB = true;
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
         return m_currentTrend;
      }

      m_rangeChannel.isActive = false;

      double emaDistance = ema50 - slowEma;
      double minSeparation = currentAtr * m_minEmaSeparationAtrMult;

      if(structTrend == TREND_UP && emaDistance > minSeparation && closePrice > ema50)
         m_currentTrend = TREND_UP;
      else if(structTrend == TREND_DOWN && emaDistance < -minSeparation && closePrice < ema50)
         m_currentTrend = TREND_DOWN;
      else
         m_currentTrend = TREND_TRANSITION;

      return m_currentTrend;
   }

   ENUM_MARKET_TREND GetCurrentTrend() const { return m_currentTrend; }
   bool IsRangeActive() const { return (m_currentTrend == TREND_RANGE && m_rangeChannel.isActive); }
   RangeChannel GetRangeChannel() const { return m_rangeChannel; }
};

//====================================================================
// SECTION 7: STRATEGY 1 - MM (TREND)
//====================================================================
class CStrategyMM
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   bool              m_enableStandard;
   bool              m_enableHighRisk;
   bool              m_enableReversal;
   double            m_minEmaSeparationAtr;
   double            m_reversalMinSeparationAtr;
   bool              m_useTightEmaSl;
   double            m_tightEmaSlBufferAtr;

public:
   CStrategyMM()
      : m_enableStandard(true),
        m_enableHighRisk(true),
        m_enableReversal(true),
        m_minEmaSeparationAtr(0.50),
        m_reversalMinSeparationAtr(2.50),
        m_useTightEmaSl(true),
        m_tightEmaSlBufferAtr(0.15)
   {
   }

   bool Init(const string symbol, const ENUM_TIMEFRAMES tf, const bool std = true, const bool hr = true, const bool rev = true, const double minSep = 0.50, const double revSep = 2.50, const bool useTightSl = true, const double tightSlBuffer = 0.15)
   {
      m_symbol                   = symbol;
      m_timeframe                = tf;
      m_enableStandard           = std;
      m_enableHighRisk           = hr;
      m_enableReversal           = rev;
      m_minEmaSeparationAtr      = minSep;
      m_reversalMinSeparationAtr = revSep;
      m_useTightEmaSl            = useTightSl;
      m_tightEmaSlBufferAtr      = tightSlBuffer;
      return true;
   }

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

      if(marketTrend == TREND_RANGE) return false;

      double ema50   = indicators.GetEMA50(1);
      double slowEma = indicators.GetSlowEMA(1);
      double emaSep  = MathAbs(ema50 - slowEma);

      // Reversal Setup
      if(m_enableReversal && emaSep >= (currentAtr * m_reversalMinSeparationAtr))
      {
         if(ema50 < slowEma && candle.isStrongBull && candle.close > ema50 && candle.open <= ema50)
         {
            SwingPoint lastLow;
            if(structure.GetLastLow(lastLow))
            {
               signal.signalType   = SIGNAL_MM_REVERSAL_BUY;
               signal.direction    = DIR_BUY;
               signal.entryPrice   = candle.close;
               signal.stopLoss     = MathMin(candle.low, lastLow.price) - (currentAtr * 0.15);
               signal.takeProfit   = signal.entryPrice + ((signal.entryPrice - signal.stopLoss) * 2.0);
               signal.riskPercent  = 0.50;
               signal.riskRewardRatio = (signal.takeProfit - signal.entryPrice) / (signal.entryPrice - signal.stopLoss);
               signal.relevantLevel= ema50;
               signal.reasonCode   = "MM_REVERSAL_BUY|LARGE_EMA_SEP|STRONG_BULL_CROSS_EMA50";
               signal.deterministicStrength = 80.0;
               signal.isValid      = true;
               return true;
            }
         }
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
               signal.riskPercent  = 0.50;
               signal.riskRewardRatio = (signal.entryPrice - signal.takeProfit) / (signal.stopLoss - signal.entryPrice);
               signal.relevantLevel= ema50;
               signal.reasonCode   = "MM_REVERSAL_SELL|LARGE_EMA_SEP|STRONG_BEAR_CROSS_EMA50";
               signal.deterministicStrength = 80.0;
               signal.isValid      = true;
               return true;
            }
         }
      }

      if(emaSep < (currentAtr * m_minEmaSeparationAtr)) return false;

      // Trend Following
      if(ema50 > slowEma && marketTrend == TREND_UP)
      {
         bool touchesEma50 = (candle.low <= (ema50 + (currentAtr * 0.10)) && candle.high >= (ema50 - (currentAtr * 0.10)));
         if(touchesEma50)
         {
            if(m_enableStandard && candle.isStrongBull && candle.close > ema50)
            {
               double sl = 0.0;
               if(m_useTightEmaSl)
               {
                  sl = MathMin(candle.low, ema50) - (currentAtr * m_tightEmaSlBufferAtr);
               }
               else
               {
                  SwingPoint lastLow;
                  sl = candle.low - (currentAtr * 0.15);
                  if(structure.GetLastLow(lastLow) && lastLow.price < candle.close) sl = MathMin(sl, lastLow.price);
               }

               if(sl >= candle.close) sl = candle.close - (currentAtr * 0.30);

               signal.signalType   = SIGNAL_MM_STANDARD_BUY;
               signal.direction    = DIR_BUY;
               signal.entryPrice   = candle.close;
               signal.stopLoss     = sl;
               signal.takeProfit   = signal.entryPrice + ((signal.entryPrice - signal.stopLoss) * 2.0);
               signal.riskPercent  = 1.0;
               signal.riskRewardRatio = (signal.takeProfit - signal.entryPrice) / (signal.entryPrice - signal.stopLoss);
               signal.relevantLevel= ema50;
               signal.reasonCode   = "MM_BUY_STANDARD|TREND_UP|EMA50_BOUNCE|SL_AGILE";
               signal.deterministicStrength = 90.0;
               signal.isValid      = true;
               return true;
            }
            if(m_enableHighRisk && candle.isVeryStrongBull && candle.open < ema50 && candle.close > ema50)
            {
               double sl = m_useTightEmaSl ? (MathMin(candle.low, ema50) - (currentAtr * m_tightEmaSlBufferAtr))
                                           : (candle.low - (currentAtr * 0.20));

               signal.signalType   = SIGNAL_MM_HIGHRISK_BUY;
               signal.direction    = DIR_BUY;
               signal.entryPrice   = candle.close;
               signal.stopLoss     = sl;
               signal.takeProfit   = signal.entryPrice + ((signal.entryPrice - signal.stopLoss) * 1.5);
               signal.riskPercent  = 0.50;
               signal.riskRewardRatio = (signal.takeProfit - signal.entryPrice) / (signal.entryPrice - signal.stopLoss);
               signal.relevantLevel= ema50;
               signal.reasonCode   = "MM_BUY_HIGHRISK|TREND_UP|EMA50_MOMENTUM_CROSS|SL_AGILE";
               signal.deterministicStrength = 75.0;
               signal.isValid      = true;
               return true;
            }
         }
      }
      else if(ema50 < slowEma && marketTrend == TREND_DOWN)
      {
         bool touchesEma50 = (candle.high >= (ema50 - (currentAtr * 0.10)) && candle.low <= (ema50 + (currentAtr * 0.10)));
         if(touchesEma50)
         {
            if(m_enableStandard && candle.isStrongBear && candle.close < ema50)
            {
               double sl = 0.0;
               if(m_useTightEmaSl)
               {
                  sl = MathMax(candle.high, ema50) + (currentAtr * m_tightEmaSlBufferAtr);
               }
               else
               {
                  SwingPoint lastHigh;
                  sl = candle.high + (currentAtr * 0.15);
                  if(structure.GetLastHigh(lastHigh) && lastHigh.price > candle.close) sl = MathMax(sl, lastHigh.price);
               }

               if(sl <= candle.close) sl = candle.close + (currentAtr * 0.30);

               signal.signalType   = SIGNAL_MM_STANDARD_SELL;
               signal.direction    = DIR_SELL;
               signal.entryPrice   = candle.close;
               signal.stopLoss     = sl;
               signal.takeProfit   = signal.entryPrice - ((signal.stopLoss - signal.entryPrice) * 2.0);
               signal.riskPercent  = 1.0;
               signal.riskRewardRatio = (signal.entryPrice - signal.takeProfit) / (signal.stopLoss - signal.entryPrice);
               signal.relevantLevel= ema50;
               signal.reasonCode   = "MM_SELL_STANDARD|TREND_DOWN|EMA50_BOUNCE|SL_AGILE";
               signal.deterministicStrength = 90.0;
               signal.isValid      = true;
               return true;
            }
            if(m_enableHighRisk && candle.isVeryStrongBear && candle.open > ema50 && candle.close < ema50)
            {
               double sl = m_useTightEmaSl ? (MathMax(candle.high, ema50) + (currentAtr * m_tightEmaSlBufferAtr))
                                           : (candle.high + (currentAtr * 0.20));

               signal.signalType   = SIGNAL_MM_HIGHRISK_SELL;
               signal.direction    = DIR_SELL;
               signal.entryPrice   = candle.close;
               signal.stopLoss     = sl;
               signal.takeProfit   = signal.entryPrice - ((signal.stopLoss - signal.entryPrice) * 1.5);
               signal.riskPercent  = 0.50;
               signal.riskRewardRatio = (signal.entryPrice - signal.takeProfit) / (signal.stopLoss - signal.entryPrice);
               signal.relevantLevel= ema50;
               signal.reasonCode   = "MM_SELL_HIGHRISK|TREND_DOWN|EMA50_MOMENTUM_CROSS|SL_AGILE";
               signal.deterministicStrength = 75.0;
               signal.isValid      = true;
               return true;
            }
         }
      }
      return false;
   }
};

//====================================================================
// SECTION 8: STRATEGY 2 - SM / STUBBORN MAN (RANGE)
//====================================================================
class CStrategySM
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   double            m_riskPercent;
   double            m_zoneApproachAtrMult;

public:
   CStrategySM()
      : m_riskPercent(1.0),
        m_zoneApproachAtrMult(0.50)
   {
   }

   bool Init(const string symbol, const ENUM_TIMEFRAMES tf, const double risk = 1.0, const double approach = 0.50)
   {
      m_symbol              = symbol;
      m_timeframe           = tf;
      m_riskPercent         = risk;
      m_zoneApproachAtrMult = approach;
      return true;
   }

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

      if(trendEngine.GetCurrentTrend() == TREND_UP || trendEngine.GetCurrentTrend() == TREND_DOWN)
         return false;

      if(!trendEngine.IsRangeActive())
         return false;

      RangeChannel channel = trendEngine.GetRangeChannel();
      SupplyDemandZone supplyZone, demandZone;
      bool hasSupply = sdEngine.FindNearestSupply(channel.midPoint, supplyZone, true);
      bool hasDemand = sdEngine.FindNearestDemand(channel.midPoint, demandZone, true);

      // Sell near Range High / Supply
      if(hasSupply && !supplyZone.isBroken)
      {
         if(candle.high >= (supplyZone.lowerPrice - (currentAtr * m_zoneApproachAtrMult)))
         {
            if(candle.isRefusalNearSupply || candle.isPinbarBear || (candle.upperWickPercent >= 45.0 && candle.close < candle.open))
            {
               double sl = supplyZone.upperPrice + (currentAtr * 0.15);
               double tp = hasDemand ? (demandZone.upperPrice + (currentAtr * 0.20)) : (channel.rangeLow + (currentAtr * 0.20));

               if(candle.close > tp && (candle.close - tp) >= (sl - candle.close))
               {
                  signal.signalType   = SIGNAL_SM_RANGE_SELL;
                  signal.direction    = DIR_SELL;
                  signal.entryPrice   = candle.close;
                  signal.stopLoss     = sl;
                  signal.takeProfit   = tp;
                  signal.riskPercent  = m_riskPercent;
                  signal.riskRewardRatio = (signal.entryPrice - signal.takeProfit) / (signal.stopLoss - signal.entryPrice);
                  signal.relevantLevel= supplyZone.lowerPrice;
                  signal.reasonCode   = "SM_SELL|RANGE_CONFIRMED|SUPPLY_TOUCH|REFUSAL_UPPER_WICK";
                  signal.deterministicStrength = 85.0;
                  signal.isValid      = true;
                  return true;
               }
            }
         }
      }

      // Buy near Range Low / Demand
      if(hasDemand && !demandZone.isBroken)
      {
         if(candle.low <= (demandZone.upperPrice + (currentAtr * m_zoneApproachAtrMult)))
         {
            if(candle.isRefusalNearDemand || candle.isPinbarBull || (candle.lowerWickPercent >= 45.0 && candle.close > candle.open))
            {
               double sl = demandZone.lowerPrice - (currentAtr * 0.15);
               double tp = hasSupply ? (supplyZone.lowerPrice - (currentAtr * 0.20)) : (channel.rangeHigh - (currentAtr * 0.20));

               if(candle.close < tp && (tp - candle.close) >= (candle.close - sl))
               {
                  signal.signalType   = SIGNAL_SM_RANGE_BUY;
                  signal.direction    = DIR_BUY;
                  signal.entryPrice   = candle.close;
                  signal.stopLoss     = sl;
                  signal.takeProfit   = tp;
                  signal.riskPercent  = m_riskPercent;
                  signal.riskRewardRatio = (signal.takeProfit - signal.entryPrice) / (signal.entryPrice - signal.stopLoss);
                  signal.relevantLevel= demandZone.upperPrice;
                  signal.reasonCode   = "SM_BUY|RANGE_CONFIRMED|DEMAND_TOUCH|REFUSAL_LOWER_WICK";
                  signal.deterministicStrength = 85.0;
                  signal.isValid      = true;
                  return true;
               }
            }
         }
      }

      return false;
   }
};

//====================================================================
// SECTION 9: STRATEGY 3 - UniT (CP & MOVING)
//====================================================================
class CStrategyUniT
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   bool              m_enableCP;
   bool              m_enableMoving;
   
   ENUM_DIRECTION    m_spikeDir;
   double            m_spikeExtremePrice;
   double            m_pullbackExtremePrice;
   int               m_cpStep; // 0=idle, 1=wait_pullback, 2=wait_retest
   int               m_barsSinceSpike;

   bool              m_useLastPivotForCP;
   double            m_cpLastPivotBufferAtr;
   bool              m_movingBehindEmaSL;
   double            m_movingBehindEmaBufferAtr;

public:
   CStrategyUniT()
      : m_enableCP(true),
        m_enableMoving(true),
        m_spikeDir(DIR_NONE),
        m_spikeExtremePrice(0.0),
        m_pullbackExtremePrice(0.0),
        m_cpStep(0),
        m_barsSinceSpike(0),
        m_useLastPivotForCP(true),
        m_cpLastPivotBufferAtr(0.10),
        m_movingBehindEmaSL(true),
        m_movingBehindEmaBufferAtr(0.10)
   {
   }

   bool Init(const string symbol, const ENUM_TIMEFRAMES tf, const bool cp = true, const bool moving = true,
             const bool useLastPivot = true, const double cpPivotBuffer = 0.10,
             const bool behindEma = true, const double behindEmaBuffer = 0.10)
   {
      m_symbol                   = symbol;
      m_timeframe                = tf;
      m_enableCP                 = cp;
      m_enableMoving             = moving;
      m_useLastPivotForCP        = useLastPivot;
      m_cpLastPivotBufferAtr     = cpPivotBuffer;
      m_movingBehindEmaSL        = behindEma;
      m_movingBehindEmaBufferAtr = behindEmaBuffer;
      Reset();
      return true;
   }

   void Reset()
   {
      m_spikeDir             = DIR_NONE;
      m_spikeExtremePrice    = 0.0;
      m_pullbackExtremePrice = 0.0;
      m_cpStep               = 0;
      m_barsSinceSpike       = 0;
   }

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

      if(marketTrend == TREND_RANGE) return false;

      // 1. UniT CP
      if(m_enableCP)
      {
         MqlRates rates[];
         ArraySetAsSeries(rates, true);
         if(CopyRates(m_symbol, m_timeframe, 1, 20, rates) >= 20)
         {
            if(m_cpStep > 0)
            {
               m_barsSinceSpike++;
               if(m_barsSinceSpike > 20) Reset();
            }

            // Spike detection
            if(m_cpStep == 0)
            {
               bool isBullSpike = (rates[3].close > rates[3].open && rates[2].close > rates[2].open && rates[1].close > rates[1].open &&
                                   rates[1].high > rates[2].high && rates[2].high > rates[3].high);
               if(isBullSpike && (rates[1].high - rates[3].low) >= (currentAtr * 1.5))
               {
                  m_spikeDir = DIR_BUY;
                  m_spikeExtremePrice = rates[1].high;
                  m_cpStep = 1;
                  m_barsSinceSpike = 1;
               }
               else
               {
                  bool isBearSpike = (rates[3].close < rates[3].open && rates[2].close < rates[2].open && rates[1].close < rates[1].open &&
                                      rates[1].low < rates[2].low && rates[2].low < rates[3].low);
                  if(isBearSpike && (rates[3].high - rates[1].low) >= (currentAtr * 1.5))
                  {
                     m_spikeDir = DIR_SELL;
                     m_spikeExtremePrice = rates[1].low;
                     m_cpStep = 1;
                     m_barsSinceSpike = 1;
                  }
               }
            }
            // Pullback detection: candle sees beyond the high/low of candle immediately before it
            else if(m_cpStep == 1)
            {
               if(m_spikeDir == DIR_BUY && rates[0].low < rates[1].low)
               {
                  m_pullbackExtremePrice = rates[0].low;
                  m_cpStep = 2;
               }
               else if(m_spikeDir == DIR_SELL && rates[0].high > rates[1].high)
               {
                  m_pullbackExtremePrice = rates[0].high;
                  m_cpStep = 2;
               }
            }
            // Retest
            else if(m_cpStep == 2)
            {
               double ema21 = indicators.GetEMA21(1);
               if(m_spikeDir == DIR_BUY)
               {
                  if(rates[0].low < m_pullbackExtremePrice) m_pullbackExtremePrice = rates[0].low;
                  if(rates[0].high >= m_spikeExtremePrice && candle.isStrongBull)
                  {
                     double entryPrice = candle.close;
                     double sl = 0.0;

                     if(m_useLastPivotForCP)
                     {
                        double lastPivotLow = rates[1].low;
                        int lookback = MathMin(m_barsSinceSpike + 2, 14);
                        bool foundPivot = false;

                        for(int k = 1; k < lookback - 1; k++)
                        {
                           if(rates[k].low <= rates[k - 1].low && rates[k].low <= rates[k + 1].low)
                           {
                              lastPivotLow = rates[k].low;
                              foundPivot   = true;
                              break;
                           }
                        }

                        if(!foundPivot)
                        {
                           for(int k = 1; k < lookback; k++)
                           {
                              if(rates[k].low < lastPivotLow)
                                 lastPivotLow = rates[k].low;
                           }
                        }

                        sl = lastPivotLow - (currentAtr * m_cpLastPivotBufferAtr);
                     }
                     else
                     {
                        sl = m_pullbackExtremePrice - (currentAtr * 0.15);
                     }

                     if(sl >= entryPrice) sl = entryPrice - (currentAtr * 0.30);

                     double ep = entryPrice;
                     double tp = ep + ((ep - sl) * 2.0);
                     int riskFactors = 0;
                     if(marketTrend != TREND_UP) riskFactors++;
                     if(ep < ema21) riskFactors++;
                     double finalRisk = 1.0;
                     for(int r = 0; r < riskFactors; r++) finalRisk *= 0.50;

                     signal.strategy     = STRATEGY_UNIT_CP;
                     signal.signalType   = SIGNAL_UNIT_CP_BUY;
                     signal.direction    = DIR_BUY;
                     signal.entryPrice   = ep;
                     signal.stopLoss     = sl;
                     signal.takeProfit   = tp;
                     signal.riskPercent  = finalRisk;
                     signal.riskRewardRatio = (tp - ep) / (ep - sl);
                     signal.relevantLevel= m_spikeExtremePrice;
                     signal.reasonCode   = StringFormat("UNIT_CP_BUY|SPIKE_RETEST|LAST_PIVOT_SL_%.5f|RISK_FACTORS_%d", sl, riskFactors);
                     signal.deterministicStrength = 85.0 - (riskFactors * 15.0);
                     signal.isValid      = true;
                     Reset();
                     return true;
                  }
               }
               else if(m_spikeDir == DIR_SELL)
               {
                  if(rates[0].high > m_pullbackExtremePrice) m_pullbackExtremePrice = rates[0].high;
                  if(rates[0].low <= m_spikeExtremePrice && candle.isStrongBear)
                  {
                     double entryPrice = candle.close;
                     double sl = 0.0;

                     if(m_useLastPivotForCP)
                     {
                        double lastPivotHigh = rates[1].high;
                        int lookback = MathMin(m_barsSinceSpike + 2, 14);
                        bool foundPivot = false;

                        for(int k = 1; k < lookback - 1; k++)
                        {
                           if(rates[k].high >= rates[k - 1].high && rates[k].high >= rates[k + 1].high)
                           {
                              lastPivotHigh = rates[k].high;
                              foundPivot    = true;
                              break;
                           }
                        }

                        if(!foundPivot)
                        {
                           for(int k = 1; k < lookback; k++)
                           {
                              if(rates[k].high > lastPivotHigh)
                                 lastPivotHigh = rates[k].high;
                           }
                        }

                        sl = lastPivotHigh + (currentAtr * m_cpLastPivotBufferAtr);
                     }
                     else
                     {
                        sl = m_pullbackExtremePrice + (currentAtr * 0.15);
                     }

                     if(sl <= entryPrice) sl = entryPrice + (currentAtr * 0.30);

                     double ep = entryPrice;
                     double tp = ep - ((sl - ep) * 2.0);
                     int riskFactors = 0;
                     if(marketTrend != TREND_DOWN) riskFactors++;
                     if(ep > ema21) riskFactors++;
                     double finalRisk = 1.0;
                     for(int r = 0; r < riskFactors; r++) finalRisk *= 0.50;

                     signal.strategy     = STRATEGY_UNIT_CP;
                     signal.signalType   = SIGNAL_UNIT_CP_SELL;
                     signal.direction    = DIR_SELL;
                     signal.entryPrice   = ep;
                     signal.stopLoss     = sl;
                     signal.takeProfit   = tp;
                     signal.riskPercent  = finalRisk;
                     signal.riskRewardRatio = (ep - tp) / (sl - ep);
                     signal.relevantLevel= m_spikeExtremePrice;
                     signal.reasonCode   = StringFormat("UNIT_CP_SELL|SPIKE_RETEST|LAST_PIVOT_SL_%.5f|RISK_FACTORS_%d", sl, riskFactors);
                     signal.deterministicStrength = 85.0 - (riskFactors * 15.0);
                     signal.isValid      = true;
                     Reset();
                     return true;
                  }
               }
            }
         }
      }

      // 2. UniT Moving (EMA21 Only) - SL strictly behind EMA21
      if(m_enableMoving)
      {
         double ema21 = indicators.GetEMA21(1);
         double tol = currentAtr * 0.35;

         if(marketTrend == TREND_UP)
         {
            bool touches = (candle.low <= (ema21 + tol) && candle.high >= (ema21 - tol));
            if(touches && candle.isStrongBull && candle.close > ema21)
            {
               double sl = 0.0;
               if(m_movingBehindEmaSL)
               {
                  sl = ema21 - (currentAtr * m_movingBehindEmaBufferAtr);
                  if(candle.low < ema21)
                     sl = MathMin(sl, candle.low - (currentAtr * m_movingBehindEmaBufferAtr));
               }
               else
               {
                  sl = candle.low - (currentAtr * 0.15);
               }

               signal.strategy     = STRATEGY_UNIT_MOVING;
               signal.signalType   = SIGNAL_UNIT_MOVING_STD_BUY;
               signal.direction    = DIR_BUY;
               signal.entryPrice   = candle.close;
               signal.stopLoss     = sl;
               signal.takeProfit   = signal.entryPrice + ((signal.entryPrice - sl) * 1.8);
               signal.riskPercent  = 1.0;
               signal.riskRewardRatio = (signal.takeProfit - signal.entryPrice) / (signal.entryPrice - sl);
               signal.relevantLevel= ema21;
               signal.reasonCode   = "UNIT_MOVING_STD_BUY|TREND_UP|EMA21_TOUCH|SL_BEHIND_EMA21";
               signal.deterministicStrength = 85.0;
               signal.isValid      = true;
               return true;
            }
            if(candle.isVeryStrongBull && candle.open < ema21 && candle.close > ema21)
            {
               double sl = 0.0;
               if(m_movingBehindEmaSL)
               {
                  sl = ema21 - (currentAtr * m_movingBehindEmaBufferAtr);
                  if(candle.low < ema21)
                     sl = MathMin(sl, candle.low - (currentAtr * m_movingBehindEmaBufferAtr));
               }
               else
               {
                  sl = candle.low - (currentAtr * 0.20);
               }

               signal.strategy     = STRATEGY_UNIT_MOVING;
               signal.signalType   = SIGNAL_UNIT_MOVING_HR_BUY;
               signal.direction    = DIR_BUY;
               signal.entryPrice   = candle.close;
               signal.stopLoss     = sl;
               signal.takeProfit   = signal.entryPrice + ((signal.entryPrice - sl) * 1.5);
               signal.riskPercent  = 0.50;
               signal.riskRewardRatio = (signal.takeProfit - signal.entryPrice) / (signal.entryPrice - sl);
               signal.relevantLevel= ema21;
               signal.reasonCode   = "UNIT_MOVING_HR_BUY|TREND_UP|EMA21_CROSS|SL_BEHIND_EMA21";
               signal.deterministicStrength = 70.0;
               signal.isValid      = true;
               return true;
            }
         }
         else if(marketTrend == TREND_DOWN)
         {
            bool touches = (candle.high >= (ema21 - tol) && candle.low <= (ema21 + tol));
            if(touches && candle.isStrongBear && candle.close < ema21)
            {
               double sl = 0.0;
               if(m_movingBehindEmaSL)
               {
                  sl = ema21 + (currentAtr * m_movingBehindEmaBufferAtr);
                  if(candle.high > ema21)
                     sl = MathMax(sl, candle.high + (currentAtr * m_movingBehindEmaBufferAtr));
               }
               else
               {
                  sl = candle.high + (currentAtr * 0.15);
               }

               signal.strategy     = STRATEGY_UNIT_MOVING;
               signal.signalType   = SIGNAL_UNIT_MOVING_STD_SELL;
               signal.direction    = DIR_SELL;
               signal.entryPrice   = candle.close;
               signal.stopLoss     = sl;
               signal.takeProfit   = signal.entryPrice - ((sl - signal.entryPrice) * 1.8);
               signal.riskPercent  = 1.0;
               signal.riskRewardRatio = (signal.entryPrice - signal.takeProfit) / (sl - signal.entryPrice);
               signal.relevantLevel= ema21;
               signal.reasonCode   = "UNIT_MOVING_STD_SELL|TREND_DOWN|EMA21_TOUCH|SL_BEHIND_EMA21";
               signal.deterministicStrength = 85.0;
               signal.isValid      = true;
               return true;
            }
            if(candle.isVeryStrongBear && candle.open > ema21 && candle.close < ema21)
            {
               double sl = 0.0;
               if(m_movingBehindEmaSL)
               {
                  sl = ema21 + (currentAtr * m_movingBehindEmaBufferAtr);
                  if(candle.high > ema21)
                     sl = MathMax(sl, candle.high + (currentAtr * m_movingBehindEmaBufferAtr));
               }
               else
               {
                  sl = candle.high + (currentAtr * 0.20);
               }

               signal.strategy     = STRATEGY_UNIT_MOVING;
               signal.signalType   = SIGNAL_UNIT_MOVING_HR_SELL;
               signal.direction    = DIR_SELL;
               signal.entryPrice   = candle.close;
               signal.stopLoss     = sl;
               signal.takeProfit   = signal.entryPrice - ((sl - signal.entryPrice) * 1.5);
               signal.riskPercent  = 0.50;
               signal.riskRewardRatio = (signal.entryPrice - signal.takeProfit) / (sl - signal.entryPrice);
               signal.relevantLevel= ema21;
               signal.reasonCode   = "UNIT_MOVING_HR_SELL|TREND_DOWN|EMA21_CROSS|SL_BEHIND_EMA21";
               signal.deterministicStrength = 70.0;
               signal.isValid      = true;
               return true;
            }
         }
      }

      return false;
   }
};

//====================================================================
// SECTION 10: CONFLICT MANAGER, RISK ENGINE, EXECUTION & POSITION MGR
//====================================================================
class CStrategyConflictManager
{
private:
   CPositionInfo     m_positionInfo;

public:
   CStrategyConflictManager() {}

   bool ValidateSignal(const TradeSignal &signal, const ENUM_MARKET_TREND currentTrend, const double currentAtr, string &outReason)
   {
      outReason = "";
      if(currentTrend == TREND_RANGE && (signal.strategy == STRATEGY_MM || signal.strategy == STRATEGY_UNIT_CP || signal.strategy == STRATEGY_UNIT_MOVING))
      {
         outReason = "CONFLICT: Trend strategy blocked in confirmed RANGE";
         return false;
      }
      if((currentTrend == TREND_UP || currentTrend == TREND_DOWN) && signal.strategy == STRATEGY_SM)
      {
         outReason = "CONFLICT: Range strategy (SM) blocked in confirmed TREND";
         return false;
      }
      if((currentTrend == TREND_TRANSITION || currentTrend == TREND_UNCLEAR) && signal.deterministicStrength < 85.0)
      {
         outReason = "CONFLICT: Transition market, signal strength < 85.0";
         return false;
      }

      int total = PositionsTotal();
      for(int i = 0; i < total; i++)
      {
         if(m_positionInfo.SelectByIndex(i))
         {
            if(m_positionInfo.Symbol() == signal.symbol)
            {
               outReason = "CONFLICT: Open position exists on this symbol";
               return false;
            }
         }
      }
      return true;
   }
};

class CRiskEngine
{
private:
   CAccountInfo      m_account;
   CSymbolInfo       m_symbolInfo;
   double            m_maxRiskPerTradePercent;
   double            m_maxDailyLossPercent;
   double            m_hardKillThresholdPercent;
   double            m_minRiskRewardRatio;
   int               m_maxSpreadPoints;
   bool              m_eodFlatEnabled;
   int               m_eodCloseHour;
   int               m_eodCloseMinute;
   int               m_consecutiveLossCount;
   bool              m_isReducedRiskMode;
   datetime          m_currentDay;
   double            m_dayStartBalance;
   bool              m_killSwitchTriggered;

public:
   CRiskEngine()
      : m_maxRiskPerTradePercent(1.0),
        m_maxDailyLossPercent(4.0),
        m_hardKillThresholdPercent(3.8),
        m_minRiskRewardRatio(1.5),
        m_maxSpreadPoints(35),
        m_eodFlatEnabled(true),
        m_eodCloseHour(23),
        m_eodCloseMinute(45),
        m_consecutiveLossCount(0),
        m_isReducedRiskMode(false),
        m_currentDay(0),
        m_dayStartBalance(0.0),
        m_killSwitchTriggered(false)
   {
   }

   bool Init(const double maxRisk = 1.0, const double maxDaily = 4.0, const double hardKill = 3.8, const double minRR = 1.5, const int maxSpread = 35, const bool eod = true, const int eodH = 23, const int eodM = 45)
   {
      m_maxRiskPerTradePercent   = maxRisk;
      m_maxDailyLossPercent      = maxDaily;
      m_hardKillThresholdPercent = hardKill;
      m_minRiskRewardRatio       = minRR;
      m_maxSpreadPoints          = maxSpread;
      m_eodFlatEnabled           = eod;
      m_eodCloseHour             = eodH;
      m_eodCloseMinute           = eodM;
      UpdateDailyState();
      return true;
   }

   void UpdateDailyState()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      datetime today = StringToTime(StringFormat("%04d.%02d.%02d 00:00", dt.year, dt.mon, dt.day));
      if(today != m_currentDay)
      {
         m_currentDay          = today;
         m_dayStartBalance     = m_account.Balance();
         m_killSwitchTriggered = false;
      }
   }

   bool CheckDailyDrawdown(double &outDrawdownPercent)
   {
      UpdateDailyState();
      if(m_dayStartBalance <= 0.0) m_dayStartBalance = m_account.Balance();
      double equity = m_account.Equity();
      double dd = (m_dayStartBalance > 0.0) ? (((m_dayStartBalance - equity) / m_dayStartBalance) * 100.0) : 0.0;
      outDrawdownPercent = MathMax(dd, 0.0);

      if(outDrawdownPercent >= m_hardKillThresholdPercent)
      {
         m_killSwitchTriggered = true;
         return false;
      }
      return (outDrawdownPercent < m_maxDailyLossPercent);
   }

   bool ValidateSignal(TradeSignal &signal, string &rejectionReason)
   {
      rejectionReason = "";
      double dd = 0.0;
      if(!CheckDailyDrawdown(dd))
      {
         rejectionReason = m_killSwitchTriggered ? "CRITICAL: Hard kill switch triggered (3.8%)" : "Daily drawdown limit exceeded (4%)";
         return false;
      }

      if(m_eodFlatEnabled && IsNearEOD())
      {
         rejectionReason = "Approaching EOD flat time";
         return false;
      }

      if(signal.riskRewardRatio < m_minRiskRewardRatio)
      {
         rejectionReason = StringFormat("R:R %.2f below min %.2f", signal.riskRewardRatio, m_minRiskRewardRatio);
         return false;
      }

      if(!m_symbolInfo.Name(signal.symbol)) m_symbolInfo.RefreshRates();
      if((int)m_symbolInfo.Spread() > m_maxSpreadPoints)
      {
         rejectionReason = "Spread too high";
         return false;
      }

      if(m_isReducedRiskMode)
         signal.riskPercent = MathMin(signal.riskPercent, 0.50);
      else
         signal.riskPercent = MathMin(signal.riskPercent, m_maxRiskPerTradePercent);

      return true;
   }

   double CalculateLotSize(const string symbol, const double entryPrice, const double stopLossPrice, const double riskPercent, string &err)
   {
      err = "";
      if(!m_symbolInfo.Name(symbol)) { err = "Symbol error"; return 0.0; }
      m_symbolInfo.RefreshRates();

      double equity = m_account.Equity();
      if(equity <= 0.0) equity = m_account.Balance();
      double riskMoney = equity * (riskPercent / 100.0);
      double slDist = MathAbs(entryPrice - stopLossPrice);
      if(slDist <= 0.0) { err = "Zero SL"; return 0.0; }

      double tickSize = m_symbolInfo.TickSize();
      double tickValue = m_symbolInfo.TickValue();
      if(tickSize <= 0.0 || tickValue <= 0.0) { err = "Invalid tick spec"; return 0.0; }

      double lossPerLot = (slDist / tickSize) * tickValue;
      if(lossPerLot <= 0.0) { err = "Zero loss per lot"; return 0.0; }

      double rawLots = riskMoney / lossPerLot;
      double minLot  = m_symbolInfo.LotsMin();
      double maxLot  = m_symbolInfo.LotsMax();
      double lotStep = m_symbolInfo.LotsStep();
      if(lotStep <= 0.0) lotStep = 0.01;

      double normalized = MathFloor(rawLots / lotStep) * lotStep;
      if(normalized < minLot) { err = "Below min lot"; return 0.0; }
      if(normalized > maxLot) normalized = maxLot;

      return NormalizeDouble(normalized, 2);
   }

   void OnTradeClosed(const double profit)
   {
      if(profit < 0.0)
      {
         m_consecutiveLossCount++;
         if(m_consecutiveLossCount >= 3) m_isReducedRiskMode = true;
      }
      else if(profit > 0.0)
      {
         m_consecutiveLossCount = 0;
         m_isReducedRiskMode = false;
      }
   }

   bool IsNearEOD() const
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      return (dt.hour > m_eodCloseHour || (dt.hour == m_eodCloseHour && dt.min >= m_eodCloseMinute));
   }

   bool IsKillSwitchTriggered() const { return m_killSwitchTriggered; }
   int GetConsecutiveLosses() const { return m_consecutiveLossCount; }
};

class CExecutionEngine
{
private:
   CTrade            m_trade;
   ulong             m_baseMagic;

public:
   CExecutionEngine(ulong baseMagic = 90000) : m_baseMagic(baseMagic)
   {
      m_trade.SetExpertMagicNumber(m_baseMagic);
      m_trade.SetDeviationInPoints(10);
      m_trade.SetTypeFilling(ORDER_FILLING_FOK);
   }

   bool ExecuteSignal(const TradeSignal &signal, const double lotSize, ulong &outTicket, string &outError)
   {
      outTicket = 0; outError = "";
      ulong magic = m_baseMagic + (ulong)signal.strategy * 100;
      m_trade.SetExpertMagicNumber(magic);

      bool res = false;
      if(signal.direction == DIR_BUY)
         res = m_trade.Buy(lotSize, signal.symbol, 0.0, signal.stopLoss, signal.takeProfit, "[D-EA]");
      else if(signal.direction == DIR_SELL)
         res = m_trade.Sell(lotSize, signal.symbol, 0.0, signal.stopLoss, signal.takeProfit, "[D-EA]");

      if(res || m_trade.ResultRetcode() == TRADE_RETCODE_DONE)
      {
         outTicket = m_trade.ResultOrder();
         return true;
      }
      outError = m_trade.ResultRetcodeDescription();
      return false;
   }
};

class CPositionManager
{
private:
   CTrade            m_trade;
   CPositionInfo     m_posInfo;
   ulong             m_baseMagic;

public:
   CPositionManager(ulong baseMagic = 90000) : m_baseMagic(baseMagic) {}

   void MonitorPositions(CRiskEngine &riskEngine, const string symbol)
   {
      if(riskEngine.IsKillSwitchTriggered())
         CloseAllPositions(symbol, "HARD_KILL_EMERGENCY");
      else if(riskEngine.IsNearEOD())
         CloseAllPositions(symbol, "EOD_FLAT");
   }

   void CloseAllPositions(const string symbol, const string reason)
   {
      int total = PositionsTotal();
      for(int i = total - 1; i >= 0; i--)
      {
         if(m_posInfo.SelectByIndex(i) && m_posInfo.Symbol() == symbol)
         {
            if(m_posInfo.Magic() >= m_baseMagic && m_posInfo.Magic() <= m_baseMagic + 500)
               m_trade.PositionClose(m_posInfo.Ticket());
         }
      }
   }
};

//====================================================================
// INPUT PARAMETERS
//====================================================================
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

input group "=== Risk & Capital Protection ==="
input double            InpBaseRiskPercent      = 1.0;         // Base Risk Per Trade (%)
input double            InpMaxDailyLossPercent  = 4.0;         // Max Daily Loss (%)
input double            InpHardKillThreshold    = 3.8;         // Hard Kill Switch (%)
input double            InpMinRiskRewardRatio   = 1.5;         // Minimum Acceptable R:R
input int               InpMaxSpreadPoints      = 35;          // Max Allowed Spread (Points)
input bool              InpEnableEODFlat        = true;        // Close All Positions EOD
input int               InpEODCloseHour         = 23;          // EOD Close Hour
input int               InpEODCloseMinute       = 45;          // EOD Close Minute

input group "=== System ==="
input ulong             InpBaseMagicNumber      = 90000;       // Base Magic Number

// Global instances
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

datetime                g_lastBarTime = 0;

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

int OnInit()
{
   Print("Initializing Deterministic Standalone EA...");
   if(!g_indicators.Init(_Symbol, InpStrategyTimeframe, 14)) return INIT_FAILED;
   g_structure.Init(_Symbol, InpStrategyTimeframe, InpSwingLeftBars, InpSwingRightBars, InpBosBufferAtrMult);
   g_sdEngine.Init(_Symbol, InpStrategyTimeframe, InpZoneDepartureAtrMult, 30);
   g_strategyMM.Init(_Symbol, InpStrategyTimeframe, InpEnableMMStandard, InpEnableMMHighRisk, InpEnableMMReversal, InpMMMinSeparationAtr, InpMMRevSeparationAtr, InpMMTightEmaSl, InpMMTightEmaSlBufferAtr);
   g_strategySM.Init(_Symbol, InpStrategyTimeframe, InpBaseRiskPercent, InpSMZoneApproachAtr);
   g_strategyUniT.Init(_Symbol, InpStrategyTimeframe, InpEnableUniT_CP, InpEnableUniT_Moving, InpUniTBaseRiskPercent, InpUniTCP_LastPivotSL, InpUniTCP_PivotBufferAtr, InpUniTMoving_BehindEmaSL, InpUniTMoving_BehindEmaBuf);
   g_riskEngine.Init(InpBaseRiskPercent, InpMaxDailyLossPercent, InpHardKillThreshold, InpMinRiskRewardRatio, InpMaxSpreadPoints, InpEnableEODFlat, InpEODCloseHour, InpEODCloseMinute);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   g_indicators.Release();
}

void OnTick()
{
   g_positionManager.MonitorPositions(g_riskEngine, _Symbol);

   if(!IsNewClosedBar()) return;

   double currentAtr = g_indicators.GetATR(1);
   if(currentAtr <= 0.0) currentAtr = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 20.0;

   CandleMetrics closedCandle;
   if(!g_candleEngine.Analyze(_Symbol, InpStrategyTimeframe, 1, currentAtr, closedCandle)) return;

   g_structure.Update(currentAtr, 120);
   g_sdEngine.Update(currentAtr, g_candleEngine);
   ENUM_MARKET_TREND marketTrend = g_trendEngine.Evaluate(_Symbol, InpStrategyTimeframe, g_indicators, g_structure, g_sdEngine, currentAtr);

   TradeSignal candidates[3];
   int count = 0;

   if(InpEnableMM)
   {
      TradeSignal s;
      if(g_strategyMM.Evaluate(closedCandle, g_indicators, g_structure, marketTrend, currentAtr, s))
         candidates[count++] = s;
   }

   if(InpEnableSM)
   {
      TradeSignal s;
      if(g_strategySM.Evaluate(closedCandle, g_trendEngine, g_sdEngine, g_structure, currentAtr, s))
         candidates[count++] = s;
   }

   if(InpEnableUniT_CP || InpEnableUniT_Moving)
   {
      TradeSignal s;
      if(g_strategyUniT.Evaluate(closedCandle, g_indicators, g_structure, marketTrend, currentAtr, s))
         candidates[count++] = s;
   }

   for(int i = 0; i < count; i++)
   {
      TradeSignal sig = candidates[i];
      string conflictErr = "";
      if(!g_conflictManager.ValidateSignal(sig, marketTrend, currentAtr, conflictErr)) continue;

      string riskErr = "";
      if(!g_riskEngine.ValidateSignal(sig, riskErr)) continue;

      string lotErr = "";
      double lots = g_riskEngine.CalculateLotSize(_Symbol, sig.entryPrice, sig.stopLoss, sig.riskPercent, lotErr);
      if(lots <= 0.0) continue;

      ulong ticket = 0;
      string execErr = "";
      if(g_execution.ExecuteSignal(sig, lots, ticket, execErr)) break;
   }
}

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      if(HistoryDealSelect(trans.deal))
      {
         long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
         if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT)
            g_riskEngine.OnTradeClosed(HistoryDealGetDouble(trans.deal, DEAL_PROFIT));
      }
   }
}
