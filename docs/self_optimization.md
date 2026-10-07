# Self-Optimization & Attribution Core: Dual-Engine Architecture

## Executive Overview
The **Self-Optimization Engine** (`CSelfOptimizer`) equips the Expert Advisor with adaptive mathematical self-tuning to overcome market regime shifts. To cater to different quantitative philosophies, the EA provides two distinct optimization modes:

1. **Option 1: Classic Quant Optimization** (`OPT_CORE_CLASSIC`)
   - Pure statistical trade attribution, discrete volatility corridor regimes, rolling win rate and profit factor thresholds, and rule-based dynamic TP calibration.
   - 100% deterministic, zero curve-fitting, highly transparent, and fully audit-trail compliant.

2. **Option 2: Smart Neural Network Optimization** (`OPT_CORE_NEURAL`)
   - Native on-device Deep Multi-Layer Perceptron (MLP) with online backpropagation learning directly executed in pure MQL5 without any external Python servers, cloud calls, or DLLs.
   - 6 Input features $\rightarrow$ 8 Hidden-1 ($\tanh$) $\rightarrow$ 6 Hidden-2 ($\tanh$) $\rightarrow$ 4 Continuous Outputs ($\text{Sigmoid}$).
   - Continuously adapts risk weights, setup win confidence, dynamic TP multiples, and continuous volatility buffer scaling.

---

## 1. Mode Comparison: Classic Quant vs Smart Neural Network

| Dimension | Option 1: Classic Quant (`OPT_CORE_CLASSIC`) | Option 2: Smart Neural Network (`OPT_CORE_NEURAL`) |
| :--- | :--- | :--- |
| **Mathematical Core** | Rolling attribution window & statistical threshold rules | 3-Layer Deep Multi-Layer Perceptron (MLP 6-8-6-4) |
| **Learning Mechanism** | Discrete recalculation upon closed deals in ring buffer | Online supervised gradient descent backpropagation ($\eta=0.05, \alpha=0.10$) |
| **Risk Weighting** | Step-function: $0.50\times$ (probation), $1.00\times$ (normal), $1.20\times$ (edge) | Continuous regression: $0.30\times$ to $1.40\times$ risk multiplier |
| **Win Confidence** | Historical win rate percentage ($0-100\%$) | Multi-feature setup win probability prediction ($0.0-1.0$) |
| **TP Optimization** | Step adjustments: $\pm 0.3-0.4\text{R}$ based on win rate & PF | Continuous non-linear target prediction ($1.4\text{R}-3.0\text{R}$) |
| **Volatility Scaling** | Discrete thresholds: $0.85\times$ ($<0.75$), $1.00\times$, $1.25\times$ ($>1.35$) | Continuous non-linear buffer scalar output ($0.80\times-1.35\times$) |
| **External Dependencies** | None (100% Native MQL5) | None (100% Native MQL5, Zero Python/DLLs) |

---

## 2. Option 1: Classic Quant Optimization Details

### A. Rolling Trade Attribution & Ring Buffer
The engine maintains a circular ring buffer of the last $N$ closed trades (configurable via `InpSelfOptRollingTrades`, default $30$ trades):
- Each closed trade is matched to its parent strategy via deal ticket magic numbers:
  - `STRATEGY_MM` (Magic: Base + 100)
  - `STRATEGY_SM` (Magic: Base + 200)
  - `STRATEGY_UNIT_CP` (Magic: Base + 300)
  - `STRATEGY_UNIT_MOVING` (Magic: Base + 400)
- Metrics computed:
  - **Win Rate ($\text{WR}$)**: $\frac{\text{Wins}}{\text{Total}} \times 100$
  - **Profit Factor ($\text{PF}$)**: $\frac{\text{Gross Profit}}{\text{Gross Loss}}$
  - **Composite Score**: $(\text{WR} \times 0.40) + (\min(\text{PF}, 3.0) \times 20.0)$

### B. Probation & Edge Weighting
- **Probation Trigger**: $\text{PF} < 0.80$ OR $\text{WR} < 35.0\%$ OR $\ge 3$ consecutive strategy losses. Risk weight halved to **$0.50\times$** (or **$0.35\times$** in Aggressive mode).
- **High-Edge Boost**: $\text{PF} \ge 1.60$ AND $\text{WR} \ge 58.0\%$. Risk weight boosted to **$1.20\times$** (or **$1.30\times$** in Aggressive mode).
- **Neutral**: Default weight of **$1.00\times$**.

---

## 3. Option 2: Smart Neural Network Details

