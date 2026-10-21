# Multi-Asset Auto-Adaptive Calibration Specification

**Author**: Hemanth Ranam  
**Repository**: `HR-Professional-Services/HemanthRanam-MT5-EAs`  
**Target Core Assets**: `XAUUSD` (Gold), `XAGUSD` (Silver), `US500` (S&P 500), `USTEC` (Nasdaq 100)  
**Target Scope**: All MT5 Expert Advisors in repository  
**Architecture**: Self-Calibrating Single-File Standalone MQL5 Architecture  

---

## 1. Executive Master Specification Prompt

```markdown
### MASTER INSTRUCTION — Multi-Asset Self-Calibrating Architecture for MT5 EAs

Implement an intelligent, multi-asset auto-adaptive volatility calibration engine inside each single-file MT5 Expert Advisor in the repository.

1. ARCHITECTURAL MANDATES:
   - Standalone single-file architecture: Use standard MT5 platform includes (<Trade\Trade.mqh>, <Trade\SymbolInfo.mqh>, <Trade\PositionInfo.mqh>, <Trade\AccountInfo.mqh>) only.
   - Clean, highly organized input parameters categorized using `input group`.
   - Asset Profile Enum (`ENUM_ASSET_PROFILE`) providing:
     * PROFILE_AUTO_DETECT (Default): Autonomously detects symbol from chart name and applies institutional optimal defaults.
     * PROFILE_XAUUSD: Gold optimized defaults.
     * PROFILE_XAGUSD: Silver optimized defaults.
     * PROFILE_US500: S&P 500 index CFD optimized defaults.
     * PROFILE_USTEC: Nasdaq 100 index CFD optimized defaults.
     * PROFILE_CUSTOM: Respects manual user-configured point inputs.
   - Closed-bar anti-repainting execution: All trading decisions use closed bars (Bar 1) with `ArraySetAsSeries(..., true)`.
   - Risk management: Maximum 1.0% equity risk per trade hard-capped dynamically via exact monetary tick value formula.
   - Position & Magic Number isolation: Every EA operates independently via unique Magic Number.

2. QUANTITATIVE CALIBRATION MATRIX (Verified Broker Constraints):
   - XAUUSD: Digits 2/3, Point 0.01/0.001, MinSL 100 pts ($1.00), BE 100 pts ($1.00), Safety 10 pts ($0.10), Trail 10 pts ($0.10), MaxSpread 50 pts ($0.50).
   - XAGUSD: Digits 3, Point 0.001, MinSL 80 pts ($0.080), BE 120 pts ($0.120), Safety 15 pts ($0.015), Trail 15 pts ($0.015), MaxSpread 35 pts ($0.035). Contract 5,000 oz.
   - US500: Digits 2, Point 0.01, MinSL 350 pts ($3.50), BE 500 pts ($5.00), Safety 50 pts ($0.50), Trail 50 pts ($0.50), MaxSpread 120 pts ($1.20).
   - USTEC: Digits 2, Point 0.01, MinSL 2500 pts ($25.00), BE 3500 pts ($35.00), Safety 300 pts ($3.00), Trail 300 pts ($3.00), MaxSpread 300 pts ($3.00).

3. COMPILATION & VERIFICATION:
   - Compile every modified EA using MetaEditor CLI (0 errors, 0 warnings).
   - Synchronize all changes to GitHub and record commit hashes in CHANGELOG_INTERNAL.md.
```

---

## 2. Institutional Volatility & Contract Calibration Matrix

