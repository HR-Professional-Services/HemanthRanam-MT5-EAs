# 06 — Multi-Pair Scanners

This directory contains production-grade multi-pair scanning engines developed for MetaTrader 5 on Exness. These systems monitor multiple instruments simultaneously from a single chart instance, evaluating directional trend alignment, quantitative EMA health, volume confirmation, and pullback structures before executing trades or dispatching multi-channel alerts.

---

## Systems Overview

| EA Source File | Matching Documentation | Primary Strategy | Scanning Capacity | Auto Trading |
| :--- | :--- | :--- | :--- | :--- |
| [`9_21_EMA_MULTI_PAIR_SCANNER_EA.mq5`](file:///Users/rh/.gemini/antigravity-ide/scratch/Trading/HemanthRanam-MT5-EAs/06_MULTI_PAIR_SCANNERS/9_21_EMA_MULTI_PAIR_SCANNER_EA.mq5) | [`9_21_EMA_MULTI_PAIR_SCANNER_EA_README.md`](file:///Users/rh/.gemini/antigravity-ide/scratch/Trading/HemanthRanam-MT5-EAs/06_MULTI_PAIR_SCANNERS/9_21_EMA_MULTI_PAIR_SCANNER_EA_README.md) | M5 9/21 EMA Pullback + Quantitative Health Filter | Up to 32 Symbols (Default 4: Gold, Silver, US500, USTEC) | Full Auto + Alert Modes |
| [`MULTI_PAIR_SCANNER_V1_EA.mq5`](file:///Users/rh/.gemini/antigravity-ide/scratch/Trading/HemanthRanam-MT5-EAs/06_MULTI_PAIR_SCANNERS/MULTI_PAIR_SCANNER_V1_EA.mq5) | [`MULTI_PAIR_SCANNER_V1_EA_README.md`](file:///Users/rh/.gemini/antigravity-ide/scratch/Trading/HemanthRanam-MT5-EAs/06_MULTI_PAIR_SCANNERS/MULTI_PAIR_SCANNER_V1_EA_README.md) | Multi-Pair Pullback Engine (Trend Runner & Partial Close) | Multi-Currency + Indices + Metals | Full Auto + Alert Modes |
| [`MULTI_PAIR_SCANNER_V2_EA.mq5`](file:///Users/rh/.gemini/antigravity-ide/scratch/Trading/HemanthRanam-MT5-EAs/06_MULTI_PAIR_SCANNERS/MULTI_PAIR_SCANNER_V2_EA.mq5) | [`MULTI_PAIR_SCANNER_V2_EA_README.md`](file:///Users/rh/.gemini/antigravity-ide/scratch/Trading/HemanthRanam-MT5-EAs/06_MULTI_PAIR_SCANNERS/MULTI_PAIR_SCANNER_V2_EA_README.md) | Multi-Pair Scanner V2 with Dynamic BOS Filtering & Visual Canvas | Up to 32 Symbols with Adaptive Spreads | Full Auto + Terminal Alerts + Telegram |

---

## Architecture & Design Principles

1. **Standalone Execution**:
   - Each EA is self-contained and compiles directly in MetaEditor MT5 (Build 4000+) without custom `.mqh` header requirements.
   - Utilizes standard MT5 libraries (`<Trade\Trade.mqh>`, `<Trade\SymbolInfo.mqh>`, `<Canvas\Canvas.mqh>`).
2. **Single-Chart Watchlist Monitoring**:
   - Attach the scanner to any liquid M5 or M15 chart (e.g. `EURUSD` or `XAUUSD`).
   - Automatically initializes price buffers, indicator handles, and spread limits for every configured symbol.
3. **Strict Risk & Drawdown Controls**:
   - Default risk per trade: 1.0% (configurable to 0.5%).
   - Automatic 1R Break-Even migration and 2R partial profit taking (50%).
   - Session protection (force-close before weekend / New York close).
4. **Timeframe Discipline**:
   - Primary operational timeframes: **M5** and **M15**.
   - M1 execution layer is disabled by default due to spread drag under high Exness trading costs.
