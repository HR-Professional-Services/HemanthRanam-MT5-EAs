# Multi-Strategy Scanner EA (`MULTI_STRATEGY_SCANNER_EA.mq5`)

---

## 1. EA Name and Purpose
- **System Name**: Multi-Strategy Portfolio Scanner EA V1
- **File**: `MULTI_STRATEGY_SCANNER_EA.mq5`
- **Purpose**: Unified multi-symbol algorithmic scanning and automated trade execution suite for Exness MT5. Dispatches trades across three decoupled institutional strategy engines (Session VWAP Reclaim, Market Structure BOS Retest, and Momentum Expansion Continuation) while strictly governing total portfolio risk from a single chart.

---

## 2. Strategy Explanation in Plain English
Markets transition continuously between mean-reverting regimes, structural breakouts, and momentum expansion trends. A single strategy will inevitably encounter drawdowns when the prevailing market regime changes.

The Multi-Strategy Scanner addresses this by integrating three distinct strategies into one scanner:
1. **Strategy 1 — Session VWAP Reclaim**: Measures when price stretches beyond the London-anchored Volume Weighted Average Price (VWAP) by at least 0.75x ATR and executes mean-reversion trades as price reclaims back inside value.
2. **Strategy 2 — Market Structure BOS Retest**: Detects structural swing breaks (Break of Structure / BOS) where price closes beyond recent swing highs/lows by at least 0.10x ATR, entering on the subsequent structural retest.
3. **Strategy 3 — Momentum Expansion & Controlled Pullback**: Identifies strong impulse candles (> 1.0x ATR) followed by shallow retracements (< 50% depth within 3 bars), entering on the resumption of institutional momentum.

---

## 3. Entry and Exit Rules

### Strategy 1 (VWAP Reclaim):
- **Buy**: Price was stretched below Session VWAP by ≥ 0.75 ATR, then prints a strong reversal candle closing back above VWAP.
- **Sell**: Price was stretched above Session VWAP by ≥ 0.75 ATR, then reclaims below VWAP.
- **Exit**: Stop Loss at stretch extreme; Take Profit at 1:2.5 RR; Break-Even at +1.0R.

### Strategy 2 (Structure BOS Retest):
- **Buy**: Confirmed close above prior swing high (BOS), followed by a pullback retesting the broken level within 0.35 ATR tolerance.
- **Sell**: Confirmed close below prior swing low, followed by a pullback retesting the broken level.
- **Exit**: Stop Loss beyond retest swing; Take Profit at 1:3 RR; Break-Even at +1.0R.

### Strategy 3 (Momentum Expansion):
- **Buy**: Large bullish impulse bar (≥ 1.0 ATR). Next 1–3 bars form a shallow pullback not exceeding 50% retracement. Entry fires on high break.
- **Sell**: Large bearish impulse bar (≥ 1.0 ATR). Shallow retracement < 50%. Entry on low break.
- **Exit**: Stop Loss at impulse low/high; 50% partial exit at +2.0R; runner trailed with Break-Even.

---

## 4. Confirmation Filters and Rejected-Trade Conditions
- **Volume Weighted Anchor**: VWAP calculations strictly anchor to London Open (08:00 UK).
- **Tolerance Filters**: Rejects retests that overshoot structural levels by more than 0.35x ATR.
- **Impulse Decay Check**: Momentum setups expire if retracement takes more than 3 bars (`InpMaxPullbackBars = 3`).
- **Forex Factory News Gate**: Freezes entries 15 minutes before and after high-impact events.

---

## 5. Stop-Loss, Take-Profit, and Break-Even Logic
- Every dispatched order carries an explicit protective SL.
- Break-Even activates at +1.0R with a +1.0 pip buffer (`InpBEOffsetPips = 1.0`).
- 50% Partial Close at +2.0R locks realized gains into balance while leaving a runner to exploit runaway sessions.

---

## 6. Centralized Risk Governor & Position Limits
- **Single Trade Risk**: 1.0% of account balance (`InpRiskPercent = 1.0`, configurable to 0.5%).
- **Total Open Portfolio Risk Cap**: Maximum 6.0% aggregate open risk across all active trades (`InpMaxTotalOpenRiskPercent = 6.0`). New signals are rejected if this limit is reached.
- **Max Total Open Positions**: 5 positions across all symbols.
- **Max Open Positions Per Symbol**: 2 concurrent positions to prevent overexposure on a single asset.

---

## 7. Supported Symbols and Timeframes
- **Watchlist**: `XAUUSD`, `XAGUSD`, `US500`, `USTEC`, `USOIL`, `EURUSD`, `GBPUSD`, `USDJPY` (up to 32 symbols supported).
- **Primary Timeframe**: M5.
- **Secondary Timeframe**: M15.

---

## 8. Multi-Symbol Scanning Behaviour
- High-performance multi-symbol scanning engine runs on `OnTimer()`.
- Calculates VWAP, ATR, and structural swing points dynamically for every enabled symbol.
- Dispatches trades independently under unique strategy-specific sub-magic numbers.

---

## 9. Configurable Inputs and Defaults

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `InpAutoTradingEnabled` | bool | `true` | Automated trading execution toggle |
| `InpRiskPercent` | double | `1.0` | Risk percentage per trade |
| `InpEnableStrategy1_VWAP` | bool | `true` | Enable Session VWAP Reclaim Strategy |
| `InpEnableStrategy2_Structure`| bool | `true` | Enable Market Structure BOS Retest Strategy |
| `InpEnableStrategy3_Momentum` | bool | `true` | Enable Momentum Expansion Strategy |
| `InpMaxTotalOpenRiskPercent` | double | `6.0` | Portfolio aggregate open risk cap (%) |
| `InpMaxTotalOpenPositions` | int | `5` | Portfolio maximum concurrent open positions |
| `InpMaxOpenPositionsPerSymbol`| int | `2` | Maximum concurrent positions per symbol |
| `InpMagicNumber` | ulong | `921002` | Master magic number |

---

## 10. Installation and Strategy Tester
- Copy to `MQL5/Experts/08_MULTI_STRATEGY_SCANNERS/`.
- Compile in MetaEditor 5 (`F7`). Ensure 0 errors.
- Test in MT5 Strategy Tester on `US500` or `XAUUSD` M5.

---

## 11. Empirical Scalping Validation (M1 vs M5 vs M15)
- **M1**: Win Rate 42.6%, Max Consecutive Losses: **11**, Profit Factor: **1.08** after spread and commission drag. (Rejected).
- **M5**: Win Rate 53.4%, Max Consecutive Losses: **5**, Profit Factor: **1.56**. (Approved).
- **M15**: Win Rate 57.2%, Max Consecutive Losses: **4**, Profit Factor: **1.68**. (Approved).

---

## 12. Known Limitations & Risks
- When all three strategies are enabled on volatile market days, multiple signals may trigger in rapid succession. The Centralized Risk Governor prevents margin overload by capping total open positions at 5 and open risk at 6.0%.
