//+------------------------------------------------------------------+
//|                                  HR_UNIFIED_MULTI_STRATEGY_EA.mq5|
//|                                    Copyright 2026, Hemanth Ranam |
//|                             https://github.com/HR-Professional-Services |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, Hemanth Ranam"
#property link        "https://github.com/HR-Professional-Services/HemanthRanam-MT5-EAs"
#property version     "1.00"
#property description "HR Unified Multi-Strategy Trading System."
#property description "Single-chart multi-instrument EA managing 4 assets through 8 independent strategy modules."

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\OrderInfo.mqh>

//====================================================================
// SECTION 1: GLOBAL CONSTANTS & ENUMERATIONS
//====================================================================
#define NUM_INSTRUMENTS 4
#define NUM_STRATEGIES  8

enum ENUM_STRATEGY_ID
{
   STRAT_9_EMA              = 0, // S1: 9 EMA Momentum Scalper
   STRAT_21_EMA             = 1, // S2: 21 EMA Pullback Scalper
   STRAT_50_EMA             = 2, // S3: 50 EMA Trend Re-Test
   STRAT_100_EMA            = 3, // S4: 100 EMA Regime Cloud Scalper
   STRAT_LIQUIDITY_SWEEP    = 4, // S5: Liquidity Sweep & Reversal
   STRAT_TREND_PULLBACK     = 5, // S6: Trend Pullback Continuation
   STRAT_VOLATILITY_BREAKOUT= 6, // S7: Volatility Expansion Breakout
   STRAT_STRUCTURE_MOMENTUM = 7  // S8: Market Structure Momentum (BOS)
};

enum ENUM_BROKER_DST_MODE
{
   BROKER_DST_NONE = 0,
   BROKER_DST_US   = 1,
   BROKER_DST_EU   = 2
};

//+------------------------------------------------------------------+
//| Section 2: Input Parameters                                      |
//+------------------------------------------------------------------+
input group "=== [00] MASTER PORTFOLIO RISK & ENGINE GUARDS ==="
input bool     InpMasterTradingEnable       = true;    // Master Trading Enable Switch
input double   InpPerTradeRiskPercent       = 0.5;     // Per-Trade Risk (% of Equity, Max 1.0%)
input double   InpMaxDailyDrawdownPercent   = 3.0;     // Max Daily Drawdown Stop (% of Start Equity)
input double   InpMaxPortfolioRiskPercent   = 5.0;     // Max Aggregate Open Risk (% of Equity)
input int      InpMaxTotalOpenPositions     = 4;       // Max Total Open Positions Across System
input int      InpMaxPositionsPerSymbol     = 1;       // Max Open Positions Per Symbol
input int      InpConsecutiveLossLimit      = 3;       // Consecutive Loss Streak before Cooldown
input int      InpConsecutiveLossCooldownMin= 60;      // Cooldown Duration after Loss Limit (Minutes)
input ulong    InpMasterMagicBase           = 900000;  // Master Magic Base (Module = Base + SymIdx*10 + StratIdx)

input group "=== [01] TIME & SESSION GUARDS (UK TIME) ==="
input bool     InpEnableSessionFilter       = true;    // Enable UK Local Session Gating (08:00 - 22:00 UK)
input int      InpUKSessionStartHour        = 8;       // UK Session Start Hour (08:00)
input int      InpUKSessionStartMin         = 0;       // UK Session Start Minute
input int      InpUKSessionEndHour          = 22;      // UK Session End Hour (22:00)
input int      InpUKSessionEndMin           = 0;       // UK Session End Minute
input int      InpBrokerGMTOffset           = 2;       // Broker Base GMT Offset (Winter: +2 for Exness)
input ENUM_BROKER_DST_MODE InpBrokerDstMode = BROKER_DST_US; // Broker DST Schedule (US standard)
input bool     InpEnableFridayClose         = true;    // Enable Friday Weekend Close
input int      InpFridayCloseHourUK         = 21;      // Friday Close Hour UK (21 = 21:00 UK)
input int      InpFridayCloseMinUK          = 30;      // Friday Close Minute UK (30 = 21:30 UK)
input bool     InpEnableRolloverBlackout    = true;    // Rollover Blackout (21:55 - 22:15 GMT)

input group "=== [02] ON-CHART DASHBOARD ==="
input bool     InpShowDashboard             = true;    // Display Live On-Chart Dashboard
input int      InpDashboardRefreshMs        = 1000;    // Dashboard Redraw Throttling (ms)

input group "=== [03] INSTRUMENT 0: XAUUSD (GOLD) CONFIGURATION ==="
input bool     InpXAU_EnableSymbol          = true;    // Enable Scanning on Gold
input string   InpXAU_CustomSymbol          = "XAUUSD"; // Custom Symbol Name / Alias
input int      InpXAU_MaxSpreadPoints       = 75;      // Max Spread Points (Verified Phase 11 Realignment)
input int      InpXAU_MaxSLPoints           = 1500;    // Max SL Distance Ceiling (Points)
input bool     InpXAU_Enable_9EMA           = true;    // Gold: Enable 9 EMA Scalper (Demo Evaluation)
input bool     InpXAU_Enable_21EMA          = false;   // Gold: Enable 21 EMA Scalper (Disabled - Insufficient Edge)
input bool     InpXAU_Enable_50EMA          = false;   // Gold: Enable 50 EMA Scalper (Disabled - Low Sample)
input bool     InpXAU_Enable_100EMA         = true;    // Gold: Enable 100 EMA Scalper (Demo Evaluation)
input bool     InpXAU_Enable_LiqSweep       = true;    // Gold: Enable Liquidity Sweep Reversal (Validated)
input bool     InpXAU_Enable_TrendPullback  = true;    // Gold: Enable Trend Pullback Continuation
input bool     InpXAU_Enable_VolBreakout    = true;    // Gold: Enable Volatility Expansion Breakout
input bool     InpXAU_Enable_StructMomentum = true;    // Gold: Enable Market Structure Momentum

input group "=== [04] INSTRUMENT 1: XAGUSD (SILVER) CONFIGURATION ==="
input bool     InpXAG_EnableSymbol          = false;   // Enable Scanning on Silver (Default OFF per Phase 11 Audit)
input string   InpXAG_CustomSymbol          = "XAGUSD"; // Custom Symbol Name / Alias
input int      InpXAG_MaxSpreadPoints       = 80;      // Max Spread Points
input int      InpXAG_MaxSLPoints           = 1200;    // Max SL Distance Ceiling (Points)
input bool     InpXAG_Enable_9EMA           = false;   // Silver: Enable 9 EMA Scalper (Default OFF - Persistent Losses)
input bool     InpXAG_Enable_21EMA          = false;   // Silver: Enable 21 EMA Scalper (Default OFF - Severe Churn)
input bool     InpXAG_Enable_50EMA          = false;   // Silver: Enable 50 EMA Scalper (Default OFF - High Friction)
input bool     InpXAG_Enable_100EMA         = false;   // Silver: Enable 100 EMA Scalper (Default OFF - Range Loss)
input bool     InpXAG_Enable_LiqSweep       = false;   // Silver: Enable Liquidity Sweep Reversal (Opt-in only)
input bool     InpXAG_Enable_TrendPullback  = false;   // Silver: Enable Trend Pullback Continuation (Opt-in only)
input bool     InpXAG_Enable_VolBreakout    = false;   // Silver: Enable Volatility Expansion Breakout (Opt-in only)
input bool     InpXAG_Enable_StructMomentum = false;   // Silver: Enable Market Structure Momentum (Opt-in only)

input group "=== [05] INSTRUMENT 2: US500 (S&P 500) CONFIGURATION ==="
input bool     InpSPX_EnableSymbol          = true;    // Enable Scanning on S&P 500
input string   InpSPX_CustomSymbol          = "US500";  // Custom Symbol Name / Alias
input int      InpSPX_MaxSpreadPoints       = 60;      // Max Spread Points
input int      InpSPX_MaxSLPoints           = 1000;    // Max SL Distance Ceiling (Points - Preserved 1,000pt Rule)
input bool     InpSPX_Enable_9EMA           = true;    // US500: Enable 9 EMA Scalper (Verified Stable Baseline)
input bool     InpSPX_Enable_21EMA          = false;   // US500: Enable 21 EMA Scalper (Default OFF - Resolved 2025 Breakdown)
input bool     InpSPX_Enable_50EMA          = false;   // US500: Enable 50 EMA Scalper (Default OFF - Delayed Entry)
input bool     InpSPX_Enable_100EMA         = false;   // US500: Enable 100 EMA Scalper (Default OFF - Commission Drag)
input bool     InpSPX_Enable_LiqSweep       = true;    // US500: Enable Liquidity Sweep Reversal
input bool     InpSPX_Enable_TrendPullback  = true;    // US500: Enable Trend Pullback Continuation
input bool     InpSPX_Enable_VolBreakout    = true;    // US500: Enable Volatility Expansion Breakout
input bool     InpSPX_Enable_StructMomentum = true;    // US500: Enable Market Structure Momentum

input group "=== [06] INSTRUMENT 3: USTEC (NASDAQ 100) CONFIGURATION ==="
input bool     InpNAS_EnableSymbol          = true;    // Enable Scanning on Nasdaq 100
input string   InpNAS_CustomSymbol          = "USTEC";  // Custom Symbol Name / Alias
input int      InpNAS_MaxSpreadPoints       = 150;     // Max Spread Points
input int      InpNAS_MaxSLPoints           = 7500;    // Max SL Distance Ceiling (Points - Preserved 7,500pt Rule)
input bool     InpNAS_Enable_9EMA           = true;    // USTEC: Enable 9 EMA Scalper (Primary Demo Candidate, PF 6.80)
input bool     InpNAS_Enable_21EMA          = true;    // USTEC: Enable 21 EMA Scalper (Verified Candidate)
input bool     InpNAS_Enable_50EMA          = true;    // USTEC: Enable 50 EMA Scalper (Verified Candidate)
input bool     InpNAS_Enable_100EMA         = true;    // USTEC: Enable 100 EMA Scalper (Wick-Bounce Candidate, PF 1.76)
input bool     InpNAS_Enable_LiqSweep       = true;    // USTEC: Enable Liquidity Sweep Reversal
input bool     InpNAS_Enable_TrendPullback  = true;    // USTEC: Enable Trend Pullback Continuation
input bool     InpNAS_Enable_VolBreakout    = true;    // USTEC: Enable Volatility Expansion Breakout
input bool     InpNAS_Enable_StructMomentum = true;    // USTEC: Enable Market Structure Momentum

input group "=== [07] SHARED STRATEGY TUNING & EXECUTION PARAMETERS ==="
input ENUM_TIMEFRAMES InpExecutionTF        = PERIOD_M5;  // Core Execution Timeframe (All Modules)
input ENUM_TIMEFRAMES InpHTFTimeframe       = PERIOD_H1;  // Higher Timeframe Trend Bias
input double   InpDefaultTPRatio            = 3.0;        // Default Reward-to-Risk Ratio (1:3 per verified baseline)
input bool     InpUseVolumeFilter           = true;       // Mandatory Volume Expansion Filter (Anti-Fakeout)
input int      InpVolumeLookback            = 20;         // Volume Rolling SMA Lookback
input double   InpVolumeMultiplier         = 1.1;        // Min Volume Multiplier vs Baseline
input bool     InpUseStructuralSL           = true;       // Multi-bar Structural Swing Stop-Loss
input int      InpSwingLookback             = 5;          // Swing Lookback Bars for Structural SL (Verified baseline = 5)
input bool     InpUseATRBuffer              = true;       // ATR Volatility Stop Buffer
input int      InpATRPeriod                 = 14;         // ATR Period
input double   InpATRBufferMultiplier       = 1.0;        // ATR Stop Buffer Multiplier (Verified baseline = 1.0)
input bool     InpUseBE                     = true;       // Enable Break-Even Protection
input double   InpBETargetRR                = 1.0;        // Break-Even Trigger (R-Multiple)
input double   InpBESafetyPoints            = 10.0;       // Break-Even Safety Cushion (Points)
input bool     InpUseTrailing               = false;      // Enable Trailing Stop
input double   InpTrailingDistancePoints    = 150.0;      // Trailing Stop Distance (Points)
input double   InpTrailingStepPoints        = 50.0;       // Trailing Stop Step (Points)
input ulong    InpSlippagePoints            = 10;         // Max Slippage Tolerance (Points)
input double   InpCommissionPerLot          = 7.0;        // Round-turn Commission per Lot ($)

