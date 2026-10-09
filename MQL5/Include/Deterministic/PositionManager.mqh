//+------------------------------------------------------------------+
//|                                              PositionManager.mqh |
//|                     Deterministic Position Lifecycle Manager     |
//|               EOD Flattening, Hard Kill Emergency Liquidation    |
//|                                  Copyright 2026, Quant Systems   |
//+------------------------------------------------------------------+
#property copyright "Quant Systems"
#property strict

#include "Defines.mqh"
#include "RiskEngine.mqh"
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>

class CPositionManager
{
private:
   CTrade            m_trade;
   CPositionInfo     m_posInfo;
   ulong             m_baseMagic;

public:
   CPositionManager(ulong baseMagic = 90000)
      : m_baseMagic(baseMagic)
   {
   }

   ~CPositionManager() {}

   //+------------------------------------------------------------------+
   //| OnTick / OnTimer Monitoring: Enforces EOD Flat & Hard Kill       |
   //+------------------------------------------------------------------+
   void MonitorPositions(CRiskEngine &riskEngine, const string symbol)
   {
      // 1. Check Hard Kill Emergency Liquidation
      if(riskEngine.IsKillSwitchTriggered())
      {
         CloseAllPositions(symbol, "HARD_KILL_TRIGGERED_EMERGENCY_CLOSE");
         return;
      }

      // 2. Check EOD Flat Liquidation
      if(riskEngine.IsNearEOD())
      {
         CloseAllPositions(symbol, "EOD_FLAT_SCHEDULED_CLOSE");
         return;
      }
   }

   //+------------------------------------------------------------------+
   //| Close all positions belonging to this EA/Symbol                  |
   //+------------------------------------------------------------------+
   int CloseAllPositions(const string symbol, const string reason)
   {
      int closedCount = 0;
      int total = PositionsTotal();

      for(int i = total - 1; i >= 0; i--)
      {
         if(m_posInfo.SelectByIndex(i))
         {
            if(m_posInfo.Symbol() == symbol)
            {
               ulong magic = (ulong)m_posInfo.Magic();
               // Check if magic belongs to our EA (within baseMagic to baseMagic+500)
               if(magic >= m_baseMagic && magic <= (m_baseMagic + 500))
               {
                  ulong ticket = m_posInfo.Ticket();
                  if(m_trade.PositionClose(ticket))
                  {
                     PrintFormat("[PositionManager] Position #%d closed. Reason: %s", ticket, reason);
                     closedCount++;
                  }
                  else
                  {
                     PrintFormat("[PositionManager] Failed to close position #%d: %s", ticket, m_trade.ResultRetcodeDescription());
                  }
               }
            }
         }
      }
      return closedCount;
   }

   //+------------------------------------------------------------------+
   //| Count open positions for this symbol                             |
   //+------------------------------------------------------------------+
   int CountOpenPositions(const string symbol)
   {
      int count = 0;
      int total = PositionsTotal();

      for(int i = 0; i < total; i++)
      {
         if(m_posInfo.SelectByIndex(i))
         {
            if(m_posInfo.Symbol() == symbol)
            {
               ulong magic = m_posInfo.Magic();
               if(magic >= m_baseMagic && magic <= (m_baseMagic + 500))
                  count++;
            }
         }
      }
      return count;
   }
};
