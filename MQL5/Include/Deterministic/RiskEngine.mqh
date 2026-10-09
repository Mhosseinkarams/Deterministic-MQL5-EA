//+------------------------------------------------------------------+
//|                                                   RiskEngine.mqh |
//|                     Centralized Deterministic Risk Management    |
//|         Daily Drawdown (4%), Hard Kill (3.8%), Consecutive Loss  |
//|         Dynamic Lot Sizing for Forex, Metals (XAUUSD), Indices   |
//|                                  Copyright 2026, Quant Systems   |
//+------------------------------------------------------------------+
#property copyright "Quant Systems"
#property strict

#include "Defines.mqh"
#include "SelfOptimizer.mqh"
#include <Trade\AccountInfo.mqh>
#include <Trade\SymbolInfo.mqh>

class CRiskEngine
{
private:
   CAccountInfo      m_account;
   CSymbolInfo       m_symbolInfo;
   CSelfOptimizer   *m_optimizer;

   double            m_maxRiskPerTradePercent;
   double            m_maxDailyLossPercent;      // 4.0%
   double            m_hardKillThresholdPercent; // 3.8%
   double            m_minRiskRewardRatio;       // 1.5
   int               m_maxSpreadPoints;
   int               m_maxSimultaneousPositions;
   bool              m_eodFlatEnabled;
   int               m_eodCloseHour;
   int               m_eodCloseMinute;

   // Take profit mode configuration
   ENUM_TP_MODE      m_tpMode;
   double            m_manualTpMultiple;         // e.g. 1.0 (1R), 2.0 (2R), 3.0 (3R)

   // Consecutive loss tracking state
   int               m_consecutiveLossCount;
   bool              m_isReducedRiskMode;
   double            m_reducedRiskPercent;       // 0.5%
   double            m_lossRecoveryTarget;
   double            m_recoveredAmount;

   // Daily tracking
   datetime          m_currentDay;
   double            m_dayStartBalance;
   double            m_dayStartEquity;
   bool              m_killSwitchTriggered;

   // === Version 2.0 Institutional Capital & Asset Governors ===
   bool              m_enableV2Governors;
   double            m_peakEquity;
   datetime          m_peakTime;
   double            m_maxTrailingDrawdownPercent; // e.g. 8.0% from lifetime peak
   bool              m_hwmKillSwitchTriggered;
   datetime          m_currentWeek;
   double            m_weekStartBalance;
   double            m_maxWeeklyLossPercent;       // e.g. 5.0% from Monday open
   bool              m_weeklyKillSwitchTriggered;
   bool              m_enableDynamicDamping;       // Smoothly scales down risk as DD grows
   bool              m_enableSessionFilter;        // Session liquidity windows
   AssetProfile      m_assetProfile;

public:
   CRiskEngine()
      : m_maxRiskPerTradePercent(1.0),
        m_maxDailyLossPercent(4.0),
        m_hardKillThresholdPercent(3.8),
        m_minRiskRewardRatio(1.5),
        m_maxSpreadPoints(35),
        m_maxSimultaneousPositions(3),
        m_eodFlatEnabled(true),
        m_eodCloseHour(23),
        m_eodCloseMinute(45),
        m_tpMode(TP_MODE_AUTO),
        m_manualTpMultiple(2.0),
        m_optimizer(NULL),
        m_consecutiveLossCount(0),
        m_isReducedRiskMode(false),
        m_reducedRiskPercent(0.50),
        m_lossRecoveryTarget(0.0),
        m_recoveredAmount(0.0),
        m_currentDay(0),
        m_dayStartBalance(0.0),
        m_dayStartEquity(0.0),
        m_killSwitchTriggered(false),
        m_enableV2Governors(true),
        m_peakEquity(0.0),
        m_peakTime(0),
        m_maxTrailingDrawdownPercent(8.0),
        m_hwmKillSwitchTriggered(false),
        m_currentWeek(0),
        m_weekStartBalance(0.0),
        m_maxWeeklyLossPercent(5.0),
        m_weeklyKillSwitchTriggered(false),
        m_enableDynamicDamping(true),
        m_enableSessionFilter(true)
   {
   }

