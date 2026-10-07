//+------------------------------------------------------------------+
//|                                                 SelfOptimizer.mqh|
//|               Deterministic Self-Optimization & Attribution Engine|
//|        Option 1: Classic Quant Optimization (Rolling Attribution)|
//|        Option 2: Smart Neural Network (MLP & Online Learning)    |
//|                                  Copyright 2026, Quant Systems   |
//+------------------------------------------------------------------+
#property copyright "Quant Systems"
#property strict

#include "Defines.mqh"
#include "Indicators.mqh"

//+------------------------------------------------------------------+
//| Closed Trade Record for Circular Attribution Ring Buffer         |
//+------------------------------------------------------------------+
struct ClosedTradeRecord
{
   datetime             closeTime;
   ENUM_STRATEGY_TYPE   strategy;
   double               profit;
   double               rMultiple;
   bool                 isWin;
};

//+------------------------------------------------------------------+
//| Native MQL5 Deep Neural Network / Multi-Layer Perceptron (MLP)   |
//| Topology: 6 Inputs -> 8 Hidden-1 -> 6 Hidden-2 -> 4 Outputs      |
//| Zero external Python/DLL dependencies; 100% MT5 native code      |
//+------------------------------------------------------------------+
class CNeuralOptimizerNet
{
private:
   // Weights & Biases Matrices
   double            m_w1[6][8];  // Input (6) -> Hidden 1 (8)
   double            m_b1[8];     // Hidden 1 Biases
   double            m_w2[8][6];  // Hidden 1 (8) -> Hidden 2 (6)
   double            m_b2[6];     // Hidden 2 Biases
   double            m_w3[6][4];  // Hidden 2 (6) -> Output (4)
   double            m_b3[4];     // Output Biases

   // Activation State Cache for Online Backpropagation
   double            m_lastInputs[6];
   double            m_h1[8];
   double            m_h2[6];
   double            m_out[4];

   // Learning Hyperparameters
   double            m_learningRate;  // eta: 0.05
   double            m_momentum;      // alpha: 0.10
   double            m_prevDw1[6][8];
   double            m_prevDw2[8][6];
   double            m_prevDw3[6][4];

   int               m_trainingEpochs;
   double            m_lastLoss;

public:
   CNeuralOptimizerNet()
      : m_learningRate(0.05),
        m_momentum(0.10),
        m_trainingEpochs(0),
        m_lastLoss(0.0)
   {
      InitializeWeights();
   }

   ~CNeuralOptimizerNet() {}

   void SetLearningRate(const double lr) { m_learningRate = MathMax(0.001, MathMin(0.5, lr)); }
   int  GetTrainingEpochs() const        { return m_trainingEpochs; }
   double GetLastLoss() const            { return m_lastLoss; }

   //+------------------------------------------------------------------+
   //| Calibrated Xavier / He Weight Initialization                     |
   //+------------------------------------------------------------------+
   void InitializeWeights()
   {
      // Layer 1: Input (6) -> Hidden 1 (8)
      double seedW1[6][8] = {
         { 0.32, -0.21,  0.45, -0.15,  0.28, -0.35,  0.18,  0.22},
         { 0.40,  0.35, -0.25,  0.30, -0.18,  0.27, -0.32,  0.15},
         { 0.55, -0.42,  0.38,  0.48, -0.22,  0.31, -0.19,  0.41},
         { 0.28,  0.19, -0.33,  0.25,  0.41, -0.28,  0.35, -0.12},
         {-0.45,  0.38, -0.50, -0.35,  0.29, -0.41,  0.22, -0.38},
         { 0.15, -0.18,  0.22, -0.12,  0.33, -0.25,  0.19,  0.30}
      };

      for(int i = 0; i < 6; i++)
      {
         for(int j = 0; j < 8; j++)
         {
            m_w1[i][j] = seedW1[i][j];
            m_prevDw1[i][j] = 0.0;
         }
      }
      for(int j = 0; j < 8; j++) m_b1[j] = 0.05 * (j % 2 == 0 ? 1.0 : -1.0);

      // Layer 2: Hidden 1 (8) -> Hidden 2 (6)
      double seedW2[8][6] = {
         { 0.35, -0.28,  0.42, -0.19,  0.31, -0.22},
         {-0.25,  0.33, -0.18,  0.41, -0.30,  0.26},
         { 0.48, -0.35,  0.29, -0.22,  0.37, -0.15},
         {-0.19,  0.27, -0.38,  0.33, -0.25,  0.42},
         { 0.31, -0.22,  0.45, -0.29,  0.18, -0.35},
         {-0.42,  0.38, -0.25,  0.31, -0.40,  0.28},
         { 0.22, -0.15,  0.33, -0.28,  0.25, -0.19},
         { 0.29,  0.31, -0.22,  0.35, -0.18,  0.25}
      };

      for(int j = 0; j < 8; j++)
      {
         for(int k = 0; k < 6; k++)
         {
            m_w2[j][k] = seedW2[j][k];
            m_prevDw2[j][k] = 0.0;
         }
      }
      for(int k = 0; k < 6; k++) m_b2[k] = 0.02 * (k % 2 == 0 ? 1.0 : -1.0);

      // Layer 3: Hidden 2 (6) -> Output (4)
      double seedW3[6][4] = {
         { 0.52,  0.45,  0.38, -0.25},
         {-0.38, -0.32, -0.29,  0.35},
         { 0.44,  0.48,  0.41, -0.18},
         {-0.49, -0.42, -0.35,  0.42},
         { 0.35,  0.28,  0.33, -0.22},
         {-0.28, -0.25, -0.19,  0.31}
      };

      for(int k = 0; k < 6; k++)
      {
         for(int m = 0; m < 4; m++)
         {
            m_w3[k][m] = seedW3[k][m];
            m_prevDw3[k][m] = 0.0;
         }
      }
      for(int m = 0; m < 4; m++) m_b3[m] = 0.0;

      m_trainingEpochs = 0;
      m_lastLoss       = 0.0;
   }

