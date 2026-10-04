//+------------------------------------------------------------------+
//|                                              ExecutionEngine.mqh |
//|                     Deterministic Trade Execution Layer          |
//|               Safe Order Routing, Retcode Validation, Retries    |
//|                                  Copyright 2026, Quant Systems   |
//+------------------------------------------------------------------+
#property copyright "Quant Systems"
#property strict

#include "Defines.mqh"
#include <Trade\Trade.mqh>

class CExecutionEngine
{
private:
   CTrade            m_trade;
   ulong             m_baseMagic;
   ulong             m_deviation;

public:
   CExecutionEngine(ulong baseMagic = 90000, ulong deviation = 10)
      : m_baseMagic(baseMagic),
        m_deviation(deviation)
   {
      m_trade.SetExpertMagicNumber(m_baseMagic);
      m_trade.SetDeviationInPoints(m_deviation);
      m_trade.SetTypeFilling(ORDER_FILLING_FOK);
   }

   ~CExecutionEngine() {}

   //+------------------------------------------------------------------+
   //| Map Strategy and Signal Type to Unique Magic Identifier          |
   //+------------------------------------------------------------------+
   ulong GetMagicForSignal(const TradeSignal &signal)
   {
      switch(signal.signalType)
      {
         case SIGNAL_MM_STANDARD_BUY:
         case SIGNAL_MM_STANDARD_SELL:    return m_baseMagic + 101;
         case SIGNAL_MM_HIGHRISK_BUY:
         case SIGNAL_MM_HIGHRISK_SELL:    return m_baseMagic + 102;
         case SIGNAL_MM_REVERSAL_BUY:
         case SIGNAL_MM_REVERSAL_SELL:    return m_baseMagic + 103;
         
         case SIGNAL_SM_RANGE_BUY:
         case SIGNAL_SM_RANGE_SELL:       return m_baseMagic + 201;
         
         case SIGNAL_UNIT_CP_BUY:
         case SIGNAL_UNIT_CP_SELL:        return m_baseMagic + 301;
         
         case SIGNAL_UNIT_MOVING_STD_BUY:
         case SIGNAL_UNIT_MOVING_STD_SELL:return m_baseMagic + 401;
         case SIGNAL_UNIT_MOVING_HR_BUY:
         case SIGNAL_UNIT_MOVING_HR_SELL: return m_baseMagic + 402;
         
         default:                         return m_baseMagic;
      }
   }

   //+------------------------------------------------------------------+
   //| Execute Order Deterministically                                  |
   //+------------------------------------------------------------------+
   bool ExecuteSignal(const TradeSignal &signal,
                      const double lotSize,
                      ulong &outTicket,
                      string &outError)
   {
      outTicket = 0;
      outError  = "";

      if(lotSize <= 0.0)
      {
         outError = "Invalid lot size (<= 0.0)";
         return false;
      }

      ulong magic = GetMagicForSignal(signal);
      m_trade.SetExpertMagicNumber(magic);

      string comment = StringFormat("[D-EA] %s", signal.reasonCode);
      // Truncate comment to MT5 limit if needed
      if(StringLen(comment) > 31)
         comment = StringSubstr(comment, 0, 31);

      bool result = false;
      int maxRetries = 3;

      for(int attempt = 1; attempt <= maxRetries; attempt++)
      {
         if(signal.direction == DIR_BUY)
         {
            result = m_trade.Buy(lotSize, signal.symbol, 0.0, signal.stopLoss, signal.takeProfit, comment);
         }
         else if(signal.direction == DIR_SELL)
         {
            result = m_trade.Sell(lotSize, signal.symbol, 0.0, signal.stopLoss, signal.takeProfit, comment);
         }

         uint retcode = m_trade.ResultRetcode();
         if(result || retcode == TRADE_RETCODE_DONE || retcode == TRADE_RETCODE_PLACED)
         {
            outTicket = m_trade.ResultOrder();
            PrintFormat("[ExecutionEngine] ORDER SUCCESS! Strategy: %s, Ticket: %d, Lots: %.2f, SL: %.5f, TP: %.5f, Magic: %d",
                        EnumToString(signal.strategy), outTicket, lotSize, signal.stopLoss, signal.takeProfit, magic);
            return true;
         }

         PrintFormat("[ExecutionEngine] Order failed (Attempt %d/%d). Retcode: %d (%s)",
                     attempt, maxRetries, retcode, m_trade.ResultRetcodeDescription());

         // Non-retryable errors
         if(retcode == TRADE_RETCODE_INVALID_VOLUME ||
            retcode == TRADE_RETCODE_INVALID_STOPS ||
            retcode == TRADE_RETCODE_TRADE_DISABLED ||
            retcode == TRADE_RETCODE_MARKET_CLOSED)
         {
            outError = StringFormat("Fatal Retcode: %d - %s", retcode, m_trade.ResultRetcodeDescription());
            return false;
         }

         Sleep(200);
      }

      outError = StringFormat("Failed after %d attempts. Last retcode: %d (%s)",
                              maxRetries, m_trade.ResultRetcode(), m_trade.ResultRetcodeDescription());
      return false;
   }
};