| Parameter / Metric | Gold (`XAUUSD`) | Silver (`XAGUSD`) | S&P 500 (`US500`) | Nasdaq 100 (`USTEC`) | Unit / Meaning |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Typical Digits** | 2 or 3 | 3 | 2 | 2 | Broker Decimal Digits |
| **Typical Point** | 0.01 or 0.001 | 0.001 | 0.01 | 0.01 | Smallest price change |
| **Contract Size** | 100 oz | 5,000 oz | 1 contract | 1 contract | Units per 1.0 lot |
| **$1.00 Price Move PnL** | **$100.00** | **$5,000.00** | **$1.00** | **$1.00** | Monetary leverage per lot |
| **Average M5 Candle Range**| ~$2.50 (250 pts) | ~$0.091 (91 pts) | ~$4.64 (464 pts) | ~$31.50 (3,150 pts)| Empirical M5 Volatility |
| **`InpMaxSpreadPoints`** | **50 points** ($0.50) | **35 points** ($0.035) | **120 points** ($1.20) | **300 points** ($3.00) | Spread filter rejection limit |
| **`InpMinSLPoints`** | **100 points** ($1.00) | **80 points** ($0.080) | **350 points** ($3.50) | **2,500 points** ($25.00)| Minimum SL distance floor |
| **`InpBEPoints`** | **100 points** ($1.00) | **120 points** ($0.120)| **500 points** ($5.00) | **3,500 points** ($35.00)| Break-Even expansion threshold |
| **`InpBESafetyPoints`** | **10 points** ($0.10) | **15 points** ($0.015) | **50 points** ($0.50) | **300 points** ($3.00) | Buffer over entry upon BE lock |
| **`InpTrailingStepPoints`**| **10 points** ($0.10) | **15 points** ($0.015) | **50 points** ($0.50) | **300 points** ($3.00) | Trailing modification step |
| **`InpTPRatio`** | **3 (1:3 RR)** | **3 (1:3 RR)** | **3 (1:3 RR)** | **3 (1:3 RR)** | Reward-to-Risk ratio |
| **`InpRiskPercent`** | **1.0%** | **1.0%** | **1.0%** | **1.0%** | Max equity risk per trade |

---

## 3. Core Implementation Blueprint

Every EA incorporates the following standardized structure:

```mql5
//--- Asset Profiles
enum ENUM_ASSET_PROFILE
{
   PROFILE_AUTO_DETECT = 0, // Auto-Detect from Chart Symbol
   PROFILE_XAUUSD      = 1, // Gold (XAUUSD) Optimized Defaults
   PROFILE_XAGUSD      = 2, // Silver (XAGUSD) Optimized Defaults
   PROFILE_US500       = 3, // S&P 500 (US500) Optimized Defaults
   PROFILE_USTEC       = 4, // Nasdaq 100 (USTEC) Optimized Defaults
   PROFILE_CUSTOM      = 5  // Manual Custom Inputs Below
};

//--- Input Groups
input group "=== Asset Profile & Auto-Calibration ==="
input ENUM_ASSET_PROFILE InpAssetProfile       = PROFILE_AUTO_DETECT; // Asset Volatility Profile

input group "=== Strategy Parameters ==="
input int                InpEMAPeriod         = 9;              // Primary Indicator Period
input ENUM_TIMEFRAMES    InpHTFTimeframe      = PERIOD_H1;      // Higher Timeframe Trend Filter
input int                InpTPRatio           = 3;              // Reward to Risk Ratio (1:N)
input int                InpMinSLPoints       = 100;            // Minimum SL Floor Distance (Points, Custom only)

input group "=== Risk Management ==="
input double             InpRiskPercent       = 1.0;            // Max Risk % per Trade (Max 1.0%)
input bool               InpUseEquityForRisk  = true;           // Calculate Risk on Equity (true) or Balance (false)
input int                InpMaxPositions      = 1;              // Max Concurrent Positions
input int                InpMaxSpreadPoints   = 50;             // Max Allowed Spread (Points, Custom only)
input ulong              InpDeviationPoints   = 20;             // Max Slippage Deviation (Points)

input group "=== Position Management & Trailing ==="
input bool               InpUseBE             = true;           // Enable Break-Even Protection
input int                InpBEPoints          = 100;            // Profit in Points to Trigger BE (Custom only)
input int                InpBESafetyPoints    = 10;             // Profit Buffer Above/Below Entry (Custom only)
input bool               InpUseTrailing       = true;           // Enable Trailing Stop
input int                InpTrailingStepPoints= 10;             // Minimum Improvement to Modify SL (Custom only)

input group "=== Session Filtering (Broker Time) ==="
input bool               InpFilterSessions    = true;           // Restrict Trading to Active Market Windows
input int                InpLondonStartHour   = 8;              // Session Start Hour (Broker Time)
input int                InpNYCloseHour       = 22;             // Session End Hour (Broker Time)
input bool               InpCloseFridayLate   = true;           // Restrict Late Friday Entries
input int                InpFridayCloseHour   = 20;             // Friday Entry Cutoff Hour

input group "=== Order Routing & Isolation ==="
input ulong              InpMagicNumber       = 909001;         // Unique Magic Number
input string             InpTradeComment      = "9 EMA PRO Scalper"; // Execution Tag
```