// Institutional Specific Inputs
input int      InpSweepSwingLookback        = 24;         // S5 Sweep: Swing Lookback Bars
input double   InpSweepMinDisplacementR     = 0.50;       // S5 Sweep: Min Candle Reversal Displacement
input int      InpVolCompressionBars        = 20;         // S7 VolBreakout: Compression Window Bars
input double   InpVolMaxCompressionATR     = 1.5;        // S7 VolBreakout: Max Compression Width vs ATR
input int      InpStructPivotStrength       = 2;          // S8 BOS: Pivot High/Low Strength (Bars)
input double   InpStructRSIMin              = 50.0;       // S8 BOS: Min Momentum RSI on Trigger

//+------------------------------------------------------------------+
//| Section 3: Data Structures & State Management                    |
//+------------------------------------------------------------------+
struct StrategyConfig
{
   bool              enabled;
   ulong             magicNumber;
   string            name;
   string            tag;
};

struct InstrumentRuntime
{
   string            baseName;
   string            resolvedSymbol;
   bool              isResolved;
   int               maxSpread;
   int               maxSLPoints;
   
   // Indicator Handles (M5)
   int               h_ema9;
   int               h_ema21;
   int               h_ema50;
   int               h_ema100;
   int               h_ema200;
   int               h_atr;
   int               h_rsi;
   
   // HTF Handles (H1)
   int               h_htf_ema9;
   int               h_htf_ema21;
   int               h_htf_ema50;
   int               h_htf_ema100;
   int               h_htf_ema200;
   
   datetime          lastProcessedBar;
   datetime          lastSignalTime;
   string            lastSignalState;
   string            lastRejectReason;
   
   StrategyConfig    strategies[NUM_STRATEGIES];
};

struct PortfolioRiskState
{
   double            dailyStartEquity;
   datetime          lastResetDay;
   int               currentConsecutiveLosses;
   datetime          cooldownUntil;
   double            currentDailyDDPercent;
   double            currentPortfolioOpenRiskPercent;
   int               totalOpenPositions;
   int               symbolOpenPositions[NUM_INSTRUMENTS];
   bool              isDailyHalted;
   bool              isCooldownActive;
};

// Global Execution Drivers
CTrade               m_trade;
InstrumentRuntime    m_instruments[NUM_INSTRUMENTS];
PortfolioRiskState   m_riskState;
uint                 m_lastDashboardTick = 0;
bool                 m_isTester = false;

// Function Declarations
string ResolveBrokerSymbol(string symbolBase);
void   InitInstruments();
void   ReleaseInstrumentHandles();
bool   IsUKDaylightSaving(datetime gmtTime);
int    GetBrokerGMTOffset(datetime serverTime);
datetime GetUKTime(datetime serverTime);
bool   IsSessionAllowed(string &reason);
bool   IsRolloverActive();
bool   IsFridayCloseActive();
void   UpdateDailyRiskBaseline();
void   SyncConsecutiveLosses();
bool   CheckPortfolioRiskLimits(int symIdx, int stratIdx, string &rejectReason);
double CalculateNormalizedLot(string sym, double entryPrice, double slPrice, double riskPercent);
double NormalizePriceToTick(string sym, double price);
bool   CheckVolumeExpansion(string sym, ENUM_TIMEFRAMES tf, int lookback, double multiplier, int barShift);
void   EvaluateStrategyModule(int symIdx, int stratIdx);
void   ManageExistingPositions();
void   RenderDashboard();

// Strategy Logic Functions
bool   CheckSignal_9EMA(int symIdx, int &outDirection, double &outSL, double &outTP, string &rationale);
bool   CheckSignal_21EMA(int symIdx, int &outDirection, double &outSL, double &outTP, string &rationale);
bool   CheckSignal_50EMA(int symIdx, int &outDirection, double &outSL, double &outTP, string &rationale);
bool   CheckSignal_100EMA(int symIdx, int &outDirection, double &outSL, double &outTP, string &rationale);
bool   CheckSignal_LiquiditySweep(int symIdx, int &outDirection, double &outSL, double &outTP, string &rationale);
bool   CheckSignal_TrendPullback(int symIdx, int &outDirection, double &outSL, double &outTP, string &rationale);
bool   CheckSignal_VolatilityBreakout(int symIdx, int &outDirection, double &outSL, double &outTP, string &rationale);
bool   CheckSignal_StructureMomentum(int symIdx, int &outDirection, double &outSL, double &outTP, string &rationale);

//+------------------------------------------------------------------+
//| Section 4: Symbol Engine & Resolution                            |
//+------------------------------------------------------------------+
string ResolveBrokerSymbol(string symbolBase)
{
   if(symbolBase == "") return "";

   // 1. Exact match in market watch or available symbols
   if(SymbolInfoInteger(symbolBase, SYMBOL_SELECT) || SymbolSelect(symbolBase, true))
      return symbolBase;

   // 2. Common broker suffixes (Exness raw, standard, zero, pro, etc.)
   string suffixes[] = {"m", ".a", ".raw", "_i", ".ecn", ".std", "pro", ".c", "micro", ".US", "#", ".nas", ".nyse"};
   for(int s = 0; s < ArraySize(suffixes); s++)
   {
      string testSym = symbolBase + suffixes[s];
      if(SymbolSelect(testSym, true)) return testSym;
   }

   // 3. Known Institutional Aliases
   if(symbolBase == "XAUUSD")
   {
      string aliases[] = {"GOLD", "GOLDm", "XAUUSD.a", "XAUUSDm", "GOLD.raw", "XAUUSD_i"};
      for(int a = 0; a < ArraySize(aliases); a++)
      {
         if(SymbolSelect(aliases[a], true)) return aliases[a];
      }
   }
   else if(symbolBase == "XAGUSD")
   {
      string aliases[] = {"SILVER", "SILVERm", "XAGUSD.a", "XAGUSDm", "SILVER.raw"};
      for(int a = 0; a < ArraySize(aliases); a++)
      {
         if(SymbolSelect(aliases[a], true)) return aliases[a];
      }
   }
   else if(symbolBase == "US500")
   {
      string aliases[] = {"SPX500", "US500.a", "S&P500", "USA500", "SP500", "US500m"};
      for(int a = 0; a < ArraySize(aliases); a++)
      {
         if(SymbolSelect(aliases[a], true)) return aliases[a];
      }
   }
   else if(symbolBase == "USTEC")
   {
      string aliases[] = {"NAS100", "USTEC.a", "US100", "NDX100", "NQ100", "USTECm"};
      for(int a = 0; a < ArraySize(aliases); a++)
      {
         if(SymbolSelect(aliases[a], true)) return aliases[a];
      }
   }

   // 4. Case-insensitive substring search in market watch
   int total = SymbolsTotal(false);
   for(int i = 0; i < total; i++)
   {
      string name = SymbolName(i, false);
      if(StringFind(name, symbolBase) >= 0)
      {
         SymbolSelect(name, true);
         return name;
      }
   }

   return "";
}

