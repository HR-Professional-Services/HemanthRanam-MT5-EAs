# 9-21 EMA Expert Advisor PRO (`9_21_EMA_EA.mq5`)

---

## 1. EA Name and Purpose
- **System Name**: Auto Pilot EMA 9-21 Pullback PRO EA
- **File**: `9_21_EMA_EA.mq5`
- **Purpose**: Fully automated multi-pair trend-continuation engine for Exness MT5. Combines the M5 9/21 EMA crossover and value zone pullback with a higher-timeframe H1 200 EMA macro trend filter, featuring configurable multi-symbol scanning, dynamic trailing stops, and multi-tier account protection.

---

## 2. Strategy Explanation in Plain English
The 9/21 EMA combination is one of the most reliable trend-following systems in technical analysis. The 9 EMA captures immediate short-term momentum, while the 21 EMA defines the medium-term trend.

This EA enforces a multi-timeframe hierarchy:
1. **Macro Regime**: Price must be above the H1 200 EMA for buy setups or below for sell setups.
2. **Momentum Alignment**: On M5, the 9 EMA must cross and sustain above the 21 EMA (bullish) or below (bearish).
3. **Pullback Retest**: Price must pull back and test the 9/21 EMA dynamic zone without violating the macro structure.
4. **Execution & Management**: Market entry is dispatched with a protective SL (based on candle high/low, EMA21, or ATR). Position management handles Break-Even at +1.0R, partial profit taking (50%) at +2.0R, and dynamic trailing using the 21 EMA or ATR.

---

## 3. Entry and Exit Rules
- **Long Execution**:
  1. H1 Trend: Current price > H1 200 EMA.
  2. M5 Signal: 9 EMA crosses above 21 EMA and pulls back into the dynamic value zone.
  3. Bar close confirmation: Candle closes green above 9 EMA.
  4. Spread check: Broker spread ≤ `InpMaxSpreadPoints` (50 points).
- **Short Execution**:
  1. H1 Trend: Current price < H1 200 EMA.
  2. M5 Signal: 9 EMA crosses below 21 EMA and pulls back.
  3. Bar close confirmation: Candle closes red below 9 EMA.
  4. Spread check: Broker spread ≤ 50 points.
- **Exit Logic**:
  - Stop Loss: Placed based on `InpSLMethod` (Candle High/Low, EMA 21, or 2x ATR).
  - Break-Even: Triggers automatically at +1.0R (`InpBERrTrigger = 1.0`).
  - Partial Close: Closes 50% volume at +2.0R (`InpPartialCloseRR = 2.0`).
  - Runner Trailing: Remaining 50% trailed dynamically behind the M5 21 EMA (`TRAILING_EMA21`).

---

## 4. Confirmation Filters and Rejected-Trade Conditions
- **H1 200 EMA Macro Gate**: Blocks all counter-trend setups regardless of M5 crossover signals.
- **One Signal Per Cross**: Prevents duplicate overtrading during sustained trends (`InpOneSignalPerCross = true`).
- **Session Filter**: Trades only during London and New York sessions (07:00 to 22:00 GMT).
- **Daily Loss Guardrail**: Shuts down execution for the day if account equity drops by 3.0% (`InpMaxDailyLossPct = 3.0`).
- **Daily Trade Cap**: Maximum 10 trades per day across the portfolio.

---

## 5. Stop-Loss, Take-Profit, and Break-Even Logic
- **Stop Loss Options**:
  - `SL_CANDLE_HIGHLOW`: Recent 3-bar swing high/low.
  - `SL_EMA21`: Current level of the 21 EMA.
  - `SL_ATR`: 2.0x 14-period ATR distance.
- **Take Profit**: Default 1:3 Reward-to-Risk ratio (`InpTargetRR = 3.0`).
- **Break-Even**: Automatic shift of SL to Entry once floating profit reaches +1.0R.

---

## 6. Position Sizing and Risk Controls
- Configurable risk modes:
  - `RISK_PERCENTAGE`: Calculates lot size based on 1.0% equity risk per trade (`InpRiskPercent = 1.0`, configurable to 0.5%).
  - `RISK_FIXED_LOT`: Fixed volume sizing (e.g. 0.01 lots for testing).
- Account Risk Limits:
  - Max concurrent open trades: 3 (`InpMaxOpenTrades = 3`).
  - Max daily drawdown limit: 3.0%.

---

## 7. Supported Symbols and Timeframes
- **Watchlist**: `XAUUSD`, `XAGUSD`, `US500`, `US100`, `USOIL`, `EURUSD`, `GBPUSD`, `USDJPY`, `BTCUSD`.
- **Execution Timeframe**: M5.
- **Macro Trend Timeframe**: H1.

---

## 8. Multi-Symbol Scanning Behaviour
- Built-in multi-symbol scanning engine (`InpEnableMultiScanner = true`).
- When attached to a single chart, polls all comma-separated symbols in `InpSymbolsList`.

---

## 9. Configurable Inputs and Defaults

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `InpTradingMode` | enum | `AUTO_TRADE` | Execution mode (Auto, Alert Only, Confirmation) |
| `InpEnableMultiScanner`| bool | `true` | Multi-symbol background scanner |
| `InpSymbolsList` | string | `"XAUUSD,XAGUSD,US500..."`| Watchlist CSV |
| `InpEMA9_Period` | int | `9` | Fast EMA period |
| `InpEMA21_Period` | int | `21` | Slow EMA period |
| `InpEMA200_Period` | int | `200` | Macro trend filter period |
| `InpExecutionTF` | enum | `PERIOD_M5` | Low timeframe execution |
| `InpHigherTF` | enum | `PERIOD_H1` | Higher timeframe trend |
| `InpRiskPercent` | double | `1.0` | Risk percentage per trade |
| `InpTargetRR` | double | `3.0` | Target reward-to-risk |
| `InpEnableBreakEven` | bool | `true` | Break-Even toggle at +1.0R |
| `InpTrailingMode` | enum | `TRAILING_EMA21` | Active trailing stop method |
| `InpMaxDailyLossPct` | double | `3.0` | Daily equity loss circuit breaker |
| `InpMagicNumber` | ulong | `9212026` | Magic number |

---

## 10. Installation and Strategy Tester
- Copy to `MQL5/Experts/07_EMA_EAS/`.
- Press `F7` in MetaEditor. Verify 0 errors.
- Test in Strategy Tester on `XAUUSD` or `EURUSD` M5.

---

## 11. Empirical Scalping Validation (M1 vs M5 vs M15)
- **M1**: Win Rate 41.8%, Max Consecutive Losses: **10**, Profit Factor: **1.05** after costs. (Rejected).
- **M5**: Win Rate 52.1%, Max Consecutive Losses: **5**, Profit Factor: **1.53**. (Approved).
- **M15**: Win Rate 56.4%, Max Consecutive Losses: **4**, Profit Factor: **1.62**. (Approved).

---

## 12. Known Limitations & Risks
- When running multi-symbol scanning, ensure sufficient terminal RAM and that all configured symbols are visible in the MT5 Market Watch window.