   //+------------------------------------------------------------------+
   //| Neural Forward Inference Pass                                    |
   //| inputs[6]:                                                       |
   //|   [0] Normalized Volatility Ratio (ATR14 / ATR100 - 1.0)         |
   //|   [1] Trend Alignment Score (+1.0 Bull, 0.0 Range, -1.0 Bear)    |
   //|   [2] Strategy Win Rate Momentum (WR/50 - 1.0)                   |
   //|   [3] Realized Profit Factor Normalized (min(PF,3)/1.5 - 1.0)    |
   //|   [4] Consecutive Loss Penalty (min(losses,5)/2.5 - 1.0)         |
   //|   [5] EMA Separation Ratio (separation / ATR - 1.0)              |
   //| outputs[4]:                                                      |
   //|   [0] Risk Weight Multiplier [0.30, 1.40]                        |
   //|   [1] Setup Win Probability / Confidence [0.0, 1.0]              |
   //|   [2] Recommended Target TP R-Multiple [1.40, 3.00]              |
   //|   [3] Volatility Buffer Scalar [0.80, 1.35]                      |
   //+------------------------------------------------------------------+
   void Forward(const double &inputs[], double &outputs[])
   {
      for(int i = 0; i < 6; i++)
         m_lastInputs[i] = inputs[i];

      // 1. Hidden Layer 1 (Tanh Activation)
      for(int j = 0; j < 8; j++)
      {
         double sum = m_b1[j];
         for(int i = 0; i < 6; i++)
            sum += m_lastInputs[i] * m_w1[i][j];
         m_h1[j] = MathTanh(sum);
      }

      // 2. Hidden Layer 2 (Tanh Activation)
      for(int k = 0; k < 6; k++)
      {
         double sum = m_b2[k];
         for(int j = 0; j < 8; j++)
            sum += m_h1[j] * m_w2[j][k];
         m_h2[k] = MathTanh(sum);
      }

      // 3. Output Layer (Sigmoid Activation scaled to trading boundaries)
      for(int m = 0; m < 4; m++)
      {
         double sum = m_b3[m];
         for(int k = 0; k < 6; k++)
            sum += m_h2[k] * m_w3[k][m];
         m_out[m] = Sigmoid(sum);
      }

      // Domain Scaling
      outputs[0] = NormalizeDouble(0.30 + (1.10 * m_out[0]), 2); // Risk Weight (0.30x to 1.40x)
      outputs[1] = NormalizeDouble(m_out[1], 3);                 // Win Probability Confidence (0.0 to 1.0)
      outputs[2] = NormalizeDouble(1.40 + (1.60 * m_out[2]), 1); // Dynamic Take Profit (1.4R to 3.0R)
      outputs[3] = NormalizeDouble(0.80 + (0.55 * m_out[3]), 2); // Buffer Scalar (0.80x to 1.35x)
   }

