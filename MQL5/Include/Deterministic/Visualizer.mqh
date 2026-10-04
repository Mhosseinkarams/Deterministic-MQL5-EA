//+------------------------------------------------------------------+
//|                                                   Visualizer.mqh |
//|                     Deterministic Chart Visualization & Debug    |
//|               Draws Swings, BOS, CHOCH, S&D Zones, Range, Levels |
//|                     NEVER INFLUENCES TRADING DECISIONS           |
//|                                  Copyright 2026, Quant Systems   |
//+------------------------------------------------------------------+
#property copyright "Quant Systems"
#property strict

#include "Defines.mqh"
#include "MarketStructure.mqh"
#include "SupplyDemand.mqh"

class CVisualizer
{
private:
   string            m_prefix;
   bool              m_debugEnabled;
   long              m_chartId;

public:
   CVisualizer(string prefix = "D_EA_")
      : m_prefix(prefix),
        m_debugEnabled(false),
        m_chartId(0)
   {
   }

   ~CVisualizer()
   {
      CleanObjects();
   }

   void Init(const bool debugEnabled, const long chartId = 0)
   {
      m_debugEnabled = debugEnabled;
      m_chartId      = (chartId == 0) ? ChartID() : chartId;
      if(!m_debugEnabled)
         CleanObjects();
   }

   //+------------------------------------------------------------------+
   //| Draw or Refresh Visual Elements                                  |
   //+------------------------------------------------------------------+
   void UpdateChart(const CMarketStructureEngine &structure,
                    const CSupplyDemandEngine &sdEngine,
                    const RangeChannel &rangeChannel)
   {
      if(!m_debugEnabled) return;

      // 1. Draw Confirmed Swing Points
      for(int i = 0; i < MathMin(structure.GetHighCount(), 10); i++)
      {
         SwingPoint sp;
         if(structure.GetHighByIndex(i, sp))
         {
            string name = StringFormat("%sSWING_H_%d", m_prefix, i);
            ObjectCreate(m_chartId, name, OBJ_ARROW_DOWN, 0, sp.time, sp.price);
            ObjectSetInteger(m_chartId, name, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(m_chartId, name, OBJPROP_WIDTH, 1);
         }
      }

      for(int i = 0; i < MathMin(structure.GetLowCount(), 10); i++)
      {
         SwingPoint sp;
         if(structure.GetLowByIndex(i, sp))
         {
            string name = StringFormat("%sSWING_L_%d", m_prefix, i);
            ObjectCreate(m_chartId, name, OBJ_ARROW_UP, 0, sp.time, sp.price);
            ObjectSetInteger(m_chartId, name, OBJPROP_COLOR, clrGreen);
            ObjectSetInteger(m_chartId, name, OBJPROP_WIDTH, 1);
         }
      }

      // 2. Draw Supply & Demand Zones
      for(int i = 0; i < MathMin(sdEngine.GetZoneCount(), 15); i++)
      {
         SupplyDemandZone zone;
         if(sdEngine.GetZoneByIndex(i, zone))
         {
            string name = StringFormat("%sZONE_%d", m_prefix, zone.id);
            color zoneColor = (zone.type == ZONE_SUPPLY) ? clrIndianRed : clrMediumSeaGreen;
            if(zone.status == ZONE_BROKEN) zoneColor = clrGray;

            datetime endTime = TimeCurrent() + PeriodSeconds() * 20;
            ObjectCreate(m_chartId, name, OBJ_RECTANGLE, 0, zone.creationTime, zone.upperPrice, endTime, zone.lowerPrice);
            ObjectSetInteger(m_chartId, name, OBJPROP_COLOR, zoneColor);
            ObjectSetInteger(m_chartId, name, OBJPROP_FILL, true);
            ObjectSetInteger(m_chartId, name, OBJPROP_BACK, true);
         }
      }

      // 3. Draw Range Channel if Active
      if(rangeChannel.isActive)
      {
         string highName = m_prefix + "RANGE_HIGH";
         string lowName  = m_prefix + "RANGE_LOW";

         ObjectCreate(m_chartId, highName, OBJ_HLINE, 0, 0, rangeChannel.rangeHigh);
         ObjectSetInteger(m_chartId, highName, OBJPROP_COLOR, clrOrangeRed);
         ObjectSetInteger(m_chartId, highName, OBJPROP_STYLE, STYLE_DASH);

         ObjectCreate(m_chartId, lowName, OBJ_HLINE, 0, 0, rangeChannel.rangeLow);
         ObjectSetInteger(m_chartId, lowName, OBJPROP_COLOR, clrDodgerBlue);
         ObjectSetInteger(m_chartId, lowName, OBJPROP_STYLE, STYLE_DASH);
      }
      else
      {
         ObjectDelete(m_chartId, m_prefix + "RANGE_HIGH");
         ObjectDelete(m_chartId, m_prefix + "RANGE_LOW");
      }

      ChartRedraw(m_chartId);
   }

   //+------------------------------------------------------------------+
   //| Draw Trade Signal Markers                                        |
   //+------------------------------------------------------------------+
   void DrawSignal(const TradeSignal &signal)
   {
      if(!m_debugEnabled) return;

      string arrowName = StringFormat("%sSIG_%s_%s", m_prefix, EnumToString(signal.signalType), TimeToString(signal.timestamp));
      ENUM_OBJECT arrowType = (signal.direction == DIR_BUY) ? OBJ_ARROW_BUY : OBJ_ARROW_SELL;
      color arrowColor      = (signal.direction == DIR_BUY) ? clrDeepSkyBlue : clrHotPink;

      ObjectCreate(m_chartId, arrowName, arrowType, 0, signal.timestamp, signal.entryPrice);
      ObjectSetInteger(m_chartId, arrowName, OBJPROP_COLOR, arrowColor);
      ObjectSetInteger(m_chartId, arrowName, OBJPROP_WIDTH, 2);

      // Draw SL line
      string slName = arrowName + "_SL";
      ObjectCreate(m_chartId, slName, OBJ_TREND, 0, signal.timestamp, signal.stopLoss, signal.timestamp + PeriodSeconds() * 10, signal.stopLoss);
      ObjectSetInteger(m_chartId, slName, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(m_chartId, slName, OBJPROP_STYLE, STYLE_DOT);

      // Draw TP line
      string tpName = arrowName + "_TP";
      ObjectCreate(m_chartId, tpName, OBJ_TREND, 0, signal.timestamp, signal.takeProfit, signal.timestamp + PeriodSeconds() * 10, signal.takeProfit);
      ObjectSetInteger(m_chartId, tpName, OBJPROP_COLOR, clrLimeGreen);
      ObjectSetInteger(m_chartId, tpName, OBJPROP_STYLE, STYLE_DOT);

      ChartRedraw(m_chartId);
   }

   //+------------------------------------------------------------------+
   //| Clean all created chart objects with our prefix                  |
   //+------------------------------------------------------------------+
   void CleanObjects()
   {
      int total = ObjectsTotal(m_chartId, 0, -1);
      for(int i = total - 1; i >= 0; i--)
      {
         string name = ObjectName(m_chartId, i);
         if(StringFind(name, m_prefix) == 0)
         {
            ObjectDelete(m_chartId, name);
         }
      }
      ChartRedraw(m_chartId);
   }
};
