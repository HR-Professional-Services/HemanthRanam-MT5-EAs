# Solo EMA Scalping Suite — Stage 3: Structural Stop-Loss & ATR Protection Report

**Date:** 2026-10-23  
**Repository:** `C:\Users\vaibh\.gemini\antigravity-ide\scratch\HemanthRanam-MT5-EAs`  
**Git Branch:** `main` (commit `7b52e47`)  
**Scope:** Stage 3 only from `Solo_EMA_Suite_Source_Audit_and_Development_Plan.md`.

---

## 1. Executive Summary

Stage 3 has been successfully implemented across all four solo EMA Expert Advisors (`9_EMA_EA.mq5`, `21_EMA_EA.mq5`, `50_EMA_EA.mq5`, and `100_EMA_EA.mq5`). 

All four EAs now replace single-bar low/high stop placements with **dynamic multi-bar structural swing extremes**, cushioned by an **ATR-based volatility buffer** and bounded by broker stop-level minimums and defensible maximum-distance guards. All positions are sized using the post-tick-normalized distance to ensure absolute adherence to the 1.0% equity risk ceiling.

All four EAs compiled cleanly with **MetaEditor 64 (build 5420)** with **0 errors and 0 warnings**.

---

## 2. Pre- and Post-Change File Verification

### Archive Preserved Integrity
The baseline reference copies in `Archive/Single_EMAs/` remain 100% pristine and unaltered:
- `Archive/Single_EMAs/9_EMA_EA.mq5`: `D18874174B6D26BA91DC3AC1B36161B13D277D58604100EA887364A7262DC6DD`
- `Archive/Single_EMAs/21_EMA_EA.mq5`: `554046A132759309B2C0A669B58F33D1E8367B9F279F75925517EB3B08EAA22D`
- `Archive/Single_EMAs/50_EMA_EA.mq5`: `B95659295AD21A1ADBF784ED815224292FE391FFCA729E80B69313C3039EEDBE`
- `Archive/Single_EMAs/100_EMA_EA.mq5`: `2C6156A4AE5B478287C890A07DD65BA031E9F683E7ABB4E6940A4E62F38DED07`

### Active Target Files: Stage 1 & 2 vs Stage 3 SHA-256 Hashes
| File | Stage 1 & 2 SHA-256 (Before Stage 3) | Stage 3 SHA-256 (After Stage 3) | Compilation Status |
| :--- | :--- | :--- | :--- |
| `07_EMA_EAS/9_EMA_EA.mq5` | `A07A07EBF62590BF9956C816E870425FE48A76B8EBC2CF5F7DFBC81084E677F6` | `7E8F9BF5F4AB340B0529DCAFC6DD37CFBBF3FC887D4F743FE236984B21E8E9A3` | **0 errors, 0 warnings** |
| `07_EMA_EAS/21_EMA_EA.mq5` | `2BFBCDA7C53DF176DA3BE7E57C32431713B44DED48A6ED076326BD6823F07B57` | `A0B9BB666FC3685483A561F645CBAD4830D6E17C191A8777F08C14D66DFDC54D` | **0 errors, 0 warnings** |
| `07_EMA_EAS/50_EMA_EA.mq5` | `F39F80E53F9B93F3841D3B5145EF026D7B4810AF0820F0D24B3EB4DF0B3E743A` | `86C4A0B8084F94611E5E893B93AFCBC384A548FE96BED6039BBC9D4931A6A503` | **0 errors, 0 warnings** |
| `07_EMA_EAS/100_EMA_EA.mq5` | `102CFB2DF6E74B3BA2794D0238C9BA2939BC008D0B3454B98E901E7870A37D1D` | `7DC872334A6F80BFBAA584B3431CDB9887AA3498A0955FC60F5464DEAC2DE5AA` | **0 errors, 0 warnings** |

---

## 3. Detailed Structural Stop-Loss & ATR Design

### 3.1 Input Parameters Added
Each EA has received an identical, self-documenting input group:
```mql5
input group "=== Structural Stop-Loss & ATR Protection (Stage 3) ==="
input bool            InpUseStructuralSL   = true;           // Enable Multi-Bar Swing Structure SL (Completed Bars)
input int             InpSwingLookback     = 5;              // Swing High/Low Lookback Window (Completed Bars)
input bool            InpUseATRBuffer      = true;           // Apply ATR Volatility Buffer Beyond Swing Structure
input int             InpATRPeriod         = 14;             // ATR Smoothing Period
input double          InpATRMultiplier     = 1.0;            // ATR Multiplier for Safety Buffer (e.g. 1.0x ATR)
input int             InpMaxSLPoints       = 1000;           // Maximum Defensible SL Guard in Points (0 = Disabled)
```
*Engineering Defaults Notice:* All defaults are safe engineering baselines and are explicitly labeled **untested**, not optimized or guaranteed profitable for live deployment.