### Dynamic Auto-Calibration Routine in `OnInit()`:

```mql5
void ApplyAssetCalibration()
{
   ENUM_ASSET_PROFILE profile = InpAssetProfile;

   if(profile == PROFILE_AUTO_DETECT)
   {
      string sym = _Symbol;
      StringToUpper(sym);
      if(StringFind(sym, "XAU") >= 0 || StringFind(sym, "GOLD") >= 0)
         profile = PROFILE_XAUUSD;
      else if(StringFind(sym, "XAG") >= 0 || StringFind(sym, "SILVER") >= 0)
         profile = PROFILE_XAGUSD;
      else if(StringFind(sym, "500") >= 0 || StringFind(sym, "SPX") >= 0)
         profile = PROFILE_US500;
      else if(StringFind(sym, "100") >= 0 || StringFind(sym, "TEC") >= 0 || StringFind(sym, "NAS") >= 0)
         profile = PROFILE_USTEC;
      else
         profile = PROFILE_CUSTOM;
   }

   switch(profile)
   {
      case PROFILE_XAUUSD:
         activeMaxSpread = 50;
         activeMinSL     = 100;
         activeBE        = 100;
         activeBESafety  = 10;
         activeTrailStep = 10;
         break;
      case PROFILE_XAGUSD:
         activeMaxSpread = 35;
         activeMinSL     = 80;
         activeBE        = 120;
         activeBESafety  = 15;
         activeTrailStep = 15;
         break;
      case PROFILE_US500:
         activeMaxSpread = 120;
         activeMinSL     = 350;
         activeBE        = 500;
         activeBESafety  = 50;
         activeTrailStep = 50;
         break;
      case PROFILE_USTEC:
         activeMaxSpread = 300;
         activeMinSL     = 2500;
         activeBE        = 3500;
         activeBESafety  = 300;
         activeTrailStep = 300;
         break;
      case PROFILE_CUSTOM:
      default:
         activeMaxSpread = InpMaxSpreadPoints;
         activeMinSL     = InpMinSLPoints;
         activeBE        = InpBEPoints;
         activeBESafety  = InpBESafetyPoints;
         activeTrailStep = InpTrailingStepPoints;
         break;
   }
}
```

---

## 4. Complete Repository Rollout Inventory

All Expert Advisors in `HemanthRanam-MT5-EAs` adhere to the calibrated architecture:

