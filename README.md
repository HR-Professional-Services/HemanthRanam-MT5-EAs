# Hemanth Ranam — MetaTrader 5 Expert Advisors (MQL5)

[![MQL5](https://img.shields.io/badge/Language-MQL5-blue.svg)](https://www.mql5.com/)
[![MetaTrader 5](https://img.shields.io/badge/Platform-MetaTrader%205-007acc.svg)](https://www.metatrader5.com/)
[![Organization](https://img.shields.io/badge/GitHub%20Org-HR--Professional--Services-success.svg)](https://github.com/HR-Professional-Services)
[![Architecture](https://img.shields.io/badge/Architecture-Autonomous%20Trading%20Engines-orange.svg)](#architecture--structure)
[![Clean Code](https://img.shields.io/badge/Source%20Only-No%20Executables%20%7C%20No%20Secrets-brightgreen.svg)](#security--clean-code-guarantees)

Production-grade **MetaTrader 5 (MQL5)** Expert Advisor source code developed and engineered by **Hemanth Ranam**. This repository serves as the central source-of-truth for multi-pair scanning engines, multi-timeframe trend/pullback algorithms, systematic single-period EMA models, and real-time execution/API bridges.

---

## 🏛️ Architecture & Structure

All Expert Advisors follow standard MetaTrader 5 library architecture (`<Trade\Trade.mqh>`, `<Trade\PositionInfo.mqh>`, `<Trade\SymbolInfo.mqh>`, `<Canvas\Canvas.mqh>`), requiring zero proprietary closed-source DLLs or third-party wrappers.

The repository is organized into five functional strategy directories:

```
HemanthRanam-MT5-EAs/
├── 01_Multi_Pair_Scanners/          # Multi-symbol radar scanners & real-time dashboard engines
│   ├── 9-21_EMA_MULTI_PAIR_SCANNER_EA.mq5
│   ├── MULTI_PAIR_SCANNER_V1_EA.mq5
│   ├── MULTI_PAIR_SCANNER_V2_EA.mq5
│   └── MULTI_STRATEGY_SCANNER_V1_EA.mq5
│
├── 02_Trend_And_Pullback_EAs/       # Automated trend-following & pullback execution algorithms
│   ├── AUTO_PILOT_EMA_921_PULLBACK_PRO_EA.mq5
│   ├── AI_TREND_PILOT_PRO_V1_EA.mq5
│   ├── 9_EMA_VOLUME_TREND_RIDER_EA.mq5
│   ├── EMA_TREND_RIDER_EA.mq5
│   └── EMA_VOLUME_TREND_EA.mq5
│
├── 03_Multi_Timeframe_EAs/          # Higher-timeframe regime filters with tactical MTF triggers
│   ├── 9-21-200_EMA_MTF_EA.mq5
│   ├── 9-21-200_EMA_MACD_EA.mq5
│   ├── 9-15_EMA_V2_2_EA.mq5
│   ├── 50_PERCENT_WIN_EMA_EA.mq5
│   └── XAUUSD_EMA_VWAP_RSI_EA.mq5
│
├── 04_Single_EMA_Strategies/        # Modular benchmark single-period EMA execution systems
│   ├── 9_EMA_STRATEGY_EA.mq5
│   ├── 21_EMA_STRATEGY_EA.mq5
│   ├── 50_EMA_STRATEGY_EA.mq5
│   ├── 100_EMA_STRATEGY_EA.mq5
│   ├── 150_EMA_STRATEGY_EA.mq5
│   └── 200_EMA_STRATEGY_EA.mq5
│
└── 05_Execution_And_Bridge_EAs/     # External REST/WebSocket bridge, signal broadcast & tester
    ├── CHARTORA_OFFICIAL_V1_EA.mq5
    ├── CHARTORA_MT5_BRIDGE_EA.mq5
    ├── HEMANTH_RANAM_PRO_TRADER_EA.mq5
    └── STRATEGY_TESTER_PRO_EA.mq5
```

---

## 📋 Complete Expert Advisor Catalog

### Category 01: Multi-Pair & Multi-Strategy Scanners (`01_Multi_Pair_Scanners/`)

| File Name | Original Source Reference | Strategy & Capabilities | Supported Assets |
| :--- | :--- | :--- | :--- |
| `9-21_EMA_MULTI_PAIR_SCANNER_EA.mq5` | `921 EMA Multipair Scanner V1.mq5` | Scans up to 30 currency & index pairs concurrently for 9/21 EMA slope, alignment, and pullback entry signals. Features GUI dashboard, automatic symbol cycling, and Telegram chart broadcasting. | Major & Minor FX, Gold, US500, USTEC |
| `MULTI_PAIR_SCANNER_V1_EA.mq5` | `Multi_Pair_Scanner_V1.mq5` | High-frequency multi-pair market radar monitoring spread, momentum, volume bursts, and price action cross triggers. | FX Majors, Crypto, Metals |
| `MULTI_PAIR_SCANNER_V2_EA.mq5` | `Multi_Pair_Scanner_V2.mq5` | Enhanced version 2 scanner with adaptive volatility thresholds, dynamic spread protection, and prioritized alert sequencing. | All MT5 Market Watch symbols |
| `MULTI_STRATEGY_SCANNER_V1_EA.mq5` | `Multi_Strategy_Scanner_V1.mq5` | Composite engine running parallel strategy filters (EMA cross, breakout, RSI divergence, volume spikes) to identify high-confluence trade opportunities. | Multi-asset class scanner |

---

### Category 02: Trend & Pullback Automated Engines (`02_Trend_And_Pullback_EAs/`)

| File Name | Original Source Reference | Strategy & Capabilities | Supported Assets |
| :--- | :--- | :--- | :--- |
| `AUTO_PILOT_EMA_921_PULLBACK_PRO_EA.mq5` | `Auto_Pilot_EMA_921_Pullback_PRO.mq5` | 100% autonomous trading bot executing high-probability pullback entries into the 9/21 EMA channel during confirmed higher-timeframe trends. Trailing stop and partial profit taking. | EURUSD, GBPUSD, XAUUSD, NAS100 |
| `AI_TREND_PILOT_PRO_V1_EA.mq5` | `AI Trend Pilot PRO V1.mq5` | Adaptive trend follower combining machine-computed trend strength slope, ATR dynamic risk buffers, and automated trade sizing. | Forex, Indices, Energies |
| `9_EMA_VOLUME_TREND_RIDER_EA.mq5` | `9EMA_Volume_Trend_Rider.mq5` | Combines 9 EMA impulse tests with on-balance volume (OBV) and tick volume surges for high-momentum breakout continuation trades. | Equities, Indices, FX |
| `EMA_TREND_RIDER_EA.mq5` | `EMA Trend Rider.mq5` | Classical trend rider utilizing EMA crossovers, break-even shift automation, and stepped trailing stop functionality. | All instruments |
| `EMA_VOLUME_TREND_EA.mq5` | `EMA + Volume.mq5` | Trend continuation model filtering false breakouts by requiring minimum volume percentiles before trade execution. | FX Majors, Metals |

---

### Category 03: Multi-Timeframe & Indicator Confluence EAs (`03_Multi_Timeframe_EAs/`)

| File Name | Original Source Reference | Strategy & Capabilities | Supported Assets |
| :--- | :--- | :--- | :--- |
| `9-21-200_EMA_MTF_EA.mq5` | `9-21-200 EMA MTF EA.mq5` | Triple EMA architecture: 200 EMA establishes macro directional bias (Daily/H4), while 9 and 21 EMAs govern tactical entry triggers (H1/M15). | Multi-asset |
| `9-21-200_EMA_MACD_EA.mq5` | `9-21-200 EMA + MACD EA.mq5` | Trend and momentum confluence system pairing triple EMA directional alignment with MACD histogram zero-line crossovers. | Major FX pairs, Gold |
| `9-15_EMA_V2_2_EA.mq5` | `9-15 EMA EA V2.2.mq5` | High-precision fast EMA scalp engine built for intraday volatility captures, tight stop losses, and accelerated profit harvesting. | M5/M15 Scalping |
| `50_PERCENT_WIN_EMA_EA.mq5` | `50% Win EMA.mq5` | Mathematical edge strategy optimized for asymmetric reward-to-risk (minimum 1:2.5 R:R), sustaining consistent profitability even at 45–50% win rates. | High-beta FX & Indices |
| `XAUUSD_EMA_VWAP_RSI_EA.mq5` | `XAUUSD EMA VWAP RSI.mq5` | Purpose-built Gold (XAUUSD) algorithm combining session volume-weighted average price (VWAP), 9/21 EMA trend bias, and RSI overextension filters. | XAUUSD (Gold), XAGUSD (Silver) |

---

### Category 04: Single-Period EMA Strategies (`04_Single_EMA_Strategies/`)

| File Name | Original Source Reference | Strategy & Capabilities | Recommended Role |
| :--- | :--- | :--- | :--- |
| `9_EMA_STRATEGY_EA.mq5` | `9 EMA.mq5` | Fast dynamic baseline strategy executing aggressive impulse continuation and tight trailing exits. | Momentum Scalping |
| `21_EMA_STRATEGY_EA.mq5` | `21 EMA.mq5` | Medium-speed pullback strategy capturing secondary swings in established trends. | Swing Trading |
| `50_EMA_STRATEGY_EA.mq5` | `50 EMA.mq5` | Intermediate trend filter identifying healthy corrections and institutional dynamic support/resistance. | Trend Following |
| `100_EMA_STRATEGY_EA.mq5` | `100 EMA.mq5` | Structural swing benchmark distinguishing primary trends from major corrective phases. | Positional Trading |
| `150_EMA_STRATEGY_EA.mq5` | `150 EMA.mq5` | Macro transition filter identifying medium-to-long term market regime changes. | Regime Detection |
| `200_EMA_STRATEGY_EA.mq5` | `200 EMA.mq5` | Institutional benchmark dividing structural bull and bear markets across global exchanges. | Macro Trend Filter |

---

### Category 05: Execution, Bridge & Testing Engines (`05_Execution_And_Bridge_EAs/`)

| File Name | Original Source Reference | Strategy & Capabilities | Integration Details |
| :--- | :--- | :--- | :--- |
| `CHARTORA_OFFICIAL_V1_EA.mq5` | `Chartora_Official_V1.mq5` | Flagship Chartora automated trading & alerting engine with high-resolution screenshot export, multi-channel Telegram broadcasting, and order execution. | WebRequest to Telegram Bot API |
| `CHARTORA_MT5_BRIDGE_EA.mq5` | `ChartoraBridge.mq5` | Ultra-low latency HTTP/REST bridge transmitting real-time tick prices, position telemetry, and account statistics to external microservices. | HMAC-SHA256 signature verification |
| `HEMANTH_RANAM_PRO_TRADER_EA.mq5` | `HemanthRanamEA.mq5` | Personal proprietary automated trader featuring rigorous capital preservation rules, max daily drawdown locks, and dynamic lot sizing. | Proprietary Trading Rules |
| `STRATEGY_TESTER_PRO_EA.mq5` | `Tester.mq5` | Full diagnostic Expert Advisor engineered specifically for stress testing MT5 Strategy Tester execution models, slippage, and spread widening. | Backtest Optimization |

---

## 🛠️ Setup & Compilation Guide

### 1. MT5 Terminal Directory Setup
Copy the desired `.mq5` file into your MetaTrader 5 terminal's `Experts` folder:
- **Windows**: `C:\Users\<User>\AppData\Roaming\MetaQuotes\Terminal\<InstanceID>\MQL5\Experts\`
- **macOS / Wine**: `~/Library/Application Support/net.metaquotes.wine.metatrader5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/`

### 2. Compiling the Expert Advisor
1. Open **MetaEditor** (Press `F4` inside MetaTrader 5).
2. In the Navigator pane, expand `Experts` and double-click the `.mq5` file.
3. Click **Compile** in the toolbar (or press `F7`).
4. Ensure the compile output reports:
   ```
   0 errors, 0 warnings
   ```
5. The compiled `.ex5` executable will automatically be created in your local terminal (ready for backtesting or live deployment).

### 3. Enabling Algorithmic Trading & WebRequest
For EAs utilizing Telegram alerts or external HTTP bridges:
1. In MetaTrader 5, navigate to **Tools** > **Options** (or press `Ctrl + O`).
2. Select the **Expert Advisors** tab:
   - Check **Allow Algo Trading**.
   - Check **Allow WebRequest for listed URL**.
   - Add the required endpoints:
     - `https://api.telegram.org` (for Telegram broadcast)
     - `http://localhost:5000` or your custom server URL (for Chartora Bridge)
3. Click **OK**.

### 4. Input Configuration
When attaching an EA to a chart, input your credentials in the **Inputs** dialog:
- `InpTelegramBotToken`: Enter your Telegram Bot Token obtained from `@BotFather`.
- `InpTelegramChatID`: Enter your target Channel or Group ID (e.g., `-100xxxxxxxxx`).
- `InpSecretKey` / `InpApiKey`: Enter your authorized bridge access keys.

---

## 🔒 Security & Clean Code Guarantees

- **100% Pure Source Code**: This repository contains strictly readable `.mq5` source code files. Zero compiled `.ex5`, `.ex4`, or compiled `.dll` binaries are committed.
- **Zero Hardcoded Secrets**: All Telegram bot tokens, channel IDs, webhook secrets, and private API authorization keys have been fully sanitized with empty input defaults (`""`). Users provide their credentials via runtime input parameters.
- **Local File Preservation**: Original source files on the developer's workstation remain untouched in their native environments.

---

## 👨‍💻 Author & Organization

- **Author**: Hemanth Ranam
- **GitHub Organization**: [HR-Professional-Services](https://github.com/HR-Professional-Services)
- **Repository**: [HemanthRanam-MT5-EAs](https://github.com/HR-Professional-Services/HemanthRanam-MT5-EAs)
- **License**: Proprietary / MIT (Source code reference for authorized systems)