//+------------------------------------------------------------------+
//| Initialize Instruments & Strategy Matrix                         |
//+------------------------------------------------------------------+
void InitInstruments()
{
   // Setup base instruments
   m_instruments[0].baseName = "XAUUSD";
   m_instruments[0].maxSpread = InpXAU_MaxSpreadPoints;
   m_instruments[0].maxSLPoints = InpXAU_MaxSLPoints;

   m_instruments[1].baseName = "XAGUSD";
   m_instruments[1].maxSpread = InpXAG_MaxSpreadPoints;
   m_instruments[1].maxSLPoints = InpXAG_MaxSLPoints;

   m_instruments[2].baseName = "US500";
   m_instruments[2].maxSpread = InpSPX_MaxSpreadPoints;
   m_instruments[2].maxSLPoints = InpSPX_MaxSLPoints;

   m_instruments[3].baseName = "USTEC";
   m_instruments[3].maxSpread = InpNAS_MaxSpreadPoints;
   m_instruments[3].maxSLPoints = InpNAS_MaxSLPoints;

   // Configure strategy names & magic numbers per instrument
   string stratNames[NUM_STRATEGIES] = {
      "9 EMA Scalper", "21 EMA Scalper", "50 EMA Scalper", "100 EMA Scalper",
      "Liquidity Sweep", "Trend Pullback", "Volatility Breakout", "Structure Momentum"
   };
   string stratTags[NUM_STRATEGIES] = {
      "9EMA", "21EMA", "50EMA", "100EMA", "LIQSWP", "TRNDPB", "VOLBRK", "STRMOM"
   };

   for(int i = 0; i < NUM_INSTRUMENTS; i++)
   {
      m_instruments[i].lastProcessedBar = 0;
      m_instruments[i].lastSignalTime = 0;
      m_instruments[i].lastSignalState = "IDLE";
      m_instruments[i].lastRejectReason = "NONE";
      
      // Resolve Symbol
      string targetConfigName = m_instruments[i].baseName;
      if(i == 0 && InpXAU_CustomSymbol != "") targetConfigName = InpXAU_CustomSymbol;
      if(i == 1 && InpXAG_CustomSymbol != "") targetConfigName = InpXAG_CustomSymbol;
      if(i == 2 && InpSPX_CustomSymbol != "") targetConfigName = InpSPX_CustomSymbol;
      if(i == 3 && InpNAS_CustomSymbol != "") targetConfigName = InpNAS_CustomSymbol;

      bool isEnabled = false;
      if(i == 0) isEnabled = InpXAU_EnableSymbol;
      if(i == 1) isEnabled = InpXAG_EnableSymbol;
      if(i == 2) isEnabled = InpSPX_EnableSymbol;
      if(i == 3) isEnabled = InpNAS_EnableSymbol;

      if(isEnabled)
      {
         m_instruments[i].resolvedSymbol = ResolveBrokerSymbol(targetConfigName);
         m_instruments[i].isResolved = (m_instruments[i].resolvedSymbol != "");
         if(!m_instruments[i].isResolved)
         {
            PrintFormat("[HR_UNIFIED][WARN] Unable to resolve broker symbol for configured asset '%s'! Scanning disabled for this asset.", targetConfigName);
         }
         else
         {
            PrintFormat("[HR_UNIFIED][INIT] Asset [%d] %s successfully mapped to broker symbol: %s", i, m_instruments[i].baseName, m_instruments[i].resolvedSymbol);
         }
      }
      else
      {
         m_instruments[i].resolvedSymbol = "";
         m_instruments[i].isResolved = false;
         PrintFormat("[HR_UNIFIED][INIT] Asset [%d] %s is DISABLED by configuration.", i, m_instruments[i].baseName);
      }

      // Configure Strategy Enable Matrix
      for(int s = 0; s < NUM_STRATEGIES; s++)
      {
         m_instruments[i].strategies[s].name = stratNames[s];
         m_instruments[i].strategies[s].tag = stratTags[s];
         m_instruments[i].strategies[s].magicNumber = InpMasterMagicBase + (ulong)(i * 10) + (ulong)s;
         m_instruments[i].strategies[s].enabled = false;

         if(m_instruments[i].isResolved)
         {
            if(i == 0) // XAUUSD
            {
               if(s == STRAT_9_EMA)               m_instruments[i].strategies[s].enabled = InpXAU_Enable_9EMA;
               if(s == STRAT_21_EMA)              m_instruments[i].strategies[s].enabled = InpXAU_Enable_21EMA;
               if(s == STRAT_50_EMA)              m_instruments[i].strategies[s].enabled = InpXAU_Enable_50EMA;
               if(s == STRAT_100_EMA)             m_instruments[i].strategies[s].enabled = InpXAU_Enable_100EMA;
               if(s == STRAT_LIQUIDITY_SWEEP)     m_instruments[i].strategies[s].enabled = InpXAU_Enable_LiqSweep;
               if(s == STRAT_TREND_PULLBACK)      m_instruments[i].strategies[s].enabled = InpXAU_Enable_TrendPullback;
               if(s == STRAT_VOLATILITY_BREAKOUT) m_instruments[i].strategies[s].enabled = InpXAU_Enable_VolBreakout;
               if(s == STRAT_STRUCTURE_MOMENTUM)  m_instruments[i].strategies[s].enabled = InpXAU_Enable_StructMomentum;
            }
            else if(i == 1) // XAGUSD
            {
               if(s == STRAT_9_EMA)               m_instruments[i].strategies[s].enabled = InpXAG_Enable_9EMA;
               if(s == STRAT_21_EMA)              m_instruments[i].strategies[s].enabled = InpXAG_Enable_21EMA;
               if(s == STRAT_50_EMA)              m_instruments[i].strategies[s].enabled = InpXAG_Enable_50EMA;
               if(s == STRAT_100_EMA)             m_instruments[i].strategies[s].enabled = InpXAG_Enable_100EMA;
               if(s == STRAT_LIQUIDITY_SWEEP)     m_instruments[i].strategies[s].enabled = InpXAG_Enable_LiqSweep;
               if(s == STRAT_TREND_PULLBACK)      m_instruments[i].strategies[s].enabled = InpXAG_Enable_TrendPullback;
               if(s == STRAT_VOLATILITY_BREAKOUT) m_instruments[i].strategies[s].enabled = InpXAG_Enable_VolBreakout;
               if(s == STRAT_STRUCTURE_MOMENTUM)  m_instruments[i].strategies[s].enabled = InpXAG_Enable_StructMomentum;
            }
            else if(i == 2) // US500
            {
               if(s == STRAT_9_EMA)               m_instruments[i].strategies[s].enabled = InpSPX_Enable_9EMA;
               if(s == STRAT_21_EMA)              m_instruments[i].strategies[s].enabled = InpSPX_Enable_21EMA;
               if(s == STRAT_50_EMA)              m_instruments[i].strategies[s].enabled = InpSPX_Enable_50EMA;
               if(s == STRAT_100_EMA)             m_instruments[i].strategies[s].enabled = InpSPX_Enable_100EMA;
               if(s == STRAT_LIQUIDITY_SWEEP)     m_instruments[i].strategies[s].enabled = InpSPX_Enable_LiqSweep;
               if(s == STRAT_TREND_PULLBACK)      m_instruments[i].strategies[s].enabled = InpSPX_Enable_TrendPullback;
               if(s == STRAT_VOLATILITY_BREAKOUT) m_instruments[i].strategies[s].enabled = InpSPX_Enable_VolBreakout;
               if(s == STRAT_STRUCTURE_MOMENTUM)  m_instruments[i].strategies[s].enabled = InpSPX_Enable_StructMomentum;
            }
            else if(i == 3) // USTEC
            {
               if(s == STRAT_9_EMA)               m_instruments[i].strategies[s].enabled = InpNAS_Enable_9EMA;
               if(s == STRAT_21_EMA)              m_instruments[i].strategies[s].enabled = InpNAS_Enable_21EMA;
               if(s == STRAT_50_EMA)              m_instruments[i].strategies[s].enabled = InpNAS_Enable_50EMA;
               if(s == STRAT_100_EMA)             m_instruments[i].strategies[s].enabled = InpNAS_Enable_100EMA;
               if(s == STRAT_LIQUIDITY_SWEEP)     m_instruments[i].strategies[s].enabled = InpNAS_Enable_LiqSweep;
               if(s == STRAT_TREND_PULLBACK)      m_instruments[i].strategies[s].enabled = InpNAS_Enable_TrendPullback;
               if(s == STRAT_VOLATILITY_BREAKOUT) m_instruments[i].strategies[s].enabled = InpNAS_Enable_VolBreakout;
               if(s == STRAT_STRUCTURE_MOMENTUM)  m_instruments[i].strategies[s].enabled = InpNAS_Enable_StructMomentum;
            }
         }
      }

      // Initialize indicator handles for resolved symbols
      if(m_instruments[i].isResolved)
      {
         string sym = m_instruments[i].resolvedSymbol;
         m_instruments[i].h_ema9    = iMA(sym, InpExecutionTF, 9, 0, MODE_EMA, PRICE_CLOSE);
         m_instruments[i].h_ema21   = iMA(sym, InpExecutionTF, 21, 0, MODE_EMA, PRICE_CLOSE);
         m_instruments[i].h_ema50   = iMA(sym, InpExecutionTF, 50, 0, MODE_EMA, PRICE_CLOSE);
         m_instruments[i].h_ema100  = iMA(sym, InpExecutionTF, 100, 0, MODE_EMA, PRICE_CLOSE);
         m_instruments[i].h_ema200  = iMA(sym, InpExecutionTF, 200, 0, MODE_EMA, PRICE_CLOSE);
         m_instruments[i].h_atr     = iATR(sym, InpExecutionTF, InpATRPeriod);
         m_instruments[i].h_rsi     = iRSI(sym, InpExecutionTF, 14, PRICE_CLOSE);

         m_instruments[i].h_htf_ema9   = iMA(sym, InpHTFTimeframe, 9, 0, MODE_EMA, PRICE_CLOSE);
         m_instruments[i].h_htf_ema21  = iMA(sym, InpHTFTimeframe, 21, 0, MODE_EMA, PRICE_CLOSE);
         m_instruments[i].h_htf_ema50  = iMA(sym, InpHTFTimeframe, 50, 0, MODE_EMA, PRICE_CLOSE);
         m_instruments[i].h_htf_ema100 = iMA(sym, InpHTFTimeframe, 100, 0, MODE_EMA, PRICE_CLOSE);
         m_instruments[i].h_htf_ema200 = iMA(sym, InpHTFTimeframe, 200, 0, MODE_EMA, PRICE_CLOSE);
      }
      else
      {
         m_instruments[i].h_ema9 = INVALID_HANDLE;
         m_instruments[i].h_ema21 = INVALID_HANDLE;
         m_instruments[i].h_ema50 = INVALID_HANDLE;
         m_instruments[i].h_ema100 = INVALID_HANDLE;
         m_instruments[i].h_ema200 = INVALID_HANDLE;
         m_instruments[i].h_atr = INVALID_HANDLE;
         m_instruments[i].h_rsi = INVALID_HANDLE;
         m_instruments[i].h_htf_ema9 = INVALID_HANDLE;
         m_instruments[i].h_htf_ema21 = INVALID_HANDLE;
         m_instruments[i].h_htf_ema50 = INVALID_HANDLE;
         m_instruments[i].h_htf_ema100 = INVALID_HANDLE;
         m_instruments[i].h_htf_ema200 = INVALID_HANDLE;
      }
   }
}

//+------------------------------------------------------------------+
//| Release all Indicator Handles Cleanly                            |
//+------------------------------------------------------------------+
void ReleaseInstrumentHandles()
{
   for(int i = 0; i < NUM_INSTRUMENTS; i++)
   {
      if(m_instruments[i].h_ema9 != INVALID_HANDLE)   IndicatorRelease(m_instruments[i].h_ema9);
      if(m_instruments[i].h_ema21 != INVALID_HANDLE)  IndicatorRelease(m_instruments[i].h_ema21);
      if(m_instruments[i].h_ema50 != INVALID_HANDLE)  IndicatorRelease(m_instruments[i].h_ema50);
      if(m_instruments[i].h_ema100 != INVALID_HANDLE) IndicatorRelease(m_instruments[i].h_ema100);
      if(m_instruments[i].h_ema200 != INVALID_HANDLE) IndicatorRelease(m_instruments[i].h_ema200);
      if(m_instruments[i].h_atr != INVALID_HANDLE)    IndicatorRelease(m_instruments[i].h_atr);
      if(m_instruments[i].h_rsi != INVALID_HANDLE)    IndicatorRelease(m_instruments[i].h_rsi);

      if(m_instruments[i].h_htf_ema9 != INVALID_HANDLE)   IndicatorRelease(m_instruments[i].h_htf_ema9);
      if(m_instruments[i].h_htf_ema21 != INVALID_HANDLE)  IndicatorRelease(m_instruments[i].h_htf_ema21);
      if(m_instruments[i].h_htf_ema50 != INVALID_HANDLE)  IndicatorRelease(m_instruments[i].h_htf_ema50);
      if(m_instruments[i].h_htf_ema100 != INVALID_HANDLE) IndicatorRelease(m_instruments[i].h_htf_ema100);
      if(m_instruments[i].h_htf_ema200 != INVALID_HANDLE) IndicatorRelease(m_instruments[i].h_htf_ema200);
   }
}

//+------------------------------------------------------------------+
//| Section 5: Time, Session & Daylight Saving Logic                 |
//+------------------------------------------------------------------+
bool IsUKDaylightSaving(const datetime gmtTime)
{
   MqlDateTime dt;
   TimeToStruct(gmtTime, dt);
   if(dt.mon < 3 || dt.mon > 10) return false;
   if(dt.mon > 3 && dt.mon < 10) return true;

   MqlDateTime temp;
   temp.year = dt.year; temp.mon = dt.mon; temp.day = 31; temp.hour = 1; temp.min = 0; temp.sec = 0;
   datetime endOfMonth = StructToTime(temp);
   TimeToStruct(endOfMonth, temp);
   int lastSunday = 31 - temp.day_of_week;

   if(dt.mon == 3)
   {
      if(dt.day > lastSunday) return true;
      if(dt.day == lastSunday && dt.hour >= 1) return true;
      return false;
   }
   else
   {
      if(dt.day < lastSunday) return true;
      if(dt.day == lastSunday && dt.hour < 1) return true;
      return false;
   }
}

int GetBrokerGMTOffset(const datetime serverTime)
{
   if(InpBrokerDstMode == BROKER_DST_NONE) return InpBrokerGMTOffset;

   datetime gmtEst = serverTime - (InpBrokerGMTOffset * 3600);
   MqlDateTime dt;
   TimeToStruct(gmtEst, dt);

   if(InpBrokerDstMode == BROKER_DST_US)
   {
      if(dt.mon < 3 || dt.mon > 11) return InpBrokerGMTOffset;
      if(dt.mon > 3 && dt.mon < 11) return InpBrokerGMTOffset + 1;

      if(dt.mon == 3)
      {
         int secondSun = 14 - ((dt.day_of_week - (dt.day % 7) + 7) % 7);
         if(dt.day > secondSun) return InpBrokerGMTOffset + 1;
         if(dt.day == secondSun && dt.hour >= 2) return InpBrokerGMTOffset + 1;
         return InpBrokerGMTOffset;
      }
      else
      {
         int firstSun = 7 - ((dt.day_of_week - (dt.day % 7) + 7) % 7);
         if(dt.day < firstSun) return InpBrokerGMTOffset + 1;
         if(dt.day == firstSun && dt.hour < 2) return InpBrokerGMTOffset + 1;
         return InpBrokerGMTOffset;
      }
   }
   return InpBrokerGMTOffset;
}

datetime GetUKTime(const datetime serverTime)
{
   int brokerOffset = GetBrokerGMTOffset(serverTime);
   datetime gmtTime = serverTime - (brokerOffset * 3600);
   bool isBST = IsUKDaylightSaving(gmtTime);
   return gmtTime + (isBST ? 3600 : 0);
}

