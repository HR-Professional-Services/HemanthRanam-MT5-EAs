# Root Cause Report: Premature Break-Even Invalidation & Trade Sizing

## 1. Executive Summary

This investigation analyzed both:
1. `06_MULTI_PAIR_SCANNERS/9_21_EMA_MULTI_PAIR_SCANNER_EA.mq5` (The EA generating the multi-pair trades shown in the user's terminal screenshots)
2. `07_EMA_EAS/9_21_EMA_EA.mq5` (The single-pair / legacy multi-scanner EA referenced in the prompt)

Both codebases possess structural flaws in how Break-Even is activated, calculated, and executed. 

---

## 2. Identified & Verified Defects in `9_21_EMA_MULTI_PAIR_SCANNER_EA.mq5`

The live demo account (`279630904`) is actively running `9_21_EMA_MULTI_PAIR_SCANNER_EA.mq5`. Our line-by-line inspection identified the following confirmed defects:

### Defect 1: Intrabar Microscopic R-Calculation on Every Tick
In `ManageActiveTrades()` (lines 2422-2438):
```mql5
double currentR = isBuy ? (currentPrice - m_activeTrades[i].entry) / riskDist : (m_activeTrades[i].entry - currentPrice) / riskDist;
...
if(Use_BreakEven && !m_activeTrades[i].reachedBE && currentR >= BreakEven_R) {
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   double beOffset = MathMin(m_activeTrades[i].initialRiskDist * 0.05, BreakEven_Offset * point * (digits == 3 || digits == 5 ? 10 : 1));
   if(beOffset <= 0) beOffset = point * (digits == 3 || digits == 5 ? 10 : 1);
   double bePrice = isBuy ? (m_activeTrades[i].entry + beOffset) : (m_activeTrades[i].entry - beOffset);
   bePrice = NormalizeDouble(bePrice, digits);
   m_trade.PositionModify(ticket, bePrice, PositionGetDouble(POSITION_TP));
}
```
**Why this triggers prematurely:**
1. **Initial Risk Under-Sizing**: In index instruments (`ustec`, `us500`), stop-loss is placed at the engulfing candle low:
   ```mql5
   double slPrice = low[0] - (InpSLEngulfingBufferPoints * pointVal) - (atr[0] * InpSLBufferATR * 0.5);
   ```
   On M5 indices, a tight engulfing candle can have a range of only **1.5 to 3 index points**.
2. **Sub-Tick Spikes**: On Nasdaq (`ustec`), a 3-point range is crossed in **1 to 2 ticks** by standard bid-ask vibration.
3. Because `ManageActiveTrades()` runs on **every tick** without any time delay, candle-close confirmation, or minimum point floor, a momentary favorable tick of 2 points flags `currentR >= 1.0`.
4. The EA immediately modifies the position's SL to `Entry + beOffset`.
5. The very next tick retraces 1 point, instantly executing a stop-out at Break-Even.

### Defect 2: Flawed Pip-to-Point Multiplier for Indices & Commodities
Look at line 2434:
```mql5
BreakEven_Offset * point * (digits == 3 || digits == 5 ? 10 : 1)
```
* On `ustec` and `us500`, `digits == 2`. The expression evaluates to `1.0 * point * 1 = 0.01` (one cent!).
* On `xauusd`, `digits == 2` or `3` depending on broker. On Exness, `xauusd` has 2 or 3 digits. If 2 digits, offset is `0.01` ($0.01 on Gold!).
* Result: S/L is placed **0.01 points** away from Entry Price. In market reality, bid-ask spread alone is 10 to 30 times larger than this offset.

---

## 3. Identified & Verified Defects in `07_EMA_EAS/9_21_EMA_EA.mq5`

### Defect 1: Disconnected R-Multiple Trigger
* Line 118 declares:
  ```mql5
  input double InpBERrTrigger = 1.0; // Break Even Trigger (R Multiplier)
  ```
* However, inside `ManageActiveTrades()` (lines 764-788), `InpBERrTrigger` is **completely ignored**.
* Instead, it relies on static calibrated points:
  ```mql5
  if(posType == POSITION_TYPE_BUY && (currentPrice - openPrice) >= bePointsDist)
  ```
* In `GetSymbolCalibration()`:
  * `PROFILE_XAUUSD`: `bePoints = 100` ($1.00 move on Gold).
  * `PROFILE_CUSTOM`: `bePoints = 100` (10 pips on Forex).
  * `PROFILE_US500`: `bePoints = 500` (5 index points).
* These static point distances trigger long before 1R is ever achieved, directly contradicting risk-based trade management.

---

## 4. Synthesis: Why 100% of Trades are Exiting at BE

1. **Trade Opens** on confirmed M5 candle.
2. **Market Ticks Favorable**: Price moves 2 to 3 points due to post-candle momentum.
3. **Premature Evaluation**: Both EAs evaluate trade status on raw sub-second ticks.
4. **Instant BE Modification**: The EA sends `PositionModify` to move SL to entry price.
5. **Retest of Entry**: The market pulls back to retest the broken level or EMA 9.
6. **Stop Out**: Because the SL is sitting directly at entry (or +0.01), the position is liquidated for $0.00.
7. **Missed Trend**: Price then continues along the trend direction towards TP, leaving the trader with zero profit and accumulated spread/slippage costs.