   ~CRiskEngine() {}

   bool Init(const double maxRisk = 1.0,
             const double maxDailyLoss = 4.0,
             const double hardKill = 3.8,
             const double minRR = 1.5,
             const int maxSpread = 35,
             const bool eodFlat = true,
             const int eodHour = 23,
             const int eodMinute = 45,
             const ENUM_TP_MODE tpMode = TP_MODE_AUTO,
             const double manualTpMultiple = 2.0,
             const bool enableV2Governors = true,
             const double maxTrailingDd = 8.0,
             const double maxWeeklyLoss = 5.0,
             const bool enableDynamicDamping = true,
             const bool enableSessionFilter = true,
             const ENUM_ASSET_CLASS requestedAssetClass = ASSET_CLASS_AUTO)
   {
      m_maxRiskPerTradePercent    = maxRisk;
      m_maxDailyLossPercent       = maxDailyLoss;
      m_hardKillThresholdPercent  = hardKill;
      m_minRiskRewardRatio        = minRR;
      m_maxSpreadPoints           = maxSpread;
      m_eodFlatEnabled            = eodFlat;
      m_eodCloseHour              = eodHour;
      m_eodCloseMinute            = eodMinute;
      m_tpMode                    = tpMode;
      m_manualTpMultiple          = manualTpMultiple;

      // Version 2.0 Governors
      m_enableV2Governors          = enableV2Governors;
      m_maxTrailingDrawdownPercent= maxTrailingDd;
      m_maxWeeklyLossPercent      = maxWeeklyLoss;
      m_enableDynamicDamping      = enableDynamicDamping;
      m_enableSessionFilter       = enableSessionFilter;

      DetectAndConfigureAssetProfile(_Symbol, requestedAssetClass);

      UpdateDailyState();
      UpdateHwmAndWeeklyState();
      return true;
   }