### A. Native MLP Architecture (Zero Dependencies)
The `CNeuralOptimizerNet` class implements a fully self-contained neural network inside MT5:
- **Input Layer (6 Features)**:
  1. $x_0$: Volatility Ratio normalized: $\frac{\text{ATR}_{14}}{\text{ATR}_{100}} - 1.0$
  2. $x_1$: Regime alignment score: $+0.8$ Expansion, $-0.8$ Compression, $0.0$ Normal
  3. $x_2$: Strategy Win Rate momentum: $\frac{\text{WR}}{50.0} - 1.0$
  4. $x_3$: Profit Factor normalized: $\frac{\min(\text{PF}, 3.0)}{1.5} - 1.0$
  5. $x_4$: Consecutive Loss Penalty: $\frac{\min(\text{Losses}, 5)}{2.5} - 1.0$
  6. $x_5$: Average Realized R momentum: $\frac{\bar{R}}{1.5} - 1.0$

- **Hidden Layer 1 (8 Neurons, Tanh Activation)**:
  $$h_1^{(j)} = \tanh\left(\sum_{i=0}^5 w_{ij}^{(1)} x_i + b_j^{(1)}\right)$$

- **Hidden Layer 2 (6 Neurons, Tanh Activation)**:
  $$h_2^{(k)} = \tanh\left(\sum_{j=0}^7 w_{jk}^{(2)} h_1^{(j)} + b_k^{(2)}\right)$$

- **Output Layer (4 Neurons, Sigmoid + Domain Scaling)**:
  $$o_m = \sigma\left(\sum_{k=0}^5 w_{km}^{(3)} h_2^{(k)} + b_m^{(3)}\right)$$
  - $\hat{y}_0$: Risk Weight = $0.30 + 1.10 \times o_0 \in [0.30, 1.40]$
  - $\hat{y}_1$: Win Confidence = $o_1 \in [0.00, 1.00]$
  - $\hat{y}_2$: Recommended Dynamic TP = $1.40 + 1.60 \times o_2 \in [1.4\text{R}, 3.0\text{R}]$
  - $\hat{y}_3$: Volatility Buffer Scalar = $0.80 + 0.55 \times o_3 \in [0.80, 1.35]$

### B. Online Supervised Backpropagation
Whenever a trade closes (`OnTradeTransaction` $\rightarrow$ `OnTradeClosed`), the network executes a live gradient descent step:
- Computes Mean Squared Error (MSE Loss) against the realized trade outcome.
- Propagates error deltas backwards through layer 3, layer 2, and layer 1.
- Updates synaptic weights and biases with learning rate $\eta=0.05$ and momentum $\alpha=0.10$.
- Zero lag: Weights adapt immediately to live broker conditions without waiting for weekend offline re-training.

---

## 4. Input Parameter Configuration

```mql5
input group "=== Self-Optimization Engine ==="
input ENUM_OPTIMIZER_CORE InpSelfOptCore        = OPT_CORE_CLASSIC;  // Optimization Core: OPT_CORE_CLASSIC vs OPT_CORE_NEURAL
input ENUM_SELF_OPT_MODE InpSelfOptMode         = SELF_OPT_ADAPTIVE; // Mode (Disabled / Adaptive / Aggressive)
input int               InpSelfOptRollingTrades = 30;                // Rolling Attribution Window (Trades)
input int               InpSelfOptMinEvalTrades = 4;                 // Min Trades for Strategy Weight Calibration
input bool              InpSelfOptAdaptiveVol   = true;              // Adaptive Volatility Buffer Scaling
input bool              InpSelfOptAdaptiveWeight= true;              // Adaptive Strategy Risk Weighting
input bool              InpSelfOptAdaptiveTp    = true;              // Adaptive Take Profit R-Multiple Optimization
```

---

## 5. Central Sovereign Safeguards
Regardless of whether Classic Quant or Smart Neural Network is chosen:
1. **Hard Kill Authority Prevails**: The Risk Engine ($4.0\%$ max daily loss, $3.8\%$ Hard Kill, $0.5\%$ consecutive-loss risk halving) maintains sovereign authority and overrides any optimizer recommendation.
2. **Deterministic Bounded Domains**: Neural network outputs are strictly bounded via hard clamped affine domain mappings ($0.30\times-1.40\times$ risk, $1.4\text{R}-3.0\text{R}$ TP, $0.80\times-1.35\times$ buffer) to prevent runaway model states.
3. **Live MT5 Chart Telemetry**: Active engine state is rendered continuously on chart comments and the MT5 terminal journal.