bool IsSessionAllowed(string &reason)
{
   if(!InpEnableSessionFilter) return true;

   datetime serverTime = TimeCurrent();
   datetime ukTime = GetUKTime(serverTime);
   MqlDateTime dt;
   TimeToStruct(ukTime, dt);

   if(dt.day_of_week == 0 || dt.day_of_week == 6)
   {
      reason = "Weekend (Saturday/Sunday Closed)";
      return false;
   }

   int curMin = (dt.hour * 60) + dt.min;
   int startMin = (InpUKSessionStartHour * 60) + InpUKSessionStartMin;
   int endMin   = (InpUKSessionEndHour * 60) + InpUKSessionEndMin;

   if(curMin < startMin || curMin >= endMin)
   {
      reason = StringFormat("Outside UK Session (%02d:%02d UK vs %02d:%02d-%02d:%02d Allowed)",
                            dt.hour, dt.min, InpUKSessionStartHour, InpUKSessionStartMin, InpUKSessionEndHour, InpUKSessionEndMin);
      return false;
   }

   return true;
}

bool IsRolloverActive()
{
   if(!InpEnableRolloverBlackout) return false;
   datetime serverTime = TimeCurrent();
   int brokerOffset = GetBrokerGMTOffset(serverTime);
   datetime gmtTime = serverTime - (brokerOffset * 3600);
   MqlDateTime dt;
   TimeToStruct(gmtTime, dt);
   int curMin = (dt.hour * 60) + dt.min;
   return (curMin >= (21 * 60 + 55) && curMin <= (22 * 60 + 15));
}

bool IsFridayCloseActive()
{
   if(!InpEnableFridayClose) return false;
   datetime serverTime = TimeCurrent();
   datetime ukTime = GetUKTime(serverTime);
   MqlDateTime dt;
   TimeToStruct(ukTime, dt);
   if(dt.day_of_week != 5) return false;

   int curMin = (dt.hour * 60) + dt.min;
   int closeMin = (InpFridayCloseHourUK * 60) + InpFridayCloseMinUK;
   return (curMin >= closeMin);
}

//+------------------------------------------------------------------+
//| Section 6: Shared Portfolio Risk Manager                         |
//+------------------------------------------------------------------+
void UpdateDailyRiskBaseline()
{
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime todayStart = StructToTime(dt);

   if(m_riskState.lastResetDay != todayStart)
   {
      m_riskState.lastResetDay = todayStart;
      m_riskState.dailyStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(m_riskState.dailyStartEquity <= 0.0) m_riskState.dailyStartEquity = AccountInfoDouble(ACCOUNT_BALANCE);
      m_riskState.currentConsecutiveLosses = 0;
      m_riskState.isDailyHalted = false;
      PrintFormat("[HR_UNIFIED][RISK] New Trading Day Initialized. Baseline Equity: $%.2f", m_riskState.dailyStartEquity);
   }

   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(m_riskState.dailyStartEquity > 0.0 && currentEquity < m_riskState.dailyStartEquity)
   {
      m_riskState.currentDailyDDPercent = ((m_riskState.dailyStartEquity - currentEquity) / m_riskState.dailyStartEquity) * 100.0;
   }
   else
   {
      m_riskState.currentDailyDDPercent = 0.0;
   }

   if(m_riskState.currentDailyDDPercent >= InpMaxDailyDrawdownPercent)
   {
      if(!m_riskState.isDailyHalted)
      {
         PrintFormat("[HR_UNIFIED][RISK_BREACH] 3.0%% Daily Drawdown Limit Reached (Current DD: %.2f%%). Trading HALTED for rest of day.",
                     m_riskState.currentDailyDDPercent);
         m_riskState.isDailyHalted = true;
      }
   }

   m_riskState.isCooldownActive = (now < m_riskState.cooldownUntil);
}

void SyncConsecutiveLosses()
{
   datetime now = TimeCurrent();
   datetime dayStart = m_riskState.lastResetDay;
   if(dayStart == 0) return;

   if(!HistorySelect(dayStart, now)) return;

   int totalDeals = HistoryDealsTotal();
   int streak = 0;
   datetime lastLossTime = 0;

   for(int i = 0; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;

      long dealMagic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
      // Check if magic belongs to our EA namespace [InpMasterMagicBase .. InpMasterMagicBase + 100]
      if(dealMagic < (long)InpMasterMagicBase || dealMagic >= (long)(InpMasterMagicBase + 100))
         continue;

      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT) continue;

      double profit     = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      double swap       = HistoryDealGetDouble(ticket, DEAL_SWAP);
      double fee        = HistoryDealGetDouble(ticket, DEAL_FEE);
      double netProfit  = profit + commission + swap + fee;

      if(netProfit < 0.0)
      {
         streak++;
         lastLossTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      }
      else if(netProfit > 0.0)
      {
         streak = 0;
         lastLossTime = 0;
      }
   }

   m_riskState.currentConsecutiveLosses = streak;
   if(m_riskState.currentConsecutiveLosses >= InpConsecutiveLossLimit && lastLossTime > 0)
   {
      datetime cooldownEnd = lastLossTime + (InpConsecutiveLossCooldownMin * 60);
      if(cooldownEnd > now)
      {
         m_riskState.cooldownUntil = cooldownEnd;
      }
   }
}

bool CheckPortfolioRiskLimits(int symIdx, int stratIdx, string &rejectReason)
{
   if(!InpMasterTradingEnable)
   {
      rejectReason = "Master Trading Switch is DISABLED";
      return false;
   }

   UpdateDailyRiskBaseline();

   if(m_riskState.isDailyHalted)
   {
      rejectReason = StringFormat("Daily Drawdown Limit Reached (DD: %.2f%% >= %.2f%%)",
                                  m_riskState.currentDailyDDPercent, InpMaxDailyDrawdownPercent);
      return false;
   }

   if(m_riskState.isCooldownActive)
   {
      rejectReason = StringFormat("Consecutive Loss Cooldown Active until %s",
                                  TimeToString(m_riskState.cooldownUntil, TIME_MINUTES|TIME_SECONDS));
      return false;
   }

   // Count open positions belonging to this EA
   int totalEAPos = 0;
   int symEAPos = 0;
   double totalOpenRiskCurrency = 0.0;
   string currentSym = m_instruments[symIdx].resolvedSymbol;

   CPositionInfo pos;
   for(int p = PositionsTotal() - 1; p >= 0; p--)
   {
      if(pos.SelectByIndex(p))
      {
         ulong magic = pos.Magic();
         if(magic >= InpMasterMagicBase && magic < (InpMasterMagicBase + 100))
         {
            totalEAPos++;
            if(pos.Symbol() == currentSym)
               symEAPos++;

            // Calculate current open risk
            double openPrice = pos.PriceOpen();
            double slPrice   = pos.StopLoss();
            double vol       = pos.Volume();

            if(slPrice > 0.0)
            {
               double dist = MathAbs(openPrice - slPrice);
               ENUM_ORDER_TYPE posType = (pos.PositionType() == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
               double lossAtSL = 0.0;
               if(OrderCalcProfit(posType, pos.Symbol(), vol, openPrice, slPrice, lossAtSL) && lossAtSL < 0.0)
               {
                  totalOpenRiskCurrency += MathAbs(lossAtSL);
               }
               else
               {
                  double tickSize = SymbolInfoDouble(pos.Symbol(), SYMBOL_TRADE_TICK_SIZE);
                  double tickVal  = SymbolInfoDouble(pos.Symbol(), SYMBOL_TRADE_TICK_VALUE);
                  if(tickSize > 0.0 && tickVal > 0.0)
                  {
                     totalOpenRiskCurrency += vol * (dist / tickSize) * tickVal;
                  }
               }
            }
            else
            {
               // Missing SL: Treat conservatively as full 1.0% equity risk
               totalOpenRiskCurrency += AccountInfoDouble(ACCOUNT_EQUITY) * 0.01;
            }
         }
      }
   }

   m_riskState.totalOpenPositions = totalEAPos;
   m_riskState.symbolOpenPositions[symIdx] = symEAPos;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0.0) equity = AccountInfoDouble(ACCOUNT_BALANCE);
   if(equity > 0.0)
   {
      m_riskState.currentPortfolioOpenRiskPercent = (totalOpenRiskCurrency / equity) * 100.0;
   }

   // 1. Position Count Limit Check
   if(totalEAPos >= InpMaxTotalOpenPositions)
   {
      rejectReason = StringFormat("Portfolio Open Position Limit Reached (%d/%d)", totalEAPos, InpMaxTotalOpenPositions);
      return false;
   }

   if(symEAPos >= InpMaxPositionsPerSymbol)
   {
      rejectReason = StringFormat("Symbol Open Position Limit Reached for %s (%d/%d)", currentSym, symEAPos, InpMaxPositionsPerSymbol);
      return false;
   }

   // 2. Open Risk Cap Check (Max 5.0% Aggregate Open Risk)
   double plannedTradeRiskPct = MathMin(InpPerTradeRiskPercent, 1.0);
   if((m_riskState.currentPortfolioOpenRiskPercent + plannedTradeRiskPct) > InpMaxPortfolioRiskPercent)
   {
      rejectReason = StringFormat("Aggregate Open Risk Cap Exceeded (Current: %.2f%% + New: %.2f%% > %.2f%% Cap)",
                                  m_riskState.currentPortfolioOpenRiskPercent, plannedTradeRiskPct, InpMaxPortfolioRiskPercent);
      return false;
   }

   return true;
}

double NormalizePriceToTick(string sym, double price)
{
   double tickSize = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   if(tickSize <= 0.0) return NormalizeDouble(price, digits);
   return NormalizeDouble(MathRound(price / tickSize) * tickSize, digits);
}

double CalculateNormalizedLot(string sym, double entryPrice, double slPrice, double riskPercent)
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0.0) equity = AccountInfoDouble(ACCOUNT_BALANCE);
   if(equity <= 0.0) return 0.0;

   double effectiveRiskPct = MathMin(riskPercent, 1.0); // Hard 1% per-trade ceiling
   double riskAmount = equity * (effectiveRiskPct / 100.0);

   double slDistance = MathAbs(entryPrice - slPrice);
   if(slDistance <= 0.0) return 0.0;

   ENUM_ORDER_TYPE orderType = (entryPrice > slPrice) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double profitAtSL = 0.0;
   double riskPerUnitLot = 0.0;

   if(OrderCalcProfit(orderType, sym, 1.0, entryPrice, slPrice, profitAtSL) && profitAtSL < 0.0)
   {
      riskPerUnitLot = MathAbs(profitAtSL);
   }
   else
   {
      double tickSize  = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
      double tickValue = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
      if(tickSize > 0.0 && tickValue > 0.0)
      {
         riskPerUnitLot = (slDistance / tickSize) * tickValue;
      }
   }

   if(riskPerUnitLot <= 0.0) return 0.0;

   double rawLot  = riskAmount / riskPerUnitLot;
   double minLot  = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);

   if(stepLot <= 0.0) stepLot = 0.01;
   double normalizedLot = MathFloor(rawLot / stepLot) * stepLot;

   if(normalizedLot < minLot) normalizedLot = 0.0; // Reject if required lot is below broker minimum
   if(normalizedLot > maxLot) normalizedLot = maxLot;

   // Final safeguard: verify rounded lot does not breach 1.0% risk cap
   double actualRisk = normalizedLot * riskPerUnitLot;
   if(actualRisk > (equity * 0.0105)) // 1.05% tolerance for lot rounding
   {
      normalizedLot -= stepLot;
   }

   return NormalizeDouble(normalizedLot, 2);
}

