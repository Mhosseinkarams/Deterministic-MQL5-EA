//+------------------------------------------------------------------+
//|                                                   Indicators.mqh |
//|                           Indicator Engine for Deterministic EA  |
//|               EMA21, EMA50, EMA600, EMA800, ATR - Pure Handles  |
//|                                  Copyright 2026, Quant Systems   |
//+------------------------------------------------------------------+
#property copyright "Quant Systems"
#property strict

#include "Defines.mqh"

class CIndicatorEngine
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   
   // Indicator handles
   int               m_handleEma21;
   int               m_handleEma50;
   int               m_handleSlowEma;  // EMA600 on M5, EMA800 on M15
   int               m_handleAtr;
   int               m_handleBaselineAtr; // Baseline ATR 100 for volatility regime tracking
   int               m_handleAdx;         // ADX 14 for trend/chop regime gating
   
   int               m_slowEmaPeriod;
   int               m_atrPeriod;
   int               m_adxPeriod;

public:
   CIndicatorEngine()
      : m_handleEma21(INVALID_HANDLE),
        m_handleEma50(INVALID_HANDLE),
        m_handleSlowEma(INVALID_HANDLE),
        m_handleAtr(INVALID_HANDLE),
        m_handleBaselineAtr(INVALID_HANDLE),
        m_handleAdx(INVALID_HANDLE),
        m_slowEmaPeriod(600),
        m_atrPeriod(14),
        m_adxPeriod(14)
   {
   }

   ~CIndicatorEngine()
   {
      Release();
   }

   //+------------------------------------------------------------------+
   //| Initialize handles for a specific timeframe                      |
   //+------------------------------------------------------------------+
   bool Init(const string symbol, const ENUM_TIMEFRAMES tf, const int atrPeriod = 14)
   {
      m_symbol    = symbol;
      m_timeframe = tf;
      m_atrPeriod = atrPeriod;
      m_adxPeriod = 14;

      // Deterministic slow EMA selection based on timeframe:
      // M5 -> EMA 600, M15 (and above) -> EMA 800
      if(m_timeframe == PERIOD_M5)
         m_slowEmaPeriod = 600;
      else
         m_slowEmaPeriod = 800;

      Release();

      m_handleEma21 = iMA(m_symbol, m_timeframe, 21, 0, MODE_EMA, PRICE_CLOSE);
      if(m_handleEma21 == INVALID_HANDLE)
      {
         PrintFormat("[IndicatorEngine] Failed to create EMA21 handle for %s %s", m_symbol, EnumToString(m_timeframe));
         return false;
      }

      m_handleEma50 = iMA(m_symbol, m_timeframe, 50, 0, MODE_EMA, PRICE_CLOSE);
      if(m_handleEma50 == INVALID_HANDLE)
      {
         PrintFormat("[IndicatorEngine] Failed to create EMA50 handle for %s %s", m_symbol, EnumToString(m_timeframe));
         return false;
      }

      m_handleSlowEma = iMA(m_symbol, m_timeframe, m_slowEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(m_handleSlowEma == INVALID_HANDLE)
      {
         PrintFormat("[IndicatorEngine] Failed to create Slow EMA%d handle for %s %s", m_slowEmaPeriod, m_symbol, EnumToString(m_timeframe));
         return false;
      }

      m_handleAtr = iATR(m_symbol, m_timeframe, m_atrPeriod);
      if(m_handleAtr == INVALID_HANDLE)
      {
         PrintFormat("[IndicatorEngine] Failed to create ATR%d handle for %s %s", m_atrPeriod, m_symbol, EnumToString(m_timeframe));
         return false;
      }

      m_handleBaselineAtr = iATR(m_symbol, m_timeframe, 100);
      if(m_handleBaselineAtr == INVALID_HANDLE)
      {
         PrintFormat("[IndicatorEngine] Warning: Failed to create baseline ATR100 handle for %s %s", m_symbol, EnumToString(m_timeframe));
      }

      m_handleAdx = iADX(m_symbol, m_timeframe, m_adxPeriod);
      if(m_handleAdx == INVALID_HANDLE)
      {
         PrintFormat("[IndicatorEngine] Warning: Failed to create ADX%d handle for %s %s", m_adxPeriod, m_symbol, EnumToString(m_timeframe));
      }

      return true;
   }

   //+------------------------------------------------------------------+
   //| Release indicator handles                                        |
   //+------------------------------------------------------------------+
   void Release()
   {
      if(m_handleEma21 != INVALID_HANDLE)       { IndicatorRelease(m_handleEma21);       m_handleEma21 = INVALID_HANDLE; }
      if(m_handleEma50 != INVALID_HANDLE)       { IndicatorRelease(m_handleEma50);       m_handleEma50 = INVALID_HANDLE; }
      if(m_handleSlowEma != INVALID_HANDLE)     { IndicatorRelease(m_handleSlowEma);     m_handleSlowEma = INVALID_HANDLE; }
      if(m_handleAtr != INVALID_HANDLE)         { IndicatorRelease(m_handleAtr);         m_handleAtr = INVALID_HANDLE; }
      if(m_handleBaselineAtr != INVALID_HANDLE) { IndicatorRelease(m_handleBaselineAtr); m_handleBaselineAtr = INVALID_HANDLE; }
      if(m_handleAdx != INVALID_HANDLE)         { IndicatorRelease(m_handleAdx);         m_handleAdx = INVALID_HANDLE; }
   }

   //+------------------------------------------------------------------+
   //| Get EMA 21 value at shift (1 = last closed candle)               |
   //+------------------------------------------------------------------+
   double GetEMA21(const int shift = 1) const
   {
      if(m_handleEma21 == INVALID_HANDLE) return 0.0;
      double buffer[];
      ArraySetAsSeries(buffer, true);
      if(CopyBuffer(m_handleEma21, 0, shift, 1, buffer) < 1) return 0.0;
      return buffer[0];
   }

   //+------------------------------------------------------------------+
   //| Get EMA 50 value at shift                                        |
   //+------------------------------------------------------------------+
   double GetEMA50(const int shift = 1) const
   {
      if(m_handleEma50 == INVALID_HANDLE) return 0.0;
      double buffer[];
      ArraySetAsSeries(buffer, true);
      if(CopyBuffer(m_handleEma50, 0, shift, 1, buffer) < 1) return 0.0;
      return buffer[0];
   }

   //+------------------------------------------------------------------+
   //| Get Slow EMA (EMA600/800) value at shift                         |
   //+------------------------------------------------------------------+
   double GetSlowEMA(const int shift = 1) const
   {
      if(m_handleSlowEma == INVALID_HANDLE) return 0.0;
      double buffer[];
      ArraySetAsSeries(buffer, true);
      if(CopyBuffer(m_handleSlowEma, 0, shift, 1, buffer) < 1) return 0.0;
      return buffer[0];
   }

   //+------------------------------------------------------------------+
   //| Get ATR value at shift                                           |
   //+------------------------------------------------------------------+
   double GetATR(const int shift = 1) const
   {
      if(m_handleAtr == INVALID_HANDLE) return 0.0;
      double buffer[];
      ArraySetAsSeries(buffer, true);
      if(CopyBuffer(m_handleAtr, 0, shift, 1, buffer) < 1) return 0.0;
      return buffer[0];
   }

   //+------------------------------------------------------------------+
   //| Get Baseline ATR(100) value at shift for regime comparison       |
   //+------------------------------------------------------------------+
   double GetBaselineATR(const int shift = 1) const
   {
      if(m_handleBaselineAtr == INVALID_HANDLE) return GetATR(shift);
      double buffer[];
      ArraySetAsSeries(buffer, true);
      if(CopyBuffer(m_handleBaselineAtr, 0, shift, 1, buffer) < 1) return GetATR(shift);
      return buffer[0];
   }

   //+------------------------------------------------------------------+
   //| Get Volatility Ratio: ATR(14) / Baseline ATR(100)                |
   //+------------------------------------------------------------------+
   double GetVolatilityRatio(const int shift = 1) const
   {
      double baseline = GetBaselineATR(shift);
      if(baseline <= 0.0) return 1.0;
      double current = GetATR(shift);
      return (current / baseline);
   }

   //+------------------------------------------------------------------+
   //| Get ADX(14) value at shift for regime gating                     |
   //+------------------------------------------------------------------+
   double GetADX(const int shift = 1) const
   {
      if(m_handleAdx == INVALID_HANDLE) return 25.0; // Neutral default if handle missing
      double buffer[];
      ArraySetAsSeries(buffer, true);
      if(CopyBuffer(m_handleAdx, 0, shift, 1, buffer) < 1) return 25.0;
      return buffer[0];
   }

   //+------------------------------------------------------------------+
   //| Get Kaufman Efficiency Ratio (ER = Direction / Volatility)       |
   //| ER in [0.0, 1.0]: >0.35 = Trending, <0.20 = Pure Noise/Chop      |
   //+------------------------------------------------------------------+
   double GetKaufmanER(const int period = 10, const int shift = 1) const
   {
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      int copied = CopyRates(m_symbol, m_timeframe, shift, period + 1, rates);
      if(copied <= period) return 0.30;

      double change = MathAbs(rates[0].close - rates[period].close);
      double volatility = 0.0;
      for(int i = 0; i < period; i++)
         volatility += MathAbs(rates[i].close - rates[i + 1].close);

      if(volatility <= 0.0) return 0.0;
      return MathMin(1.0, change / volatility);
   }

   int GetSlowEmaPeriod() const { return m_slowEmaPeriod; }
   ENUM_TIMEFRAMES GetTimeframe() const { return m_timeframe; }
};
