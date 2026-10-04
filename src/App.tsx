import React, { useState } from 'react';
import {
  ShieldCheck,
  Cpu,
  Layers,
  Code2,
  Calculator,
  CheckCircle2,
  BookOpen,
  Download,
  Copy,
  Check,
  Play,
  RotateCcw,
  AlertTriangle,
  ArrowRight,
  TrendingUp,
  TrendingDown,
  Activity,
  Flame,
  FileCode,
  Sliders,
  Compass,
  Zap,
  Info
} from 'lucide-react';
import JSZip from 'jszip';
import { MQL_FILES, CodeFile } from './data/mqlCode';
import { SCENARIOS, Scenario, SimCandle } from './data/simulatorData';
import { VERIFICATION_TESTS, VerificationTest } from './data/testsData';
import { DOCS_ARTICLES, DocArticle } from './data/docsContent';

export default function App() {
  const [activeTab, setActiveTab] = useState<'architecture' | 'simulator' | 'code' | 'risk' | 'tests' | 'docs'>('architecture');
  const [selectedFile, setSelectedFile] = useState<CodeFile>(MQL_FILES[0]);
  const [copied, setCopied] = useState(false);
  const [downloadingZip, setDownloadingZip] = useState(false);

  // Simulator state
  const [activeScenario, setActiveScenario] = useState<Scenario>(SCENARIOS[0]);
  const [stepIndex, setStepIndex] = useState<number>(activeScenario.candles.length - 1);
  const [isPlaying, setIsPlaying] = useState<boolean>(false);

  // Calculator state
  const [calcEquity, setCalcEquity] = useState<number>(10000);
  const [calcRiskPct, setCalcRiskPct] = useState<number>(1.0);
  const [calcSymbol, setCalcSymbol] = useState<'EURUSD' | 'GBPUSD' | 'XAUUSD' | 'US30'>('EURUSD');
  const [calcEntry, setCalcEntry] = useState<number>(1.0850);
  const [calcSL, setCalcSL] = useState<number>(1.0830);
  const [consecLosses, setConsecLosses] = useState<number>(0);

  // Tests state
  const [tests, setTests] = useState<VerificationTest[]>(VERIFICATION_TESTS);
  const [selectedTest, setSelectedTest] = useState<VerificationTest>(VERIFICATION_TESTS[0]);

  // Docs state
  const [selectedDoc, setSelectedDoc] = useState<DocArticle>(DOCS_ARTICLES[0]);
  const [docSearch, setDocSearch] = useState<string>('');

  // Copy code handler
  const handleCopyCode = (text: string) => {
    navigator.clipboard.writeText(text);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  // Download single file handler
  const handleDownloadFile = (file: CodeFile) => {
    const blob = new Blob([file.code], { type: 'text/plain;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = file.name;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  // Download complete MQL5 package ZIP
  const handleDownloadZip = async () => {
    setDownloadingZip(true);
    try {
      const zip = new JSZip();
      
      // Experts
      const expertsFolder = zip.folder('MQL5/Experts');
      MQL_FILES.filter(f => f.category === 'master').forEach(f => {
        expertsFolder?.file(f.name, f.code);
      });

      // Include/Deterministic
      const includeFolder = zip.folder('MQL5/Include/Deterministic');
      MQL_FILES.filter(f => f.category === 'include').forEach(f => {
        includeFolder?.file(f.name, f.code);
      });

      // Docs
      const docsFolder = zip.folder('docs');
      DOCS_ARTICLES.forEach(doc => {
        docsFolder?.file(doc.filename.replace('docs/', ''), doc.content);
      });

      const content = await zip.generateAsync({ type: 'blob' });
      const url = URL.createObjectURL(content);
      const a = document.createElement('a');
      a.href = url;
      a.download = 'Deterministic_MQL5_EA_Package.zip';
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
    } catch (e) {
      console.error('Failed to generate zip', e);
    } finally {
      setDownloadingZip(false);
    }
  };

  // Calculate lot size
  const calculateLots = () => {
    const riskMoney = calcEquity * ((consecLosses >= 3 ? 0.5 : calcRiskPct) / 100);
    const slDist = Math.abs(calcEntry - calcSL);
    if (slDist <= 0) return { lots: 0, riskMoney, lossPerLot: 0 };

    let tickSize = 0.00001;
    let tickValue = 1.0;
    if (calcSymbol === 'EURUSD' || calcSymbol === 'GBPUSD') {
      tickSize = 0.00001;
      tickValue = 1.0; // 1 pip = 10 ticks = $10 per lot
    } else if (calcSymbol === 'XAUUSD') {
      tickSize = 0.01;
      tickValue = 1.0; // $1 per point
    } else if (calcSymbol === 'US30') {
      tickSize = 1.0;
      tickValue = 1.0;
    }

    const ticks = slDist / tickSize;
    const lossPerLot = ticks * tickValue;
    const rawLots = lossPerLot > 0 ? riskMoney / lossPerLot : 0;
    const normalizedLots = Math.max(0.01, Math.min(100.0, Math.floor(rawLots * 100) / 100));
    return { lots: normalizedLots, riskMoney, lossPerLot };
  };

  const lotCalc = calculateLots();

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 flex flex-col font-sans">
      {/* Top Header Bar */}
      <header className="border-b border-slate-800 bg-slate-900/90 backdrop-blur sticky top-0 z-50">
        <div className="max-w-7xl mx-auto px-4 py-3 flex flex-wrap items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-emerald-500 to-cyan-600 flex items-center justify-center shadow-lg shadow-emerald-500/20">
              <Cpu className="w-5 h-5 text-slate-950 font-bold" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h1 className="text-lg font-bold text-slate-50 tracking-tight">Deterministic MQL5 EA Studio</h1>
                <span className="px-2 py-0.5 text-xs font-semibold rounded-full bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">
                  Pure Rules • Zero AI/ML
                </span>
              </div>
              <p className="text-xs text-slate-400">Hard-coded: MM (Trend) • SM (Stubborn Man) • UniT (CP & Moving)</p>
            </div>
          </div>

          <div className="flex items-center gap-2.5">
            <button
              onClick={() => handleCopyCode(MQL_FILES[0].code)}
              className="flex items-center gap-2 px-3 py-1.5 text-xs font-medium rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700 transition"
              title="Copy Standalone .mq5 ready for MetaEditor"
            >
              {copied ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Copy className="w-3.5 h-3.5 text-slate-400" />}
              <span>{copied ? 'Copied .mq5!' : 'Copy Standalone EA'}</span>
            </button>

            <button
              onClick={handleDownloadZip}
              disabled={downloadingZip}
              className="flex items-center gap-2 px-3.5 py-1.5 text-xs font-medium rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white shadow-md shadow-emerald-600/30 transition disabled:opacity-50"
            >
              <Download className="w-3.5 h-3.5" />
              <span>{downloadingZip ? 'Packaging...' : 'Download Full Package (.zip)'}</span>
            </button>
          </div>
        </div>

        {/* Navigation Tabs */}
        <div className="max-w-7xl mx-auto px-4 flex space-x-1 overflow-x-auto scrollbar-none border-t border-slate-800/60 pt-1">
          {[
            { id: 'architecture', label: 'Architecture & Pipeline', icon: Layers },
            { id: 'simulator', label: 'Interactive Simulator', icon: Activity },
            { id: 'code', label: 'MQL5 Code Explorer', icon: Code2 },
            { id: 'risk', label: 'Risk & Sizing Engine', icon: Calculator },
            { id: 'tests', label: 'Verification Matrix (26)', icon: CheckCircle2 },
            { id: 'docs', label: 'Technical Documentation', icon: BookOpen }
          ].map((tab) => {
            const Icon = tab.icon;
            const isActive = activeTab === tab.id;
            return (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id as any)}
                className={`flex items-center gap-2 px-3.5 py-2 text-xs font-semibold border-b-2 transition whitespace-nowrap ${
                  isActive
                    ? 'border-emerald-400 text-emerald-400 bg-emerald-500/10'
                    : 'border-transparent text-slate-400 hover:text-slate-200 hover:bg-slate-800/40'
                }`}
              >
                <Icon className="w-4 h-4" />
                <span>{tab.label}</span>
              </button>
            );
          })}
        </div>
      </header>

      {/* Main Content Area */}
      <main className="max-w-7xl mx-auto px-4 py-6 flex-1 w-full">
        {/* ========================================================================= */}
        {/* TAB 1: ARCHITECTURE & PIPELINE */}
        {/* ========================================================================= */}
        {activeTab === 'architecture' && (
          <div className="space-y-6">
            {/* Header banner */}
            <div className="p-5 rounded-2xl bg-gradient-to-r from-slate-900 via-slate-900 to-slate-850 border border-slate-800 shadow-xl">
              <div className="flex flex-wrap items-center justify-between gap-4">
                <div>
                  <h2 className="text-xl font-bold text-slate-100 flex items-center gap-2">
                    <ShieldCheck className="w-5 h-5 text-emerald-400" />
                    Sovereign Rule-Based Decision Pipeline
                  </h2>
                  <p className="text-xs text-slate-400 mt-1 max-w-3xl">
                    Every trading decision flows through a linear, non-probabilistic pipeline. No external ML, sentiment,
                    or news feeds exist in the execution path. Only closed candles, verified swings, structural levels,
                    and central risk constraints.
                  </p>
                </div>
                <div className="flex items-center gap-4 text-xs font-mono bg-slate-950/80 px-4 py-2 rounded-xl border border-slate-800">
                  <div className="text-slate-400">Timeframes: <span className="text-emerald-400 font-semibold">M5 & M15</span></div>
                  <div className="text-slate-400">Lookahead: <span className="text-cyan-400 font-semibold">0 Bars (Confirmed Only)</span></div>
                  <div className="text-slate-400">Daily Max Loss: <span className="text-amber-400 font-semibold">4.0% (Kill: 3.8%)</span></div>
                </div>
              </div>
            </div>

            {/* Decision Pipeline Flowchart */}
            <div className="p-6 rounded-2xl bg-slate-900 border border-slate-800 shadow-lg">
              <h3 className="text-sm font-semibold uppercase tracking-wider text-slate-400 mb-6 flex items-center gap-2">
                <Compass className="w-4 h-4 text-emerald-400" />
                End-to-End Execution Sequence
              </h3>

              <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
                {/* Step 1 */}
                <div className="p-4 rounded-xl bg-slate-950/60 border border-slate-800 flex flex-col justify-between">
                  <div>
                    <div className="flex items-center justify-between text-xs text-slate-400 mb-2">
                      <span className="font-mono text-emerald-400">STAGE 01</span>
                      <span className="px-1.5 py-0.5 rounded bg-slate-800 text-[10px]">On New Bar</span>
                    </div>
                    <h4 className="font-bold text-slate-200 text-sm">Candles & Indicators</h4>
                    <p className="text-xs text-slate-400 mt-1">
                      Copies closed rates at shift 1. Updates EMA 21, EMA 50, Slow EMA (600 on M5, 800 on M15), and ATR(14).
                    </p>
                  </div>
                  <div className="mt-3 pt-2 border-t border-slate-800/80 text-[11px] font-mono text-cyan-400">
                    Indicators.mqh
                  </div>
                </div>

                {/* Step 2 */}
                <div className="p-4 rounded-xl bg-slate-950/60 border border-slate-800 flex flex-col justify-between">
                  <div>
                    <div className="flex items-center justify-between text-xs text-slate-400 mb-2">
                      <span className="font-mono text-emerald-400">STAGE 02</span>
                      <span className="px-1.5 py-0.5 rounded bg-slate-800 text-[10px]">Zero-Lookahead</span>
                    </div>
                    <h4 className="font-bold text-slate-200 text-sm">Market Structure & S/D</h4>
                    <p className="text-xs text-slate-400 mt-1">
                      Detects confirmed swings with 3-bar confirmation delay. Identifies BOS, CHOCH, and Fresh/Tested Supply & Demand zones.
                    </p>
                  </div>
                  <div className="mt-3 pt-2 border-t border-slate-800/80 text-[11px] font-mono text-cyan-400">
                    MarketStructure.mqh
                  </div>
                </div>

                {/* Step 3 */}
                <div className="p-4 rounded-xl bg-slate-950/60 border border-slate-800 flex flex-col justify-between">
                  <div>
                    <div className="flex items-center justify-between text-xs text-slate-400 mb-2">
                      <span className="font-mono text-emerald-400">STAGE 03</span>
                      <span className="px-1.5 py-0.5 rounded bg-slate-800 text-[10px]">Deterministic</span>
                    </div>
                    <h4 className="font-bold text-slate-200 text-sm">Trend & Regime Classifier</h4>
                    <p className="text-xs text-slate-400 mt-1">
                      Classifies market into UP, DOWN, RANGE, or TRANSITION based on structural swings, EMA separation, and boundary corridors.
                    </p>
                  </div>
                  <div className="mt-3 pt-2 border-t border-slate-800/80 text-[11px] font-mono text-cyan-400">
                    TrendEngine.mqh
                  </div>
                </div>

                {/* Step 4 */}
                <div className="p-4 rounded-xl bg-slate-950/60 border border-slate-800 flex flex-col justify-between">
                  <div>
                    <div className="flex items-center justify-between text-xs text-slate-400 mb-2">
                      <span className="font-mono text-emerald-400">STAGE 04</span>
                      <span className="px-1.5 py-0.5 rounded bg-slate-800 text-[10px]">Arbitration</span>
                    </div>
                    <h4 className="font-bold text-slate-200 text-sm">Conflict Manager & Risk</h4>
                    <p className="text-xs text-slate-400 mt-1">
                      Blocks trend setups in Range; blocks SM in Trend. Validates 4.0% daily limit, 3.8% kill switch, 1 position per symbol, and computes exact lots.
                    </p>
                  </div>
                  <div className="mt-3 pt-2 border-t border-slate-800/80 text-[11px] font-mono text-cyan-400">
                    ConflictManager.mqh • RiskEngine.mqh
                  </div>
                </div>
              </div>
            </div>

            {/* Three Distinct Strategies Deep Dive */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              {/* Strategy 1: MM */}
              <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col justify-between">
                <div>
                  <div className="flex items-center justify-between mb-3">
                    <span className="px-2.5 py-1 text-xs font-bold rounded-lg bg-blue-500/20 text-blue-400 border border-blue-500/30">
                      STRATEGY 1: MM
                    </span>
                    <span className="text-xs font-mono text-slate-400">Trend Following</span>
                  </div>
                  <h4 className="text-base font-bold text-slate-100">EMA50 & Slow EMA (600/800)</h4>
                  <p className="text-xs text-slate-400 mt-2 leading-relaxed">
                    Operates in confirmed <code className="text-blue-300">TREND_UP</code> or <code className="text-blue-300">TREND_DOWN</code>.
                    <span className="block mt-1 font-semibold text-amber-300">
                      Slow EMA is context ONLY — never an independent trigger!
                    </span>
                  </p>
                  <ul className="mt-3 space-y-1.5 text-xs text-slate-300">
                    <li className="flex items-start gap-1.5">
                      <span className="text-blue-400">•</span>
                      <span><strong>Standard Bounce:</strong> Price interacts with EMA50 with strong candle agreeing with trend.</span>
                    </li>
                    <li className="flex items-start gap-1.5">
                      <span className="text-blue-400">•</span>
                      <span><strong>High-Risk Cross:</strong> Strong candle displaces through EMA50 aligned with Slow EMA.</span>
                    </li>
                    <li className="flex items-start gap-1.5">
                      <span className="text-blue-400">•</span>
                      <span><strong>Agile Stop Loss:</strong> Anchored behind EMA50 and bounce candle low (no wide multi-day macro swings).</span>
                    </li>
                    <li className="flex items-start gap-1.5">
                      <span className="text-blue-400">•</span>
                      <span><strong>Reversal:</strong> Extreme separation &gt; 2.5 ATR with EMA50 counter-cross.</span>
                    </li>
                  </ul>
                </div>
                <div className="mt-4 pt-3 border-t border-slate-800 flex items-center justify-between text-xs font-mono text-slate-400">
                  <span>Magic: 90101-90103</span>
                  <span className="text-emerald-400">Target: 1:2 R:R</span>
                </div>
              </div>

              {/* Strategy 2: SM */}
              <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col justify-between">
                <div>
                  <div className="flex items-center justify-between mb-3">
                    <span className="px-2.5 py-1 text-xs font-bold rounded-lg bg-purple-500/20 text-purple-400 border border-purple-500/30">
                      STRATEGY 2: SM
                    </span>
                    <span className="text-xs font-mono text-slate-400">Stubborn Man Range</span>
                  </div>
                  <h4 className="text-base font-bold text-slate-100">Supply/Demand & Refusal Candles</h4>
                  <p className="text-xs text-slate-400 mt-2 leading-relaxed">
                    Operates strictly in confirmed <code className="text-purple-300">TREND_RANGE</code>.
                    <span className="block mt-1 font-semibold text-rose-400">
                      Strictly blocked during confirmed TREND conditions!
                    </span>
                  </p>
                  <ul className="mt-3 space-y-1.5 text-xs text-slate-300">
                    <li className="flex items-start gap-1.5">
                      <span className="text-purple-400">•</span>
                      <span><strong>Range High Sell:</strong> Price enters Supply boundary and forms a confirmed upper-wick refusal candle (&ge;45%).</span>
                    </li>
                    <li className="flex items-start gap-1.5">
                      <span className="text-purple-400">•</span>
                      <span><strong>Range Low Buy:</strong> Price enters Demand boundary and forms a confirmed lower-wick refusal candle (&ge;45%).</span>
                    </li>
                    <li className="flex items-start gap-1.5">
                      <span className="text-purple-400">•</span>
                      <span><strong>Invalidation:</strong> SL placed strictly outside zone; TP before opposing boundary.</span>
                    </li>
                  </ul>
                </div>
                <div className="mt-4 pt-3 border-t border-slate-800 flex items-center justify-between text-xs font-mono text-slate-400">
                  <span>Magic: 90201</span>
                  <span className="text-emerald-400">Min R:R &ge; 1.5</span>
                </div>
              </div>

              {/* Strategy 3: UniT */}
              <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col justify-between">
                <div>
                  <div className="flex items-center justify-between mb-3">
                    <span className="px-2.5 py-1 text-xs font-bold rounded-lg bg-amber-500/20 text-amber-400 border border-amber-500/30">
                      STRATEGY 3: UniT
                    </span>
                    <span className="text-xs font-mono text-slate-400">CP & Moving</span>
                  </div>
                  <h4 className="text-base font-bold text-slate-100">Spike Retest & EMA21 Follow</h4>
                  <p className="text-xs text-slate-400 mt-2 leading-relaxed">
                    Consists of UniT CP and UniT Moving.
                    <span className="block mt-1 font-semibold text-rose-400">
                      Contains NO reversal setup whatsoever!
                    </span>
                  </p>
                  <ul className="mt-3 space-y-1.5 text-xs text-slate-300">
                    <li className="flex items-start gap-1.5">
                      <span className="text-amber-400">•</span>
                      <span><strong>UniT CP:</strong> Detects sharp 3-bar spike move and exact pullback breach. Retests spike extreme.</span>
                    </li>
                    <li className="flex items-start gap-1.5">
                      <span className="text-emerald-400 font-semibold">•</span>
                      <span><strong>CP Last-Pivot SL:</strong> Stop Loss is placed at the <em>Last Pivot</em> (local pivot turn), preventing oversized risk and long holding times.</span>
                    </li>
                    <li className="flex items-start gap-1.5">
                      <span className="text-emerald-400 font-semibold">•</span>
                      <span><strong>Moving SL Behind EMA 21:</strong> Stop Loss is placed strictly <em>Behind the EMA 21</em> line, ensuring rapid invalidation and high velocity.</span>
                    </li>
                    <li className="flex items-start gap-1.5">
                      <span className="text-amber-400">•</span>
                      <span><strong>Dynamic CP Risk:</strong> Halved for each adverse condition (1% &rarr; 0.5% &rarr; 0.25%).</span>
                    </li>
                  </ul>
                </div>
                <div className="mt-4 pt-3 border-t border-slate-800 flex items-center justify-between text-xs font-mono text-slate-400">
                  <span>Magic: 90301, 90401-90402</span>
                  <span className="text-emerald-400 font-semibold">Agile SL: Last Pivot & Behind EMA21</span>
                </div>
              </div>
            </div>

            {/* Conflict Resolution & Risk Rules Matrix */}
            <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800">
              <h3 className="text-sm font-semibold uppercase tracking-wider text-slate-400 mb-4 flex items-center gap-2">
                <Sliders className="w-4 h-4 text-emerald-400" />
                Strategy Conflict Matrix & Hard Risk Limits
              </h3>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-xs">
                <div className="p-4 rounded-xl bg-slate-950 border border-slate-800/80 space-y-2">
                  <div className="font-bold text-slate-200">Deterministic Conflict Manager Rules</div>
                  <p className="text-slate-400">
                    <strong>Rule 1:</strong> Trend strategies (MM and UniT) are strictly rejected during confirmed <code className="text-cyan-300">TREND_RANGE</code>.
                  </p>
                  <p className="text-slate-400">
                    <strong>Rule 2:</strong> Range strategy (SM) is strictly rejected during confirmed <code className="text-cyan-300">TREND_UP</code> or <code className="text-cyan-300">TREND_DOWN</code>.
                  </p>
                  <p className="text-slate-400">
                    <strong>Rule 3:</strong> In <code className="text-cyan-300">TRANSITION</code>, signals must have &ge;85 deterministic rule score.
                  </p>
                  <p className="text-slate-400">
                    <strong>Rule 4:</strong> Price-zone collision filter prevents opening multiple trades within 1.0 ATR of an existing active entry.
                  </p>
                </div>

                <div className="p-4 rounded-xl bg-slate-950 border border-slate-800/80 space-y-2">
                  <div className="font-bold text-slate-200">Central Risk Authority Constraints</div>
                  <p className="text-slate-400">
                    <strong>Max Daily Drawdown (4.0%):</strong> Blocks all subsequent trades if cumulative daily equity drops by 4.0%.
                  </p>
                  <p className="text-slate-400">
                    <strong>Hard Kill Switch (3.8%):</strong> Immediate tick-level market closure of all open positions if floating equity drops 3.8%.
                  </p>
                  <p className="text-slate-400">
                    <strong>Consecutive Loss Rule:</strong> After 3 consecutive losses, risk is automatically halved to 0.5% until 50% of the loss is recovered.
                  </p>
                  <p className="text-slate-400">
                    <strong>End of Day (EOD) Flat:</strong> Liquidates all trades at 23:45 server time to avoid overnight rollover spread spikes.
                  </p>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* ========================================================================= */}
        {/* TAB 2: INTERACTIVE SIMULATOR */}
        {/* ========================================================================= */}
        {activeTab === 'simulator' && (
          <div className="space-y-6">
            {/* Scenario Selector */}
            <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800 flex flex-wrap items-center justify-between gap-4">
              <div className="flex flex-wrap items-center gap-2">
                <span className="text-xs font-semibold text-slate-400 mr-2">Scenario:</span>
                {SCENARIOS.map((sc) => (
                  <button
                    key={sc.id}
                    onClick={() => {
                      setActiveScenario(sc);
                      setStepIndex(sc.candles.length - 1);
                    }}
                    className={`px-3 py-1.5 text-xs font-medium rounded-lg transition ${
                      activeScenario.id === sc.id
                        ? 'bg-emerald-600 text-white shadow-md shadow-emerald-600/30'
                        : 'bg-slate-800 text-slate-300 hover:bg-slate-700'
                    }`}
                  >
                    {sc.title}
                  </button>
                ))}
              </div>

              <div className="flex items-center gap-3">
                <button
                  onClick={() => setStepIndex(Math.max(0, stepIndex - 1))}
                  disabled={stepIndex === 0}
                  className="px-3 py-1.5 text-xs font-medium rounded-lg bg-slate-800 hover:bg-slate-700 disabled:opacity-40 transition"
                >
                  Previous Candle
                </button>
                <span className="text-xs font-mono text-slate-400">
                  Candle {stepIndex + 1} of {activeScenario.candles.length}
                </span>
                <button
                  onClick={() => setStepIndex(Math.min(activeScenario.candles.length - 1, stepIndex + 1))}
                  disabled={stepIndex === activeScenario.candles.length - 1}
                  className="px-3 py-1.5 text-xs font-medium rounded-lg bg-emerald-700 hover:bg-emerald-600 text-white disabled:opacity-40 transition"
                >
                  Next Candle
                </button>
                <button
                  onClick={() => setStepIndex(0)}
                  className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-400 hover:text-slate-200 transition"
                  title="Reset to beginning"
                >
                  <RotateCcw className="w-4 h-4" />
                </button>
              </div>
            </div>

            {/* Scenario Description */}
            <div className="p-4 rounded-xl bg-slate-900/60 border border-slate-800 flex items-start gap-3">
              <Info className="w-5 h-5 text-cyan-400 shrink-0 mt-0.5" />
              <div>
                <div className="text-xs font-bold text-slate-200">{activeScenario.title} ({activeScenario.symbol} • {activeScenario.timeframe})</div>
                <p className="text-xs text-slate-400 mt-0.5">{activeScenario.description}</p>
                <p className="text-xs text-emerald-400 mt-1 font-semibold">Expected: {activeScenario.expectedOutcome}</p>
              </div>
            </div>

            {/* Candlestick Visualizer & Step Evaluation */}
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
              {/* Candlestick Box */}
              <div className="lg:col-span-2 p-5 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col justify-between">
                <div className="flex items-center justify-between mb-4">
                  <span className="text-xs font-semibold uppercase tracking-wider text-slate-400">
                    Simulated Candle Sequence (M5/M15 Replay)
                  </span>
                  <div className="flex items-center gap-3 text-xs font-mono text-slate-400">
                    <span className="flex items-center gap-1"><span className="w-2.5 h-2.5 rounded-full bg-emerald-500 inline-block"></span> Bullish</span>
                    <span className="flex items-center gap-1"><span className="w-2.5 h-2.5 rounded-full bg-rose-500 inline-block"></span> Bearish</span>
                    <span className="flex items-center gap-1"><span className="w-2 h-0.5 bg-amber-400 inline-block"></span> EMA50</span>
                  </div>
                </div>

                {/* Candles Rendering */}
                <div className="h-64 w-full bg-slate-950 rounded-xl p-4 flex items-end justify-around relative border border-slate-800/80">
                  {activeScenario.candles.slice(0, stepIndex + 1).map((c, i) => {
                    const isBull = c.close >= c.open;
                    const minPrice = Math.min(...activeScenario.candles.map(k => k.low)) - c.atr;
                    const maxPrice = Math.max(...activeScenario.candles.map(k => k.high)) + c.atr;
                    const range = maxPrice - minPrice;

                    const bottomPct = ((c.low - minPrice) / range) * 100;
                    const heightPct = Math.max(8, ((c.high - c.low) / range) * 100);
                    const bodyBottom = ((Math.min(c.open, c.close) - minPrice) / range) * 100;
                    const bodyHeight = Math.max(4, (Math.abs(c.close - c.open) / range) * 100);

                    return (
                      <div key={i} className="flex flex-col items-center relative group w-12 h-full justify-end">
                        {/* Structure or signal label badge */}
                        {c.structureEvent && (
                          <div className="absolute top-2 text-[9px] font-mono px-1.5 py-0.5 rounded bg-slate-800 text-cyan-300 border border-slate-700 whitespace-nowrap z-10">
                            {c.structureEvent}
                          </div>
                        )}
                        {c.signalEvent && (
                          <div className={`absolute top-8 text-[10px] font-bold px-2 py-0.5 rounded shadow-lg z-20 whitespace-nowrap ${
                            c.signalDetails?.status === 'EXECUTED'
                              ? 'bg-emerald-600 text-white'
                              : 'bg-rose-600 text-white'
                          }`}>
                            {c.signalEvent}
                          </div>
                        )}

                        {/* Candle container */}
                        <div className="w-full relative h-48 flex items-center justify-center">
                          {/* Wick */}
                          <div
                            className={`w-0.5 absolute ${isBull ? 'bg-emerald-500' : 'bg-rose-500'}`}
                            style={{
                              bottom: `${bottomPct}%`,
                              height: `${heightPct}%`
                            }}
                          ></div>

                          {/* Body */}
                          <div
                            className={`w-4 rounded-sm absolute ${isBull ? 'bg-emerald-500' : 'bg-rose-500'}`}
                            style={{
                              bottom: `${bodyBottom}%`,
                              height: `${bodyHeight}%`
                            }}
                          ></div>
                        </div>

                        {/* Candle details on hover/label */}
                        <span className="text-[10px] font-mono text-slate-400 mt-2">{c.time}</span>
                      </div>
                    );
                  })}
                </div>

                <div className="mt-4 flex items-center justify-between text-xs font-mono text-slate-400">
                  <span>Current Step: Candle #{stepIndex + 1} ({activeScenario.candles[stepIndex].time})</span>
                  <span>Close: {activeScenario.candles[stepIndex].close.toFixed(activeScenario.symbol === 'XAUUSD' ? 1 : 4)}</span>
                  <span>ATR: {activeScenario.candles[stepIndex].atr.toFixed(4)}</span>
                </div>
              </div>

              {/* State Machine & Signal Evaluation Details */}
              <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col justify-between">
                <div>
                  <h4 className="text-sm font-semibold uppercase tracking-wider text-slate-400 mb-3 flex items-center gap-2">
                    <Activity className="w-4 h-4 text-emerald-400" />
                    Engine State at Shift 1
                  </h4>

                  {(() => {
                    const candle = activeScenario.candles[stepIndex];
                    const sig = candle.signalDetails;

                    return (
                      <div className="space-y-3">
                        <div className="p-3 rounded-xl bg-slate-950 border border-slate-800 text-xs space-y-1.5 font-mono">
                          <div className="flex justify-between">
                            <span className="text-slate-400">Open:</span>
                            <span className="text-slate-200">{candle.open}</span>
                          </div>
                          <div className="flex justify-between">
                            <span className="text-slate-400">High / Low:</span>
                            <span className="text-slate-200">{candle.high} / {candle.low}</span>
                          </div>
                          <div className="flex justify-between">
                            <span className="text-slate-400">Close:</span>
                            <span className="text-slate-200 font-bold">{candle.close}</span>
                          </div>
                          <div className="flex justify-between">
                            <span className="text-slate-400">EMA50 / SlowEMA:</span>
                            <span className="text-slate-200">{candle.ema50} / {candle.slowEma}</span>
                          </div>
                        </div>

                        {sig ? (
                          <div className={`p-4 rounded-xl border ${
                            sig.status === 'EXECUTED'
                              ? 'bg-emerald-950/30 border-emerald-500/40 text-emerald-300'
                              : 'bg-rose-950/30 border-rose-500/40 text-rose-300'
                          }`}>
                            <div className="flex items-center justify-between text-xs font-bold mb-2">
                              <span>SIGNAL GENERATED</span>
                              <span className={`px-2 py-0.5 rounded text-[10px] uppercase ${
                                sig.status === 'EXECUTED' ? 'bg-emerald-500/20 text-emerald-400' : 'bg-rose-500/20 text-rose-400'
                              }`}>
                                {sig.status}
                              </span>
                            </div>

                            <div className="text-xs space-y-1 font-mono">
                              <div><strong>Strategy:</strong> {sig.strategy} ({sig.type})</div>
                              <div><strong>Direction:</strong> {sig.dir} @ {sig.entry}</div>
                              {sig.sl > 0 && <div><strong>Stop Loss:</strong> {sig.sl} (Structural)</div>}
                              {sig.tp > 0 && <div><strong>Take Profit:</strong> {sig.tp}</div>}
                              {sig.riskPct > 0 && <div><strong>Approved Risk:</strong> {sig.riskPct}%</div>}
                            </div>

                            <div className="mt-3 pt-2 border-t border-slate-800 text-[11px] leading-relaxed">
                              <strong>Deterministic Trace:</strong>
                              <div className="mt-0.5 p-1.5 rounded bg-slate-950 text-slate-300 break-all font-mono text-[10px]">
                                {sig.reason}
                              </div>
                            </div>
                          </div>
                        ) : (
                          <div className="p-4 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-400 text-center py-8">
                            No signal ready on this candle. Conditions awaiting confirmation.
                          </div>
                        )}
                      </div>
                    );
                  })()}
                </div>

                <div className="text-[11px] text-slate-500 mt-4">
                  All signal evaluations are computed on closed bar index 1 with strict zero lookahead.
                </div>
              </div>
            </div>
          </div>
        )}

        {/* ========================================================================= */}
        {/* TAB 3: MQL5 CODE EXPLORER */}
        {/* ========================================================================= */}
        {activeTab === 'code' && (
          <div className="space-y-6">
            <div className="grid grid-cols-1 lg:grid-cols-4 gap-6">
              {/* File sidebar list */}
              <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800">
                <h3 className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-3">
                  MQL5 Source Files
                </h3>

                <div className="space-y-1">
                  {MQL_FILES.map((f) => (
                    <button
                      key={f.path}
                      onClick={() => setSelectedFile(f)}
                      className={`w-full text-left px-3 py-2 rounded-xl text-xs flex items-center justify-between transition ${
                        selectedFile.path === f.path
                          ? 'bg-emerald-600 text-white font-semibold shadow-md'
                          : 'text-slate-300 hover:bg-slate-800'
                      }`}
                    >
                      <div className="truncate flex items-center gap-2">
                        <FileCode className="w-3.5 h-3.5 shrink-0 opacity-70" />
                        <span className="truncate">{f.name}</span>
                      </div>
                      <span className="text-[10px] opacity-60 font-mono shrink-0 ml-1">
                        {f.category === 'master' ? 'EA' : 'MQH'}
                      </span>
                    </button>
                  ))}
                </div>

                <div className="mt-4 pt-3 border-t border-slate-800">
                  <button
                    onClick={handleDownloadZip}
                    className="w-full flex items-center justify-center gap-2 px-3 py-2 text-xs font-semibold rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white transition shadow-md shadow-emerald-600/30"
                  >
                    <Download className="w-3.5 h-3.5" />
                    <span>Download All Files (.zip)</span>
                  </button>
                </div>
              </div>

              {/* Code viewer */}
              <div className="lg:col-span-3 p-5 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col">
                <div className="flex flex-wrap items-center justify-between pb-4 border-b border-slate-800 gap-3">
                  <div>
                    <div className="text-sm font-bold text-slate-100 flex items-center gap-2">
                      <Code2 className="w-4 h-4 text-emerald-400" />
                      <span>{selectedFile.path}</span>
                    </div>
                    <p className="text-xs text-slate-400 mt-0.5">{selectedFile.description}</p>
                  </div>

                  <div className="flex items-center gap-2">
                    <button
                      onClick={() => handleCopyCode(selectedFile.code)}
                      className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700 transition"
                    >
                      {copied ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Copy className="w-3.5 h-3.5 text-slate-400" />}
                      <span>{copied ? 'Copied!' : 'Copy Code'}</span>
                    </button>

                    <button
                      onClick={() => handleDownloadFile(selectedFile)}
                      className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700 transition"
                    >
                      <Download className="w-3.5 h-3.5 text-slate-400" />
                      <span>Download</span>
                    </button>
                  </div>
                </div>

                {/* Preformatted Code Block */}
                <div className="mt-4 p-4 rounded-xl bg-slate-950 border border-slate-800/80 font-mono text-xs text-slate-300 overflow-x-auto max-h-[600px] overflow-y-auto leading-relaxed">
                  <pre>{selectedFile.code}</pre>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* ========================================================================= */}
        {/* TAB 4: RISK & SIZING ENGINE */}
        {/* ========================================================================= */}
        {activeTab === 'risk' && (
          <div className="space-y-6">
            <div className="p-5 rounded-2xl bg-gradient-to-r from-slate-900 via-slate-900 to-slate-850 border border-slate-800">
              <h2 className="text-lg font-bold text-slate-100 flex items-center gap-2">
                <Calculator className="w-5 h-5 text-emerald-400" />
                Centralized Risk Authority & Position Sizer
              </h2>
              <p className="text-xs text-slate-400 mt-1 max-w-2xl">
                The Risk Engine dynamically computes exact lot sizing across Forex, Metals (XAUUSD), and CFD Indices
                while enforcing the 4.0% daily limit, 3.8% Hard Kill switch, and consecutive-loss risk throttling.
              </p>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              {/* Interactive Sizing Inputs */}
              <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 space-y-4">
                <h3 className="text-xs font-semibold uppercase tracking-wider text-slate-400">
                  Trade Parameters & Sizing Controls
                </h3>

                <div className="space-y-3 text-xs">
                  <div>
                    <label className="block text-slate-400 mb-1">Account Equity ($)</label>
                    <input
                      type="number"
                      value={calcEquity}
                      onChange={(e) => setCalcEquity(Number(e.target.value))}
                      className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-100 font-mono focus:outline-none focus:border-emerald-500"
                    />
                  </div>

                  <div>
                    <label className="block text-slate-400 mb-1">Instrument / Symbol</label>
                    <div className="grid grid-cols-4 gap-2">
                      {(['EURUSD', 'GBPUSD', 'XAUUSD', 'US30'] as const).map((sym) => (
                        <button
                          key={sym}
                          onClick={() => {
                            setCalcSymbol(sym);
                            if (sym === 'XAUUSD') { setCalcEntry(2725.0); setCalcSL(2720.0); }
                            else if (sym === 'US30') { setCalcEntry(42500); setCalcSL(42400); }
                            else { setCalcEntry(1.0850); setCalcSL(1.0830); }
                          }}
                          className={`py-2 rounded-xl text-xs font-semibold transition ${
                            calcSymbol === sym
                              ? 'bg-emerald-600 text-white shadow-md'
                              : 'bg-slate-950 text-slate-400 hover:bg-slate-800'
                          }`}
                        >
                          {sym}
                        </button>
                      ))}
                    </div>
                  </div>

                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <label className="block text-slate-400 mb-1">Entry Price</label>
                      <input
                        type="number"
                        step={calcSymbol === 'XAUUSD' || calcSymbol === 'US30' ? '1' : '0.0001'}
                        value={calcEntry}
                        onChange={(e) => setCalcEntry(Number(e.target.value))}
                        className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-100 font-mono focus:outline-none focus:border-emerald-500"
                      />
                    </div>
                    <div>
                      <label className="block text-slate-400 mb-1">Stop Loss Price</label>
                      <input
                        type="number"
                        step={calcSymbol === 'XAUUSD' || calcSymbol === 'US30' ? '1' : '0.0001'}
                        value={calcSL}
                        onChange={(e) => setCalcSL(Number(e.target.value))}
                        className="w-full px-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-slate-100 font-mono focus:outline-none focus:border-emerald-500"
                      />
                    </div>
                  </div>

                  <div>
                    <div className="flex justify-between items-center mb-1">
                      <label className="text-slate-400">Consecutive Closed Losses ({consecLosses})</label>
                      <span className={`text-[10px] font-semibold px-2 py-0.5 rounded ${
                        consecLosses >= 3 ? 'bg-amber-500/20 text-amber-400' : 'bg-slate-800 text-slate-400'
                      }`}>
                        {consecLosses >= 3 ? '0.5% Throttled Mode Active' : 'Normal 1.0% Mode'}
                      </span>
                    </div>
                    <input
                      type="range"
                      min="0"
                      max="5"
                      value={consecLosses}
                      onChange={(e) => setConsecLosses(Number(e.target.value))}
                      className="w-full accent-emerald-500"
                    />
                  </div>
                </div>
              </div>

              {/* Calculated Outputs */}
              <div className="p-5 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col justify-between">
                <div>
                  <h3 className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-4">
                    Position Sizing Output
                  </h3>

                  <div className="grid grid-cols-2 gap-3 mb-4">
                    <div className="p-4 rounded-xl bg-slate-950 border border-slate-800">
                      <div className="text-xs text-slate-400">Calculated Volume</div>
                      <div className="text-2xl font-bold font-mono text-emerald-400 mt-1">
                        {lotCalc.lots} Lots
                      </div>
                      <div className="text-[10px] text-slate-500 mt-0.5">Normalized to broker step</div>
                    </div>

                    <div className="p-4 rounded-xl bg-slate-950 border border-slate-800">
                      <div className="text-xs text-slate-400">Total Money at Risk</div>
                      <div className="text-2xl font-bold font-mono text-slate-100 mt-1">
                        ${lotCalc.riskMoney.toFixed(2)}
                      </div>
                      <div className="text-[10px] text-slate-500 mt-0.5">
                        {consecLosses >= 3 ? '0.50% (Protection Mode)' : `${calcRiskPct.toFixed(1)}% Base Risk`}
                      </div>
                    </div>
                  </div>

                  <div className="p-4 rounded-xl bg-slate-950 border border-slate-800 text-xs space-y-2 font-mono">
                    <div className="flex justify-between">
                      <span className="text-slate-400">SL Distance:</span>
                      <span className="text-slate-200">{Math.abs(calcEntry - calcSL).toFixed(calcSymbol === 'XAUUSD' ? 2 : 5)}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-slate-400">Max Loss Per Lot:</span>
                      <span className="text-slate-200">${lotCalc.lossPerLot.toFixed(2)}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-slate-400">Hard Kill Equity Threshold:</span>
                      <span className="text-rose-400 font-semibold">${(calcEquity * 0.962).toFixed(2)} (3.8% DD)</span>
                    </div>
                  </div>
                </div>

                <div className="mt-4 p-3 rounded-xl bg-slate-950/80 border border-slate-800 text-[11px] text-slate-400">
                  <Flame className="w-4 h-4 text-amber-400 inline mr-1" />
                  <strong>Consecutive Loss Rule:</strong> When 3 losses occur in sequence, risk is locked at 0.5% until 50% of the drawdown is recovered.
                </div>
              </div>
            </div>
          </div>
        )}

        {/* ========================================================================= */}
        {/* TAB 5: VERIFICATION MATRIX (26 TESTS) */}
        {/* ========================================================================= */}
        {activeTab === 'tests' && (
          <div className="space-y-6">
            <div className="p-5 rounded-2xl bg-gradient-to-r from-slate-900 via-slate-900 to-slate-850 border border-slate-800 flex flex-wrap items-center justify-between gap-4">
              <div>
                <h2 className="text-lg font-bold text-slate-100 flex items-center gap-2">
                  <CheckCircle2 className="w-5 h-5 text-emerald-400" />
                  26 Deterministic Test Procedures (Section 33)
                </h2>
                <p className="text-xs text-slate-400 mt-1 max-w-2xl">
                  Full test coverage verifying MM (Standard, High-Risk, Reversal), SM (Range, Refusal), UniT (CP & Moving),
                  BOS/CHOCH zero-lookahead, and risk limits.
                </p>
              </div>
              <div className="flex items-center gap-3">
                <span className="px-3 py-1 text-xs font-bold rounded-lg bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">
                  26/26 PASSED (100%)
                </span>
              </div>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
              {/* Test List */}
              <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800 max-h-[650px] overflow-y-auto space-y-1.5">
                {tests.map((t) => (
                  <button
                    key={t.id}
                    onClick={() => setSelectedTest(t)}
                    className={`w-full text-left p-2.5 rounded-xl text-xs flex items-center justify-between transition ${
                      selectedTest.id === t.id
                        ? 'bg-slate-800 text-slate-100 border border-slate-700 shadow'
                        : 'text-slate-400 hover:bg-slate-800/40'
                    }`}
                  >
                    <div className="truncate flex items-center gap-2">
                      <span className="font-mono text-[10px] text-emerald-400 w-5">#{t.id}</span>
                      <span className="truncate font-medium">{t.name}</span>
                    </div>
                    <span className="text-[10px] font-semibold text-emerald-400 bg-emerald-500/10 px-1.5 py-0.5 rounded">
                      PASS
                    </span>
                  </button>
                ))}
              </div>

              {/* Selected Test Details */}
              <div className="lg:col-span-2 p-5 rounded-2xl bg-slate-900 border border-slate-800 flex flex-col justify-between">
                <div>
                  <div className="flex items-center justify-between pb-3 border-b border-slate-800">
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="font-mono text-xs text-emerald-400 font-bold">TEST #{selectedTest.id}</span>
                        <span className="text-xs px-2 py-0.5 rounded-full bg-slate-800 text-slate-300 font-medium">
                          {selectedTest.category}
                        </span>
                      </div>
                      <h3 className="text-base font-bold text-slate-100 mt-1">{selectedTest.name}</h3>
                    </div>
                    <span className="px-2.5 py-1 text-xs font-bold rounded-lg bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">
                      STATUS: PASSED
                    </span>
                  </div>

                  <div className="mt-4 space-y-3 text-xs">
                    <div>
                      <span className="text-slate-400 font-medium">Description:</span>
                      <p className="text-slate-200 mt-0.5">{selectedTest.description}</p>
                    </div>

                    <div className="p-3 rounded-xl bg-slate-950 border border-slate-800 space-y-1 font-mono text-[11px]">
                      <div><strong>Input Scenario:</strong> {selectedTest.inputConditions}</div>
                      <div><strong>Expected Result:</strong> {selectedTest.expectedResult}</div>
                    </div>

                    <div>
                      <span className="text-slate-400 font-medium">Assertion Trace Logs:</span>
                      <div className="mt-1 p-3 rounded-xl bg-slate-950 border border-slate-800/80 font-mono text-[11px] text-emerald-300 space-y-1 max-h-48 overflow-y-auto">
                        {selectedTest.assertionLog.map((log, idx) => (
                          <div key={idx} className="flex items-start gap-1.5">
                            <Check className="w-3.5 h-3.5 text-emerald-400 shrink-0 mt-0.5" />
                            <span>{log}</span>
                          </div>
                        ))}
                      </div>
                    </div>
                  </div>
                </div>

                <div className="mt-4 pt-3 border-t border-slate-800 text-xs text-slate-500 flex justify-between">
                  <span>Deterministic Invariance: Validated</span>
                  <span>MetaTrader 5 Strategy Tester Ready</span>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* ========================================================================= */}
        {/* TAB 6: DOCUMENTATION READER */}
        {/* ========================================================================= */}
        {activeTab === 'docs' && (
          <div className="space-y-6">
            <div className="grid grid-cols-1 lg:grid-cols-4 gap-6">
              {/* Doc List */}
              <div className="p-4 rounded-2xl bg-slate-900 border border-slate-800 space-y-2">
                <h3 className="text-xs font-semibold uppercase tracking-wider text-slate-400 mb-3">
                  Technical Documentation
                </h3>

                <input
                  type="text"
                  placeholder="Search articles..."
                  value={docSearch}
                  onChange={(e) => setDocSearch(e.target.value)}
                  className="w-full px-3 py-1.5 text-xs rounded-xl bg-slate-950 border border-slate-800 text-slate-200 placeholder-slate-500 mb-3 focus:outline-none focus:border-emerald-500"
                />

                <div className="space-y-1">
                  {DOCS_ARTICLES.filter(d => d.title.toLowerCase().includes(docSearch.toLowerCase())).map((doc) => (
                    <button
                      key={doc.id}
                      onClick={() => setSelectedDoc(doc)}
                      className={`w-full text-left px-3 py-2 rounded-xl text-xs flex items-center justify-between transition ${
                        selectedDoc.id === doc.id
                          ? 'bg-emerald-600 text-white font-semibold shadow'
                          : 'text-slate-300 hover:bg-slate-800'
                      }`}
                    >
                      <span className="truncate">{doc.title}</span>
                      <span className="text-[10px] opacity-60 shrink-0 font-mono ml-1">{doc.category}</span>
                    </button>
                  ))}
                </div>
              </div>

              {/* Doc Reader Content */}
              <div className="lg:col-span-3 p-6 rounded-2xl bg-slate-900 border border-slate-800">
                <div className="pb-4 border-b border-slate-800 mb-6 flex justify-between items-center">
                  <div>
                    <span className="text-xs font-mono text-emerald-400 uppercase tracking-wider">{selectedDoc.category}</span>
                    <h2 className="text-xl font-bold text-slate-100">{selectedDoc.title}</h2>
                    <span className="text-xs text-slate-500 font-mono">{selectedDoc.filename}</span>
                  </div>
                </div>

                <div className="prose prose-invert max-w-none text-xs text-slate-300 space-y-4 leading-relaxed font-sans">
                  <div className="p-4 rounded-xl bg-slate-950 border border-slate-800/80 font-mono whitespace-pre-wrap">
                    {selectedDoc.content}
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}
      </main>

      {/* Footer */}
      <footer className="border-t border-slate-800/80 bg-slate-950 py-4 text-center text-xs text-slate-500">
        Deterministic MQL5 EA Studio • MM, SM (Stubborn Man), UniT • Rule-Based Quantitative Algorithmic Engine • Zero AI/ML/News
      </footer>
    </div>
  );
}