### 3.2 Anti-Lookahead Swing Identification
- Evaluated strictly across completed bars `[1 .. lookback]` using `iLowest(_Symbol, _Period, MODE_LOW, lookback, 1)` for BUY orders and `iHighest(_Symbol, _Period, MODE_HIGH, lookback, 1)` for SELL orders.
- Bar 0 (currently forming) is never queried, guaranteeing zero look-ahead bias and anti-repainting integrity.
- If `iLowest`/`iHighest` returns `< 0` or the retrieved price is `<= 0.0`, the EA logs a descriptive error and **rejects the trade**.

### 3.3 ATR Volatility Buffer Placement
- Indicator handle `handleATR` is initialized in `OnInit()` via `iATR(_Symbol, _Period, MathMax(1, InpATRPeriod))` and released cleanly in `OnDeinit()`.
- During execution, the completed bar 1 ATR value is fetched (`CopyBuffer(handleATR, 0, 1, 1, atrValues)`).
- If the handle is invalid or ATR copying fails/returns `<= 0.0`, the trade is rejected cleanly.
- Volatility buffer: `atrBuffer = atrValues[0] * MathMax(0.0, InpATRMultiplier)`.
- Initial stop placement:
  - BUY: `structuralSL = rawSwing - atrBuffer; rawDist = price - structuralSL;`
  - SELL: `structuralSL = rawSwing + atrBuffer; rawDist = structuralSL - price;`

### 3.4 Broker Stop Levels, Tick Normalization & Risk Sizing Flow
1. **Floor Enforcement:** `slDist = MathMax(rawDist, GetMinimumStopDistance())` enforces `SYMBOL_TRADE_STOPS_LEVEL`, current spread, and asset-calibrated minimum SL.
2. **Defensible Ceiling Guard:** If `InpMaxSLPoints > 0` and `slDist > InpMaxSLPoints * _Point`, the trade is rejected with `[SL_REJECT]` logging.
3. **Tick Rounding:** Target `sl` and `tp` are normalized using `NormalizePriceToTick()`.
4. **Post-Normalization Revalidation:** `finalSLDist = MathAbs(price - sl)`. If `finalSLDist < GetMinimumStopDistance()`, the trade is aborted to prevent broker rejection.
5. **Monetary Lot Sizing:** `CalculateLotSize(finalSLDist / _Point)` uses `finalSLDist`. Because volume step uses `MathFloor(lot / lotStep) * lotStep`, position size is strictly rounded down, ensuring risk never inflates above the 1.0% equity cap.

### 3.5 Break-Even and Trailing Stop Compatibility
- Existing Stage 1 & 2 position management (`ManagePositions`) remains completely intact.
- Trailing stops continue to respect `NormalizePriceToTick` and `GetMinimumStopDistance()`.
- Stops are never loosened: BUY trailing checks `newSL > currentSL + (activeTrailStep * point)` and preserves secured break-even levels.

---

## 4. Compilation Verification Evidence

Batch compilation was executed directly against `C:\Program Files\MetaTrader 5\MetaEditor64.exe` (X64 Regular build 5420):
```
07_EMA_EAS\9_EMA_EA.mq5   => Result: 0 errors, 0 warnings, 1315 ms elapsed
07_EMA_EAS\21_EMA_EA.mq5  => Result: 0 errors, 0 warnings, 1353 ms elapsed
07_EMA_EAS\50_EMA_EA.mq5  => Result: 0 errors, 0 warnings, 1366 ms elapsed
07_EMA_EAS\100_EMA_EA.mq5 => Result: 0 errors, 0 warnings, 1389 ms elapsed
```

---

## 5. Scope Compliance & Unresolved Risks

1. **Scope Compliance:** Only Stage 3 was implemented. No Stage 4 portfolio exposure managers, no Stage 5 asset calibration tables, and no Stage 6 multi-pair tests were run.
2. **Git Hygiene:** Zero commits or pushes were made. All changes remain staged in the working tree.
3. **Unresolved Risks:**
   - Default parameters (`lookback = 5`, `ATR = 14`, `1.0x ATR multiplier`, `MaxSL = 1000`) are engineering baselines and require formal asset-specific walk-forward calibration before live capital deployment.
   - On low-liquidity or high-volatility spikes, swing stops plus ATR buffers may occasionally exceed `InpMaxSLPoints`, resulting in intentional trade rejections (defensive behaviour).
