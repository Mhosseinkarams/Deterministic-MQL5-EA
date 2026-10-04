//+------------------------------------------------------------------+
//|                                              ConflictManager.mqh |
//|                     Deterministic Strategy Conflict Manager      |
//|               Resolves Strategy vs State & Zone Collisions       |
//|                                  Copyright 2026, Quant Systems   |
//+------------------------------------------------------------------+
#property copyright "Quant Systems"
#property strict

#include "Defines.mqh"
#include <Trade\PositionInfo.mqh>

class CStrategyConflictManager
{
private:
   double            m_zoneCollisionAtrMult; // Buffer around open position entry to prevent duplicate entries
   CPositionInfo     m_positionInfo;

public:
   CStrategyConflictManager(double zoneCollisionAtr = 1.0)
      : m_zoneCollisionAtrMult(zoneCollisionAtr)
   {
   }

   ~CStrategyConflictManager() {}

   //+------------------------------------------------------------------+
   //| Validate Signal against Market State & Open Positions            |
   //+------------------------------------------------------------------+
   bool ValidateSignal(const TradeSignal &signal,
                       const ENUM_MARKET_TREND currentTrend,
                       const double currentAtr,
                       string &outRejectionReason)
   {
      outRejectionReason = "";

      // RULE 1: Trend strategies must NOT trigger during confirmed RANGE
      if(currentTrend == TREND_RANGE)
      {
         if(signal.strategy == STRATEGY_MM ||
            signal.strategy == STRATEGY_UNIT_CP ||
            signal.strategy == STRATEGY_UNIT_MOVING)
         {
            outRejectionReason = "CONFLICT_RULE_1: Trend strategy blocked in confirmed RANGE state";
            return false;
         }
      }

      // RULE 2: Range strategies must NOT trigger during confirmed TREND
      if(currentTrend == TREND_UP || currentTrend == TREND_DOWN)
      {
         if(signal.strategy == STRATEGY_SM)
         {
            outRejectionReason = "CONFLICT_RULE_2: Range strategy (SM) blocked in confirmed TREND state";
            return false;
         }
      }

      // RULE 3: UNCLEAR / TRANSITION handling
      if(currentTrend == TREND_TRANSITION || currentTrend == TREND_UNCLEAR)
      {
         // Only permit high-strength signals (> 85 deterministic strength) with tight SL
         if(signal.deterministicStrength < 85.0)
         {
            outRejectionReason = "CONFLICT_RULE_3: Market is TRANSITION/UNCLEAR; signal strength below 85.0 threshold";
            return false;
         }
      }

      // RULE 4: Open Position & Price Zone Conflict (Section 14)
      // Check existing open positions on the symbol
      int totalPositions = PositionsTotal();
      for(int i = 0; i < totalPositions; i++)
      {
         if(m_positionInfo.SelectByIndex(i))
         {
            if(m_positionInfo.Symbol() == signal.symbol)
            {
               // Rule: One position per symbol
               outRejectionReason = "CONFLICT_RULE_4A: Symbol already has an active open position";
               return false;
            }

            // Price zone proximity check across correlated trades
            double openPrice = m_positionInfo.PriceOpen();
            double priceDist = MathAbs(openPrice - signal.entryPrice);
            if(priceDist < (currentAtr * m_zoneCollisionAtrMult))
            {
               outRejectionReason = StringFormat("CONFLICT_RULE_4B: Active position #%d occupied price zone (dist: %.5f < %.5f)",
                                                 m_positionInfo.Ticket(), priceDist, currentAtr * m_zoneCollisionAtrMult);
               return false;
            }
         }
      }

      return true;
   }
};
