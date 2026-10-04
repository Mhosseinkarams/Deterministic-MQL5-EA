//+------------------------------------------------------------------+
//|                                                      Journal.mqh |
//|                     Structured Deterministic Logging System      |
//|               Auditable Reason Codes & State Tracing             |
//|                                  Copyright 2026, Quant Systems   |
//+------------------------------------------------------------------+
#property copyright "Quant Systems"
#property strict

#include "Defines.mqh"

class CJournal
{
private:
   bool              m_verboseLogging;

public:
   CJournal(bool verbose = true)
      : m_verboseLogging(verbose)
   {
   }

   ~CJournal() {}

   void SetVerbose(const bool verbose) { m_verboseLogging = verbose; }

   void LogStructureEvent(const string symbol, const ENUM_TIMEFRAMES tf, const ENUM_STRUCTURE_EVENT event, const double price, const datetime time)
   {
      if(!m_verboseLogging) return;
      PrintFormat("[JOURNAL][STRUCTURE] %s %s | Event: %s | Level: %.5f | Time: %s",
                  symbol, EnumToString(tf), EnumToString(event), price, TimeToString(time));
   }

   void LogZoneCreated(const SupplyDemandZone &zone, const string symbol, const ENUM_TIMEFRAMES tf)
   {
      if(!m_verboseLogging) return;
      PrintFormat("[JOURNAL][ZONE_NEW] %s %s | ID: %d | Type: %s | Range: [%.5f - %.5f] | Strength: %.1f",
                  symbol, EnumToString(tf), zone.id, EnumToString(zone.type), zone.lowerPrice, zone.upperPrice, zone.strength);
   }

   void LogZoneBroken(const SupplyDemandZone &zone, const string symbol, const ENUM_TIMEFRAMES tf)
   {
      if(!m_verboseLogging) return;
      PrintFormat("[JOURNAL][ZONE_BROKEN] %s %s | ID: %d | Type: %s | Invalidated at [%.5f - %.5f]",
                  symbol, EnumToString(tf), zone.id, EnumToString(zone.type), zone.lowerPrice, zone.upperPrice);
   }

   void LogSignalGenerated(const TradeSignal &signal)
   {
      PrintFormat("[JOURNAL][SIGNAL_GENERATED] Strategy: %s | Type: %s | %s %s | Entry: %.5f | SL: %.5f | TP: %.5f | RR: %.2f | Risk: %.2f%% | Code: %s",
                  EnumToString(signal.strategy), EnumToString(signal.signalType),
                  signal.symbol, EnumToString(signal.timeframe),
                  signal.entryPrice, signal.stopLoss, signal.takeProfit,
                  signal.riskRewardRatio, signal.riskPercent, signal.reasonCode);
   }

   void LogSignalRejected(const TradeSignal &signal, const string stage, const string reason)
   {
      if(!m_verboseLogging) return;
      PrintFormat("[JOURNAL][SIGNAL_REJECTED] Stage: %s | Strategy: %s | Reason: %s | Details: %s",
                  stage, EnumToString(signal.strategy), EnumToString(signal.rejectionReason), reason);
   }

   void LogOrderExecuted(const ulong ticket, const TradeSignal &signal, const double lots)
   {
      PrintFormat("[JOURNAL][TRADE_EXECUTED] Ticket: %d | Strategy: %s | Dir: %s | Lots: %.2f | Price: %.5f | SL: %.5f | TP: %.5f",
                  ticket, EnumToString(signal.strategy), EnumToString(signal.direction), lots, signal.entryPrice, signal.stopLoss, signal.takeProfit);
   }

   void LogMarketState(const string symbol, const ENUM_TIMEFRAMES tf, const ENUM_MARKET_TREND trend, const double ema50, const double slowEma, const double atr)
   {
      if(!m_verboseLogging) return;
      PrintFormat("[JOURNAL][STATE] %s %s | Trend: %s | EMA50: %.5f | SlowEMA: %.5f | ATR: %.5f",
                  symbol, EnumToString(tf), EnumToString(trend), ema50, slowEma, atr);
   }
};