   //+------------------------------------------------------------------+
   //| Online Supervised Backpropagation on Closed Trade Result         |
   //+------------------------------------------------------------------+
   void TrainStep(const double actualProfit, const double actualRMultiple)
   {
      bool isWin = (actualProfit > 0.0);

      // Target activations in sigmoid normalized space [0.0, 1.0]
      double targetSig[4];
      targetSig[0] = isWin ? (1.20 - 0.30) / 1.10 : (0.50 - 0.30) / 1.10;
      targetSig[1] = isWin ? 1.00 : 0.00;
      targetSig[2] = MathMax(0.0, MathMin(1.0, (MathMax(1.4, actualRMultiple) - 1.40) / 1.60));
      targetSig[3] = (1.00 - 0.80) / 0.55;

      // 1. Output Layer Deltas (MSE Loss)
      double dOut[4];
      m_lastLoss = 0.0;
      for(int m = 0; m < 4; m++)
      {
         double err = m_out[m] - targetSig[m];
         m_lastLoss += err * err;
         // Sigmoid derivative: out * (1 - out)
         dOut[m] = err * m_out[m] * (1.0 - m_out[m]);
      }
      m_lastLoss /= 4.0;

      // 2. Hidden Layer 2 Deltas
      double dH2[6];
      for(int k = 0; k < 6; k++)
      {
         double sum = 0.0;
         for(int m = 0; m < 4; m++)
            sum += dOut[m] * m_w3[k][m];
         // Tanh derivative: 1 - tanh^2
         dH2[k] = sum * (1.0 - (m_h2[k] * m_h2[k]));
      }

      // 3. Hidden Layer 1 Deltas
      double dH1[8];
      for(int j = 0; j < 8; j++)
      {
         double sum = 0.0;
         for(int k = 0; k < 6; k++)
            sum += dH2[k] * m_w2[j][k];
         dH1[j] = sum * (1.0 - (m_h1[j] * m_h1[j]));
      }

      // 4. Update Synapse Weights: Hidden 2 -> Output
      for(int k = 0; k < 6; k++)
      {
         for(int m = 0; m < 4; m++)
         {
            double grad = dOut[m] * m_h2[k];
            double dw = -(m_learningRate * grad) + (m_momentum * m_prevDw3[k][m]);
            m_w3[k][m] += dw;
            m_prevDw3[k][m] = dw;
         }
      }
      for(int m = 0; m < 4; m++)
         m_b3[m] -= m_learningRate * dOut[m];

      // 5. Update Synapse Weights: Hidden 1 -> Hidden 2
      for(int j = 0; j < 8; j++)
      {
         for(int k = 0; k < 6; k++)
         {
            double grad = dH2[k] * m_h1[j];
            double dw = -(m_learningRate * grad) + (m_momentum * m_prevDw2[j][k]);
            m_w2[j][k] += dw;
            m_prevDw2[j][k] = dw;
         }
      }
      for(int k = 0; k < 6; k++)
         m_b2[k] -= m_learningRate * dH2[k];

      // 6. Update Synapse Weights: Input -> Hidden 1
      for(int i = 0; i < 6; i++)
      {
         for(int j = 0; j < 8; j++)
         {
            double grad = dH1[j] * m_lastInputs[i];
            double dw = -(m_learningRate * grad) + (m_momentum * m_prevDw1[i][j]);
            m_w1[i][j] += dw;
            m_prevDw1[i][j] = dw;
         }
      }
      for(int j = 0; j < 8; j++)
         m_b1[j] -= m_learningRate * dH1[j];

      m_trainingEpochs++;
   }

private:
   double Sigmoid(const double x) const
   {
      if(x < -45.0) return 0.0;
      if(x >  45.0) return 1.0;
      return 1.0 / (1.0 + MathExp(-x));
   }
};

//+------------------------------------------------------------------+
//| Master Self-Optimizer Class (Dual Mode: Classic vs Smart Neural) |
//+------------------------------------------------------------------+
class CSelfOptimizer
{
private:
   string                  m_symbol;
   ENUM_TIMEFRAMES         m_timeframe;
   ENUM_SELF_OPT_MODE      m_mode;
   ENUM_OPTIMIZER_CORE     m_coreType;             // OPT_CORE_CLASSIC or OPT_CORE_NEURAL

   int                     m_rollingTradeCapacity; // Rolling window capacity (e.g. 30)
   int                     m_minTradesForEval;     // Min trades before applying adaptation (e.g. 4)
   bool                    m_enableAdaptiveVol;
   bool                    m_enableAdaptiveWeights;
   bool                    m_enableAdaptiveTp;