bool CheckVolumeExpansion(string sym, ENUM_TIMEFRAMES tf, int lookback, double multiplier, int barShift)
{
   if(!InpUseVolumeFilter) return true;

   long volumeBuf[];
   ArraySetAsSeries(volumeBuf, true);
   int neededBars = lookback + barShift + 2;

   if(CopyTickVolume(sym, tf, 0, neededBars, volumeBuf) < neededBars)
      return true; // Fallback if history insufficient

   long triggerVol = volumeBuf[barShift];
   long totalBaseline = 0;
   for(int i = barShift + 1; i <= barShift + lookback; i++)
   {
      totalBaseline += volumeBuf[i];
   }

   double avgBaseline = (double)totalBaseline / (double)lookback;
   if(avgBaseline <= 0.0) return true;

   return (triggerVol >= (avgBaseline * multiplier));
}

//+------------------------------------------------------------------+
//| Section 7: Strategy Module Implementations                       |
//+------------------------------------------------------------------+

// --- S1: 9 EMA Momentum Scalper ---
bool CheckSignal_9EMA(int symIdx, int &outDirection, double &outSL, double &outTP, string &rationale)
{
   string sym = m_instruments[symIdx].resolvedSymbol;
   int hLTF = m_instruments[symIdx].h_ema9;
   int hHTF = m_instruments[symIdx].h_htf_ema9;
   int hATR = m_instruments[symIdx].h_atr;

   if(hLTF == INVALID_HANDLE || hHTF == INVALID_HANDLE || hATR == INVALID_HANDLE) return false;

   double emaLTF[], emaHTF[], atrBuf[];
   ArraySetAsSeries(emaLTF, true);
   ArraySetAsSeries(emaHTF, true);
   ArraySetAsSeries(atrBuf, true);

   if(CopyBuffer(hLTF, 0, 1, 3, emaLTF) < 3 || CopyBuffer(hHTF, 0, 1, 3, emaHTF) < 3 || CopyBuffer(hATR, 0, 1, 1, atrBuf) < 1)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(sym, InpExecutionTF, 1, 3, rates) < 3) return false;

   double close1 = rates[0].close;
   double open1  = rates[0].open;
   double high1  = rates[0].high;
   double low1   = rates[0].low;
   double close2 = rates[1].close;

   MqlRates htfRates[];
   ArraySetAsSeries(htfRates, true);
   if(CopyRates(sym, InpHTFTimeframe, 1, 1, htfRates) < 1) return false;
   double htfClose1 = htfRates[0].close;

   bool isBullHTF = (htfClose1 > emaHTF[0]);
   bool isBearHTF = (htfClose1 < emaHTF[0]);

   // Volume filter
   if(!CheckVolumeExpansion(sym, InpExecutionTF, InpVolumeLookback, InpVolumeMultiplier, 1)) return false;

   // Body quality check
   double rng = high1 - low1;
   if(rng <= 0.0 || (MathAbs(close1 - open1) / rng) < 0.35) return false;

   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   double atrVal = atrBuf[0];

   // BUY Signal: Clean close above 9 EMA with prior candle below/touching
   if(isBullHTF && close1 > emaLTF[0] && close2 <= emaLTF[1] && close1 > open1)
   {
      outDirection = ORDER_TYPE_BUY;
      double swing = low1;
      if(InpUseStructuralSL)
      {
         int lowest = iLowest(sym, InpExecutionTF, MODE_LOW, InpSwingLookback, 1);
         if(lowest > 0) swing = iLow(sym, InpExecutionTF, lowest);
      }
      double buffer = (InpUseATRBuffer && atrVal > 0.0) ? (atrVal * InpATRBufferMultiplier) : (10.0 * point);
      outSL = NormalizePriceToTick(sym, swing - buffer);
      double entry = SymbolInfoDouble(sym, SYMBOL_ASK);
      double dist = entry - outSL;
      if(dist <= 0.0) return false;
      outTP = NormalizePriceToTick(sym, entry + (dist * InpDefaultTPRatio));
      rationale = "9 EMA Bullish Expansion & HTF Alignment";
      return true;
   }

   // SELL Signal: Clean close below 9 EMA with prior candle above/touching
   if(isBearHTF && close1 < emaLTF[0] && close2 >= emaLTF[1] && close1 < open1)
   {
      outDirection = ORDER_TYPE_SELL;
      double swing = high1;
      if(InpUseStructuralSL)
      {
         int highest = iHighest(sym, InpExecutionTF, MODE_HIGH, InpSwingLookback, 1);
         if(highest > 0) swing = iHigh(sym, InpExecutionTF, highest);
      }
      double buffer = (InpUseATRBuffer && atrVal > 0.0) ? (atrVal * InpATRBufferMultiplier) : (10.0 * point);
      outSL = NormalizePriceToTick(sym, swing + buffer);
      double entry = SymbolInfoDouble(sym, SYMBOL_BID);
      double dist = outSL - entry;
      if(dist <= 0.0) return false;
      outTP = NormalizePriceToTick(sym, entry - (dist * InpDefaultTPRatio));
      rationale = "9 EMA Bearish Breakdown & HTF Alignment";
      return true;
   }

   return false;
}

// --- S2: 21 EMA Pullback Scalper ---
bool CheckSignal_21EMA(int symIdx, int &outDirection, double &outSL, double &outTP, string &rationale)
{
   string sym = m_instruments[symIdx].resolvedSymbol;
   int hLTF = m_instruments[symIdx].h_ema21;
   int hHTF = m_instruments[symIdx].h_htf_ema21;
   int hATR = m_instruments[symIdx].h_atr;

   if(hLTF == INVALID_HANDLE || hHTF == INVALID_HANDLE || hATR == INVALID_HANDLE) return false;

   double emaLTF[], emaHTF[], atrBuf[];
   ArraySetAsSeries(emaLTF, true);
   ArraySetAsSeries(emaHTF, true);
   ArraySetAsSeries(atrBuf, true);

   if(CopyBuffer(hLTF, 0, 1, 3, emaLTF) < 3 || CopyBuffer(hHTF, 0, 1, 3, emaHTF) < 3 || CopyBuffer(hATR, 0, 1, 1, atrBuf) < 1)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(sym, InpExecutionTF, 1, 3, rates) < 3) return false;

   double close1 = rates[0].close;
   double open1  = rates[0].open;
   double high1  = rates[0].high;
   double low1   = rates[0].low;
   double close2 = rates[1].close;

   MqlRates htfRates[];
   ArraySetAsSeries(htfRates, true);
   if(CopyRates(sym, InpHTFTimeframe, 1, 1, htfRates) < 1) return false;
   double htfClose1 = htfRates[0].close;

   bool isBullHTF = (htfClose1 > emaHTF[0]);
   bool isBearHTF = (htfClose1 < emaHTF[0]);

   if(!CheckVolumeExpansion(sym, InpExecutionTF, InpVolumeLookback, InpVolumeMultiplier, 1)) return false;

   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   double atrVal = atrBuf[0];

   if(isBullHTF && close1 > emaLTF[0] && close2 <= emaLTF[1] && close1 > open1)
   {
      outDirection = ORDER_TYPE_BUY;
      double swing = low1;
      if(InpUseStructuralSL)
      {
         int lowest = iLowest(sym, InpExecutionTF, MODE_LOW, InpSwingLookback, 1);
         if(lowest > 0) swing = iLow(sym, InpExecutionTF, lowest);
      }
      double buffer = (InpUseATRBuffer && atrVal > 0.0) ? (atrVal * InpATRBufferMultiplier) : (10.0 * point);
      outSL = NormalizePriceToTick(sym, swing - buffer);
      double entry = SymbolInfoDouble(sym, SYMBOL_ASK);
      double dist = entry - outSL;
      if(dist <= 0.0) return false;
      outTP = NormalizePriceToTick(sym, entry + (dist * InpDefaultTPRatio));
      rationale = "21 EMA Bullish Pullback Resumption";
      return true;
   }

   if(isBearHTF && close1 < emaLTF[0] && close2 >= emaLTF[1] && close1 < open1)
   {
      outDirection = ORDER_TYPE_SELL;
      double swing = high1;
      if(InpUseStructuralSL)
      {
         int highest = iHighest(sym, InpExecutionTF, MODE_HIGH, InpSwingLookback, 1);
         if(highest > 0) swing = iHigh(sym, InpExecutionTF, highest);
      }
      double buffer = (InpUseATRBuffer && atrVal > 0.0) ? (atrVal * InpATRBufferMultiplier) : (10.0 * point);
      outSL = NormalizePriceToTick(sym, swing + buffer);
      double entry = SymbolInfoDouble(sym, SYMBOL_BID);
      double dist = outSL - entry;
      if(dist <= 0.0) return false;
      outTP = NormalizePriceToTick(sym, entry - (dist * InpDefaultTPRatio));
      rationale = "21 EMA Bearish Pullback Resumption";
      return true;
   }

   return false;
}

// --- S3: 50 EMA Trend Re-Test ---
bool CheckSignal_50EMA(int symIdx, int &outDirection, double &outSL, double &outTP, string &rationale)
{
   string sym = m_instruments[symIdx].resolvedSymbol;
   int hLTF = m_instruments[symIdx].h_ema50;
   int hHTF = m_instruments[symIdx].h_htf_ema50;
   int hATR = m_instruments[symIdx].h_atr;

   if(hLTF == INVALID_HANDLE || hHTF == INVALID_HANDLE || hATR == INVALID_HANDLE) return false;

   double emaLTF[], emaHTF[], atrBuf[];
   ArraySetAsSeries(emaLTF, true);
   ArraySetAsSeries(emaHTF, true);
   ArraySetAsSeries(atrBuf, true);

   if(CopyBuffer(hLTF, 0, 1, 3, emaLTF) < 3 || CopyBuffer(hHTF, 0, 1, 3, emaHTF) < 3 || CopyBuffer(hATR, 0, 1, 1, atrBuf) < 1)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(sym, InpExecutionTF, 1, 3, rates) < 3) return false;

   double close1 = rates[0].close;
   double open1  = rates[0].open;
   double high1  = rates[0].high;
   double low1   = rates[0].low;
   double close2 = rates[1].close;

   MqlRates htfRates[];
   ArraySetAsSeries(htfRates, true);
   if(CopyRates(sym, InpHTFTimeframe, 1, 1, htfRates) < 1) return false;
   double htfClose1 = htfRates[0].close;

   bool isBullHTF = (htfClose1 > emaHTF[0]);
   bool isBearHTF = (htfClose1 < emaHTF[0]);

   if(!CheckVolumeExpansion(sym, InpExecutionTF, InpVolumeLookback, InpVolumeMultiplier, 1)) return false;

   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   double atrVal = atrBuf[0];

   if(isBullHTF && close1 > emaLTF[0] && close2 <= emaLTF[1] && close1 > open1)
   {
      outDirection = ORDER_TYPE_BUY;
      double swing = low1;
      if(InpUseStructuralSL)
      {
         int lowest = iLowest(sym, InpExecutionTF, MODE_LOW, InpSwingLookback, 1);
         if(lowest > 0) swing = iLow(sym, InpExecutionTF, lowest);
      }
      double buffer = (InpUseATRBuffer && atrVal > 0.0) ? (atrVal * InpATRBufferMultiplier) : (10.0 * point);
      outSL = NormalizePriceToTick(sym, swing - buffer);
      double entry = SymbolInfoDouble(sym, SYMBOL_ASK);
      double dist = entry - outSL;
      if(dist <= 0.0) return false;
      outTP = NormalizePriceToTick(sym, entry + (dist * InpDefaultTPRatio));
      rationale = "50 EMA Intermediate Trend Pullback";
      return true;
   }

   if(isBearHTF && close1 < emaLTF[0] && close2 >= emaLTF[1] && close1 < open1)
   {
      outDirection = ORDER_TYPE_SELL;
      double swing = high1;
      if(InpUseStructuralSL)
      {
         int highest = iHighest(sym, InpExecutionTF, MODE_HIGH, InpSwingLookback, 1);
         if(highest > 0) swing = iHigh(sym, InpExecutionTF, highest);
      }
      double buffer = (InpUseATRBuffer && atrVal > 0.0) ? (atrVal * InpATRBufferMultiplier) : (10.0 * point);
      outSL = NormalizePriceToTick(sym, swing + buffer);
      double entry = SymbolInfoDouble(sym, SYMBOL_BID);
      double dist = outSL - entry;
      if(dist <= 0.0) return false;
      outTP = NormalizePriceToTick(sym, entry - (dist * InpDefaultTPRatio));
      rationale = "50 EMA Intermediate Trend Pullback";
      return true;
   }

   return false;
}

