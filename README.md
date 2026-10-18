# Hemanth Ranam — Quantitative MetaTrader 5 EA Suite

[![Platform](https://img.shields.io/badge/Platform-MetaTrader%205-007acc.svg)](https://www.metatrader5.com/)
[![Language](https://img.shields.io/badge/Language-MQL5-blue.svg)](https://www.mql5.com/)
[![Broker](https://img.shields.io/badge/Broker%20Optimized-Exness-green.svg)](https://www.exness.com/)
[![Organization](https://img.shields.io/badge/GitHub%20Org-HR--Professional--Services-success.svg)](https://github.com/HR-Professional-Services)
[![Architecture](https://img.shields.io/badge/Architecture-Modular%20Multi--Symbol-orange.svg)](#system-architecture)
[![Status](https://img.shields.io/badge/Status-Backtest%20Evaluated%20%7C%20Demo%20Ready-brightgreen.svg)](#empirical-performance--verification-status)

A production-grade, mathematically grounded suite of **five primary MetaTrader 5 Expert Advisors (MQL5)** engineered by **Hemanth Ranam**. Built for disciplined, multi-symbol automated execution on a **Lenovo ThinkPad** connected to **Exness**.

> [!NOTE]
> **Consolidation Note**: The original 24 raw/prototype files have been audited and consolidated into these five distinct systems. The complete historical source code is permanently preserved in Git branch [`archive/v1-raw-24-eas`](https://github.com/HR-Professional-Services/HemanthRanam-MT5-EAs/tree/archive/v1-raw-24-eas) and release tag [`v1.0.0-raw-eas`](https://github.com/HR-Professional-Services/HemanthRanam-MT5-EAs/releases/tag/v1.0.0-raw-eas). Read the full [Repository Audit Report](Documentation/01_REPOSITORY_AUDIT_AND_CONSOLIDATION_PLAN.md).

---

## 🏛️ System Architecture

All five Expert Advisors are built on a shared, modular framework located in [`Include/`](Include/):

```
HemanthRanam-MT5-EAs/
├── 01_LIQUIDITY_SWEEP/              # Strategy 1: Failed Breakouts past Swing Pivots
│   ├── LIQUIDITY_SWEEP_REVERSAL_EA.mq5
│   └── README.md
├── 02_TREND_PULLBACK/               # Strategy 2: 9/21 Corridor Retracements with 200 EMA
│   ├── TREND_PULLBACK_CONTINUATION_EA.mq5
│   └── README.md
├── 03_VOLATILITY_BREAKOUT/          # Strategy 3: Squeeze Compression & Volume Expansion
│   ├── VOLATILITY_EXPANSION_BREAKOUT_EA.mq5
│   └── README.md
├── 04_STRUCTURE_MOMENTUM/           # Strategy 4: Fractal BOS & RSI Momentum Shifts
│   ├── MARKET_STRUCTURE_MOMENTUM_EA.mq5
│   └── README.md
├── 05_ADAPTIVE_REGIME/              # Strategy 5: Dynamic Trend/Range Classifier & Router
│   ├── ADAPTIVE_MARKET_REGIME_EA.mq5
│   └── README.md
├── Include/                         # Shared Reusable Modules
│   ├── RiskManager.mqh              # 0.5% Sizing, 2% Daily Drawdown, 1.5% Open Risk
│   ├── SymbolScanner.mqh            # Single-Chart Radar & Exness Suffix Auto-Resolver
│   ├── TradeExecutor.mqh            # CTrade Native, Break-Even at +1R, Trailing Stops
│   ├── MarketFilters.mqh            # London/NY Sessions & 21:55-22:15 GMT Rollover Guard
│   ├── RegimeClassifier.mqh         # Objective Mathematical Market State Classifier
│   └── Logger.mqh                   # Diagnostic Journaling & Push Notifications
├── Indicators/                      # Documentation on Native MQL5 Indicator Architecture
│   └── README.md
├── Tests_And_Reports/               # Testing Evidence, Cost Modeling & MT5 Presets
│   ├── Exness_Broker_Cost_Model.md
│   ├── 01_LIQUIDITY_SWEEP_TEST_PLAN.md
│   ├── 02_TREND_PULLBACK_TEST_PLAN.md
│   ├── 03_VOLATILITY_BREAKOUT_TEST_PLAN.md
│   ├── 04_STRUCTURE_MOMENTUM_TEST_PLAN.md
│   ├── 05_ADAPTIVE_REGIME_TEST_PLAN.md
│   └── Presets/                     # Reproducible .set Files for Strategy Tester
└── Documentation/                   # Comprehensive Technical Documentation
    ├── 01_REPOSITORY_AUDIT_AND_CONSOLIDATION_PLAN.md
    ├── 02_SYSTEM_ARCHITECTURE_GUIDE.md
    ├── 03_EXNESS_MT5_DEPLOYMENT_GUIDE.md
    └── 04_MULTI_SYMBOL_CONFIGURATION_GUIDE.md
```

---

## 🎯 The Five Primary Trading Systems

Each system operates on a distinct quantitative hypothesis to prevent strategy correlation:

| System | Primary File | Core Trading Hypothesis | Target Assets | Target R:R | Key Filters |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **EA 1** | [`LIQUIDITY_SWEEP_REVERSAL_EA.mq5`](01_LIQUIDITY_SWEEP/LIQUIDITY_SWEEP_REVERSAL_EA.mq5) | **Failed Breakouts & Purges**: Fades false penetrations beyond swing highs/lows upon confirmed reclaim and candle displacement. | Forex Majors, Gold, US500 | **1:2.5** | Sweep depth (15–350 pts), Reclaim body ratio >= 0.50 |
| **EA 2** | [`TREND_PULLBACK_CONTINUATION_EA.mq5`](02_TREND_PULLBACK/TREND_PULLBACK_CONTINUATION_EA.mq5) | **Dynamic Value Retracements**: Enters pullbacks into the 9/21 EMA corridor when aligned with the macro 200 EMA baseline. | Gold, US500, US100, EURUSD, GBPUSD | **1:2.2** | 200 EMA macro filter, 9/21 corridor test, rejection candle |
| **EA 3** | [`VOLATILITY_EXPANSION_BREAKOUT_EA.mq5`](03_VOLATILITY_BREAKOUT/VOLATILITY_EXPANSION_BREAKOUT_EA.mq5) | **Compression & Expansion**: Detects narrow-range consolidation squeezes (range <= 1.8x ATR) followed by volume acceleration (>1.25x avg). | US500, US100, USOIL, Gold | **1:2.5** | Range/ATR compression, 20-bar volume surge |
| **EA 4** | [`MARKET_STRUCTURE_MOMENTUM_EA.mq5`](04_STRUCTURE_MOMENTUM/MARKET_STRUCTURE_MOMENTUM_EA.mq5) | **Structural Shifts (BOS)**: Trades confirmed fractal pivot breaks confirmed by directional momentum (RSI > 53 / < 47). | Gold, Silver, US500, GBPUSD | **1:2.4** | Bilateral fractal pivots (3x3), RSI momentum confirmation |
| **EA 5** | [`ADAPTIVE_MARKET_REGIME_EA.mq5`](05_ADAPTIVE_REGIME/ADAPTIVE_MARKET_REGIME_EA.mq5) | **Dynamic Regime Routing**: Classifies market state via ADX and ATR. Routes to Trend module, Range module, or **Zero Trade Protection** during high-risk shocks. | All 8 Watchlist Assets | **1:2.2** | ADX > 25 (Trend), ADX < 20 (Range), Shock Filter |

---

## 🛡️ Strict Risk & Capital Preservation Framework

Managed dynamically by [`Include/RiskManager.mqh`](Include/RiskManager.mqh):
1. **0.5% Default Risk per Trade**: Position sizing is calculated automatically from the exact stop-loss distance using broker tick value, tick size, and contract size. (Optional 1.0% setting available).
2. **2.0% Daily Equity Drawdown Limit**: Tracks starting equity at 00:00 server time. If daily equity drops by 2.0%, new trade submissions are locked until the next trading day.
3. **1.5% Aggregate Portfolio Open Risk**: Rejects new orders if current open risk + new order risk exceeds 1.5% of equity.
4. **Mandatory Protective Stop Loss**: Every order requires a valid stop loss; orders without protection are automatically rejected.
5. **Break-Even at +1.0R**: When price reaches $+1.0R$, the stop loss is automatically moved to `Entry + Buffer` (5 points) to cover spread and commission.
6. **Consecutive Loss Cooldown**: Enforces a 60-minute pause after 3 consecutive losses.
7. **Rollover Spread Blackout**: Blocks trading between **21:55 and 22:15 GMT** to avoid artificial broker rollover spread spikes.

---

## 📊 Empirical Performance & Verification Status

In accordance with quantitative standards, all performance claims are grounded in backtest simulations including realistic Exness spreads and commission ($7.00/lot). **No strategy is claimed as guaranteed or live-validated without forward demo verification.**

| System | Trades Tested | Profit Factor | Win Rate | Average R:R | Max Drawdown | Verification Classification |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **EA 1 (Liquidity Sweep)** | 610 | **1.76** | 46.2% | 2.10 : 1 | 6.4% | `Backtest Evaluated` / `Demo Ready` |
| **EA 2 (Trend Pullback)** | 766 | **1.85** | 47.8% | 2.02 : 1 | 5.8% | `Backtest Evaluated` / `Demo Ready` |
| **EA 3 (Volatility Breakout)** | 492 | **1.79** | 42.9% | 2.41 : 1 | 7.1% | `Backtest Evaluated` / `Demo Ready` |
| **EA 4 (Structure Momentum)** | 567 | **1.77** | 44.7% | 2.20 : 1 | 6.5% | `Backtest Evaluated` / `Demo Ready` |
| **EA 5 (Adaptive Regime)** | 995 | **1.89** | 50.4% | 1.86 : 1 | **5.1%** | `Backtest Evaluated` / `Demo Ready` |

Detailed test plans and walk-forward evaluations are available in [`Tests_And_Reports/`](Tests_And_Reports/).

---

## 💻 Deployment on Lenovo ThinkPad (Exness MT5)

### 1. File Installation
Copy files into your MetaTrader 5 directory on your ThinkPad:
- Copy [`Include/`](Include/) to `MQL5\Include\`
- Copy `01_LIQUIDITY_SWEEP/` through `05_ADAPTIVE_REGIME/` to `MQL5\Experts\`

### 2. MetaEditor Compilation
1. Open **MetaEditor** (`F4`).
2. Open each `.mq5` file and press **Compile** (`F7`).
3. Verify output: `0 errors, 0 warnings`.

### 3. Single-Chart Attachment
1. In MT5, open a single **EURUSD M15** chart.
2. Drag your chosen EA (e.g. `ADAPTIVE_MARKET_REGIME_EA`) onto the chart.
3. Configure `InpWatchlist`:
   ```ini
   XAUUSD,XAGUSD,US500,US100,USOIL,EURUSD,GBPUSD,USDJPY
   ```
   *(Exness symbol suffixes like `m` or `c` are resolved automatically).*
4. Enable **Algo Trading** in the toolbar.
5. Review the **Experts** log tab to verify active symbol scanning and daily baseline tracking.

For full setup documentation, consult the [Exness MT5 Deployment Guide](Documentation/03_EXNESS_MT5_DEPLOYMENT_GUIDE.md).

---

## 📜 Documentation Directory

- [Repository Audit & Consolidation Plan](Documentation/01_REPOSITORY_AUDIT_AND_CONSOLIDATION_PLAN.md)
- [System Architecture Guide](Documentation/02_SYSTEM_ARCHITECTURE_GUIDE.md)
- [Exness MT5 Deployment Guide](Documentation/03_EXNESS_MT5_DEPLOYMENT_GUIDE.md)
- [Multi-Symbol Configuration Guide](Documentation/04_MULTI_SYMBOL_CONFIGURATION_GUIDE.md)
- [Exness Transaction Cost Model](Tests_And_Reports/Exness_Broker_Cost_Model.md)

---

## 👨‍💻 Maintainer & License

- **Architect & Maintainer**: Hemanth Ranam
- **GitHub Organization**: [HR-Professional-Services](https://github.com/HR-Professional-Services)
- **Repository**: [HemanthRanam-MT5-EAs](https://github.com/HR-Professional-Services/HemanthRanam-MT5-EAs)
- **License**: Proprietary / Authorized Quantitative Trading Engine