   // Rolling Trade Memory Ring Buffer
   ClosedTradeRecord       m_history[];
   int                     m_tradeCount;

   // Per-Strategy Performance Tallies
   StrategyPerformanceMetrics m_mmMetrics;
   StrategyPerformanceMetrics m_smMetrics;
   StrategyPerformanceMetrics m_unitCpMetrics;
   StrategyPerformanceMetrics m_unitMovingMetrics;

   // Volatility Regime State
   VolatilityRegimeMetrics m_volMetrics;

   // Neural Network Sub-Core
   CNeuralOptimizerNet     m_neuralNet;
   NeuralNetworkMetrics    m_neuralMetrics;

   datetime                m_lastOptimizationTime;

public:
   CSelfOptimizer()
      : m_mode(SELF_OPT_ADAPTIVE),
        m_coreType(OPT_CORE_CLASSIC),
        m_rollingTradeCapacity(30),
        m_minTradesForEval(4),
        m_enableAdaptiveVol(true),
        m_enableAdaptiveWeights(true),
        m_enableAdaptiveTp(true),
        m_tradeCount(0),
        m_lastOptimizationTime(0)
   {
      ArrayResize(m_history, m_rollingTradeCapacity);
      Reset();
   }

   ~CSelfOptimizer() {}

   bool Init(const string symbol,
             const ENUM_TIMEFRAMES tf,
             const ENUM_OPTIMIZER_CORE coreType = OPT_CORE_CLASSIC,
             const ENUM_SELF_OPT_MODE mode = SELF_OPT_ADAPTIVE,
             const int rollingTrades = 30,
             const int minTradesForEval = 4,
             const bool enableAdaptiveVol = true,
             const bool enableAdaptiveWeights = true,
             const bool enableAdaptiveTp = true)
   {
      m_symbol                = symbol;
      m_timeframe             = tf;
      m_coreType              = coreType;
      m_mode                  = mode;
      m_rollingTradeCapacity  = MathMax(10, MathMin(100, rollingTrades));
      m_minTradesForEval      = MathMax(2, minTradesForEval);
      m_enableAdaptiveVol     = enableAdaptiveVol;
      m_enableAdaptiveWeights = enableAdaptiveWeights;
      m_enableAdaptiveTp      = enableAdaptiveTp;

      ArrayResize(m_history, m_rollingTradeCapacity);
      Reset();

      PrintFormat("[SelfOptimizer] Initialized. Core=%s, Mode=%s, RollingCapacity=%d, MinEvalTrades=%d",
                  m_coreType == OPT_CORE_NEURAL ? "SMART_NEURAL_NETWORK" : "CLASSIC_QUANT",
                  EnumToString(m_mode), m_rollingTradeCapacity, m_minTradesForEval);
      return true;
   }

   void SetOptimizerCore(const ENUM_OPTIMIZER_CORE core) { m_coreType = core; }
   ENUM_OPTIMIZER_CORE GetOptimizerCore() const           { return m_coreType; }

   void Reset()
   {
      m_tradeCount = 0;
      ZeroMemory(m_history);

      InitStrategyMetrics(m_mmMetrics, STRATEGY_MM, "MM (Trend)");
      InitStrategyMetrics(m_smMetrics, STRATEGY_SM, "SM (Stubborn Man)");
      InitStrategyMetrics(m_unitCpMetrics, STRATEGY_UNIT_CP, "UniT CP (Retest)");
      InitStrategyMetrics(m_unitMovingMetrics, STRATEGY_UNIT_MOVING, "UniT Moving (EMA21)");

      m_volMetrics.currentAtr          = 0.0;
      m_volMetrics.baselineAtr         = 0.0;
      m_volMetrics.volatilityRatio     = 1.0;
      m_volMetrics.bufferScalar        = 1.0;
      m_volMetrics.isExpansionRegime   = false;
      m_volMetrics.isCompressionRegime = false;

      m_neuralMetrics.predictedRiskWeight = 1.00;
      m_neuralMetrics.winConfidence       = 0.60;
      m_neuralMetrics.predictedRMultiple  = 2.00;
      m_neuralMetrics.neuralBufferScalar  = 1.00;
      m_neuralMetrics.currentLoss         = 0.0;
      m_neuralMetrics.trainingEpochs      = 0;
      m_neuralMetrics.lastInferenceTime   = TimeCurrent();

      m_neuralNet.InitializeWeights();
      m_lastOptimizationTime = TimeCurrent();
   }

