# HR BLOOMBERG QUANT TERMINAL — HR UNIFIED MASTER OS V4 FINAL

> **V4 FINAL ARCHITECTURAL LOCK**  
> **Release Date:** May 06, 2026  
> **Status:** Compiled & Verified Linkage (0 errors, 0 warnings)  
> **Author:** Hemanth Ranam  
> **Target Platform:** MetaTrader 5 (MT5 x64 Regular)

---

## 1. Locked Visual Architecture
The UI strictly implements the institutional slate look matching the official terminal reference image (`/Screenshots/image_130c3c.png`):

- **Header (80px)**:
  - Title: `HR BLOOMBERG QUANT TERMINAL — HR UNIFIED MASTER OS`
  - Badges: Amber `QUANT` badge (`#F59E0B`), Session Pill (`NY` / `LONDON` / `ASIAN`), Active Status (`OFF` / `LIVE`), Live UK & Server Clock.
  - Risk Controls: Daily Drawdown, Aggregate Open Risk, and Concurrent Open Positions (`0/2` or `0/4`).
- **Macro Correlation Ribbon (38px)**:
  - DXY Live Quote + percentage shift.
  - Live rolling correlation for Gold, Silver, S&P 500, and Nasdaq 100.
  - `Active Trading Killzones` indicator chip.
- **2x2 Instrument Grid (4 Cards)**:
  - **Asset 1:** XAUUSD (Spot Gold)
  - **Asset 2:** XAGUSD (Spot Silver)
  - **Asset 3:** US500 (S&P 500)
  - **Asset 4:** USTEC (Nasdaq 100)
- **Inside Each Card**:
  - **Header:** 30px Tribal Bold Asset Name + 44px Consolas Bold Digital Watch Price (`Price + Percentage`).
  - **Section A (EMA Regime):** M5 Pill, H1 Pill, Overall Bias Pill (`BULLISH` / `BEARISH`), EMA Separation % and Health Score.
  - **Section B (ICT / SMC Matrix):** 4 Modular Boxes: Structure (`BOS` / `CHOCH`), Nearest BSL, Nearest SSL, and Last SWEEP confirmation.
  - **Section C (Indicators):** 3 Modular Boxes: `RSI(14)`, `MACD Cross`, and `ATR(14) pts`.
  - **Section D (Visual Flow):**
    - `VOL & ORDER FLOW`: 14px thick progress bar + Buy Pressure percentage readout.
    - `RSI GAUGE`: 10px thick semi-circular speedometer arc + internal digital readout.
    - `TRAJECTORY`: 20-bar live M5 EMA9 history curve with subtle gradient area fill and directional regime text.
- **Bottom Ribbon (72px Watchlist)**:
  - 5 columns: `GOLD`, `SILVER`, `S&P 500`, `NASDAQ 100`, `DXY`.
  - 24px digital prices, percentage changes, and tri-color trend status dots.

---

## 2. Dynamic Bloomberg Flash Flicker Engine (300ms)
- **Price Shift:** 300ms flash in Light Green (`#D1FAE5`) / Light Red (`#FEE2E2`) with bright text.
- **Percentage Shift:** 300ms flash on delta change.
- **EMA Regime Change:** 400ms Bright Yellow-Amber transition flash.
- **RSI Overbought/Oversold:** 500ms Light Yellow alert flash.
- **BSL / SSL Sweep:** 500ms Orange alert flash.
- **Volume Spike:** 300ms Bright Emerald flash when buy pressure shifts > 5%.

---

## 3. Data Linkage & 24/7 Stability
- **`VerifyAllLinked()`**: Runs every 2 seconds via `OnTimer()`. Verifies that top card prices and bottom ribbon quotes are identical (`Price Top == Price Bottom`), with live percentage recalculation from the daily open bar.
- **Handle Initialization Retries**: Attempts up to 3 retries with 500ms sleeps on `INVALID_HANDLE`.
- **Market Closed Graceful Standby**: Safe fallback rendering when quotes are static during weekend/overnight hours.
- **Automatic Recovery Watchdog**: Automatically purges and re-initializes handles and calls `ChartRedraw(0)` if error counts exceed 10 in a 60-second window.
- **Daily Refresh**: Resets internal timers and re-evaluates all matrices automatically at 00:05 server time.

---

## 4. Source Structure
- `HR_UNIFIED_MASTER_OS.mq5`: Main Expert Advisor orchestrator.
- `HR_Dashboard_Premium.mqh`: Pixel-perfect CCanvas graphics engine.
- `HR_Utils.mqh`: Global ARGB tokens, structs, and flicker state management.
- `HR_EMA_Engine.mqh`: 9/21/200 EMA buffer processor and 20-bar trajectory history.
- `HR_ICT_SMC.mqh`: Liquidity sweep, BSL/SSL, and BOS/CHOCH structure engine.
- `HR_Indicators.mqh`: ATR, RSI, and MACD calculation engine.
- `HR_Macro.mqh`: DXY multi-asset correlation calculator.