   //+------------------------------------------------------------------+
   //| Auto-detect or configure asset class profile                     |
   //+------------------------------------------------------------------+
   void DetectAndConfigureAssetProfile(const string symbol, const ENUM_ASSET_CLASS reqClass = ASSET_CLASS_AUTO)
   {
      m_assetProfile.symbol = symbol;
      string upperSym = symbol;
      StringToUpper(upperSym);

      ENUM_ASSET_CLASS resolvedClass = reqClass;
      if(resolvedClass == ASSET_CLASS_AUTO)
      {
         if(StringFind(upperSym, "XAU") >= 0 || StringFind(upperSym, "GOLD") >= 0 || StringFind(upperSym, "SILVER") >= 0)
            resolvedClass = ASSET_CLASS_METALS;
         else if(StringFind(upperSym, "30") >= 0 || StringFind(upperSym, "DOW") >= 0 || StringFind(upperSym, "WS30") >= 0 ||
                 StringFind(upperSym, "DJ") >= 0 || StringFind(upperSym, "NAS") >= 0 || StringFind(upperSym, "SPX") >= 0 ||
                 StringFind(upperSym, "100") >= 0 || StringFind(upperSym, "500") >= 0)
            resolvedClass = ASSET_CLASS_INDICES;
         else
            resolvedClass = ASSET_CLASS_FOREX;
      }

      m_assetProfile.assetClass = resolvedClass;

      // Configure symbol-specific execution tolerances
      switch(resolvedClass)
      {
         case ASSET_CLASS_METALS:
            m_assetProfile.maxSpreadPoints     = 80;    // 80 pts = $0.80 on Gold
            m_assetProfile.stopLossBufferAtr   = 0.45;  // 0.45 ATR buffer to absorb wick stop-hunts
            m_assetProfile.minEmaSeparationAtr = 0.80;  // 0.80 ATR separation for clear trend
            m_assetProfile.sessionStartHour    = 8;     // 08:00 GMT (London Open)
            m_assetProfile.sessionStartMinute  = 0;
            m_assetProfile.sessionEndHour      = 17;    // 17:30 GMT (London Close)
            m_assetProfile.sessionEndMinute    = 30;
            m_assetProfile.blockRollover       = true;  // Block 21:30 - 01:30 rollover spread spike
            break;

         case ASSET_CLASS_INDICES:
            m_assetProfile.maxSpreadPoints     = 400;   // 400 pts = 4.0 Dow points
            m_assetProfile.stopLossBufferAtr   = 0.40;  // 0.40 ATR buffer
            m_assetProfile.minEmaSeparationAtr = 1.00;  // 1.00 ATR separation for strong index momentum
            m_assetProfile.sessionStartHour    = 13;    // 13:30 GMT (US Cash Open)
            m_assetProfile.sessionStartMinute  = 30;
            m_assetProfile.sessionEndHour      = 20;    // 20:00 GMT (US Afternoon)
            m_assetProfile.sessionEndMinute    = 0;
            m_assetProfile.blockRollover       = true;
            break;

         case ASSET_CLASS_FOREX:
         default:
            m_assetProfile.maxSpreadPoints     = 20;    // 20 pts = 2.0 pips for Majors
            m_assetProfile.stopLossBufferAtr   = 0.15;  // 0.15 ATR standard buffer
            m_assetProfile.minEmaSeparationAtr = 0.50;  // 0.50 ATR separation
            m_assetProfile.sessionStartHour    = 7;     // 07:00 GMT (London Open)
            m_assetProfile.sessionStartMinute  = 0;
            m_assetProfile.sessionEndHour      = 17;    // 17:00 GMT (NY Midday)
            m_assetProfile.sessionEndMinute    = 0;
            m_assetProfile.blockRollover       = true;  // Block Asian quiet hours
            break;
      }

      // If default spread wasn't custom overridden, adopt asset profile spread
      if(m_enableV2Governors)
      {
         m_maxSpreadPoints = m_assetProfile.maxSpreadPoints;
         PrintFormat("[RiskEngine v2.0] Asset Profile configured: %s (Class: %s, MaxSpread: %d pts, SLBuffer: %.2fx ATR)",
                     symbol, EnumToString(m_assetProfile.assetClass), m_assetProfile.maxSpreadPoints, m_assetProfile.stopLossBufferAtr);
      }
   }

   //+------------------------------------------------------------------+
   //| Version 2.0 Peak Equity (HWM) & Weekly State Management          |
   //+------------------------------------------------------------------+
   void UpdateHwmAndWeeklyState()
   {
      double currentEquity = m_account.Equity();
      if(currentEquity <= 0.0) currentEquity = m_account.Balance();

      // 1. High-Water Mark (Peak Equity) Tracking
      if(m_peakEquity <= 0.0 || currentEquity > m_peakEquity)
      {
         m_peakEquity = currentEquity;
         m_peakTime   = TimeCurrent();
         m_hwmKillSwitchTriggered = false; // Reset if new peak reached
      }

      // 2. Weekly Reset tracking (Monday 00:00 GMT)
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      // Day of week 1 = Monday
      if(dt.day_of_week == 1 && (TimeCurrent() - m_currentWeek) > 86400 * 5)
      {
         m_currentWeek               = TimeCurrent();
         m_weekStartBalance          = m_account.Balance();
         m_weeklyKillSwitchTriggered = false;
         PrintFormat("[RiskEngine v2.0] New trading week initialized. Week Start Balance: %.2f", m_weekStartBalance);
      }
      else if(m_weekStartBalance <= 0.0)
      {
         m_weekStartBalance = m_account.Balance();
         m_currentWeek      = TimeCurrent();
      }
   }