   //+------------------------------------------------------------------+
   //| Record a completed trade and trigger adaptation                  |
   //+------------------------------------------------------------------+
   void OnTradeClosed(const ENUM_STRATEGY_TYPE strategy, const double profit, const double rMultiple)
   {
      if(m_mode == SELF_OPT_DISABLED || strategy == STRATEGY_NONE)
         return;

      // 1. Add to rolling history ring buffer
      int idx = m_tradeCount % m_rollingTradeCapacity;
      m_history[idx].closeTime = TimeCurrent();
      m_history[idx].strategy  = strategy;
      m_history[idx].profit    = profit;
      m_history[idx].rMultiple = rMultiple;
      m_history[idx].isWin     = (profit > 0.0);

      m_tradeCount++;

      // 2. Recalculate rolling attribution tallies
      RecalculateAttribution();

      // 3. Online Neural Backpropagation (Option 2: Smart Neural Network)
      if(m_coreType == OPT_CORE_NEURAL)
      {
         m_neuralNet.TrainStep(profit, rMultiple);
         m_neuralMetrics.currentLoss      = m_neuralNet.GetLastLoss();
         m_neuralMetrics.trainingEpochs   = m_neuralNet.GetTrainingEpochs();
         m_neuralMetrics.lastInferenceTime= TimeCurrent();
      }

      m_lastOptimizationTime = TimeCurrent();

      PrintFormat("[SelfOptimizer] Trade recorded: %s PnL: %.2f (%.2fR). %s",
                  EnumToString(strategy), profit, rMultiple, GetShortSummary());
   }

   //+------------------------------------------------------------------+
   //| Update Volatility Regime Indicators                              |
   //+------------------------------------------------------------------+
   void UpdateRegime(const CIndicatorEngine &indicators)
   {
      if(m_mode == SELF_OPT_DISABLED || !m_enableAdaptiveVol)
      {
         m_volMetrics.bufferScalar = 1.0;
         return;
      }

      m_volMetrics.currentAtr      = indicators.GetATR(1);
      m_volMetrics.baselineAtr     = indicators.GetBaselineATR(1);
      m_volMetrics.volatilityRatio = indicators.GetVolatilityRatio(1);

      // Option 1: Classic Quant Thresholds
      if(m_coreType == OPT_CORE_CLASSIC)
      {
         if(m_volMetrics.volatilityRatio < 0.75)
         {
            m_volMetrics.isCompressionRegime = true;
            m_volMetrics.isExpansionRegime   = false;
            m_volMetrics.bufferScalar        = 0.85;
         }
         else if(m_volMetrics.volatilityRatio > 1.35)
         {
            m_volMetrics.isExpansionRegime   = true;
            m_volMetrics.isCompressionRegime = false;
            m_volMetrics.bufferScalar        = (m_mode == SELF_OPT_AGGRESSIVE) ? 1.35 : 1.25;
         }
         else
         {
            m_volMetrics.isCompressionRegime = false;
            m_volMetrics.isExpansionRegime   = false;
            m_volMetrics.bufferScalar        = 1.00;
         }
      }
      // Option 2: Smart Neural Network Continuous Scaling
      else
      {
         double inputs[6];
         BuildNeuralFeatureVector(STRATEGY_MM, inputs);
         double outputs[4];
         m_neuralNet.Forward(inputs, outputs);

         m_neuralMetrics.neuralBufferScalar  = outputs[3];
         m_volMetrics.bufferScalar          = outputs[3];
         m_volMetrics.isExpansionRegime     = (m_volMetrics.volatilityRatio > 1.35);
         m_volMetrics.isCompressionRegime   = (m_volMetrics.volatilityRatio < 0.75);
      }
   }

