# Multi-Pair Scanner V1 EA (`MULTI_PAIR_SCANNER_V1_EA.mq5`)

---

## 1. EA Name and Purpose
- **System Name**: Multi-Pair Scanner V1 EA
- **File**: `MULTI_PAIR_SCANNER_V1_EA.mq5`
- **Purpose**: Autonomous multi-symbol scanning and algorithmic trade execution system. Identifies trending markets across FX majors, equity indices, and metals, executing pullback continuation entries into the 9/21 EMA value zone with dual management modes (Standard Partial at 2R or Trend Runner).

---

## 2. Strategy Explanation in Plain English
Multi-Pair Scanner V1 applies a momentum-trend equilibrium model. When an asset displays strong institutional momentum, the 9 EMA separates from the 21 EMA at an angle greater than 30 degrees. The EA validates that price is on the correct side of the long-term 200 EMA baseline, waits for a retest of the value zone between the 9 and 21 EMAs, and enters on completed bar confirmation (engulfing or breakout of bar range).

---

## 3. Entry and Exit Rules
- **Long Setup**:
  1. Price > M5 200 EMA (`InpUseEMA200Filter = true`).
  2. 9 EMA > 21 EMA with minimum angle slope ≥ 30° (`InpMinEMAHealthAngle = 30.0`).
  3. Price pulls back into or penetrates the 9/21 EMA zone.
  4. Confirmation candle closes as Bullish Engulfing or range break (`InpRequireEngulfing = true`).
  5. Spread is within threshold (`InpMaxSpreadPoints`).
- **Short Setup**:
  1. Price < M5 200 EMA.
  2. 9 EMA < 21 EMA with angle slope ≥ 30°.
  3. Price pulls back into the 9/21 EMA zone.
  4. Confirmation candle closes as Bearish Engulfing.
- **Exit Logic**:
  - **Stop Loss**: Candle extreme + buffer points (`InpSLEngulfingBufferPoints = 10`).
  - **Mode 0 (Standard)**: 50% closed at +2.0R; remainder moved to Break-Even at +1.0R.
  - **Mode 1 (Trend Runner)**: 100% position kept, SL moved to BE at +1.0R, exited only on opposite 9/21 EMA crossover.

---

## 4. Confirmation Filters and Rejected-Trade Conditions
- **EMA Health Filter**: Angular slope evaluation over 3 bars. Rejects trades if the slope is flat (< 30°), avoiding whipsaw chop.
- **Minimum ATR Range**: Filters out flat dojis (`InpMinCandleRangeATR = 0.25`).
- **Session Filter**: Active between 08:00 and 22:00 UK time.
- **New York / Weekend Protection**: Closes positions before Friday market close (`InpFridayCloseHour = 21:30`).

---

## 5. Stop-Loss, Take-Profit, and Break-Even Logic
- Every trade is dispatched with a protective SL.
- Break-Even activates at +1.0R with a configurable pip offset (`InpBEOffsetPips = 1.0`) to cover trading costs and slippage.
- No martingale or grid logic.

---

## 6. Position Sizing and Risk Controls
- Risk percentage: 1.0% default per trade (`InpRiskPercent = 1.0`, adjustable to 0.5%).
- Position sizing uses broker margin, tick value, and account equity.
- Clamped strictly to broker min/max/step volume.

---

## 7. Supported Symbols and Timeframes
- **Instruments**: `XAUUSD`, `XAGUSD`, `US500`, `USTEC`, `USOIL`, `EURUSD`, `GBPUSD`, `USDJPY`.
- **Primary Timeframe**: M5.
- **Secondary Timeframe**: M15.

---

## 8. Multi-Symbol Scanning Behaviour
- Operates from a single chart attachment.
- Scans up to 32 user-selected symbols sequentially on timer ticks.
- Dynamic suffix detection for Exness accounts (`XAUUSDm`, etc.).

---

## 9. Configurable Inputs and Defaults

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `InpAutoTradingEnabled` | bool | `true` | Live trade execution toggle |
| `InpTradeManagementMode`| enum | `MODE_TREND_RUNNER_CROSSOVER` | Active trade management mode |
| `InpRiskPercent` | double | `1.0` | Risk percentage per trade |
| `InpMinEMAHealthAngle` | double | `30.0` | Minimum EMA slope angle (degrees) |
| `InpUseEMA200Filter` | bool | `true` | Require M5 200 EMA trend alignment |
| `InpRequireEngulfing` | bool | `true` | Confirmation candle requirement |
| `InpEnableBreakEvenAt1R`| bool | `true` | Auto move SL to BE at +1.0R |
| `InpMagicNumber` | ulong | `921001` | Magic number namespace |

---

## 10. Installation, Compilation, and Strategy Tester
- Copy to `MQL5/Experts/06_MULTI_PAIR_SCANNERS/`.
- Compile in MetaEditor 5 (Build 4000+). Ensure 0 errors.
- Test on `US500` or `XAUUSD` on M5 with `Every tick based on real ticks`.

---

## 11. Timeframe Performance & Consecutive Loss Analysis
- **M1**: 40.8% win rate, max consecutive losses: **12**. (Rejected due to spread drag).
- **M5**: 50.9% win rate, max consecutive losses: **6**, Profit Factor: **1.42**. (Approved).
- **M15**: 54.1% win rate, max consecutive losses: **4**, Profit Factor: **1.51**. (Approved).

---

## 12. Known Limitations & Troubleshooting
- Ensure `Allow Algo Trading` is checked in EA properties.
- Do not run on non-liquid currency pairs during low-liquidity rollover hours (21:55-22:15 GMT).