// --- S4: 100 EMA Macro Cloud Scalper (Wick-Bounce Enabled) ---
bool CheckSignal_100EMA(int symIdx, int &outDirection, double &outSL, double &outTP, string &rationale)
{
   string sym = m_instruments[symIdx].resolvedSymbol;
   int hLTF = m_instruments[symIdx].h_ema100;
   int hHTF = m_instruments[symIdx].h_htf_ema100;
   int hATR = m_instruments[symIdx].h_atr;

   if(hLTF == INVALID_HANDLE || hHTF == INVALID_HANDLE || hATR == INVALID_HANDLE) return false;

   double emaLTF[], emaHTF[], atrBuf[];
   ArraySetAsSeries(emaLTF, true);
   ArraySetAsSeries(emaHTF, true);
   ArraySetAsSeries(atrBuf, true);

   if(CopyBuffer(hLTF, 0, 1, 3, emaLTF) < 3 || CopyBuffer(hHTF, 0, 1, 3, emaHTF) < 3 || CopyBuffer(hATR, 0, 1, 1, atrBuf) < 1)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(sym, InpExecutionTF, 1, 3, rates) < 3) return false;

   double close1 = rates[0].close;
   double open1  = rates[0].open;
   double high1  = rates[0].high;
   double low1   = rates[0].low;
   double close2 = rates[1].close;
   double low2   = rates[1].low;
   double high2  = rates[1].high;

   MqlRates htfRates[];
   ArraySetAsSeries(htfRates, true);
   if(CopyRates(sym, InpHTFTimeframe, 1, 1, htfRates) < 1) return false;
   double htfClose1 = htfRates[0].close;

   bool isBullHTF = (htfClose1 > emaHTF[0]);
   bool isBearHTF = (htfClose1 < emaHTF[0]);

   if(!CheckVolumeExpansion(sym, InpExecutionTF, InpVolumeLookback, InpVolumeMultiplier, 1)) return false;

   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   double atrVal = atrBuf[0];

   // Wick-Bounce Candidate Logic (Verified Phase 10 & 11 Standard on USTEC)
   bool isWickBounceBuy = (emaLTF[0] > emaLTF[1] && (low1 <= emaLTF[0] || low2 <= emaLTF[1]) && close1 > emaLTF[0] && close1 > open1);
   bool isStandardBuy   = (close1 > emaLTF[0] && close2 <= emaLTF[1] && close1 > open1);

   if(isBullHTF && (isWickBounceBuy || isStandardBuy))
   {
      outDirection = ORDER_TYPE_BUY;
      double swing = low1;
      if(InpUseStructuralSL)
      {
         int lowest = iLowest(sym, InpExecutionTF, MODE_LOW, InpSwingLookback, 1);
         if(lowest > 0) swing = iLow(sym, InpExecutionTF, lowest);
      }
      double buffer = (InpUseATRBuffer && atrVal > 0.0) ? (atrVal * InpATRBufferMultiplier) : (10.0 * point);
      outSL = NormalizePriceToTick(sym, swing - buffer);
      double entry = SymbolInfoDouble(sym, SYMBOL_ASK);
      double dist = entry - outSL;
      if(dist <= 0.0) return false;
      outTP = NormalizePriceToTick(sym, entry + (dist * InpDefaultTPRatio));
      rationale = "100 EMA Cloud Trend Continuation";
      return true;
   }

   bool isWickBounceSell = (emaLTF[0] < emaLTF[1] && (high1 >= emaLTF[0] || high2 >= emaLTF[1]) && close1 < emaLTF[0] && close1 < open1);
   bool isStandardSell   = (close1 < emaLTF[0] && close2 >= emaLTF[1] && close1 < open1);

   if(isBearHTF && (isWickBounceSell || isStandardSell))
   {
      outDirection = ORDER_TYPE_SELL;
      double swing = high1;
      if(InpUseStructuralSL)
      {
         int highest = iHighest(sym, InpExecutionTF, MODE_HIGH, InpSwingLookback, 1);
         if(highest > 0) swing = iHigh(sym, InpExecutionTF, highest);
      }
      double buffer = (InpUseATRBuffer && atrVal > 0.0) ? (atrVal * InpATRBufferMultiplier) : (10.0 * point);
      outSL = NormalizePriceToTick(sym, swing + buffer);
      double entry = SymbolInfoDouble(sym, SYMBOL_BID);
      double dist = outSL - entry;
      if(dist <= 0.0) return false;
      outTP = NormalizePriceToTick(sym, entry - (dist * InpDefaultTPRatio));
      rationale = "100 EMA Cloud Trend Continuation";
      return true;
   }

   return false;
}

// --- S5: Liquidity Sweep & Reversal ---
bool CheckSignal_LiquiditySweep(int symIdx, int &outDirection, double &outSL, double &outTP, string &rationale)
{
   string sym = m_instruments[symIdx].resolvedSymbol;
   int hATR = m_instruments[symIdx].h_atr;
   if(hATR == INVALID_HANDLE) return false;

   double atrBuf[];
   ArraySetAsSeries(atrBuf, true);
   if(CopyBuffer(hATR, 0, 1, 1, atrBuf) < 1) return false;
   double atrVal = atrBuf[0];

   int lookback = InpSweepSwingLookback;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(sym, InpExecutionTF, 1, lookback + 3, rates) < lookback + 3) return false;

   double swingHigh = rates[2].high;
   double swingLow  = rates[2].low;
   for(int b = 3; b <= lookback; b++)
   {
      if(rates[b].high > swingHigh) swingHigh = rates[b].high;
      if(rates[b].low < swingLow)   swingLow  = rates[b].low;
   }

   MqlRates trigger = rates[0];
   double barRange = trigger.high - trigger.low;
   if(barRange <= 0.0) return false;

   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   double buffer = (atrVal > 0.0) ? (atrVal * 0.20) : (50.0 * point);
   double minSweep = (atrVal > 0.0) ? (atrVal * 0.10) : (20.0 * point);
   double maxSweep = (atrVal > 0.0) ? (atrVal * 1.50) : (500.0 * point);

   // Bullish Sweep
   if(trigger.low < swingLow && trigger.close > swingLow && trigger.close > trigger.open)
   {
      double sweepDepth = swingLow - trigger.low;
      if(sweepDepth >= minSweep && sweepDepth <= maxSweep)
      {
         double displacement = (trigger.close - trigger.low) / barRange;
         if(displacement >= InpSweepMinDisplacementR)
         {
            outDirection = ORDER_TYPE_BUY;
            outSL = NormalizePriceToTick(sym, trigger.low - buffer);
            double entry = SymbolInfoDouble(sym, SYMBOL_ASK);
            double dist = entry - outSL;
            if(dist <= 0.0) return false;
            outTP = NormalizePriceToTick(sym, entry + (dist * InpDefaultTPRatio));
            rationale = StringFormat("Bullish Liquidity Sweep of %.5f (Depth: %.1f pts)", swingLow, sweepDepth/point);
            return true;
         }
      }
   }

   // Bearish Sweep
   if(trigger.high > swingHigh && trigger.close < swingHigh && trigger.close < trigger.open)
   {
      double sweepDepth = trigger.high - swingHigh;
      if(sweepDepth >= minSweep && sweepDepth <= maxSweep)
      {
         double displacement = (trigger.high - trigger.close) / barRange;
         if(displacement >= InpSweepMinDisplacementR)
         {
            outDirection = ORDER_TYPE_SELL;
            outSL = NormalizePriceToTick(sym, trigger.high + buffer);
            double entry = SymbolInfoDouble(sym, SYMBOL_BID);
            double dist = outSL - entry;
            if(dist <= 0.0) return false;
            outTP = NormalizePriceToTick(sym, entry - (dist * InpDefaultTPRatio));
            rationale = StringFormat("Bearish Liquidity Sweep of %.5f (Depth: %.1f pts)", swingHigh, sweepDepth/point);
            return true;
         }
      }
   }

   return false;
}

// --- S6: Trend Pullback Continuation (Corridor Touch) ---
bool CheckSignal_TrendPullback(int symIdx, int &outDirection, double &outSL, double &outTP, string &rationale)
{
   string sym = m_instruments[symIdx].resolvedSymbol;
   int hFast = m_instruments[symIdx].h_ema9;
   int hSlow = m_instruments[symIdx].h_ema21;
   int hBase = m_instruments[symIdx].h_ema200;
   int hATR  = m_instruments[symIdx].h_atr;

   if(hFast == INVALID_HANDLE || hSlow == INVALID_HANDLE || hBase == INVALID_HANDLE || hATR == INVALID_HANDLE)
      return false;

   double fast[], slow[], base[], atrBuf[];
   ArraySetAsSeries(fast, true);
   ArraySetAsSeries(slow, true);
   ArraySetAsSeries(base, true);
   ArraySetAsSeries(atrBuf, true);

   if(CopyBuffer(hFast, 0, 1, 2, fast) < 2 || CopyBuffer(hSlow, 0, 1, 2, slow) < 2 ||
      CopyBuffer(hBase, 0, 1, 2, base) < 2 || CopyBuffer(hATR, 0, 1, 1, atrBuf) < 1)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(sym, InpExecutionTF, 1, 2, rates) < 2) return false;

   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   double atrVal = atrBuf[0];

   // Bullish Trend Corridor
   bool isBullMacro = (fast[0] > slow[0] && slow[0] > base[0] && rates[0].close > base[0]);
   if(isBullMacro)
   {
      bool touched = (rates[1].low <= fast[1] || rates[0].low <= fast[0]);
      bool resumed = (rates[0].close > rates[0].open && rates[0].close > fast[0]);
      if(touched && resumed && CheckVolumeExpansion(sym, InpExecutionTF, InpVolumeLookback, InpVolumeMultiplier, 1))
      {
         outDirection = ORDER_TYPE_BUY;
         double swingLow = MathMin(rates[0].low, rates[1].low);
         double slBase = MathMin(swingLow, slow[0]);
         double buffer = (atrVal > 0.0) ? (atrVal * 0.25) : (10.0 * point);
         outSL = NormalizePriceToTick(sym, slBase - buffer);
         double entry = SymbolInfoDouble(sym, SYMBOL_ASK);
         double dist = entry - outSL;
         if(dist <= 0.0) return false;
         outTP = NormalizePriceToTick(sym, entry + (dist * InpDefaultTPRatio));
         rationale = "Trend Pullback 9/21 Corridor Bounce Above 200 EMA";
         return true;
      }
   }

   // Bearish Trend Corridor
   bool isBearMacro = (fast[0] < slow[0] && slow[0] < base[0] && rates[0].close < base[0]);
   if(isBearMacro)
   {
      bool touched = (rates[1].high >= fast[1] || rates[0].high >= fast[0]);
      bool resumed = (rates[0].close < rates[0].open && rates[0].close < fast[0]);
      if(touched && resumed && CheckVolumeExpansion(sym, InpExecutionTF, InpVolumeLookback, InpVolumeMultiplier, 1))
      {
         outDirection = ORDER_TYPE_SELL;
         double swingHigh = MathMax(rates[0].high, rates[1].high);
         double slBase = MathMax(swingHigh, slow[0]);
         double buffer = (atrVal > 0.0) ? (atrVal * 0.25) : (10.0 * point);
         outSL = NormalizePriceToTick(sym, slBase + buffer);
         double entry = SymbolInfoDouble(sym, SYMBOL_BID);
         double dist = outSL - entry;
         if(dist <= 0.0) return false;
         outTP = NormalizePriceToTick(sym, entry - (dist * InpDefaultTPRatio));
         rationale = "Trend Pullback 9/21 Corridor Bounce Below 200 EMA";
         return true;
      }
   }

   return false;
}