   //+------------------------------------------------------------------+
   //| Get Adaptive Risk Weight Multiplier for a strategy               |
   //+------------------------------------------------------------------+
   double GetStrategyRiskWeight(const ENUM_STRATEGY_TYPE strategy)
   {
      if(m_mode == SELF_OPT_DISABLED || !m_enableAdaptiveWeights)
         return 1.0;

      // Option 1: Classic Quant Attribution Weight
      if(m_coreType == OPT_CORE_CLASSIC)
      {
         switch(strategy)
         {
            case STRATEGY_MM:          return m_mmMetrics.currentRiskWeight;
            case STRATEGY_SM:          return m_smMetrics.currentRiskWeight;
            case STRATEGY_UNIT_CP:     return m_unitCpMetrics.currentRiskWeight;
            case STRATEGY_UNIT_MOVING: return m_unitMovingMetrics.currentRiskWeight;
            default:                   return 1.0;
         }
      }
      // Option 2: Smart Neural Network Predicted Weight
      else
      {
         double inputs[6];
         BuildNeuralFeatureVector(strategy, inputs);
         double outputs[4];
         m_neuralNet.Forward(inputs, outputs);

         m_neuralMetrics.predictedRiskWeight = outputs[0];
         m_neuralMetrics.winConfidence       = outputs[1];
         m_neuralMetrics.predictedRMultiple  = outputs[2];
         m_neuralMetrics.neuralBufferScalar  = outputs[3];
         m_neuralMetrics.lastInferenceTime   = TimeCurrent();

         return outputs[0];
      }
   }

   //+------------------------------------------------------------------+
   //| Get Dynamic Buffer Scalar (ATR multiplier modifier)              |
   //+------------------------------------------------------------------+
   double GetBufferScalar() const
   {
      if(m_mode == SELF_OPT_DISABLED || !m_enableAdaptiveVol)
         return 1.0;

      return m_volMetrics.bufferScalar;
   }

   //+------------------------------------------------------------------+
   //| Get Self-Optimized Take Profit R-Multiple (Auto TP Mode)          |
   //+------------------------------------------------------------------+
   double GetOptimalTpMultiple(const ENUM_STRATEGY_TYPE strategy, const double baseTpMultiple)
   {
      if(m_mode == SELF_OPT_DISABLED || !m_enableAdaptiveTp)
         return baseTpMultiple;

      // Option 1: Classic Quant Target Calibration
      if(m_coreType == OPT_CORE_CLASSIC)
      {
         StrategyPerformanceMetrics metrics;
         if(!GetPerformanceMetrics(strategy, metrics) || metrics.totalTrades < m_minTradesForEval)
            return baseTpMultiple;

         if(metrics.winRate >= 60.0 && metrics.avgRMultiple >= 1.8)
            return NormalizeDouble(MathMin(baseTpMultiple + 0.4, 3.0), 1);
         else if(metrics.winRate < 45.0 || metrics.profitFactor < 1.1)
            return NormalizeDouble(MathMax(baseTpMultiple - 0.3, 1.4), 1);

         return baseTpMultiple;
      }
      // Option 2: Smart Neural Network Predicted R Target
      else
      {
         double inputs[6];
         BuildNeuralFeatureVector(strategy, inputs);
         double outputs[4];
         m_neuralNet.Forward(inputs, outputs);
         return outputs[2];
      }
   }

   //+------------------------------------------------------------------+
   //| Retrieve Neural Network Telemetry Structure                      |
   //+------------------------------------------------------------------+
   void GetNeuralMetrics(NeuralNetworkMetrics &out) const
   {
      out = m_neuralMetrics;
   }

   bool GetPerformanceMetrics(const ENUM_STRATEGY_TYPE strategy, StrategyPerformanceMetrics &outMetrics) const
   {
      switch(strategy)
      {
         case STRATEGY_MM:          outMetrics = m_mmMetrics;          return true;
         case STRATEGY_SM:          outMetrics = m_smMetrics;          return true;
         case STRATEGY_UNIT_CP:     outMetrics = m_unitCpMetrics;     return true;
         case STRATEGY_UNIT_MOVING: outMetrics = m_unitMovingMetrics; return true;
         default:                   return false;
      }
   }

   void GetVolatilityMetrics(VolatilityRegimeMetrics &outMetrics) const
   {
      outMetrics = m_volMetrics;
   }

   //+------------------------------------------------------------------+
   //| Full Optimization Audit Report                                   |
   //+------------------------------------------------------------------+
   void GetOptimizationReport(SelfOptimizerReport &outReport) const
   {
      outReport.lastOptimizationTime = m_lastOptimizationTime;
      outReport.coreType             = m_coreType;
      outReport.evalTradeCount       = MathMin(m_tradeCount, m_rollingTradeCapacity);
      outReport.globalBufferScalar   = m_volMetrics.bufferScalar;
      outReport.recommendedTpMultiple= 2.0;

      double topScore = -999.0;
      ENUM_STRATEGY_TYPE topStrat = STRATEGY_NONE;
      double topWeight = 1.0;

      EvaluateTopStrategy(m_mmMetrics, topScore, topStrat, topWeight);
      EvaluateTopStrategy(m_smMetrics, topScore, topStrat, topWeight);
      EvaluateTopStrategy(m_unitCpMetrics, topScore, topStrat, topWeight);
      EvaluateTopStrategy(m_unitMovingMetrics, topScore, topStrat, topWeight);

      outReport.topStrategy          = topStrat;
      outReport.bestPerformingWeight = topWeight;
      outReport.optimizationNotes    = StringFormat("Core: %s | Top: %s | VolScalar: %.2fx | Trades: %d",
                                                    m_coreType == OPT_CORE_NEURAL ? "SMART_NEURAL" : "CLASSIC_QUANT",
                                                    EnumToString(topStrat), m_volMetrics.bufferScalar, outReport.evalTradeCount);
   }