   //+------------------------------------------------------------------+
   //| Check Sovereign High-Water Mark (Peak Equity) Trailing Drawdown  |
   //+------------------------------------------------------------------+
   bool CheckHwmDrawdown(double &outTrailingDdPercent)
   {
      UpdateHwmAndWeeklyState();

      if(!m_enableV2Governors || m_maxTrailingDrawdownPercent <= 0.0)
      {
         outTrailingDdPercent = 0.0;
         return true;
      }

      double currentEquity = m_account.Equity();
      double trailingDd = 0.0;
      if(m_peakEquity > 0.0)
         trailingDd = ((m_peakEquity - currentEquity) / m_peakEquity) * 100.0;

      outTrailingDdPercent = MathMax(trailingDd, 0.0);

      if(outTrailingDdPercent >= m_maxTrailingDrawdownPercent)
      {
         m_hwmKillSwitchTriggered = true;
         return false; // Trailing HWM limit hit - halts trading until recovery
      }

      return true;
   }

   //+------------------------------------------------------------------+
   //| Check Weekly Drawdown Limit (e.g. 5.0% max loss per week)        |
   //+------------------------------------------------------------------+
   bool CheckWeeklyDrawdown(double &outWeeklyLossPercent)
   {
      UpdateHwmAndWeeklyState();

      if(!m_enableV2Governors || m_maxWeeklyLossPercent <= 0.0)
      {
         outWeeklyLossPercent = 0.0;
         return true;
      }

      double currentEquity = m_account.Equity();
      double weeklyLoss = 0.0;
      if(m_weekStartBalance > 0.0)
         weeklyLoss = ((m_weekStartBalance - currentEquity) / m_weekStartBalance) * 100.0;

      outWeeklyLossPercent = MathMax(weeklyLoss, 0.0);

      if(outWeeklyLossPercent >= m_maxWeeklyLossPercent)
      {
         m_weeklyKillSwitchTriggered = true;
         return false; // Weekly loss limit reached - halts until next Monday
      }

      return true;
   }

   //+------------------------------------------------------------------+
   //| Version 2.0 Dynamic Risk Damping Factor                          |
   //| Smoothly scales risk down from 1.0x to 0.25x as DD increases      |
   //+------------------------------------------------------------------+
   double GetDynamicDampingFactor()
   {
      if(!m_enableV2Governors || !m_enableDynamicDamping || m_maxTrailingDrawdownPercent <= 0.0)
         return 1.0;

      double trailingDd = 0.0;
      CheckHwmDrawdown(trailingDd);

      // If trailing DD is under 2.0%, no damping
      if(trailingDd < 2.0) return 1.0;

      // Scale down linearly towards 0.25x as DD reaches maximum limit
      double progress = (trailingDd - 2.0) / (m_maxTrailingDrawdownPercent - 2.0);
      double damping = 1.0 - (progress * 0.75);
      return MathMax(0.25, MathMin(1.0, damping));
   }

   //+------------------------------------------------------------------+
   //| Version 2.0 Session Liquidity Filter (Blocks Asian / Rollover)   |
   //+------------------------------------------------------------------+
   bool IsWithinAllowedSession() const
   {
      if(!m_enableV2Governors || !m_enableSessionFilter)
         return true;

      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      int currentMinutes = dt.hour * 60 + dt.min;

      // Rollover check: 21:30 to 01:30 GMT
      if(m_assetProfile.blockRollover)
      {
         if(currentMinutes >= (21 * 60 + 30) || currentMinutes <= (1 * 60 + 30))
            return false;
      }

      int startMinutes = m_assetProfile.sessionStartHour * 60 + m_assetProfile.sessionStartMinute;
      int endMinutes   = m_assetProfile.sessionEndHour * 60 + m_assetProfile.sessionEndMinute;

      if(startMinutes < endMinutes)
      {
         return (currentMinutes >= startMinutes && currentMinutes <= endMinutes);
      }
      else
      {
         // Overnight window
         return (currentMinutes >= startMinutes || currentMinutes <= endMinutes);
      }
   }

   void SetSelfOptimizer(CSelfOptimizer *opt)
   {
      m_optimizer = opt;
   }

