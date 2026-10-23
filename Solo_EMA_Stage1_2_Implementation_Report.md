# Solo EMA Suite: Stage 1 & Stage 2 Implementation Report

**Repository:** `C:\Users\vaibh\.gemini\antigravity-ide\scratch\HemanthRanam-MT5-EAs`  
**Branch:** `main` (HEAD commit `7b52e47`)  
**Scope Files:**
- `07_EMA_EAS/9_EMA_EA.mq5`
- `07_EMA_EAS/21_EMA_EA.mq5`
- `07_EMA_EAS/50_EMA_EA.mq5`
- `07_EMA_EAS/100_EMA_EA.mq5`

---

## 1. Executive Summary & Verification Checkpoints

Stage 1 (Mathematical Correctness & Volume Safety) and Stage 2 (Trend & Candle Quality Filters) have been implemented across all four solo EMA Expert Advisors.

### Strict Safeguards Enforced:
1. **Preserved EA Identity & Parameters:**
   - 9 EMA EA: `InpEMAPeriod = 9`, `InpMagicNumber = 909001`, Tag: `"9 EMA PRO Scalper"`
   - 21 EMA EA: `InpEMAPeriod = 21`, `InpMagicNumber = 212101`, Tag: `"21 EMA PRO Scalper"`
   - 50 EMA EA: `InpEMAPeriod = 50`, `InpMagicNumber = 505001`, Tag: `"50 EMA PRO Trend"`
   - 100 EMA EA: `InpEMAPeriod = 100`, `InpMagicNumber = 100100`, Tag: `"100 EMA PRO Trend"`
2. **Preserved Archived Copies:**
   - Untouched `Archive/Single_EMAs/` files remain 100% intact matching initial baseline hashes.
3. **No Unstaged Commit / No Branch Switch / No Remote Push:**
   - Changes are staged in local working tree only; awaiting explicit approval.

---

## 2. Before & After SHA-256 Hashes

| EA File | Original SHA-256 Hash | Post-Implementation SHA-256 Hash |
| :--- | :--- | :--- |
| **`9_EMA_EA.mq5`** | `D18874174B6D26BA91DC3AC1B36161B13D277D58604100EA887364A7262DC6DD` | `3EFE66A194D9648A552F98FCE37470E83D3DD12EA3671C01D2263BEB36B0F930` |
| **`21_EMA_EA.mq5`** | `554046A132759309B2C0A669B58F33D1E8367B9F279F75925517EB3B08EAA22D` | `1A38DAFE97CE83DF69109CE429085928D271CFC494D8B28763687C97BF0110AC` |
| **`50_EMA_EA.mq5`** | `B95659295AD21A1ADBF784ED815224292FE391FFCA729E80B69313C3039EEDBE` | `66841A7B8617B4B5643A8134F577867E186D961531457BC1D5EF532169D48B4C` |
| **`100_EMA_EA.mq5`** | `2C6156A4AE5B478287C890A07DD65BA031E9F683E7ABB4E6940A4E62F38DED07` | `DD0731210C422CE691108ADBBCEBCF9A9F6CDBAECB73B12DD322D6DC409AA2BC` |

---

## 3. Implementation Details by Stage

### 3.1 Stage 1 — Mathematical Correctness & Volume Expansion Isolation

1. **`NormalizePriceToTick(double price)` Added:**
   - Normalizes any price coordinate directly to `SYMBOL_TRADE_TICK_SIZE`.
   - Prevents `TRADE_RETCODE_INVALID_STOPS` or `INVALID_PRICE` rejections on instruments with fractional tick granularity (e.g. 0.25 on US500, 0.5 on USTEC).
   - Applied across all execution and modification paths:
     - `price` in `ExecuteTrade`
     - `sl` and `tp` initial order placement in `ExecuteTrade`
     - `desiredBE` in `ManagePositions` (Break-Even protection)
     - `newSL` in `ManagePositions` (Closed candle trailing stop)
2. **Volume Expansion Calculation Isolated from Trigger Bar:**
   - Previous logic copied from `candleIndex` (bar 1) into an array where trigger bar was inside the buffer slice.
   - New logic strictly decouples:
     - **Trigger Bar 1 Volume:** Copied individually via `CopyRealVolume(_Symbol, _Period, candleIndex, 1, triggerVol)`. If Real Volume is unavailable or zero, falls back to `CopyTickVolume`.
     - **Baseline Lookback Window [2..Lookback+1]:** Copied starting strictly at `candleIndex + 1` for `InpVolumeLookback` elements.
     - **Strict Validation & Rejection:** If volume data is zero, missing, unreadable, or contains fewer than 50% valid bars, `CheckVolumeExpansion` safely returns `false`. Unconfirmed volume never permits order execution.
   - Documented in header comment: broker tick volume represents local tick frequency, not centralized exchange volume.

### 3.2 Stage 2 — Trend & Candle Quality Filters

1. **Higher-Timeframe EMA Slope Agreement Filter:**
   - New inputs:
     - `InpUseHTFSlopeFilter` (default: `false` for backwards compatibility)
     - `InpHTFMinSlopePoints` (default: `0.0` points)
   - Evaluates completed closed bars only (`emaHTF[1]` vs `emaHTF[2]`).
   - Ensures:
     - For BUY: `(emaHTF[1] - emaHTF[2]) / _Point >= InpHTFMinSlopePoints`
     - For SELL: `(emaHTF[2] - emaHTF[1]) / _Point >= InpHTFMinSlopePoints`
   - Safely invalidates bias if HTF EMA is flat or sloping against the trade direction.
2. **Trigger Candle Body-to-Range Quality Filter:**
   - New inputs:
     - `InpUseBodyQuality` (default: `false` for backwards compatibility)
     - `InpMinBodyRatio` (default: `0.40`, meaning candle body must comprise at least 40% of the total candle range)
   - Formula:
     - `candleRange = High[1] - Low[1]`
     - `candleBody = MathAbs(Close[1] - Open[1])`
     - Zero-range division guard: `if(candleRange <= 0.0 || (candleBody / candleRange) < InpMinBodyRatio) isBodyQualityOk = false;`
   - Suppresses low-conviction spinning tops, dojis, and long wick indecision bars.
3. **Indicator Buffer Safety:**
   - `CopyBuffer(handleEMA_HTF, 0, 0, 3, emaHTF)` updated to fetch 3 bars (0, 1, 2) with return count check `< 3`.

---

## 4. MetaEditor 64 Compilation Evidence

Each EA was compiled independently using MetaEditor 64 CLI:

```powershell
07_EMA_EAS\9_EMA_EA.mq5   -> Result: 0 errors, 0 warnings, 1443 ms elapsed, cpu='X64 Regular'
07_EMA_EAS\21_EMA_EA.mq5  -> Result: 0 errors, 0 warnings, 1376 ms elapsed, cpu='X64 Regular'
07_EMA_EAS\50_EMA_EA.mq5  -> Result: 0 errors, 0 warnings, 1432 ms elapsed, cpu='X64 Regular'
07_EMA_EAS\100_EMA_EA.mq5 -> Result: 0 errors, 0 warnings, 1428 ms elapsed, cpu='X64 Regular'
```

- **Clean Build:** 0 errors, 0 warnings across all 4 files.
- Transient `.ex5` and log files have been scrubbed.

---

## 5. Stop Condition Checkpoint

- **Scope Status:** Stage 1 & Stage 2 complete.
- **Unresolved Blockers:** None.
- **Next Potential Phase:** Awaiting authorization for Stage 3 (Stops, Exits & Multi-Tier Risk Engine) or Stage 4 (Dynamic Volatility Calibration).