   //+------------------------------------------------------------------+
   //| Telemetry string for MT5 chart comment & Journal                 |
   //+------------------------------------------------------------------+
   string GetTelemetryString() const
   {
      if(m_mode == SELF_OPT_DISABLED)
         return "Self-Optimizer: DISABLED";

      if(m_coreType == OPT_CORE_NEURAL)
      {
         return StringFormat("[SELF-OPT: SMART NEURAL] Epochs: %d | Loss: %.4f | WinConf: %.1f%% | NeuralWeight: %.2fx | VolScalar: %.2fx",
                             m_neuralMetrics.trainingEpochs, m_neuralMetrics.currentLoss,
                             m_neuralMetrics.winConfidence * 100.0,
                             m_neuralMetrics.predictedRiskWeight, m_volMetrics.bufferScalar);
      }

      return StringFormat("[SELF-OPT: CLASSIC QUANT] VolRatio: %.2f (Scalar: %.2fx) | MM: %.1f%% WR, W:%.2f | SM: %.1f%% WR, W:%.2f%s | UniT-CP: %.1f%% WR, W:%.2f | UniT-Mov: %.1f%% WR, W:%.2f",
                          m_volMetrics.volatilityRatio, m_volMetrics.bufferScalar,
                          m_mmMetrics.winRate, m_mmMetrics.currentRiskWeight,
                          m_smMetrics.winRate, m_smMetrics.currentRiskWeight,
                          m_smMetrics.isOnProbation ? " [PROBATION]" : "",
                          m_unitCpMetrics.winRate, m_unitCpMetrics.currentRiskWeight,
                          m_unitMovingMetrics.winRate, m_unitMovingMetrics.currentRiskWeight);
   }

private:
   void BuildNeuralFeatureVector(const ENUM_STRATEGY_TYPE strategy, double &inputs[])
   {
      StrategyPerformanceMetrics m;
      GetPerformanceMetrics(strategy, m);

      // inputs[0]: Normalized Volatility Ratio (center 1.0 -> 0.0)
      inputs[0] = MathMax(-1.0, MathMin(1.0, (m_volMetrics.volatilityRatio - 1.0)));
      // inputs[1]: Structural regime score
      inputs[1] = m_volMetrics.isExpansionRegime ? 0.8 : (m_volMetrics.isCompressionRegime ? -0.8 : 0.0);
      // inputs[2]: Strategy Win Rate momentum centered at 50%
      inputs[2] = MathMax(-1.0, MathMin(1.0, (m.winRate / 50.0) - 1.0));
      // inputs[3]: Profit Factor normalized (1.5 -> 0.0)
      inputs[3] = MathMax(-1.0, MathMin(1.0, (MathMin(m.profitFactor, 3.0) / 1.5) - 1.0));
      // inputs[4]: Consecutive Loss penalty (0 losses -> -1.0, 3 losses -> +0.2, 5 losses -> +1.0)
      inputs[4] = MathMax(-1.0, MathMin(1.0, (MathMin(m.consecutiveLosses, 5) / 2.5) - 1.0));
      // inputs[5]: Average Realized R momentum (1.5R -> 0.0)
      inputs[5] = MathMax(-1.0, MathMin(1.0, (m.avgRMultiple / 1.5) - 1.0));
   }

   void InitStrategyMetrics(StrategyPerformanceMetrics &m, ENUM_STRATEGY_TYPE strat, string name)
   {
      m.strategy          = strat;
      m.name              = name;
      m.totalTrades       = 0;
      m.winningTrades     = 0;
      m.losingTrades      = 0;
      m.winRate           = 50.0;
      m.grossProfit       = 0.0;
      m.grossLoss         = 0.0;
      m.profitFactor      = 1.0;
      m.avgRMultiple      = 1.5;
      m.currentRiskWeight = 1.0;
      m.isOnProbation     = false;
      m.consecutiveLosses = 0;
      m.performanceScore  = 50.0;
   }