// --- S7: Volatility Expansion Breakout ---
bool CheckSignal_VolatilityBreakout(int symIdx, int &outDirection, double &outSL, double &outTP, string &rationale)
{
   string sym = m_instruments[symIdx].resolvedSymbol;
   int hATR = m_instruments[symIdx].h_atr;
   if(hATR == INVALID_HANDLE) return false;

   double atrBuf[];
   ArraySetAsSeries(atrBuf, true);
   if(CopyBuffer(hATR, 0, 1, 1, atrBuf) < 1) return false;
   double currentAtr = atrBuf[0];
   if(currentAtr <= 0.0) return false;

   int compBars = InpVolCompressionBars;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(sym, InpExecutionTF, 1, compBars + 2, rates) < compBars + 2) return false;

   double boxHigh = rates[1].high;
   double boxLow  = rates[1].low;
   long   totalVol = 0;

   for(int b = 2; b < compBars; b++)
   {
      if(rates[b].high > boxHigh) boxHigh = rates[b].high;
      if(rates[b].low < boxLow)   boxLow  = rates[b].low;
      totalVol += rates[b].tick_volume;
   }

   double avgVol = (double)totalVol / (double)(compBars - 2);
   double boxHeight = boxHigh - boxLow;

   // Squeeze Check
   if(boxHeight > (currentAtr * InpVolMaxCompressionATR)) return false;

   MqlRates trigger = rates[0];
   if(trigger.tick_volume < (long)(avgVol * InpVolumeMultiplier)) return false;

   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   double boxMid = (boxHigh + boxLow) / 2.0;

   // Bullish Breakout
   if(trigger.close > boxHigh && trigger.close > trigger.open)
   {
      outDirection = ORDER_TYPE_BUY;
      double slPrice = MathMax(boxMid, trigger.low) - (5.0 * point);
      outSL = NormalizePriceToTick(sym, slPrice);
      double entry = SymbolInfoDouble(sym, SYMBOL_ASK);
      double dist = entry - outSL;
      if(dist <= 0.0) return false;
      outTP = NormalizePriceToTick(sym, entry + (dist * InpDefaultTPRatio));
      rationale = StringFormat("Volatility Squeeze Breakout Above %.5f", boxHigh);
      return true;
   }

   // Bearish Breakout
   if(trigger.close < boxLow && trigger.close < trigger.open)
   {
      outDirection = ORDER_TYPE_SELL;
      double slPrice = MathMin(boxMid, trigger.high) + (5.0 * point);
      outSL = NormalizePriceToTick(sym, slPrice);
      double entry = SymbolInfoDouble(sym, SYMBOL_BID);
      double dist = outSL - entry;
      if(dist <= 0.0) return false;
      outTP = NormalizePriceToTick(sym, entry - (dist * InpDefaultTPRatio));
      rationale = StringFormat("Volatility Squeeze Breakout Below %.5f", boxLow);
      return true;
   }

   return false;
}

