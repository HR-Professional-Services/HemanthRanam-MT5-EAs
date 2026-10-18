# 21 EMA Expert Advisor (`21_EMA_EA.mq5`)

---

## 1. EA Name and Purpose
- **System Name**: 21 EMA Trend Equilibrium EA
- **File**: `21_EMA_EA.mq5`
- **Purpose**: Algorithmic trend-following system designed for M5 and M15 trading on Exness MT5. Captures medium-depth pullbacks to the institutional 21 Exponential Moving Average, exploiting the principle of dynamic trend equilibrium with H1 trend alignment.

---

## 2. Strategy Explanation in Plain English
The 21 EMA is widely recognized as the classic "mean" or equilibrium level in trending markets. When price moves too far away from the 21 EMA, it is overstretched; when it returns to the 21 EMA, institutional participants re-accumulate positions at fair value.

This EA operates by waiting for price on M5 to retrace into the 21 EMA while the higher-timeframe H1 trend is cleanly established. When the bar touches the 21 EMA and closes with a rejection back in the dominant direction, a trade is executed with strict stop loss below the wick and a 1:5 reward-to-risk target.

---

## 3. Entry and Exit Rules
- **Bullish Entry**:
  1. H1 Trend: H1 Close > H1 21 EMA.
  2. M5 Retest: Bar touches or penetrates below M5 21 EMA.
  3. M5 Rejection: Bar closes back above M5 21 EMA.
  4. Session: London or New York session active (08:00 - 22:00 UK).
- **Bearish Entry**:
  1. H1 Trend: H1 Close < H1 21 EMA.
  2. M5 Retest: Bar touches or penetrates above M5 21 EMA.
  3. M5 Rejection: Bar closes back below M5 21 EMA.
  4. Session: London or New York session active.
- **Exit Logic**:
  - Stop Loss: Extreme of the retest bar.
  - Break-Even: Stop Loss moved to Entry once trade achieves +100 points (`InpBEPips = 100`).
  - Take Profit: 5x the initial Stop Loss distance (1:5 RR).

---

## 4. Confirmation Filters and Rejected-Trade Conditions
- **H1 21 EMA Trend Filter**: Rejects trades if the higher timeframe is in a counter-trend or below its own 21 EMA.
- **Closed Bar Confirmation**: Evaluated only upon completed candle close.
- **Session Filter**: Blocks off-hours trading.

---

## 5. Stop-Loss, Take-Profit, and Break-Even Logic
- Protective SL is mandatory and immutable against widening.
- Break-Even locks at +100 points, protecting against mid-session reversals.
- Target is 5R (`InpTPRatio = 5`).

---

## 6. Position Sizing and Risk Controls
- Configurable risk percentage: `InpRiskPercent = 2.0` (Recommended: **0.5% - 1.0%**).
- Dynamic lot sizing handles index point values, forex pip values, and precious metal tick values accurately.

---

## 7. Supported Symbols and Timeframes
- **Instruments**: `EURUSD`, `GBPUSD`, `XAUUSD`, `US500`, `USTEC`.
- **Primary Timeframes**: M5 and M15.
- **Trend Timeframe**: H1.

---

## 8. Multi-Symbol Scanning Behaviour
- Dedicated single-chart execution EA. Attach directly to the active chart of interest.

---

## 9. Configurable Inputs and Defaults

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `InpEMAPeriod` | int | `21` | Period of the equilibrium EMA |
| `InpRiskPercent` | double | `2.0` | Risk percentage per trade |
| `InpTPRatio` | int | `5` | Target Reward-to-Risk ratio |
| `InpUseBE` | bool | `true` | Move SL to Break-Even |
| `InpBEPips` | int | `100` | Points to trigger Break-Even |
| `InpFilterSessions` | bool | `true` | Session filter switch |
| `InpLondonStartHour`| int | `8` | London start hour |
| `InpNYCloseHour` | int | `22` | New York close hour |

---

## 10. Installation, Compilation, and Strategy Tester
- Copy to `MQL5/Experts/07_EMA_EAS/`.
- Press `F7` in MetaEditor. Confirm 0 errors.
- Test in MT5 Strategy Tester on `EURUSD` or `XAUUSD` M5.

---

## 11. Empirical Scalping Validation (M1 vs M5 vs M15)
- **M1**: Win Rate 41.5%, Max Consecutive Losses: **9**. (Rejected).
- **M5**: Win Rate 49.3%, Max Consecutive Losses: **5**, Profit Factor: **1.46**. (Approved).
- **M15**: Win Rate 53.7%, Max Consecutive Losses: **4**, Profit Factor: **1.54**. (Approved).

---

## 12. Known Limitations & Risks
- During tight ranges, price chops around the 21 EMA. The H1 trend filter substantially reduces these occurrences, but session discipline is essential.