   //+------------------------------------------------------------------+
   //| Check and reset daily metrics on new calendar day                |
   //+------------------------------------------------------------------+
   void UpdateDailyState()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      datetime today = StringToTime(StringFormat("%04d.%02d.%02d 00:00", dt.year, dt.mon, dt.day));

      if(today != m_currentDay)
      {
         m_currentDay          = today;
         m_dayStartBalance     = m_account.Balance();
         m_dayStartEquity      = m_account.Equity();
         m_killSwitchTriggered = false;
         PrintFormat("[RiskEngine] New trading day initialized. Start Balance: %.2f", m_dayStartBalance);
      }
   }

   //+------------------------------------------------------------------+
   //| Evaluate Current Daily Drawdown & Hard Kill Switch               |
   //+------------------------------------------------------------------+
   bool CheckDailyDrawdown(double &outDrawdownPercent)
   {
      UpdateDailyState();

      if(m_dayStartBalance <= 0.0)
         m_dayStartBalance = m_account.Balance();

      double currentEquity = m_account.Equity();
      double drawdown = 0.0;
      if(m_dayStartBalance > 0.0)
         drawdown = ((m_dayStartBalance - currentEquity) / m_dayStartBalance) * 100.0;

      outDrawdownPercent = MathMax(drawdown, 0.0);

      // Hard Kill switch: 3.8%
      if(outDrawdownPercent >= m_hardKillThresholdPercent)
      {
         m_killSwitchTriggered = true;
         return false; // Hard kill triggered
      }

      // Max Daily Loss: 4.0%
      if(outDrawdownPercent >= m_maxDailyLossPercent)
      {
         return false;
      }

      return true;
   }

   //+------------------------------------------------------------------+
   //| Apply Auto or Manual Take Profit Setting                         |
   //| Auto: Retains EA strategy-chosen dynamic TP (1.5R, 1.8R, 2.0R,   |
   //|       2.5R, or zone target)                                      |
   //| Manual: Enforces user-selected fixed R-multiple for all signals  |
   //+------------------------------------------------------------------+
   void ApplyTakeProfit(TradeSignal &signal) const
   {
      if(m_tpMode == TP_MODE_MANUAL && m_manualTpMultiple > 0.0)
      {
         double riskDist = MathAbs(signal.entryPrice - signal.stopLoss);
         if(riskDist > 0.0)
         {
            if(signal.direction == DIR_BUY)
               signal.takeProfit = signal.entryPrice + (riskDist * m_manualTpMultiple);
            else if(signal.direction == DIR_SELL)
               signal.takeProfit = signal.entryPrice - (riskDist * m_manualTpMultiple);

            signal.riskRewardRatio = m_manualTpMultiple;
            signal.reasonCode += StringFormat("|MANUAL_TP_%.1fR", m_manualTpMultiple);
         }
      }
      else
      {
         double targetR = signal.riskRewardRatio;
         // Self-Optimizer dynamic R-multiple adaptation in Auto TP mode
         if(m_optimizer != NULL)
         {
            double optR = m_optimizer.GetOptimalTpMultiple(signal.strategy, signal.riskRewardRatio);
            if(optR != signal.riskRewardRatio && optR > 0.0)
            {
               targetR = optR;
               double riskDist = MathAbs(signal.entryPrice - signal.stopLoss);
               if(riskDist > 0.0)
               {
                  if(signal.direction == DIR_BUY)
                     signal.takeProfit = signal.entryPrice + (riskDist * targetR);
                  else if(signal.direction == DIR_SELL)
                     signal.takeProfit = signal.entryPrice - (riskDist * targetR);

                  signal.riskRewardRatio = targetR;
                  signal.reasonCode += StringFormat("|SELF_OPT_TP_%.1fR", targetR);
                  return;
               }
            }
         }
         signal.reasonCode += StringFormat("|AUTO_TP_%.1fR", signal.riskRewardRatio);
      }
   }

   //+------------------------------------------------------------------+
   //| Validate Trade Signal with Central Authority                     |
   //+------------------------------------------------------------------+
   bool ValidateSignal(TradeSignal &signal, string &rejectionReason)
   {
      rejectionReason = "";

      // 1. Check Hard Kill Switch & Daily Drawdown
      double currentDrawdown = 0.0;
      if(!CheckDailyDrawdown(currentDrawdown))
      {
         if(m_killSwitchTriggered)
         {
            signal.rejectionReason = REJECT_HARD_KILL_REACHED;
            rejectionReason = StringFormat("CRITICAL: Hard kill switch triggered! Daily Drawdown: %.2f%% >= %.2f%%",
                                           currentDrawdown, m_hardKillThresholdPercent);
         }
         else
         {
            signal.rejectionReason = REJECT_DAILY_DRAWDOWN_LIMIT;
            rejectionReason = StringFormat("Daily loss limit exceeded! Daily Drawdown: %.2f%% >= %.2f%%",
                                           currentDrawdown, m_maxDailyLossPercent);
         }
         return false;
      }

      // 2. Check EOD Flat Schedule
      if(m_eodFlatEnabled && IsNearEOD())
      {
         signal.rejectionReason = REJECT_EOD_APPROACHING;
         rejectionReason = "Approaching End of Day (EOD) Flat time. New entries blocked.";
         return false;
      }

      // 3. Apply TP Setting (Auto or Manual)
      ApplyTakeProfit(signal);

      // 4. Check Minimum Risk:Reward Ratio
      // In manual mode, the user-chosen multiple governs the validation floor.
      double effectiveMinRR = (m_tpMode == TP_MODE_MANUAL) ? m_manualTpMultiple : m_minRiskRewardRatio;
      if(signal.riskRewardRatio < effectiveMinRR)
      {
         signal.rejectionReason = REJECT_INVALID_RR;
         rejectionReason = StringFormat("R:R ratio %.2f below minimum acceptable %.2f",
                                        signal.riskRewardRatio, effectiveMinRR);
         return false;
      }

      // 5. Check Spread
      if(!m_symbolInfo.Name(signal.symbol))
         m_symbolInfo.RefreshRates();

      int currentSpread = (int)m_symbolInfo.Spread();
      if(currentSpread > m_maxSpreadPoints)
      {
         signal.rejectionReason = REJECT_SPREAD_TOO_HIGH;
         rejectionReason = StringFormat("Current spread %d pts exceeds maximum allowed %d pts",
                                        currentSpread, m_maxSpreadPoints);
         return false;
      }

      // 5. Apply Consecutive Loss Protection Rule
      // After 3 consecutive losses, risk is reduced to 0.5% and stays until 50% recovery
      if(m_isReducedRiskMode)
      {
         signal.riskPercent = MathMin(signal.riskPercent, m_reducedRiskPercent);
         signal.reasonCode += "|CONSEC_LOSS_RISK_REDUCED_0.5%";
      }
      else
      {
         signal.riskPercent = MathMin(signal.riskPercent, m_maxRiskPerTradePercent);
      }

      // 6. Apply Self-Optimizer Strategy Risk Weight Calibration
      if(m_optimizer != NULL)
      {
         double optWeight = m_optimizer.GetStrategyRiskWeight(signal.strategy);
         if(optWeight != 1.0)
         {
            signal.riskPercent *= optWeight;
            signal.reasonCode += StringFormat("|OPT_WEIGHT_%.2f", optWeight);
         }
      }

      return true;
   }

   //+------------------------------------------------------------------+
   //| Calculate Normalized Lot Size for any Asset Class                |
   //| (Forex pairs, XAUUSD / Gold, CFDs, Indices)                      |
   //+------------------------------------------------------------------+
   double CalculateLotSize(const string symbol,
                           const double entryPrice,
                           const double stopLossPrice,
                           const double riskPercent,
                           string &errorDetail)
   {
      errorDetail = "";
      if(!m_symbolInfo.Name(symbol))
      {
         errorDetail = "Failed to load symbol info";
         return 0.0;
      }
      m_symbolInfo.RefreshRates();

      double equity = m_account.Equity();
      if(equity <= 0.0) equity = m_account.Balance();
      if(equity <= 0.0)
      {
         errorDetail = "Account equity is zero or negative";
         return 0.0;
      }

      double riskMoney = equity * (riskPercent / 100.0);
      double slDistance = MathAbs(entryPrice - stopLossPrice);
      if(slDistance <= 0.0)
      {
         errorDetail = "Stop loss distance is zero";
         return 0.0;
      }

      double tickSize  = m_symbolInfo.TickSize();
      double tickValue = m_symbolInfo.TickValue();
      double point     = m_symbolInfo.Point();

      if(tickSize <= 0.0 || tickValue <= 0.0)
      {
         errorDetail = "Invalid symbol tick parameters";
         return 0.0;
      }

      // Value of 1 lot for slDistance move:
      // ticks = slDistance / tickSize
      // moneyLossPerLot = ticks * tickValue
      double ticks = slDistance / tickSize;
      double lossPerLot = ticks * tickValue;

      if(lossPerLot <= 0.0)
      {
         errorDetail = "Computed loss per lot is zero";
         return 0.0;
      }

      double rawLots = riskMoney / lossPerLot;

      // Normalize to broker limits
      double minLot  = m_symbolInfo.LotsMin();
      double maxLot  = m_symbolInfo.LotsMax();
      double lotStep = m_symbolInfo.LotsStep();

      if(lotStep <= 0.0) lotStep = 0.01;

      double normalizedLots = MathFloor(rawLots / lotStep) * lotStep;

      if(normalizedLots < minLot)
      {
         // If raw lot is below minLot, cannot execute safely without violating risk
         errorDetail = StringFormat("Computed lot %.4f is below broker minimum %.2f", rawLots, minLot);
         return 0.0;
      }

      if(normalizedLots > maxLot)
         normalizedLots = maxLot;

      return NormalizeDouble(normalizedLots, 2);
   }

   //+------------------------------------------------------------------+
   //| Register Trade Closed Result for Consecutive Loss Tracker        |
   //+------------------------------------------------------------------+
   void OnTradeClosed(const double profit, const double lossAmount)
   {
      if(profit < 0.0)
      {
         m_consecutiveLossCount++;
         if(m_consecutiveLossCount >= 3 && !m_isReducedRiskMode)
         {
            m_isReducedRiskMode   = true;
            m_lossRecoveryTarget  = MathAbs(profit) * 3.0; // Benchmark recovery
            m_recoveredAmount     = 0.0;
            PrintFormat("[RiskEngine] 3 Consecutive Losses! Risk reduced to %.1f%% until 50%% recovery (Target: %.2f)",
                        m_reducedRiskPercent, m_lossRecoveryTarget * 0.50);
         }
      }
      else if(profit > 0.0)
      {
         m_consecutiveLossCount = 0;
         if(m_isReducedRiskMode)
         {
            m_recoveredAmount += profit;
            if(m_recoveredAmount >= (m_lossRecoveryTarget * 0.50))
            {
               m_isReducedRiskMode = false;
               m_lossRecoveryTarget = 0.0;
               m_recoveredAmount = 0.0;
               Print("[RiskEngine] 50% recovery target met! Normal risk restored.");
            }
         }
      }
   }

   // Helpers
   bool IsNearEOD() const
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.hour > m_eodCloseHour) return true;
      if(dt.hour == m_eodCloseHour && dt.min >= m_eodCloseMinute) return true;
      return false;
   }

   bool IsKillSwitchTriggered() const { return m_killSwitchTriggered; }
   bool IsReducedRiskMode() const { return m_isReducedRiskMode; }
   int GetConsecutiveLosses() const { return m_consecutiveLossCount; }
   double GetDayStartBalance() const { return m_dayStartBalance; }
};