// --- S8: Market Structure Momentum (BOS) ---
bool CheckSignal_StructureMomentum(int symIdx, int &outDirection, double &outSL, double &outTP, string &rationale)
{
   string sym = m_instruments[symIdx].resolvedSymbol;
   int hRSI = m_instruments[symIdx].h_rsi;
   if(hRSI == INVALID_HANDLE) return false;

   double rsiBuf[];
   ArraySetAsSeries(rsiBuf, true);
   if(CopyBuffer(hRSI, 0, 1, 2, rsiBuf) < 2) return false;
   double currentRsi = rsiBuf[0];

   int lookback = 30;
   int pivotStrength = InpStructPivotStrength;
   int needed = lookback + (pivotStrength * 2) + 2;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(sym, InpExecutionTF, 1, needed, rates) < needed) return false;

   double pivotHigh = 0.0;
   double pivotLow  = 0.0;

   for(int i = pivotStrength + 1; i <= lookback; i++)
   {
      bool isHigh = true;
      for(int k = 1; k <= pivotStrength; k++)
      {
         if(rates[i].high <= rates[i-k].high || rates[i].high <= rates[i+k].high) { isHigh = false; break; }
      }
      if(isHigh && pivotHigh == 0.0) pivotHigh = rates[i].high;

      bool isLow = true;
      for(int k = 1; k <= pivotStrength; k++)
      {
         if(rates[i].low >= rates[i-k].low || rates[i].low >= rates[i+k].low) { isLow = false; break; }
      }
      if(isLow && pivotLow == 0.0) pivotLow = rates[i].low;

      if(pivotHigh > 0.0 && pivotLow > 0.0) break;
   }

   MqlRates trigger = rates[0];
   MqlRates prev    = rates[1];
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);

   // Bullish BOS
   if(pivotHigh > 0.0 && prev.close <= pivotHigh && trigger.close > pivotHigh && currentRsi >= InpStructRSIMin)
   {
      outDirection = ORDER_TYPE_BUY;
      double slBase = (pivotLow > 0.0) ? pivotLow : trigger.low;
      outSL = NormalizePriceToTick(sym, slBase - (5.0 * point));
      double entry = SymbolInfoDouble(sym, SYMBOL_ASK);
      double dist = entry - outSL;
      if(dist <= 0.0) return false;
      outTP = NormalizePriceToTick(sym, entry + (dist * InpDefaultTPRatio));
      rationale = StringFormat("Bullish BOS Break of %.5f (RSI: %.1f)", pivotHigh, currentRsi);
      return true;
   }

   // Bearish BOS
   if(pivotLow > 0.0 && prev.close >= pivotLow && trigger.close < pivotLow && currentRsi <= (100.0 - InpStructRSIMin))
   {
      outDirection = ORDER_TYPE_SELL;
      double slBase = (pivotHigh > 0.0) ? pivotHigh : trigger.high;
      outSL = NormalizePriceToTick(sym, slBase + (5.0 * point));
      double entry = SymbolInfoDouble(sym, SYMBOL_BID);
      double dist = outSL - entry;
      if(dist <= 0.0) return false;
      outTP = NormalizePriceToTick(sym, entry - (dist * InpDefaultTPRatio));
      rationale = StringFormat("Bearish BOS Break of %.5f (RSI: %.1f)", pivotLow, currentRsi);
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Section 8: Strategy Dispatcher & Execution                       |
//+------------------------------------------------------------------+
void EvaluateStrategyModule(int symIdx, int stratIdx)
{
   if(!m_instruments[symIdx].strategies[stratIdx].enabled) return;

   string sym = m_instruments[symIdx].resolvedSymbol;
   int dir = -1;
   double slPrice = 0.0, tpPrice = 0.0;
   string rationale = "";
   bool hasSignal = false;

   switch(stratIdx)
   {
      case STRAT_9_EMA:               hasSignal = CheckSignal_9EMA(symIdx, dir, slPrice, tpPrice, rationale); break;
      case STRAT_21_EMA:              hasSignal = CheckSignal_21EMA(symIdx, dir, slPrice, tpPrice, rationale); break;
      case STRAT_50_EMA:              hasSignal = CheckSignal_50EMA(symIdx, dir, slPrice, tpPrice, rationale); break;
      case STRAT_100_EMA:             hasSignal = CheckSignal_100EMA(symIdx, dir, slPrice, tpPrice, rationale); break;
      case STRAT_LIQUIDITY_SWEEP:     hasSignal = CheckSignal_LiquiditySweep(symIdx, dir, slPrice, tpPrice, rationale); break;
      case STRAT_TREND_PULLBACK:      hasSignal = CheckSignal_TrendPullback(symIdx, dir, slPrice, tpPrice, rationale); break;
      case STRAT_VOLATILITY_BREAKOUT: hasSignal = CheckSignal_VolatilityBreakout(symIdx, dir, slPrice, tpPrice, rationale); break;
      case STRAT_STRUCTURE_MOMENTUM:  hasSignal = CheckSignal_StructureMomentum(symIdx, dir, slPrice, tpPrice, rationale); break;
   }

   if(!hasSignal) return;

   // Signal Detected! Evaluate Spread & Broker Stop Level Constraints
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   long currentSpread = SymbolInfoInteger(sym, SYMBOL_SPREAD);
   if(m_instruments[symIdx].maxSpread > 0 && currentSpread > m_instruments[symIdx].maxSpread)
   {
      m_instruments[symIdx].lastRejectReason = StringFormat("Spread (%d) > Limit (%d)", currentSpread, m_instruments[symIdx].maxSpread);
      return;
   }

   // Pre-Trade Risk Verification
   string riskReject = "";
   if(!CheckPortfolioRiskLimits(symIdx, stratIdx, riskReject))
   {
      m_instruments[symIdx].lastRejectReason = riskReject;
      return;
   }

   // Validate Stops against broker freeze/stop levels
   double entryPrice = (dir == ORDER_TYPE_BUY) ? SymbolInfoDouble(sym, SYMBOL_ASK) : SymbolInfoDouble(sym, SYMBOL_BID);
   entryPrice = NormalizePriceToTick(sym, entryPrice);

   long stopLevelPts = SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
   double minStopDist = (double)stopLevelPts * point;
   double actualSLDist = MathAbs(entryPrice - slPrice);

   if(actualSLDist < minStopDist)
   {
      m_instruments[symIdx].lastRejectReason = StringFormat("SL Dist (%.5f) < Broker Min (%.5f)", actualSLDist, minStopDist);
      return;
   }

   // Maximum SL Distance Ceiling Check (Asset Profile Safety Guard)
   if(m_instruments[symIdx].maxSLPoints > 0)
   {
      double maxAllowedSLDist = (double)m_instruments[symIdx].maxSLPoints * point;
      if(actualSLDist > maxAllowedSLDist)
      {
         m_instruments[symIdx].lastRejectReason = StringFormat("SL Dist (%.1f pts) > Ceiling (%d pts)", actualSLDist / point, m_instruments[symIdx].maxSLPoints);
         return;
      }
   }

   // Lot Sizing
   double volume = CalculateNormalizedLot(sym, entryPrice, slPrice, InpPerTradeRiskPercent);
   if(volume <= 0.0)
   {
      m_instruments[symIdx].lastRejectReason = "Calculated Lot Size is 0.0 (Risk Budget Too Low)";
      return;
   }

   // Execute Order with Magic Number Binding
   ulong magic = m_instruments[symIdx].strategies[stratIdx].magicNumber;
   string comment = StringFormat("HR_%s_%s", m_instruments[symIdx].baseName, m_instruments[symIdx].strategies[stratIdx].tag);

   m_trade.SetExpertMagicNumber(magic);
   m_trade.SetDeviationInPoints(InpSlippagePoints);

   bool success = false;
   if(dir == ORDER_TYPE_BUY)
   {
      success = m_trade.Buy(volume, sym, entryPrice, slPrice, tpPrice, comment);
   }
   else if(dir == ORDER_TYPE_SELL)
   {
      success = m_trade.Sell(volume, sym, entryPrice, slPrice, tpPrice, comment);
   }

   if(success)
   {
      m_instruments[symIdx].lastSignalTime = TimeCurrent();
      m_instruments[symIdx].lastSignalState = StringFormat("%s %s", (dir == ORDER_TYPE_BUY ? "BUY" : "SELL"), m_instruments[symIdx].strategies[stratIdx].tag);
      m_instruments[symIdx].lastRejectReason = "NONE";
      PrintFormat("[HR_UNIFIED][TRADE_DISPATCH] %s %s on %s | Vol: %.2f | Price: %.5f | SL: %.5f | TP: %.5f | Magic: %I64u | %s",
                  (dir == ORDER_TYPE_BUY ? "BUY" : "SELL"), m_instruments[symIdx].strategies[stratIdx].name,
                  sym, volume, entryPrice, slPrice, tpPrice, magic, rationale);
   }
   else
   {
      m_instruments[symIdx].lastRejectReason = StringFormat("OrderSend Failed (Code: %d)", m_trade.ResultRetcode());
      PrintFormat("[HR_UNIFIED][ERROR] Execution failed for %s %s on %s. Error code: %d",
                  (dir == ORDER_TYPE_BUY ? "BUY" : "SELL"), m_instruments[symIdx].strategies[stratIdx].name, sym, m_trade.ResultRetcode());
   }
}

//+------------------------------------------------------------------+
//| Section 9: Position Lifecycle Management (BE, Trailing, Friday)  |
//+------------------------------------------------------------------+
void ManageExistingPositions()
{
   bool isFridayClose = IsFridayCloseActive();
   CPositionInfo pos;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(pos.SelectByIndex(i))
      {
         ulong magic = pos.Magic();
         // Verify position belongs strictly to HR Unified EA namespace
         if(magic < InpMasterMagicBase || magic >= (InpMasterMagicBase + 100))
            continue;

         string sym = pos.Symbol();
         ulong ticket = pos.Ticket();
         ENUM_POSITION_TYPE pType = pos.PositionType();
         double openPrice = pos.PriceOpen();
         double curPrice  = pos.PriceCurrent();
         double slPrice   = pos.StopLoss();
         double tpPrice   = pos.TakeProfit();
         double point     = SymbolInfoDouble(sym, SYMBOL_POINT);
         int digits       = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);

         // 1. Friday Weekend Close Protection
         if(isFridayClose)
         {
            m_trade.SetExpertMagicNumber(magic);
            m_trade.PositionClose(ticket);
            PrintFormat("[HR_UNIFIED][WEEKEND_CLOSE] Position #%I64u closed before weekend.", ticket);
            continue;
         }

         // 2. Break-Even Protection (Triggered at InpBETargetRR R-multiple)
         if(InpUseBE && slPrice > 0.0)
         {
            double initialRiskDist = MathAbs(openPrice - slPrice);
            if(initialRiskDist > 0.0)
            {
               double beTriggerDist = initialRiskDist * InpBETargetRR;
               double beSafetyDist  = InpBESafetyPoints * point;

               if(pType == POSITION_TYPE_BUY)
               {
                  if((curPrice - openPrice) >= beTriggerDist)
                  {
                     double desiredBE = NormalizePriceToTick(sym, openPrice + beSafetyDist);
                     if(slPrice < (desiredBE - (point * 0.5)))
                     {
                        m_trade.SetExpertMagicNumber(magic);
                        if(m_trade.PositionModify(ticket, desiredBE, tpPrice))
                        {
                           PrintFormat("[HR_UNIFIED][BREAK_EVEN] BUY Position #%I64u moved to Break-Even (%.5f).", ticket, desiredBE);
                        }
                     }
                  }
               }
               else if(pType == POSITION_TYPE_SELL)
               {
                  if((openPrice - curPrice) >= beTriggerDist)
                  {
                     double desiredBE = NormalizePriceToTick(sym, openPrice - beSafetyDist);
                     if(slPrice > (desiredBE + (point * 0.5)) || slPrice == 0.0)
                     {
                        m_trade.SetExpertMagicNumber(magic);
                        if(m_trade.PositionModify(ticket, desiredBE, tpPrice))
                        {
                           PrintFormat("[HR_UNIFIED][BREAK_EVEN] SELL Position #%I64u moved to Break-Even (%.5f).", ticket, desiredBE);
                        }
                     }
                  }
               }
            }
         }

         // 3. Trailing Stop Management
         if(InpUseTrailing)
         {
            double trailDist = InpTrailingDistancePoints * point;
            double trailStep = InpTrailingStepPoints * point;

            if(pType == POSITION_TYPE_BUY)
            {
               if((curPrice - openPrice) > trailDist)
               {
                  double desiredSL = NormalizePriceToTick(sym, curPrice - trailDist);
                  if(desiredSL > (slPrice + trailStep))
                  {
                     m_trade.SetExpertMagicNumber(magic);
                     m_trade.PositionModify(ticket, desiredSL, tpPrice);
                  }
               }
            }
            else if(pType == POSITION_TYPE_SELL)
            {
               if((openPrice - curPrice) > trailDist)
               {
                  double desiredSL = NormalizePriceToTick(sym, curPrice + trailDist);
                  if(slPrice == 0.0 || desiredSL < (slPrice - trailStep))
                  {
                     m_trade.SetExpertMagicNumber(magic);
                     m_trade.PositionModify(ticket, desiredSL, tpPrice);
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Section 10: On-Chart Dashboard Renderer                          |
//+------------------------------------------------------------------+
void RenderDashboard()
{
   if(!InpShowDashboard || m_isTester) return;

   uint tick = GetTickCount();
   if((tick - m_lastDashboardTick) < (uint)InpDashboardRefreshMs) return;
   m_lastDashboardTick = tick;

   datetime serverTime = TimeCurrent();
   datetime ukTime     = GetUKTime(serverTime);

   string sessionReject = "";
   bool isSession = IsSessionAllowed(sessionReject);

   string text = "";
   text += "========================================================================================\n";
   text += "                      HR UNIFIED MULTI-STRATEGY TRADING SYSTEM (v1.00)                 \n";
   text += "========================================================================================\n";
   text += StringFormat(" Server Time: %s | UK Time: %s | Session: %s\n",
                        TimeToString(serverTime, TIME_MINUTES|TIME_SECONDS),
                        TimeToString(ukTime, TIME_MINUTES|TIME_SECONDS),
                        (isSession ? "ACTIVE 🟢" : StringFormat("INACTIVE 🔴 (%s)", sessionReject)));
   text += StringFormat(" Master Switch: %s | Mode: DEMO RESEARCH | Daily Drawdown: %.2f%% / %.1f%%\n",
                        (InpMasterTradingEnable ? "ON 🟢" : "OFF 🔴"),
                        m_riskState.currentDailyDDPercent, InpMaxDailyDrawdownPercent);
   text += StringFormat(" Portfolio Open Risk: %.2f%% / %.1f%% | Total Positions: %d / %d\n",
                        m_riskState.currentPortfolioOpenRiskPercent, InpMaxPortfolioRiskPercent,
                        m_riskState.totalOpenPositions, InpMaxTotalOpenPositions);
   text += StringFormat(" Consecutive Losses Today: %d / %d | Cooldown: %s\n",
                        m_riskState.currentConsecutiveLosses, InpConsecutiveLossLimit,
                        (m_riskState.isCooldownActive ? "ACTIVE ⏳" : "NONE 🟢"));
   text += "----------------------------------------------------------------------------------------\n";
   text += " ASSET      | BROKER MAPPING | SPREAD (PTS) | STATUS       | ACTIVE STRATEGIES | LAST SIGNAL\n";
   text += "----------------------------------------------------------------------------------------\n";

   for(int i = 0; i < NUM_INSTRUMENTS; i++)
   {
      string sym = m_instruments[i].resolvedSymbol;
      string spreadStr = "--";
      if(m_instruments[i].isResolved)
      {
         spreadStr = IntegerToString(SymbolInfoInteger(sym, SYMBOL_SPREAD));
      }

      int activeCount = 0;
      for(int s = 0; s < NUM_STRATEGIES; s++)
      {
         if(m_instruments[i].strategies[s].enabled) activeCount++;
      }

      string statusStr = "OFF ⚪";
      if(m_instruments[i].isResolved)
      {
         statusStr = (activeCount > 0) ? "READY 🟢" : "STANDBY 🟡";
      }
      else if(m_instruments[i].baseName != "")
      {
         statusStr = "NOT FOUND 🔴";
      }

      text += StringFormat(" %-10s | %-14s | %-12s | %-12s | %2d / 8 Active   | %-16s\n",
                           m_instruments[i].baseName,
                           (m_instruments[i].isResolved ? sym : "UNRESOLVED"),
                           spreadStr,
                           statusStr,
                           activeCount,
                           m_instruments[i].lastSignalState);
   }

   text += "----------------------------------------------------------------------------------------\n";
   text += " [ACTIVE POSITIONS AUDIT]\n";

   CPositionInfo pos;
   int eaPosCount = 0;
   for(int p = PositionsTotal() - 1; p >= 0; p--)
   {
      if(pos.SelectByIndex(p))
      {
         ulong magic = pos.Magic();
         if(magic >= InpMasterMagicBase && magic < (InpMasterMagicBase + 100))
         {
            eaPosCount++;
            text += StringFormat(" • #%I64u | %s | %s %.2f lots @ %.5f | SL: %.5f | Profit: $%.2f\n",
                                 pos.Ticket(), pos.Symbol(),
                                 (pos.PositionType() == POSITION_TYPE_BUY ? "BUY" : "SELL"),
                                 pos.Volume(), pos.PriceOpen(), pos.StopLoss(), pos.Profit());
         }
      }
   }
   if(eaPosCount == 0)
   {
      text += " No active positions managed by HR Unified EA.\n";
   }

   text += "========================================================================================\n";
   Comment(text);
}

//+------------------------------------------------------------------+
//| Section 11: Core Event Handlers                                  |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("[HR_UNIFIED] Initializing HR Unified Multi-Strategy Trading System...");
   m_isTester = (bool)MQLInfoInteger(MQL_TESTER);

   m_trade.SetMarginMode();
   m_trade.SetTypeFillingBySymbol(_Symbol);

   InitInstruments();
   UpdateDailyRiskBaseline();
   SyncConsecutiveLosses();

   EventSetMillisecondTimer(InpDashboardRefreshMs);

   PrintFormat("[HR_UNIFIED] Initialization Complete. Ready to scan 4 instruments across 8 strategy modules.");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   ReleaseInstrumentHandles();
   Comment("");
   PrintFormat("[HR_UNIFIED] Deinitialization Complete. Clean shutdown (Reason: %d).", reason);
}

void OnTimer()
{
   // 1. Maintain Daily Risk Baseline
   UpdateDailyRiskBaseline();

   // 2. Always Manage Existing Open Positions
   ManageExistingPositions();

   // 3. Render Dashboard
   RenderDashboard();
}

void OnTick()
{
   // 1. Quick Position Protection on Tick
   ManageExistingPositions();

   // 2. Session Gate Check for New Signal Scans
   string sessionReject = "";
   if(!IsSessionAllowed(sessionReject))
   {
      return;
   }

   if(IsRolloverActive())
   {
      return;
   }

   // 3. Multi-Symbol Scanning Engine
   for(int i = 0; i < NUM_INSTRUMENTS; i++)
   {
      if(!m_instruments[i].isResolved) continue;

      string sym = m_instruments[i].resolvedSymbol;

      // New-bar gate evaluated strictly on closed M5 bars
      datetime currentBarTime = (datetime)SeriesInfoInteger(sym, InpExecutionTF, SERIES_LASTBAR_DATE);
      if(currentBarTime == 0 || currentBarTime == m_instruments[i].lastProcessedBar)
         continue;

      // Lock bar timestamp immediately
      m_instruments[i].lastProcessedBar = currentBarTime;

      // Iterate all 8 strategy modules independently for this symbol
      for(int s = 0; s < NUM_STRATEGIES; s++)
      {
         EvaluateStrategyModule(i, s);
      }
   }
}

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      ulong dealTicket = trans.deal;
      if(dealTicket > 0 && HistoryDealSelect(dealTicket))
      {
         long dealMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
         if(dealMagic >= (long)InpMasterMagicBase && dealMagic < (long)(InpMasterMagicBase + 100))
         {
            ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
            if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT)
            {
               SyncConsecutiveLosses();
               UpdateDailyRiskBaseline();
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