| EA Directory | File Name | Magic Number | Default Target / Role | Status |
| :--- | :--- | :--- | :--- | :--- |
| `07_EMA_EAS/` | `9_EMA_EA.mq5` | `909001` | M5 Scalper + H1 Trend Filter | **Verified & Compiled (0 errors, 0 warnings)** |
| `07_EMA_EAS/` | `21_EMA_EA.mq5` | `212101` | M5 Scalper + H1 Trend Filter | **Verified & Compiled (0 errors, 0 warnings)** |
| `07_EMA_EAS/` | `50_EMA_EA.mq5` | `505001` | M5 Medium-Term Trend Continuation | **Verified & Compiled (0 errors, 0 warnings)** |
| `07_EMA_EAS/` | `100_EMA_EA.mq5` | `100100` | M5 Macro Trend Continuation | **Verified & Compiled (0 errors, 0 warnings)** |
| `07_EMA_EAS/` | `9_21_EMA_EA.mq5` | `9212026` | Dual EMA Pullback + Multi-Symbol Scanner | **Verified & Compiled (0 errors, 0 warnings)** |
| `01_LIQUIDITY_SWEEP/` | `LIQUIDITY_SWEEP_REVERSAL_EA.mq5` | `101001` | Multi-Asset Sweep Reclaim Engine | **Verified & Compiled (0 errors, 0 warnings)** |
| `02_TREND_PULLBACK/` | `TREND_PULLBACK_CONTINUATION_EA.mq5` | `102002` | Multi-Asset EMA Corridor Continuation | **Verified & Compiled (0 errors, 0 warnings)** |
| `03_VOLATILITY_BREAKOUT/` | `VOLATILITY_EXPANSION_BREAKOUT_EA.mq5` | `103003` | Multi-Asset Volatility Contraction Breakout | **Verified & Compiled (0 errors, 0 warnings)** |
| `04_STRUCTURE_MOMENTUM/` | `MARKET_STRUCTURE_MOMENTUM_EA.mq5` | `104004` | Multi-Asset Market Structure BOS/CHoCH | **Verified & Compiled (0 errors, 0 warnings)** |
| `05_ADAPTIVE_REGIME/` | `ADAPTIVE_MARKET_REGIME_EA.mq5` | `105005` | Multi-Asset Adaptive Statistical Regime | **Verified & Compiled (0 errors, 0 warnings)** |
| `06_MULTI_PAIR_SCANNERS/`| `9_21_EMA_MULTI_PAIR_SCANNER_EA.mq5` | `9212026` | 9-21 Multi-Pair Virtual Scanner | **Verified & Compiled (0 errors, 0 warnings)** |
| `06_MULTI_PAIR_SCANNERS/`| `MULTI_PAIR_SCANNER_V1_EA.mq5` | `921001` | Multi-Pair Institutional Scanner V1 | **Verified & Compiled (0 errors, 0 warnings)** |
| `06_MULTI_PAIR_SCANNERS/`| `MULTI_PAIR_SCANNER_V2_EA.mq5` | `921002` | Multi-Pair Institutional Scanner V2 | **Verified & Compiled (0 errors, 0 warnings)** |
| `08_MULTI_STRATEGY_SCANNERS/`| `MULTI_STRATEGY_SCANNER_EA.mq5` | `808001` | Multi-Strategy Execution Hub | **Verified & Compiled (0 errors, 0 warnings)** |

---

## 5. Verified Preset Profiles (`.set`)

Pre-calibrated test profiles deployed in `Tests_And_Reports/Presets/` and mirrored to MT5 Tester directory:

1. `9_EMA_XAUUSD.set`: Gold M5 Scalper (Spread 50 pts, MinSL 100 pts, BE 100 pts, Safety 10 pts, Trail 10 pts)
2. `9_EMA_XAGUSD.set`: Silver M5 Momentum (Spread 35 pts, MinSL 80 pts, BE 120 pts, Safety 15 pts, Trail 15 pts)
3. `9_EMA_US500.set`: S&P 500 Index Scalper (Spread 120 pts, MinSL 350 pts, BE 500 pts, Safety 50 pts, Trail 50 pts)
4. `9_EMA_USTEC.set`: Nasdaq 100 Index Scalper (Spread 300 pts, MinSL 2500 pts, BE 3500 pts, Safety 300 pts, Trail 300 pts)