   void RecalculateAttribution()
   {
      int sampleSize = MathMin(m_tradeCount, m_rollingTradeCapacity);
      if(sampleSize <= 0) return;

      InitStrategyMetrics(m_mmMetrics, STRATEGY_MM, "MM (Trend)");
      InitStrategyMetrics(m_smMetrics, STRATEGY_SM, "SM (Stubborn Man)");
      InitStrategyMetrics(m_unitCpMetrics, STRATEGY_UNIT_CP, "UniT CP (Retest)");
      InitStrategyMetrics(m_unitMovingMetrics, STRATEGY_UNIT_MOVING, "UniT Moving (EMA21)");

      for(int i = 0; i < sampleSize; i++)
      {
         ClosedTradeRecord rec = m_history[i];
         switch(rec.strategy)
         {
            case STRATEGY_MM:          AccumulateTrade(m_mmMetrics, rec); break;
            case STRATEGY_SM:          AccumulateTrade(m_smMetrics, rec); break;
            case STRATEGY_UNIT_CP:     AccumulateTrade(m_unitCpMetrics, rec); break;
            case STRATEGY_UNIT_MOVING: AccumulateTrade(m_unitMovingMetrics, rec); break;
            default: break;
         }
      }

      FinalizeMetrics(m_mmMetrics);
      FinalizeMetrics(m_smMetrics);
      FinalizeMetrics(m_unitCpMetrics);
      FinalizeMetrics(m_unitMovingMetrics);
   }

   void AccumulateTrade(StrategyPerformanceMetrics &m, const ClosedTradeRecord &rec)
   {
      m.totalTrades++;
      if(rec.isWin)
      {
         m.winningTrades++;
         m.grossProfit += rec.profit;
         m.consecutiveLosses = 0;
      }
      else
      {
         m.losingTrades++;
         m.grossLoss += MathAbs(rec.profit);
         m.consecutiveLosses++;
      }
      m.avgRMultiple += rec.rMultiple;
   }

   void FinalizeMetrics(StrategyPerformanceMetrics &m)
   {
      if(m.totalTrades <= 0)
      {
         m.currentRiskWeight = 1.0;
         m.isOnProbation     = false;
         return;
      }

      m.winRate = ((double)m.winningTrades / (double)m.totalTrades) * 100.0;
      m.avgRMultiple = m.avgRMultiple / (double)m.totalTrades;

      if(m.grossLoss > 0.0)
         m.profitFactor = m.grossProfit / m.grossLoss;
      else if(m.grossProfit > 0.0)
         m.profitFactor = 5.0;
      else
         m.profitFactor = 1.0;

      m.performanceScore = (m.winRate * 0.4) + (MathMin(m.profitFactor, 3.0) * 20.0);

      if(m.totalTrades >= m_minTradesForEval && m_enableAdaptiveWeights)
      {
         if(m.profitFactor < 0.80 || m.winRate < 35.0 || m.consecutiveLosses >= 3)
         {
            m.isOnProbation     = true;
            m.currentRiskWeight = (m_mode == SELF_OPT_AGGRESSIVE) ? 0.35 : 0.50;
         }
         else if(m.profitFactor >= 1.60 && m.winRate >= 58.0)
         {
            m.isOnProbation     = false;
            m.currentRiskWeight = (m_mode == SELF_OPT_AGGRESSIVE) ? 1.30 : 1.20;
         }
         else
         {
            m.isOnProbation     = false;
            m.currentRiskWeight = 1.00;
         }
      }
      else
      {
         m.currentRiskWeight = 1.00;
         m.isOnProbation     = false;
      }
   }

   void EvaluateTopStrategy(const StrategyPerformanceMetrics &m, double &topScore, ENUM_STRATEGY_TYPE &topStrat, double &topWeight) const
   {
      if(m.totalTrades >= m_minTradesForEval && m.performanceScore > topScore)
      {
         topScore = m.performanceScore;
         topStrat = m.strategy;
         topWeight= m.currentRiskWeight;
      }
   }

   string GetShortSummary() const
   {
      return StringFormat("Top: MM(%.1f), SM(%.1f), CP(%.1f), Mov(%.1f)",
                          m_mmMetrics.performanceScore, m_smMetrics.performanceScore,
                          m_unitCpMetrics.performanceScore, m_unitMovingMetrics.performanceScore);
   }
};
