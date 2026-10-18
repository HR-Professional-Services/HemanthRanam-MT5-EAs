//+------------------------------------------------------------------+
//|               921 EMA Multipair Scanner V1.mq5               |
//|        921 EMA Multipair Scanner V1 - M5 9/21 Pullback Production EA   |
//+------------------------------------------------------------------+
// ⚠️ Save this file as UTF-8 in MetaEditor before compiling to ensure 
// all emojis display correctly in Telegram alerts and reports!
#property copyright "Institutional Quantitative Engine"
#property link      ""
#property version   "1.00"
#property description "921 EMA Multipair Scanner V1 - Clean M5 9/21 EMA Pullback Continuation System"

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Canvas\Canvas.mqh>

//====================================================================
// SECTION 1: CONFIGURATION & INPUT PARAMETERS
//====================================================================

enum ENUM_TRADE_MANAGEMENT_MODE {
   MODE_STANDARD_PARTIAL_2R    = 0,   // Standard Mode: 50% partial at 2R, BE, runner on opposite cross
   MODE_TREND_RUNNER_CROSSOVER = 1    // Trend Runner Mode: 100% full position, BE at +1R, hold until opposite cross
};

input group "=== Operation & Execution Mode ==="
input bool                       InpAutoTradingEnabled        = true;      // Enable Live Auto Trading (False = Alerts Only)
input ENUM_TRADE_MANAGEMENT_MODE InpTradeManagementMode       = MODE_TREND_RUNNER_CROSSOVER; // Active Trade Management Mode
input double                     InpRiskPercent               = 1.0;       // Primary Trade Risk (% of Account Balance, Default: 1.0%)
input double                     InpPartialClosePercent       = 50.0;      // TP1 2R Partial Profit Close % (Standard Mode: 50%)
input ulong                      InpMagicNumber               = 921001;    // EA Magic Number

input group "=== Quantitative EMA Health Filter (Anti-Chop) ==="
input bool     Use_EMA_Health_Filter        = true;      // Enable Quantitative EMA Health Filter
input int      EMA_Health_Lookback          = 10;        // EMA Health Lookback Bars (Default: 10)
input double   EMA_Health_Min_Separation_ATR= 0.15;      // Minimum EMA 9-21 Separation (x ATR, Default: 0.15)
input double   EMA_Health_Min_Slope         = 25.0;      // Minimum EMA Slope Angle (Degrees, Default: 25.0)
input int      EMA_Health_Max_Crosses       = 1;         // Max 9/21 Crosses in Lookback (Chop Gate: >1 = Chop)
#define InpEnableEMAHealthFilter Use_EMA_Health_Filter
#define InpMinEMASeparationATR   EMA_Health_Min_Separation_ATR
#define InpEMAHealthLookbackBars EMA_Health_Lookback
#define InpMinEMAHealthAngle     EMA_Health_Min_Slope

input group "=== Confirmation Candle & Volume Filter ==="
input bool     Require_Closed_Confirmation_Candle = true;// Require Completed Bar 1 Close (Never enter on bar 0)
input bool     Require_Engulfing            = true;      // Require Bullish/Bearish Engulfing or Strong Rejection
input bool     Use_Volume_Filter            = true;      // Enable Volume Confirmation Filter
input int      Volume_Lookback              = 20;        // Volume Moving Average Lookback (Default: 20)
input double   Volume_Min_Multiplier        = 1.00;      // Minimum Volume Multiplier (x SMA, Default: 1.00)
#define InpRequireEngulfing Require_Engulfing

input group "=== Trade Management ==="
input bool     Use_BreakEven                = true;      // Move SL to Break-Even at +1R
input double   BreakEven_R                  = 1.0;       // Break-Even Activation (R-Multiple)
input double   BreakEven_Offset             = 1.0;       // Break-Even SL Offset (Pips above/below Entry)
#define InpEnableBreakEvenAt1R Use_BreakEven
#define InpBreakEvenRR         BreakEven_R
#define InpBEOffsetPips        BreakEven_Offset

input group "=== Telegram Mobile Alerts & Reports ==="
input bool     Telegram_Mobile_Mode         = true;      // Enable Mobile-First Compact Alert Format
input bool     Telegram_Send_NoTrade_Diagnostics = false;// Send No-Trade Rejections to Telegram (Terminal logs always kept)
input bool     Telegram_Send_Hourly_Report  = true;      // Send Hourly Radar Briefing (16:30 UK etc.)
input bool     Telegram_Send_Opening_Report = true;      // Send 07:00 UK Opening Radar
input bool     Telegram_Send_Closing_Report = true;      // Send 22:30 UK Day Closed Report
input bool     InpEnableTerminalAlert       = true;      // Enable MT5 Terminal Popup Alert (Alert())
input bool     InpEnableSoundAlert          = true;      // Enable Audio Sound Alert
input bool     InpEnablePushAlert           = false;     // Enable MT5 Mobile Notification (SendNotification)

input group "=== Core M5 9/21 Pullback Strategy ==="
input bool     InpUseEMA200Filter           = true;      // Require Price on Correct Side of M5 EMA 200 (Default: TRUE)
input bool     InpRequirePullbackAfterCross = true;      // Require Price to Retest EMA 9 / Value Zone / EMA 21 (Default: TRUE)
input bool     InpAllowDeepPullback         = true;      // Allow Pullback to Penetrate Beyond EMA 21 (Default: TRUE)
input double   InpMinCandleRangeATR         = 0.25;      // Min Confirmation Candle Range vs ATR (Filter flat dojis, Default: 0.25)
input int      InpSLEngulfingBufferPoints   = 10;        // SL Buffer below/above Confirmation Candle (Points)
input int      InpAtrPeriod                 = 14;        // ATR Period for SL Buffer & Volatility
input double   InpSLBufferATR               = 0.5;       // ATR Safety Buffer Multiplier for SL

input group "=== Cycle Continuation & Re-Entry ==="
input bool     InpEnableReEntry             = false;      // Enable Continuation Re-Entry Model (Default: TRUE)
input double   InpReEntryRiskPercent        = 0.5;       // Re-Entry Trade Risk (% of Account Balance, Default: 0.5%)
input int      InpMaxReEntriesPerCycle      = 2;         // Maximum Re-Entries Allowed Per Active Cycle (Default: 2)

input group "=== Optional Higher-Timeframe Filter (Default OFF) ==="
input bool     InpUseH1TrendFilter          = false;     // Require H1 EMA 200 Trend Alignment (Default: FALSE)

input group "=== Optional Market Regime & Chop Filters (Default OFF) ==="
input bool     InpEnableMarketRegimeFilter  = false;     // Enable Restrictive Market Regime Gate (Default: FALSE)
input int      InpEMACrossLookback          = 30;        // Lookback Bars to Count EMA 9/21 Crosses
input int      InpMaxEMACrosses             = 2;         // Max Allowed EMA Crosses (>=3 = Choppy / Block)
input int      InpEMASlopeLookback          = 5;         // Lookback Bars for EMA Directional Slope
input double   InpMinEMASlopeATR            = 0.15;      // Min EMA Slope (% of ATR over lookback)
input double   InpMinEMADistanceATR         = 0.25;      // Min Distance between EMA 9 and EMA 21 (x ATR)
input int      InpEMA200CrossLookback       = 30;        // Lookback Bars to Count Price vs EMA 200 Crosses
input int      InpMaxEMA200Crosses          = 2;         // Max Price vs EMA 200 Crosses (>=3 = Ranging / Block)
input bool     InpEnableATRRegimeFilter     = false;     // Enable ATR Volatility Compression Filter (Default: FALSE)
input double   InpMinATRPctOfAvg            = 0.60;      // Min ATR vs 14-period Avg (0.60 = 60%)

input group "=== Optional Market Structure & BOS Settings (Default OFF) ==="
input bool     InpEnableStructureFilter     = false;     // Enable Swing Structure Gate (Default: FALSE)
input int      InpSwingLookback             = 3;         // Swing High/Low Fractal Lookback (Left/Right Bars)
input int      InpStructureLookbackBars     = 30;        // Structure Lookback Window (Bars)
input bool     InpEnableBOSFilter           = false;     // Require Confirmed Break of Structure (Default: FALSE)
input double   InpMinBOSDistanceATR         = 0.10;      // Minimum BOS Break Distance (x ATR)
input bool     InpRequireCloseBeyondSwing   = true;      // Require Candle Close Beyond Swing (Not Wick Only)

input group "=== Optional Range Location Filter (Default OFF) ==="
input bool     InpEnableRangeFilter         = false;     // Block Entries in Middle of Consolidation Range (Default: FALSE)
input int      InpRangeLookback             = 30;        // Lookback Bars to Determine Range High/Low
input double   InpRangeMiddleZonePercent    = 40.0;      // Middle No-Trade Zone % (e.g. 30%-70% of Range)

input group "=== Optional Volume Expansion Filter (Default OFF) ==="
input bool     InpUseVolumeFilter           = true;     // Require Volume Expansion Confirmation (Default: FALSE)
input double   InpVolumeMultiplier          = 1.2;       // Minimum Volume Multiplier vs 20-period SMA
input int      InpVolumeLookback            = 20;        // Volume Rolling Average Lookback Period

input group "=== Diagnostics & Quality Scoring (Non-Gated) ==="
input bool     InpEnableDiagnostics         = true;      // Log Detailed Setup Rejection / Approval Diagnostics
input int      InpMinQualityScore           = 70;        // Confluence Score Rating Label Threshold (0-100, Informational)

input group "=== Trend Runner Management ==="
input bool     InpEnableTrendRunner         = true;      // Enable Unlimited Trend Runner Mode (Exit on Opposite Cross)
input bool     InpExitRunnerOnEMACross      = true;      // Close Runner Position On Confirmed Opposite EMA Cross

input group "=== Execution Timeframes & Session Hours (UK Time) ==="
input bool     InpEnableM5Execution   = true;      // Enable 5M Execution Layer (08:00-22:00 UK)
input int      InpM5StartHour         = 8;         // 5M Session Start Hour (UK Time)
input int      InpM5EndHour           = 22;        // 5M Session End Hour (UK Time)
input bool     InpEnableM1Execution   = false;     // Enable 1M Execution Layer (13:00-17:00 UK Overlap)
input int      InpM1StartHour         = 13;        // 1M Session Start Hour (UK Time: London-NY Overlap)
input int      InpM1EndHour           = 17;        // 1M Session End Hour (UK Time: London-NY Overlap)

input group "=== Session Protection & Weekend Close ==="
input bool     InpEnableNYCloseProtection   = true; // Enable New York Session Close Protection
input int      InpNYCloseCutoffMinutes      = 30;   // Cutoff Minutes Before Session End (Force Close)
input bool     InpEnableFridayClose        = true; // Enable Friday Weekend Close Protection
input int      InpFridayCloseHour           = 21;   // Friday Close Hour (UK Time)
input int      InpFridayCloseMin            = 30;   // Friday Close Minute (UK Time)
input int      InpMondayStartHour           = 8;    // Monday Session Start Hour (UK Time)

input group "=== Timezone & Server Settings ==="
input int      InpBrokerUTCOffset     = 2;         // Broker Server Time UTC Offset (Default: 2 for GMT+2)

input group "=== Telegram Intelligence & Chart Capture ==="
input bool     InpEnableTelegram      = true;                                           // Enable Telegram Notifications
input string   InpTelegramBotToken    = ""; // Telegram Bot Token (Configure in EA inputs) // Telegram Bot Token (@chartoramainbot)
input string   InpTelegramChatID      = ""; // Telegram Chat / Channel ID (Configure in EA inputs)                               // Telegram Chat / Channel ID (Chartora Official)
input bool     InpSendSignalChart     = true;                                           // Send Independent Signal Chart Image
input int      InpScreenshotWidth     = 1280;                                           // Image Width (Pixels)
input int      InpScreenshotHeight    = 720;                                            // Image Height (Pixels)

input group "=== Scheduled Intelligence Reports ==="
input bool     InpEnable30MReport     = false;     // Enable 30-Minute Market Report
input bool     InpEnable1HReport      = true;      // Enable 1-Hour Market Report
input bool     InpEnableDayOpenReport = true;      // Enable Daily Opening Report (07:00 UK)
input bool     InpEnableDayCloseReport= true;      // Enable Daily Closing Report (22:00 UK)
input int      InpDayOpenHour         = 7;         // Daily Opening Report Hour (UK Time)
input int      InpDayCloseHour        = 22;        // Daily Closing Report Hour (UK Time)

input group "=== External News & Market Context Filters ==="
input bool     InpEnableNewsFilter    = true;      // Enable Forex Factory High-Impact News Filter
input int      InpNewsPauseBefore     = 15;        // Pause Signals Before High-Impact News (Min)
input int      InpNewsPauseAfter      = 15;        // Pause Signals After High-Impact News (Min)
input bool     InpEnableFearGreed     = true;      // Enable Alternative.me Fear & Greed Context
input string   InpDxySymbol           = "DXY";     // DXY Index Symbol Name for Correlation

input group "=== Scanner Configured Symbols (XAUUSD, XAGUSD, US500, USTEC Default ON) ==="
input bool     InpSym1_Enable         = true;  input string InpSym1_Name  = "XAUUSD"; // Default ON
input bool     InpSym2_Enable         = true;  input string InpSym2_Name  = "XAGUSD"; // Default ON
input bool     InpSym3_Enable         = true;  input string InpSym3_Name  = "US500";  // Default ON
input bool     InpSym4_Enable         = true;  input string InpSym4_Name  = "USTEC";  // Default ON
input bool     InpSym5_Enable         = false; input string InpSym5_Name  = "USOIL";  // Default OFF
input bool     InpSym6_Enable         = false; input string InpSym6_Name  = "EURUSD"; // Default OFF
input bool     InpSym7_Enable         = false; input string InpSym7_Name  = "GBPUSD"; // Default OFF
input bool     InpSym8_Enable         = false; input string InpSym8_Name  = "USDJPY"; // Default OFF
input bool     InpSym9_Enable         = false; input string InpSym9_Name  = "AUDUSD"; // Default OFF
input bool     InpSym10_Enable        = false; input string InpSym10_Name = "NZDUSD"; // Default OFF
input bool     InpSym11_Enable        = false; input string InpSym11_Name = "USDCAD"; // Default OFF
input bool     InpSym12_Enable        = false; input string InpSym12_Name = "USDCHF"; // Default OFF
input bool     InpSym13_Enable        = false; input string InpSym13_Name = "AAPL";   // Default OFF
input bool     InpSym14_Enable        = false; input string InpSym14_Name = "TSLA";   // Default OFF
input bool     InpSym15_Enable        = false; input string InpSym15_Name = "AMZN";   // Default OFF
input bool     InpSym16_Enable        = false; input string InpSym16_Name = "NVDA";   // Default OFF
input bool     InpSym17_Enable        = false; input string InpSym17_Name = "INTC";   // Default OFF
input bool     InpSym18_Enable        = false; input string InpSym18_Name = "MSFT";   // Default OFF
input bool     InpSym19_Enable        = false; input string InpSym19_Name = "GOOGL";  // Default OFF
input bool     InpSym20_Enable        = false; input string InpSym20_Name = "META";   // Default OFF
input bool     InpSym21_Enable        = false; input string InpSym21_Name = "AVGO";   // Default OFF
input bool     InpSym22_Enable        = false; input string InpSym22_Name = "NFLX";   // Default OFF
input bool     InpSym23_Enable        = false; input string InpSym23_Name = "AMD";    // Default OFF
input bool     InpSym24_Enable        = false; input string InpSym24_Name = "PLTR";   // Default OFF
input bool     InpSym25_Enable        = false; input string InpSym25_Name = "MSTR";   // Default OFF
input bool     InpSym26_Enable        = false; input string InpSym26_Name = "QCOM";   // Default OFF
input bool     InpSym27_Enable        = false; input string InpSym27_Name = "JPM";    // Default OFF
input bool     InpSym28_Enable        = false; input string InpSym28_Name = "COIN";   // Default OFF
input bool     InpSym29_Enable        = false; input string InpSym29_Name = "BTCUSD"; // Default OFF
input bool     InpSym30_Enable        = false; input string InpSym30_Name = "ETHUSD"; // Default OFF
input bool     InpSym31_Enable        = false; input string InpSym31_Name = "SOLUSD"; // Default OFF
input bool     InpSym32_Enable        = false; input string InpSym32_Name = "XRPUSD"; // Default OFF

input group "=== Chart Interface Settings ==="
input bool     InpShowDashboard       = false;     // Show On-Chart Overlay Panel
input bool     InpDrawChartObjects    = false;     // Show Trade Plotting / MT5 Lines (Default: OFF)

//====================================================================
// SECTION 2: DATA STRUCTURES & ENUMS
//====================================================================

const int STATE_FILE_VERSION = 20260824;

enum ENUM_STRATEGY_TYPE {
   STRATEGY_EMA_PULLBACK = 1    // EMA Pullback Continuation Engine
};

enum ENUM_CYCLE_STATE {
   CYCLE_NEUTRAL = 0,
   CYCLE_BULLISH = 1,
   CYCLE_BEARISH = -1
};

enum ENUM_HTF_TREND {
   HTF_TREND_STRONG_BEARISH = -2,
   HTF_TREND_BEARISH        = -1,
   HTF_TREND_NEUTRAL        = 0,
   HTF_TREND_BULLISH        = 1,
   HTF_TREND_STRONG_BULLISH = 2
};

enum ENUM_VIRTUAL_STATUS {
   STATUS_ACTIVE = 0,
   STATUS_WON = 1,
   STATUS_LOST = 2,
   STATUS_BE = 3,
   STATUS_PARTIAL_CLOSED = 4
};

enum ENUM_MARKET_REGIME {
   REGIME_TRENDING_BULLISH = 1,
   REGIME_TRENDING_BEARISH = 2,
   REGIME_RANGING          = 3,
   REGIME_CHOPPY           = 4,
   REGIME_HIGH_VOLATILITY  = 5,
   REGIME_LOW_VOLATILITY   = 6,
   REGIME_NEWS_RISK        = 7,
   REGIME_UNCLEAR          = 8
};

enum ENUM_BIAS_DIRECTION {
   BIAS_BEARISH = -1,
   BIAS_NEUTRAL = 0,
   BIAS_BULLISH = 1
};

enum ENUM_EMA_HEALTH_STATE {
   EMA_HEALTH_HEALTHY     = 0, // 🟢 Healthy (Directional, Adequate separation & slope)
   EMA_HEALTH_WEAK        = 1, // 🟡 Weak (Low separation / weak slope)
   EMA_HEALTH_FLAT_CHOPPY = 2  // 🔴 Flat / Choppy (NO TRADE)
};

enum ENUM_VOLUME_STATE {
   VOLUME_CONFIRMED = 0, // 🟢 Confirmed (>= Min Multiplier)
   VOLUME_AVERAGE   = 1, // 🟡 Average (>= 0.85x)
   VOLUME_WEAK      = 2  // 🔴 Weak (< 0.85x - NO TRADE)
};

struct SignalQuality {
   int    totalScore;          // 0 - 100
   string ratingLabel;         // Excellent, Very Strong, Strong, Weak, Reject
   int    htfTrendScore;       // 0 - 20 (H1 Trend Aligned)
   int    structureScore;      // 0 - 20 (M5 Directional Structure)
   int    bosScore;            // 0 - 15 (Confirmed BOS)
   int    strategyScore;       // 0 - 10 (EMA 9/21 Separation)
   int    ema200Score;         // 0 - 10 (EMA 200 Alignment)
   int    atrQualityScore;     // 0 - 10 (ATR Volatility Quality)
   int    engulfingScore;      // 0 - 10 (Engulfing Confirmation)
   int    roomToSRScore;       // 0 - 5  (Room to Opposing Structure)
   int    volumeScore;         // 0 - 15 (Auxiliary Volume Expansion)
   int    momentumScore;       // 0 - 10
   int    liquidityScore;      // 0 - 10
   int    rrScore;             // 0 - 5
   int    newsContextScore;    // 0 - 5
};

struct StructureEvaluation {
   string   pattern;        // "HH → HL", "LH → LL", "Mixed / Range"
   string   bias;           // "Bullish", "Bearish", "Neutral"
   bool     bosConfirmed;   // True if confirmed BOS occurred
   double   lastSwingHigh;  // Most recent swing high price
   double   lastSwingLow;   // Most recent swing low price
   double   prevSwingHigh;  // Prior swing high price
   double   prevSwingLow;   // Prior swing low price
   bool     inMiddleRange;  // True if price is trapped in middle of range
   double   rangeHigh;      // Range high over lookback
   double   rangeLow;       // Range low over lookback
   double   rangePosPct;    // Position % within range (0-100)
};

struct RegimeEvaluation {
   ENUM_MARKET_REGIME regime;
   int    emaCrossCount;
   double ema9SlopeATR;
   double ema21SlopeATR;
   double emaDistanceATR;
   int    ema200CrossCount;
   double atrRatio;
   bool   isChoppy;
   bool   isFlat;
   bool   isCompressed;
   bool   isRanging;
   bool   isLowVol;
   string blockReason;
};

struct MarketStructure {
   string   h1Pattern;     // e.g. "HH → HL"
   string   h1Bias;        // "Bullish", "Bearish", "Neutral"
   string   m5Pattern;     // e.g. "HH → HL"
   string   m5Bias;        // "Bullish", "Bearish", "Neutral"
};

struct MultiTimeframeAnalysis {
   ENUM_BIAS_DIRECTION dailyBias;
   string               dailyReason;
   string               h1Analysis;
   string               m30Analysis;
   string               m5Execution;
};

struct KeyLevels {
   double r1;
   double r2;
   double s1;
   double s2;
   double pdh;
   double pdl;
   double asianHigh;
   double asianLow;
   double ema21;
   double ema200;
};

struct SymbolCycleState {
   ENUM_CYCLE_STATE state;              // CYCLE_NEUTRAL, CYCLE_BULLISH, CYCLE_BEARISH
   datetime         cycleStartBar;      // Closed bar time of the crossover
   bool             hasExpanded;        // True if price established trend expansion after cross / previous entry
   bool             pullbackActive;     // True if pullback touched EMA9, value zone, EMA21, or deep
   int              pullbackLevel;      // 1=EMA9, 2=Value Zone, 3=EMA21, 4=Deep Penetration
   datetime         lastPullbackBar;    // Closed bar time when pullback was detected
   bool             primaryEntryDone;   // True if primary entry was taken
   int              reEntriesCount;     // Number of re-entries taken in this cycle (0, 1, 2)
   datetime         lastSignalBar;      // Closed bar time of last signal (Non-repeating duplicate guard)
   double           lastEntryPrice;     // Price of last entry for expansion comparison
};

struct VirtualTrade {
   string               id;
   string               symbol;
   ENUM_STRATEGY_TYPE   strategy;
   ENUM_TIMEFRAMES      executionTF;      // PERIOD_M5 or PERIOD_M1
   int                  type;             // ORDER_TYPE_BUY or ORDER_TYPE_SELL
   bool                 isReEntry;        // true = Re-entry (0.5% risk), false = Primary (1.0% risk)
   double               initialLot;       // Full initial lot size
   double               currentLot;       // Remaining lot size
   double               entry;
   double               sl;
   double               tp1;              // 2R Target
   double               riskDistance;
   double               currentRR;
   double               maxRR;
   int                  qualityScore;
   string               qualityLabel;
   string               triggerReason;    // Dynamic setup rationale
   MarketStructure      structure;
   datetime             openTime;
   ENUM_VIRTUAL_STATUS  status;
   bool                 reachedTP1;       // 50% partial booked at 2R
   bool                 reachedBE;        // SL moved to BE (+offset)
   bool                 isRunner;         // True when riding trend after TP1
   double               tp1RealizedProfit;// Profit booked at 2R ($)
   double               tp1RealizedR;     // R booked at 2R (~ +1.0R)
   ulong                brokerTicket;
   ulong                ticket;               // Real MT5 Position Ticket (Source of Truth)
   double               initialRiskDist;      // Actual |entry - initialSL| (NEVER CHANGED)
   string               m5Pattern;            // M5 Pattern name
   string               h1Pattern;            // H1 Structure name
   string               volumeDesc;           // Volume confirmation status
   double               dxyCorrelation;       // DXY Correlation at entry
   int                  lastAlertedMilestoneR; // Last alerted integer R milestone (+1, +2, +3, +4...)
};

#define RealPositionMeta VirtualTrade

struct HistoricalTrade {
   string               id;
   string               symbol;
   ENUM_STRATEGY_TYPE   strategy;
   ENUM_TIMEFRAMES      executionTF;
   int                  type;
   bool                 isReEntry;
   double               initialLot;
   double               finalLot;
   double               entry;
   double               sl;
   double               exitPrice;
   double               resultRR;         // Combined Total Realized R
   double               resultProfit;     // Combined Total Realized P/L ($)
   double               maxRR;
   int                  qualityScore;
   string               qualityLabel;
   datetime             openTime;
   datetime             closeTime;
   ENUM_VIRTUAL_STATUS  status;
   string               exitReason;
   int                  lastAlertedMilestoneR;
};

struct SessionLiquidity {
   double asianHigh;
   double asianLow;
   double londonHigh;
   double londonLow;
   double prevDayHigh;
   double prevDayLow;
   double currentDayHigh;
   double currentDayLow;
   datetime asianDate;
};

struct ScannerSymbol {
   string           rawName;
   string           resolvedSymbol;
   bool             isValid;
   int              h_ema9_m5;
   int              h_ema21_m5;
   int              h_ema200_m5;
   int              h_atr_m5;
   
   int              h_ema9_m1;
   int              h_ema21_m1;
   int              h_ema200_m1;
   int              h_atr_m1;

   int              h_ema9_h1;
   int              h_ema21_h1;
   int              h_ema200_h1;
   
   datetime         lastProcessedBarM5;
   datetime         lastProcessedBarM1;
   datetime         lastSignalTime;
   SessionLiquidity liquidity;

   SymbolCycleState cycleM5;
   SymbolCycleState cycleM1;
};

struct NewsEvent {
   string   title;
   string   currency;
   datetime time;
   string   impact; // "High", "Medium", "Low"
};

//====================================================================
// SECTION 3: GLOBAL STATE & DRIVERS
//====================================================================

CTrade            m_trade;
ScannerSymbol     m_scanners[];
VirtualTrade      m_activeTrades[];
HistoricalTrade   m_historyTrades[];
NewsEvent         m_newsEvents[];

int               m_totalSymbols = 0;
datetime          m_lastNewsFetchTime = 0;
datetime          m_lastFearGreedFetchTime = 0;
bool              m_newsFetchFailed = false;
int               m_fearGreedScore = -1;
string            m_fearGreedLabel = "N/A";

// Persistent Report Guards
int               m_last30MReportMin = -1;
int               m_lastReportHour = -1;
int               m_lastDayOpenReportDay = -1;
int               m_lastDayCloseReportDay = -1;

bool              m_isStateChanged = false;
uint              m_lastDashboardTick = 0;

// Function Declarations
string ResolveBrokerSymbol(string symbolBase);
void InitSymbolScanner(bool enable, string rawName);
bool IsTimeframeSessionActive(ENUM_TIMEFRAMES tf, datetime serverTime);
bool CheckSessionCutoffAndForceClose(datetime currentTime);
bool IsMarketClosed(string symbol);
void UpdateSessionLiquidity(int idx);
bool IsBullishConfirmation(const double &open[], const double &high[], const double &low[], const double &close[], double atr);
bool IsBearishConfirmation(const double &open[], const double &high[], const double &low[], const double &close[], double atr);
bool CheckEMAHealthFilter(const double &ema9[], const double &ema21[], double atr, int dir, double &calculatedAngle, string &diagReason);
void LogCoreSetupDiagnostic(bool approved, string sym, ENUM_TIMEFRAMES tf, int dir, int pullbackLevel, bool deepPullback, bool h1Pass, bool newsPass, bool isReEntry, double riskPct, string decisionReason);
void ProcessEMAPullbackForCycle(int idx, ENUM_TIMEFRAMES tf, SymbolCycleState &cycle);
void EvaluateEMAPullbackStrategy(int idx, ENUM_TIMEFRAMES tf);
void ExecuteTradeSignal(int idx, ENUM_TIMEFRAMES tf, int type, double entry, double sl, double tp1, const SignalQuality &quality, string triggerReason, bool isReEntry);
void SendTrendRunnerMilestoneAlert(const VirtualTrade &vt, int milestoneR, bool isBE);
void ProcessScheduledReports(datetime ukTime, const MqlDateTime &dtUK);
void ManageActiveTrades(datetime currentTime);
void ClosePositionsForSymbolAndType(string sym, int type, string exitReason);
void ForceCloseAllEAPositions(string reasonStr);
void UpdateExternalFeeds(datetime currentTime);
void UpdateDashboard(datetime ukTime, bool isSessionActive);
void SaveState(bool isShutdown);
void LoadState();
string GetSymbolEmoji(string sym);
double CalculateDXYCorrelation(string symbol);
double CalculateADRPercentUsed(string symbol);
ENUM_HTF_TREND DetermineH1Trend(int idx);
bool SendTelegramMessage(string message);
bool GenerateCanvasChartImage(const VirtualTrade &vt, string filename, int width = 1280, int height = 720);
bool SendChartScreenshotGeneral(string symbol, ENUM_TIMEFRAMES tf, int orderType, double entry, double sl, double tp1, ulong ticket, string caption);
bool SendChartScreenshotWithAlert(const RealPositionMeta &vt, string caption);
bool CaptureAndSendChartScreenshot(const VirtualTrade &vt, string strategyName);
void AddMultipartFormField(char &body[], string boundary, string fieldName, string fieldValue);
void AddMultipartFileField(char &body[], string boundary, string fieldName, string filename, string mimeType, const char &fileBytes[]);
void FindRecentSwings(string sym, ENUM_TIMEFRAMES tf, double &swingHighs[], double &swingLows[], int lookback);
void AnalyzeMarketStructure(string sym, MarketStructure &structOut);
bool EvaluateMarketRegimeDetails(int idx, ENUM_TIMEFRAMES tf, RegimeEvaluation &regimeOut);
bool EvaluateMarketStructureDetails(int idx, ENUM_TIMEFRAMES tf, int tradeType, StructureEvaluation &structOut);
bool CheckPriceRangeLocation(int idx, ENUM_TIMEFRAMES tf, double &outRangeHigh, double &outRangeLow, double &outPosPct);
void LogCoreSetupDiagnostic(bool approved, string sym, ENUM_TIMEFRAMES tf, int dir, int pullbackLevel, bool deepPullback, bool h1Pass, bool newsPass, bool isReEntry, double riskPct, string decisionReason) {
   if(!InpEnableDiagnostics) return;

   string tfStr  = (tf == PERIOD_M1) ? "M1" : "M5";
   string dirStr = (dir == ORDER_TYPE_BUY) ? "BUY" : "SELL";
   string levelStr = "None";
   if(pullbackLevel == 1) levelStr = "Level 1 (EMA 9 Retest)";
   else if(pullbackLevel == 2) levelStr = "Level 2 (EMA 9/21 Value Zone)";
   else if(pullbackLevel == 3) levelStr = "Level 3 (EMA 21 Retest)";
   else if(pullbackLevel == 4) levelStr = "Level 4 (Deep Penetration beyond EMA 21)";

   string h1Str = InpUseH1TrendFilter ? (h1Pass ? "PASS (Aligned)" : "FAIL (Opposing)") : "OFF (Disabled)";
   string newsStr = InpEnableNewsFilter ? (newsPass ? "PASS (Clear)" : "BLOCKED (High Impact News)") : "OFF (Disabled)";
   string entryTypeStr = isReEntry ? "RE-ENTRY" : "PRIMARY";

   if(approved) {
      PrintFormat(
         "============================================================\n"
         "🚀 [M5 CORE EVALUATION] %s | %s | Direction: %s\n"
         "Cycle: %s | State: ARMED & CONFIRMED\n"
         "Pullback: PASS | %s\n"
         "EMA 200 Trend: PASS | Confirmation: PASS\n"
         "H1 Filter: %s | News Filter: %s\n"
         "Duplicate Guard: PASS (New Setup) | Entry: %s (Risk: %.2f%%)\n"
         "Decision: >>> %s SIGNAL APPROVED 🚀 <<<\n"
         "============================================================",
         sym, tfStr, dirStr,
         (dir == ORDER_TYPE_BUY ? "BULLISH" : "BEARISH"),
         levelStr, h1Str, newsStr,
         entryTypeStr, riskPct, dirStr
      );
   } else {
      PrintFormat(
         "============================================================\n"
         "⛔ [M5 CORE EVALUATION] %s | %s | Direction: %s\n"
         "Cycle: %s | Pullback Level: %s\n"
         "H1 Filter: %s | News Filter: %s\n"
         "Decision: NO SIGNAL 🚫 | Reason: %s\n"
         "============================================================",
         sym, tfStr, dirStr,
         (dir == ORDER_TYPE_BUY ? "BULLISH" : "BEARISH"),
         levelStr, h1Str, newsStr, decisionReason
      );
   }
}

void LogTradeDiagnostic(bool approved, string sym, ENUM_TIMEFRAMES tf, int dir, const RegimeEvaluation &regime, const StructureEvaluation &structure, ENUM_HTF_TREND h1Trend, int qualityScore, string decisionReason);
void GetMultiTimeframeAnalysis(string sym, int idx, MultiTimeframeAnalysis &mtfOut);
void CalculateKeyLevels(string sym, int idx, KeyLevels &levelsOut);
ENUM_MARKET_REGIME DetermineMarketRegime(string sym, int idx);
string MarketRegimeToString(ENUM_MARKET_REGIME regime);
string SanitizeHashtag(string text);
bool IsNewsRiskActive(string symbol);
void FetchForexFactoryNews();
void ParseForexFactoryJson(string json);
void FetchAlternativeMeFearGreed();
string CalculateCurrencyStrength();
SignalQuality CalculateQualityScore(int idx, int type, ENUM_HTF_TREND h1Trend, double entry, double sl, double risk, double atr, ENUM_TIMEFRAMES tf, const StructureEvaluation &structInfo, const RegimeEvaluation &regimeInfo);

bool IsValidTradeData(const VirtualTrade &vt);
string GetLiveTradesReportBlock();
string GetTodaysSummaryBlock();
string GetNewsStatusBlock(string symbol = "");
void ArchiveTrade(int index, double exitPrice, string exitReason);
void SendIndividualTradeClosedAlert(const HistoricalTrade &ht);

//+------------------------------------------------------------------+
//| Expert Initialization Function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   Print("[921 EMA Multipair Scanner V1] Initializing Production EA Engine (Real MT5 Trade Tracking & Mobile Alerts)...");

   m_trade.SetExpertMagicNumber(InpMagicNumber);
   m_trade.SetMarginMode();

   m_totalSymbols = 0;
   ArrayResize(m_scanners, 0);
   ArrayResize(m_activeTrades, 0);
   ArrayResize(m_historyTrades, 0);

   // Initialize active symbols (1..32)
   InitSymbolScanner(InpSym1_Enable, InpSym1_Name);
   InitSymbolScanner(InpSym2_Enable, InpSym2_Name);
   InitSymbolScanner(InpSym3_Enable, InpSym3_Name);
   InitSymbolScanner(InpSym4_Enable, InpSym4_Name);
   InitSymbolScanner(InpSym5_Enable, InpSym5_Name);
   InitSymbolScanner(InpSym6_Enable, InpSym6_Name);
   InitSymbolScanner(InpSym7_Enable, InpSym7_Name);
   InitSymbolScanner(InpSym8_Enable, InpSym8_Name);
   InitSymbolScanner(InpSym9_Enable, InpSym9_Name);
   InitSymbolScanner(InpSym10_Enable, InpSym10_Name);
   InitSymbolScanner(InpSym11_Enable, InpSym11_Name);
   InitSymbolScanner(InpSym12_Enable, InpSym12_Name);
   InitSymbolScanner(InpSym13_Enable, InpSym13_Name);
   InitSymbolScanner(InpSym14_Enable, InpSym14_Name);
   InitSymbolScanner(InpSym15_Enable, InpSym15_Name);
   InitSymbolScanner(InpSym16_Enable, InpSym16_Name);
   InitSymbolScanner(InpSym17_Enable, InpSym17_Name);
   InitSymbolScanner(InpSym18_Enable, InpSym18_Name);
   InitSymbolScanner(InpSym19_Enable, InpSym19_Name);
   InitSymbolScanner(InpSym20_Enable, InpSym20_Name);
   InitSymbolScanner(InpSym21_Enable, InpSym21_Name);
   InitSymbolScanner(InpSym22_Enable, InpSym22_Name);
   InitSymbolScanner(InpSym23_Enable, InpSym23_Name);
   InitSymbolScanner(InpSym24_Enable, InpSym24_Name);
   InitSymbolScanner(InpSym25_Enable, InpSym25_Name);
   InitSymbolScanner(InpSym26_Enable, InpSym26_Name);
   InitSymbolScanner(InpSym27_Enable, InpSym27_Name);
   InitSymbolScanner(InpSym28_Enable, InpSym28_Name);
   InitSymbolScanner(InpSym29_Enable, InpSym29_Name);
   InitSymbolScanner(InpSym30_Enable, InpSym30_Name);
   InitSymbolScanner(InpSym31_Enable, InpSym31_Name);
   InitSymbolScanner(InpSym32_Enable, InpSym32_Name);

   if(m_totalSymbols == 0) {
      Print("[ERROR] No valid symbols selected or available on broker server.");
      return(INIT_FAILED);
   }

   if(InpDxySymbol != "") {
      string resolvedDxy = ResolveBrokerSymbol(InpDxySymbol);
      if(resolvedDxy != "") SymbolSelect(resolvedDxy, true);
   }

   LoadState();

   EventSetTimer(1);

   string modeStr = InpAutoTradingEnabled ? "Live Trading + Telegram" : "Telegram Intelligence Only";
   
   string symbolsList = "";
   for(int i = 0; i < m_totalSymbols; i++) {
      symbolsList += m_scanners[i].rawName;
      if(i < m_totalSymbols - 1) {
         if((i + 1) % 6 == 0) symbolsList += "\n";
         else symbolsList += ", ";
      }
   }

   string startupMsg = StringFormat(
      "🚀 <b>MULTI-PAIR SCANNER V1 ONLINE</b>\n"
      "━━━━━━━━━━━━━━━━━━\n"
      "📡 %d Symbols | ⚡ %s\n"
      "📊 M5 9/21 EMA Pullback Engine | Re-Entries: %s\n"
      "💰 Risk: %.1f%% (Re-Entry: %.1f%%) | 🎯 TP1: 2R → 50%% → Runner\n"
      "⏱️ M5 %02d:00–%02d:00 | M1 %02d:00–%02d:00 UK\n"
      "🛡️ EMA200 Filter: %s | H1 Filter: %s\n\n"
      "📋 <b>Active Symbols (%d):</b>\n%s\n"
      "━━━━━━━━━━━━━━━━━━",
      m_totalSymbols, modeStr,
      (InpEnableReEntry ? StringFormat("Max %d", InpMaxReEntriesPerCycle) : "OFF"),
      InpRiskPercent, InpReEntryRiskPercent,
      InpM5StartHour, InpM5EndHour,
      InpM1StartHour, InpM1EndHour,
      (InpUseEMA200Filter ? "ON" : "OFF"),
      (InpUseH1TrendFilter ? "ON" : "OFF"),
      m_totalSymbols, symbolsList
   );

   SendTelegramMessage(startupMsg);
   Print("[921 EMA Multipair Scanner V1] Startup completed successfully. Active symbols: ", m_totalSymbols);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert Deinitialization Function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   EventKillTimer();

   for(int i = 0; i < m_totalSymbols; i++) {
      if(m_scanners[i].h_ema9_m5 != INVALID_HANDLE)   IndicatorRelease(m_scanners[i].h_ema9_m5);
      if(m_scanners[i].h_ema21_m5 != INVALID_HANDLE)  IndicatorRelease(m_scanners[i].h_ema21_m5);
      if(m_scanners[i].h_ema200_m5 != INVALID_HANDLE) IndicatorRelease(m_scanners[i].h_ema200_m5);
      if(m_scanners[i].h_atr_m5 != INVALID_HANDLE)    IndicatorRelease(m_scanners[i].h_atr_m5);

      if(m_scanners[i].h_ema9_m1 != INVALID_HANDLE)   IndicatorRelease(m_scanners[i].h_ema9_m1);
      if(m_scanners[i].h_ema21_m1 != INVALID_HANDLE)  IndicatorRelease(m_scanners[i].h_ema21_m1);
      if(m_scanners[i].h_ema200_m1 != INVALID_HANDLE) IndicatorRelease(m_scanners[i].h_ema200_m1);
      if(m_scanners[i].h_atr_m1 != INVALID_HANDLE)    IndicatorRelease(m_scanners[i].h_atr_m1);

      if(m_scanners[i].h_ema9_h1 != INVALID_HANDLE)   IndicatorRelease(m_scanners[i].h_ema9_h1);
      if(m_scanners[i].h_ema21_h1 != INVALID_HANDLE)  IndicatorRelease(m_scanners[i].h_ema21_h1);
      if(m_scanners[i].h_ema200_h1 != INVALID_HANDLE) IndicatorRelease(m_scanners[i].h_ema200_h1);
   }

   SaveState(true);
   ObjectsDeleteAll(0, "MSS_V1_");
   ObjectsDeleteAll(0, "MSS_SHOT_");
   Comment("");
}

//====================================================================
// SECTION 4: SYMBOL ENGINE & RESOLUTION
//====================================================================

string ResolveBrokerSymbol(string symbolBase) {
   if(symbolBase == "") return "";

   if(SymbolInfoInteger(symbolBase, SYMBOL_SELECT) || SymbolSelect(symbolBase, true)) {
      return symbolBase;
   }

   string suffixes[] = {"m", ".a", ".raw", "_i", ".ecn", ".std", "pro", ".c", "micro", ".US", "#", ".nas", ".nyse"};
   for(int s = 0; s < ArraySize(suffixes); s++) {
      string testSym = symbolBase + suffixes[s];
      if(SymbolSelect(testSym, true)) return testSym;
   }

   if(symbolBase == "XAUUSD") {
      string goldAliases[] = {"GOLD", "GOLDm", "XAUUSD.a", "XAUUSDm", "GOLD.raw"};
      for(int a = 0; a < ArraySize(goldAliases); a++) {
         if(SymbolSelect(goldAliases[a], true)) return goldAliases[a];
      }
   } else if(symbolBase == "XAGUSD") {
      string silverAliases[] = {"SILVER", "SILVERm", "XAGUSD.a", "XAGUSDm"};
      for(int a = 0; a < ArraySize(silverAliases); a++) {
         if(SymbolSelect(silverAliases[a], true)) return silverAliases[a];
      }
   } else if(symbolBase == "US500") {
      string spxAliases[] = {"SPX500", "US500.a", "S&P500", "USA500", "SP500"};
      for(int a = 0; a < ArraySize(spxAliases); a++) {
         if(SymbolSelect(spxAliases[a], true)) return spxAliases[a];
      }
   } else if(symbolBase == "USTEC") {
      string nasAliases[] = {"NAS100", "USTEC.a", "US100", "NDX100", "NQ100"};
      for(int a = 0; a < ArraySize(nasAliases); a++) {
         if(SymbolSelect(nasAliases[a], true)) return nasAliases[a];
      }
   } else if(symbolBase == "USOIL") {
      string oilAliases[] = {"WTI", "CRUDE", "USOIL.a", "BRENT"};
      for(int a = 0; a < ArraySize(oilAliases); a++) {
         if(SymbolSelect(oilAliases[a], true)) return oilAliases[a];
      }
   }

   int totalSymbols = SymbolsTotal(false);
   for(int i = 0; i < totalSymbols; i++) {
      string name = SymbolName(i, false);
      if(StringFind(name, symbolBase) >= 0) {
         SymbolSelect(name, true);
         return name;
      }
   }
   return "";
}

void InitSymbolScanner(bool enable, string rawName) {
   if(!enable || rawName == "") return;

   string resolved = ResolveBrokerSymbol(rawName);
   if(resolved == "") {
      Print("[WARN] Symbol not found on broker: ", rawName);
      return;
   }

   ScannerSymbol sym;
   sym.rawName = rawName;
   sym.resolvedSymbol = resolved;
   sym.isValid = true;

   // M5 Indicator Handles
   sym.h_ema9_m5   = iMA(resolved, PERIOD_M5, 9, 0, MODE_EMA, PRICE_CLOSE);
   sym.h_ema21_m5  = iMA(resolved, PERIOD_M5, 21, 0, MODE_EMA, PRICE_CLOSE);
   sym.h_ema200_m5 = iMA(resolved, PERIOD_M5, 200, 0, MODE_EMA, PRICE_CLOSE);
   sym.h_atr_m5    = iATR(resolved, PERIOD_M5, InpAtrPeriod);

   // M1 Indicator Handles
   sym.h_ema9_m1   = iMA(resolved, PERIOD_M1, 9, 0, MODE_EMA, PRICE_CLOSE);
   sym.h_ema21_m1  = iMA(resolved, PERIOD_M1, 21, 0, MODE_EMA, PRICE_CLOSE);
   sym.h_ema200_m1 = iMA(resolved, PERIOD_M1, 200, 0, MODE_EMA, PRICE_CLOSE);
   sym.h_atr_m1    = iATR(resolved, PERIOD_M1, InpAtrPeriod);

   // H1 Trend Indicator Handles
   sym.h_ema9_h1   = iMA(resolved, PERIOD_H1, 9, 0, MODE_EMA, PRICE_CLOSE);
   sym.h_ema21_h1  = iMA(resolved, PERIOD_H1, 21, 0, MODE_EMA, PRICE_CLOSE);
   sym.h_ema200_h1 = iMA(resolved, PERIOD_H1, 200, 0, MODE_EMA, PRICE_CLOSE);

   sym.lastProcessedBarM5 = 0;
   sym.lastProcessedBarM1 = 0;
   sym.lastSignalTime     = 0;
   ZeroMemory(sym.liquidity);

   ZeroMemory(sym.cycleM5);
   ZeroMemory(sym.cycleM1);
   sym.cycleM5.state = CYCLE_NEUTRAL;
   sym.cycleM1.state = CYCLE_NEUTRAL;

   if(sym.h_ema9_m5 == INVALID_HANDLE || sym.h_atr_m5 == INVALID_HANDLE ||
      sym.h_ema9_m1 == INVALID_HANDLE || sym.h_atr_m1 == INVALID_HANDLE) {
      Print("[ERROR] Failed to load indicator handles for ", resolved);
      return;
   }

   int idx = m_totalSymbols;
   m_totalSymbols++;
   ArrayResize(m_scanners, m_totalSymbols);
   m_scanners[idx] = sym;

   Print("[OK] Scanner initialized for ", rawName, " -> ", resolved);
}

string GetSymbolEmoji(string sym) {
   if(StringFind(sym, "XAUUSD") >= 0 || StringFind(sym, "GOLD") >= 0) return "🥇";
   if(StringFind(sym, "XAGUSD") >= 0 || StringFind(sym, "SILVER") >= 0) return "🥈";
   if(StringFind(sym, "US500") >= 0  || StringFind(sym, "SPX") >= 0) return "📈";
   if(StringFind(sym, "USTEC") >= 0  || StringFind(sym, "NAS") >= 0) return "💻";
   if(StringFind(sym, "USOIL") >= 0  || StringFind(sym, "WTI") >= 0) return "🛢️";
   if(StringFind(sym, "EURUSD") >= 0) return "💶";
   if(StringFind(sym, "GBPUSD") >= 0) return "💷";
   if(StringFind(sym, "USDJPY") >= 0) return "💴";
   if(StringFind(sym, "AUDUSD") >= 0) return "🇦🇺";
   if(StringFind(sym, "NZDUSD") >= 0) return "🇳🇿";
   if(StringFind(sym, "USDCAD") >= 0) return "🇨🇦";
   if(StringFind(sym, "USDCHF") >= 0) return "🇨🇭";
   if(StringFind(sym, "BTC") >= 0)    return "₿";
   if(StringFind(sym, "ETH") >= 0)    return "🔷";
   if(StringFind(sym, "SOL") >= 0)    return "☀️";
   if(StringFind(sym, "XRP") >= 0)    return "🪙";
   if(StringFind(sym, "AAPL") >= 0 || StringFind(sym, "TSLA") >= 0 || StringFind(sym, "AMZN") >= 0 ||
      StringFind(sym, "NVDA") >= 0 || StringFind(sym, "MSFT") >= 0 || StringFind(sym, "GOOGL") >= 0 ||
      StringFind(sym, "META") >= 0 || StringFind(sym, "NFLX") >= 0 || StringFind(sym, "AMD") >= 0 ||
      StringFind(sym, "PLTR") >= 0 || StringFind(sym, "MSTR") >= 0 || StringFind(sym, "COIN") >= 0 ||
      StringFind(sym, "INTC") >= 0 || StringFind(sym, "AVGO") >= 0 || StringFind(sym, "QCOM") >= 0 ||
      StringFind(sym, "JPM") >= 0) return "🏛️";
   return "📊";
}

//====================================================================
// SECTION 5: TIME ENGINE & EUROPE/LONDON TIMEZONE SYNCHRONIZATION
//====================================================================

bool IsUKDaylightSavingTime(datetime utcTime) {
   MqlDateTime dt;
   TimeToStruct(utcTime, dt);
   
   if(dt.mon < 3 || dt.mon > 10) return false;
   if(dt.mon > 3 && dt.mon < 10) return true;

   if(dt.mon == 3) {
      int lastSunday = 31 - ((dt.day - dt.day_of_week) % 7);
      return (dt.day >= lastSunday);
   }
   if(dt.mon == 10) {
      int lastSunday = 31 - ((dt.day - dt.day_of_week) % 7);
      return (dt.day < lastSunday);
   }
   return false;
}

datetime GetUKTime(datetime serverTime = 0) {
   datetime utc = 0;
   if(serverTime > 0) {
      utc = serverTime - (InpBrokerUTCOffset * 3600);
   } else {
      utc = TimeGMT();
      if(utc <= 0) {
         utc = TimeCurrent() - (InpBrokerUTCOffset * 3600);
      }
   }
   int ukOffset = IsUKDaylightSavingTime(utc) ? 1 : 0; // BST (+1) or GMT (+0)
   return utc + (ukOffset * 3600);
}

bool IsTimeframeSessionActive(ENUM_TIMEFRAMES tf, datetime serverTime) {
   datetime ukTime = GetUKTime(serverTime);
   MqlDateTime dt;
   TimeToStruct(ukTime, dt);

   // Weekend check
   if(dt.day_of_week == 0) return false; // Sunday before open
   if(dt.day_of_week == 6) return false; // Saturday
   if(dt.day_of_week == 1 && dt.hour < InpMondayStartHour) return false; // Monday early morning

   if(tf == PERIOD_M5) {
      if(!InpEnableM5Execution) return false;
      return (dt.hour >= InpM5StartHour && dt.hour < InpM5EndHour);
   }
   if(tf == PERIOD_M1) {
      if(!InpEnableM1Execution) return false;
      return (dt.hour >= InpM1StartHour && dt.hour < InpM1EndHour);
   }

   return true;
}

bool CheckSessionCutoffAndForceClose(datetime currentTime) {
   datetime ukTime = GetUKTime(currentTime);
   MqlDateTime dt; TimeToStruct(ukTime, dt);

   // A. Friday Weekend Protection (21:30 UK Cutoff)
   if(InpEnableFridayClose && dt.day_of_week == 5) {
      if(dt.hour > InpFridayCloseHour || (dt.hour == InpFridayCloseHour && dt.min >= InpFridayCloseMin)) {
         ForceCloseAllEAPositions("Friday Weekend Protection Cutoff");
         return true; // Disable trading
      }
   }

   // B. New York Session Close Protection (30 mins before 22:00 UK end)
   if(InpEnableNYCloseProtection) {
      int cutoffMin = 60 - InpNYCloseCutoffMinutes;
      int cutoffHour = InpM5EndHour - 1;
      if(dt.hour > cutoffHour || (dt.hour == cutoffHour && dt.min >= cutoffMin)) {
         ForceCloseAllEAPositions("New York Session Close Protection Cutoff");
         return true; // Disable trading
      }
   }

   return false;
}

bool IsMarketClosed(string symbol) {
   long tradeMode = SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);
   if(tradeMode == SYMBOL_TRADE_MODE_DISABLED) return true;

   datetime lastTick = (datetime)SymbolInfoInteger(symbol, SYMBOL_TIME);
   if(TimeCurrent() - lastTick > 300) return true;

   return false;
}

//====================================================================
// SECTION 6: EVENT TIMER & TICK-LESS ENGINE
//====================================================================

void OnTimer() {
   datetime currentTime = TimeCurrent();
   datetime ukTime = GetUKTime(currentTime);

   MqlDateTime dtUK;
   TimeToStruct(ukTime, dtUK);

   UpdateExternalFeeds(currentTime);
   ManageActiveTrades(currentTime);

   bool isSessionCutoff = CheckSessionCutoffAndForceClose(currentTime);
   if(isSessionCutoff) {
      UpdateDashboard(ukTime, false);
      return;
   }

   bool isM5Active = IsTimeframeSessionActive(PERIOD_M5, currentTime);
   bool isM1Active = IsTimeframeSessionActive(PERIOD_M1, currentTime);

   if(!isM5Active && !isM1Active) {
      UpdateDashboard(ukTime, false);
      return;
   }

   for(int i = 0; i < m_totalSymbols; i++) {
      if(!m_scanners[i].isValid) continue;

      if(IsMarketClosed(m_scanners[i].resolvedSymbol)) continue;

      UpdateSessionLiquidity(i);

      // Process 5M Execution Bar
      if(isM5Active) {
         datetime barM5 = iTime(m_scanners[i].resolvedSymbol, PERIOD_M5, 0);
         if(barM5 != m_scanners[i].lastProcessedBarM5 && barM5 > 0) {
            m_scanners[i].lastProcessedBarM5 = barM5;
            EvaluateEMAPullbackStrategy(i, PERIOD_M5);
         }
      }

      // Process 1M Execution Bar (13:00-17:00 UK Overlap Window)
      if(isM1Active) {
         datetime barM1 = iTime(m_scanners[i].resolvedSymbol, PERIOD_M1, 0);
         if(barM1 != m_scanners[i].lastProcessedBarM1 && barM1 > 0) {
            m_scanners[i].lastProcessedBarM1 = barM1;
            EvaluateEMAPullbackStrategy(i, PERIOD_M1);
         }
      }
   }

   ProcessScheduledReports(ukTime, dtUK);

   if(m_isStateChanged) {
      SaveState(false);
      m_isStateChanged = false;
   }

   UpdateDashboard(ukTime, (isM5Active || isM1Active));
}

void OnTick() {}

//====================================================================
// SECTION 7: MARKET STRUCTURE & KEY LEVEL ENGINES
//====================================================================

void UpdateSessionLiquidity(int idx) {
   string sym = m_scanners[idx].resolvedSymbol;
   datetime currentTime = TimeCurrent();
   datetime ukTime = GetUKTime(currentTime);
   MqlDateTime dt; TimeToStruct(ukTime, dt);

   MqlRates ratesD1[]; ArraySetAsSeries(ratesD1, true);
   if(CopyRates(sym, PERIOD_D1, 0, 2, ratesD1) >= 2) {
      m_scanners[idx].liquidity.prevDayHigh = ratesD1[1].high;
      m_scanners[idx].liquidity.prevDayLow  = ratesD1[1].low;
      m_scanners[idx].liquidity.currentDayHigh = ratesD1[0].high;
      m_scanners[idx].liquidity.currentDayLow  = ratesD1[0].low;
   }

   datetime dayStart = currentTime - (currentTime % 86400);
   if(dt.hour < 7) {
      MqlRates asianRates[]; ArraySetAsSeries(asianRates, true);
      int count = CopyRates(sym, PERIOD_M5, 0, 84, asianRates);
      if(count > 0) {
         double highest = -999999, lowest = 999999;
         for(int k = 0; k < count; k++) {
            if(asianRates[k].high > highest) highest = asianRates[k].high;
            if(asianRates[k].low < lowest)   lowest  = asianRates[k].low;
         }
         m_scanners[idx].liquidity.asianHigh = highest;
         m_scanners[idx].liquidity.asianLow  = lowest;
         m_scanners[idx].liquidity.asianDate = dayStart;
      }
   }
}

void FindRecentSwings(string sym, ENUM_TIMEFRAMES tf, double &swingHighs[], double &swingLows[], int lookback = 30) {
   double h[], l[];
   ArraySetAsSeries(h, true); ArraySetAsSeries(l, true);
   if(CopyHigh(sym, tf, 1, lookback, h) <= 0 || CopyLow(sym, tf, 1, lookback, l) <= 0) return;

   ArrayResize(swingHighs, 0); ArrayResize(swingLows, 0);

   for(int i = 2; i < lookback - 2; i++) {
      if(h[i] > h[i-1] && h[i] > h[i-2] && h[i] > h[i+1] && h[i] > h[i+2]) {
         int s = ArraySize(swingHighs); ArrayResize(swingHighs, s + 1); swingHighs[s] = h[i];
      }
      if(l[i] < l[i-1] && l[i] < l[i-2] && l[i] < l[i+1] && l[i] < l[i+2]) {
         int s = ArraySize(swingLows); ArrayResize(swingLows, s + 1); swingLows[s] = l[i];
      }
   }
}

void AnalyzeMarketStructure(string sym, MarketStructure &structOut) {
   double h1Highs[], h1Lows[], m5Highs[], m5Lows[];
   FindRecentSwings(sym, PERIOD_H1, h1Highs, h1Lows, 30);
   FindRecentSwings(sym, PERIOD_M5, m5Highs, m5Lows, 30);

   int h1H = ArraySize(h1Highs);
   int h1L = ArraySize(h1Lows);
   if(h1H >= 2 && h1L >= 2) {
      if(h1Highs[0] > h1Highs[1] && h1Lows[0] > h1Lows[1]) {
         structOut.h1Pattern = "HH → HL";
         structOut.h1Bias = "Bullish";
      } else if(h1Highs[0] < h1Highs[1] && h1Lows[0] < h1Lows[1]) {
         structOut.h1Pattern = "LH → LL";
         structOut.h1Bias = "Bearish";
      } else {
         structOut.h1Pattern = "Mixed / Range";
         structOut.h1Bias = "Neutral";
      }
   } else {
      structOut.h1Pattern = "Mixed / Range";
      structOut.h1Bias = "Neutral";
   }

   int m5H = ArraySize(m5Highs);
   int m5L = ArraySize(m5Lows);
   if(m5H >= 2 && m5L >= 2) {
      if(m5Highs[0] > m5Highs[1] && m5Lows[0] > m5Lows[1]) {
         structOut.m5Pattern = "HH → HL";
         structOut.m5Bias = "Bullish";
      } else if(m5Highs[0] < m5Highs[1] && m5Lows[0] < m5Lows[1]) {
         structOut.m5Pattern = "LH → LL";
         structOut.m5Bias = "Bearish";
      } else {
         structOut.m5Pattern = "Mixed / Range";
         structOut.m5Bias = "Neutral";
      }
   } else {
      structOut.m5Pattern = "Mixed / Range";
      structOut.m5Bias = "Neutral";
   }
}

void CalculateKeyLevels(string sym, int idx, KeyLevels &levelsOut) {
   MqlRates ratesD1[]; ArraySetAsSeries(ratesD1, true);
   if(CopyRates(sym, PERIOD_D1, 0, 2, ratesD1) >= 2) {
      levelsOut.pdh = ratesD1[1].high;
      levelsOut.pdl = ratesD1[1].low;
      double pivot = (ratesD1[1].high + ratesD1[1].low + ratesD1[1].close) / 3.0;
      levelsOut.r1 = (2.0 * pivot) - ratesD1[1].low;
      levelsOut.r2 = pivot + (ratesD1[1].high - ratesD1[1].low);
      levelsOut.s1 = (2.0 * pivot) - ratesD1[1].high;
      levelsOut.s2 = pivot - (ratesD1[1].high - ratesD1[1].low);
   }

   if(idx >= 0 && idx < m_totalSymbols) {
      levelsOut.asianHigh = m_scanners[idx].liquidity.asianHigh;
      levelsOut.asianLow  = m_scanners[idx].liquidity.asianLow;

      double e21[], e200[];
      ArraySetAsSeries(e21, true); ArraySetAsSeries(e200, true);
      if(CopyBuffer(m_scanners[idx].h_ema21_m5, 0, 1, 1, e21) > 0) levelsOut.ema21 = e21[0];
      if(CopyBuffer(m_scanners[idx].h_ema200_m5, 0, 1, 1, e200) > 0) levelsOut.ema200 = e200[0];
   }
}

void GetMultiTimeframeAnalysis(string sym, int idx, MultiTimeframeAnalysis &mtfOut) {
   ENUM_HTF_TREND h1Trend = DetermineH1Trend(idx);
   if(h1Trend >= HTF_TREND_BULLISH) {
      mtfOut.dailyBias = BIAS_BULLISH;
      mtfOut.dailyReason = "Price holding above major daily structure";
      mtfOut.h1Analysis = "Bullish | HH → HL structure | Above EMA200";
      mtfOut.m30Analysis = "Bullish / Pullback | Respecting intraday support";
      mtfOut.m5Execution = "Bullish | EMA9 > EMA21 > EMA200 | Confirmation closed";
   } else if(h1Trend <= HTF_TREND_BEARISH) {
      mtfOut.dailyBias = BIAS_BEARISH;
      mtfOut.dailyReason = "Price holding below major daily structure";
      mtfOut.h1Analysis = "Bearish | LH → LL structure | Below EMA200";
      mtfOut.m30Analysis = "Bearish / Pullback | Respecting intraday resistance";
      mtfOut.m5Execution = "Bearish | EMA9 < EMA21 < EMA200 | Confirmation closed";
   } else {
      mtfOut.dailyBias = BIAS_NEUTRAL;
      mtfOut.dailyReason = "Price consolidating inside major daily range";
      mtfOut.h1Analysis = "Neutral / Range | Consolidating around EMAs";
      mtfOut.m30Analysis = "Mixed / Consolidation";
      mtfOut.m5Execution = "Neutral | Awaiting structural breakout";
   }
}

bool EvaluateMarketRegimeDetails(int idx, ENUM_TIMEFRAMES tf, RegimeEvaluation &regimeOut) {
   ZeroMemory(regimeOut);
   regimeOut.regime = REGIME_UNCLEAR;
   
   if(idx < 0 || idx >= m_totalSymbols) return false;
   string sym = m_scanners[idx].resolvedSymbol;
   
   int hEMA9   = (tf == PERIOD_M1) ? m_scanners[idx].h_ema9_m1 : m_scanners[idx].h_ema9_m5;
   int hEMA21  = (tf == PERIOD_M1) ? m_scanners[idx].h_ema21_m1 : m_scanners[idx].h_ema21_m5;
   int hEMA200 = (tf == PERIOD_M1) ? m_scanners[idx].h_ema200_m1 : m_scanners[idx].h_ema200_m5;
   int hATR    = (tf == PERIOD_M1) ? m_scanners[idx].h_atr_m1 : m_scanners[idx].h_atr_m5;

   int lookback = MathMax(InpEMACrossLookback, InpEMA200CrossLookback) + 5;
   double ema9[], ema21[], ema200[], atr[], close[];
   ArraySetAsSeries(ema9, true); ArraySetAsSeries(ema21, true);
   ArraySetAsSeries(ema200, true); ArraySetAsSeries(atr, true);
   ArraySetAsSeries(close, true);

   if(CopyBuffer(hEMA9, 0, 1, lookback, ema9) <= 0 ||
      CopyBuffer(hEMA21, 0, 1, lookback, ema21) <= 0 ||
      CopyBuffer(hEMA200, 0, 1, lookback, ema200) <= 0 ||
      CopyBuffer(hATR, 0, 1, 20, atr) <= 0 ||
      CopyClose(sym, tf, 1, lookback, close) <= 0) {
      return false;
   }

   double curATR = atr[0];
   if(curATR <= 0 || !MathIsValidNumber(curATR)) {
      double point = SymbolInfoDouble(sym, SYMBOL_POINT);
      curATR = (point > 0) ? point * 10 : 0.0010;
   }

   // 1. Calculate ATR Rolling Average & Ratio
   double sumATR = 0;
   int atrBars = MathMin(14, ArraySize(atr));
   for(int k = 0; k < atrBars; k++) sumATR += atr[k];
   double avgATR = (atrBars > 0) ? (sumATR / (double)atrBars) : curATR;
   regimeOut.atrRatio = (avgATR > 0) ? (curATR / avgATR) : 1.0;

   // 2. Count EMA 9 / EMA 21 Crosses
   int crossCount = 0;
   int maxCrossCheck = MathMin(InpEMACrossLookback, ArraySize(ema9) - 1);
   for(int c = 0; c < maxCrossCheck - 1; c++) {
      bool cross1 = (ema9[c] > ema21[c] && ema9[c+1] <= ema21[c+1]);
      bool cross2 = (ema9[c] < ema21[c] && ema9[c+1] >= ema21[c+1]);
      if(cross1 || cross2) crossCount++;
   }
   regimeOut.emaCrossCount = crossCount;

   // 3. Measure EMA 9 & EMA 21 Directional Slopes over Lookback
   int slopeLookback = MathMin(InpEMASlopeLookback, ArraySize(ema9) - 1);
   if(slopeLookback >= 1 && curATR > 0) {
      regimeOut.ema9SlopeATR  = (ema9[0] - ema9[slopeLookback]) / (slopeLookback * curATR);
      regimeOut.ema21SlopeATR = (ema21[0] - ema21[slopeLookback]) / (slopeLookback * curATR);
   }

   // 4. Calculate Normalized EMA 9 / EMA 21 Distance
   regimeOut.emaDistanceATR = (curATR > 0) ? (MathAbs(ema9[0] - ema21[0]) / curATR) : 0.0;

   // 5. Count Price vs EMA 200 Crosses
   int ema200Crosses = 0;
   int max200Check = MathMin(InpEMA200CrossLookback, ArraySize(close) - 1);
   for(int e = 0; e < max200Check - 1; e++) {
      bool cAbove = (close[e] > ema200[e] && close[e+1] <= ema200[e+1]);
      bool cBelow = (close[e] < ema200[e] && close[e+1] >= ema200[e+1]);
      if(cAbove || cBelow) ema200Crosses++;
   }
   regimeOut.ema200CrossCount = ema200Crosses;

   // 6. Evaluate Filter Block Flags
   if(crossCount > InpMaxEMACrosses) {
      regimeOut.isChoppy = true;
      regimeOut.blockReason = StringFormat("Excessive EMA 9/21 Crosses (%d > %d)", crossCount, InpMaxEMACrosses);
   }

   if(MathAbs(regimeOut.ema9SlopeATR) < InpMinEMASlopeATR && MathAbs(regimeOut.ema21SlopeATR) < InpMinEMASlopeATR) {
      regimeOut.isFlat = true;
      if(regimeOut.blockReason == "") {
         regimeOut.blockReason = StringFormat("Flat EMA Slopes (EMA9: %.2f, EMA21: %.2f < %.2f)", regimeOut.ema9SlopeATR, regimeOut.ema21SlopeATR, InpMinEMASlopeATR);
      }
   }

   if(regimeOut.emaDistanceATR < InpMinEMADistanceATR) {
      regimeOut.isCompressed = true;
      if(regimeOut.blockReason == "") {
         regimeOut.blockReason = StringFormat("EMA Compression (Dist: %.2f ATR < %.2f ATR)", regimeOut.emaDistanceATR, InpMinEMADistanceATR);
      }
   }

   if(ema200Crosses > InpMaxEMA200Crosses) {
      regimeOut.isRanging = true;
      if(regimeOut.blockReason == "") {
         regimeOut.blockReason = StringFormat("EMA 200 Whipsaw (%d Crosses > %d)", ema200Crosses, InpMaxEMA200Crosses);
      }
   }

   if(InpEnableATRRegimeFilter && regimeOut.atrRatio < InpMinATRPctOfAvg) {
      regimeOut.isLowVol = true;
      if(regimeOut.blockReason == "") {
         regimeOut.blockReason = StringFormat("Low Volatility Squeeze (ATR Ratio: %.2f < %.2f)", regimeOut.atrRatio, InpMinATRPctOfAvg);
      }
   }

   // 7. Determine Final Market Regime
   if(IsNewsRiskActive(sym)) {
      regimeOut.regime = REGIME_NEWS_RISK;
   } else if(regimeOut.isLowVol) {
      regimeOut.regime = REGIME_LOW_VOLATILITY;
   } else if(regimeOut.isChoppy) {
      regimeOut.regime = REGIME_CHOPPY;
   } else if(regimeOut.isRanging || regimeOut.isFlat || regimeOut.isCompressed) {
      regimeOut.regime = REGIME_RANGING;
   } else if(ema9[0] > ema21[0] && ema21[0] > ema200[0] && regimeOut.ema9SlopeATR > InpMinEMASlopeATR) {
      regimeOut.regime = REGIME_TRENDING_BULLISH;
   } else if(ema9[0] < ema21[0] && ema21[0] < ema200[0] && regimeOut.ema9SlopeATR < -InpMinEMASlopeATR) {
      regimeOut.regime = REGIME_TRENDING_BEARISH;
   } else if(ema9[0] > ema21[0]) {
      regimeOut.regime = REGIME_TRENDING_BULLISH;
   } else if(ema9[0] < ema21[0]) {
      regimeOut.regime = REGIME_TRENDING_BEARISH;
   } else {
      regimeOut.regime = REGIME_UNCLEAR;
   }

   return true;
}

bool CheckPriceRangeLocation(int idx, ENUM_TIMEFRAMES tf, double &outRangeHigh, double &outRangeLow, double &outPosPct) {
   if(idx < 0 || idx >= m_totalSymbols) return false;
   string sym = m_scanners[idx].resolvedSymbol;

   double h[], l[], c[];
   ArraySetAsSeries(h, true); ArraySetAsSeries(l, true); ArraySetAsSeries(c, true);
   int copied = CopyHigh(sym, tf, 1, InpRangeLookback, h);
   if(copied < 10 || CopyLow(sym, tf, 1, InpRangeLookback, l) < 10 || CopyClose(sym, tf, 1, 1, c) <= 0) return false;

   double maxH = -99999999.0;
   double minL = 99999999.0;
   for(int k = 0; k < copied; k++) {
      if(h[k] > maxH) maxH = h[k];
      if(l[k] < minL) minL = l[k];
   }

   outRangeHigh = maxH;
   outRangeLow  = minL;
   double span  = maxH - minL;
   if(span <= 0) {
      outPosPct = 50.0;
      return false;
   }

   outPosPct = (c[0] - minL) / span * 100.0;
   double middleLower = 50.0 - (InpRangeMiddleZonePercent / 2.0);
   double middleUpper = 50.0 + (InpRangeMiddleZonePercent / 2.0);

   return (outPosPct >= middleLower && outPosPct <= middleUpper);
}

bool EvaluateMarketStructureDetails(int idx, ENUM_TIMEFRAMES tf, int tradeType, StructureEvaluation &structOut) {
   ZeroMemory(structOut);
   structOut.pattern = "Mixed / Range";
   structOut.bias    = "Neutral";
   
   if(idx < 0 || idx >= m_totalSymbols) return false;
   string sym = m_scanners[idx].resolvedSymbol;

   int lookback = InpStructureLookbackBars;
   double h[], l[], c[];
   ArraySetAsSeries(h, true); ArraySetAsSeries(l, true); ArraySetAsSeries(c, true);

   if(CopyHigh(sym, tf, 1, lookback, h) < lookback ||
      CopyLow(sym, tf, 1, lookback, l) < lookback ||
      CopyClose(sym, tf, 1, lookback, c) < lookback) {
      return false;
   }

   double atr[]; ArraySetAsSeries(atr, true);
   int hATR = (tf == PERIOD_M1) ? m_scanners[idx].h_atr_m1 : m_scanners[idx].h_atr_m5;
   double curATR = (CopyBuffer(hATR, 0, 1, 1, atr) > 0) ? atr[0] : 0.0010;

   // 1. Identify Fractal Swing Highs and Swing Lows
   double swingHighs[], swingLows[];
   ArrayResize(swingHighs, 0); ArrayResize(swingLows, 0);
   int leftRight = InpSwingLookback;

   for(int i = leftRight; i < lookback - leftRight; i++) {
      bool isHigh = true;
      bool isLow = true;
      for(int j = 1; j <= leftRight; j++) {
         if(h[i] <= h[i - j] || h[i] <= h[i + j]) isHigh = false;
         if(l[i] >= l[i - j] || l[i] >= l[i + j]) isLow  = false;
      }
      if(isHigh) {
         int sz = ArraySize(swingHighs); ArrayResize(swingHighs, sz + 1); swingHighs[sz] = h[i];
      }
      if(isLow) {
         int sz = ArraySize(swingLows); ArrayResize(swingLows, sz + 1); swingLows[sz] = l[i];
      }
   }

   int numHighs = ArraySize(swingHighs);
   int numLows  = ArraySize(swingLows);

   if(numHighs >= 1) structOut.lastSwingHigh = swingHighs[0];
   if(numHighs >= 2) structOut.prevSwingHigh = swingHighs[1];
   if(numLows >= 1)  structOut.lastSwingLow  = swingLows[0];
   if(numLows >= 2)  structOut.prevSwingLow  = swingLows[1];

   // 2. Classify Directional Structure Progression (HH-HL / LH-LL)
   if(numHighs >= 2 && numLows >= 2) {
      if(swingHighs[0] > swingHighs[1] && swingLows[0] > swingLows[1]) {
         structOut.pattern = "HH → HL";
         structOut.bias    = "Bullish";
      } else if(swingHighs[0] < swingHighs[1] && swingLows[0] < swingLows[1]) {
         structOut.pattern = "LH → LL";
         structOut.bias    = "Bearish";
      }
   } else if(numHighs >= 1 && numLows >= 1) {
      if(c[0] > structOut.lastSwingHigh) {
         structOut.pattern = "HH → HL (Emerging)";
         structOut.bias    = "Bullish";
      } else if(c[0] < structOut.lastSwingLow) {
         structOut.pattern = "LH → LL (Emerging)";
         structOut.bias    = "Bearish";
      }
   }

   // 3. Break of Structure (BOS) Detection
   double minBOSDist = InpMinBOSDistanceATR * curATR;
   if(tradeType == ORDER_TYPE_BUY) {
      if(structOut.lastSwingHigh > 0) {
         bool closeBeyond = (c[0] >= structOut.lastSwingHigh + minBOSDist);
         bool wickBeyond  = (h[0] >= structOut.lastSwingHigh + minBOSDist);
         structOut.bosConfirmed = InpRequireCloseBeyondSwing ? closeBeyond : wickBeyond;
      } else {
         structOut.bosConfirmed = true; // Fallback if no swing high within window
      }
   } else if(tradeType == ORDER_TYPE_SELL) {
      if(structOut.lastSwingLow > 0) {
         bool closeBeyond = (c[0] <= structOut.lastSwingLow - minBOSDist);
         bool wickBeyond  = (l[0] <= structOut.lastSwingLow - minBOSDist);
         structOut.bosConfirmed = InpRequireCloseBeyondSwing ? closeBeyond : wickBeyond;
      } else {
         structOut.bosConfirmed = true; // Fallback if no swing low within window
      }
   }

   // 4. Check Range Location / Middle Zone Trap
   structOut.inMiddleRange = CheckPriceRangeLocation(idx, tf, structOut.rangeHigh, structOut.rangeLow, structOut.rangePosPct);

   return true;
}

void LogTradeDiagnostic(bool approved, string sym, ENUM_TIMEFRAMES tf, int dir, const RegimeEvaluation &regime, const StructureEvaluation &structure, ENUM_HTF_TREND h1Trend, int qualityScore, string decisionReason) {
   if(!InpEnableDiagnostics) return;

   string tfStr  = (tf == PERIOD_M1) ? "M1" : "M5";
   string dirStr = (dir == ORDER_TYPE_BUY) ? "BUY" : "SELL";
   string h1Str  = (h1Trend >= HTF_TREND_BULLISH) ? "BULLISH" : ((h1Trend <= HTF_TREND_BEARISH) ? "BEARISH" : "NEUTRAL");

   if(!approved) {
      PrintFormat(
         "============================================================\n"
         "⛔ [TRADE BLOCKED] %s | %s | Direction: %s\n"
         "Regime: %s | Block Flag: %s\n"
         "Structure: %s (Bias: %s) | BOS Confirmed: %s\n"
         "EMA 9/21 Crosses: %d (Max: %d) | EMA Separation: %.2f ATR (Min: %.2f ATR)\n"
         "EMA 9 Slope: %.2f ATR | EMA 21 Slope: %.2f ATR (Min: %.2f ATR)\n"
         "EMA 200 Crosses: %d (Max: %d) | Range Pos: %.1f%% (Middle Trap: %s)\n"
         "H1 Trend: %s | Quality Score: %d/100\n"
         "Decision: NO TRADE 🚫 | Reason: %s\n"
         "============================================================",
         sym, tfStr, dirStr,
         MarketRegimeToString(regime.regime), (regime.blockReason != "" ? regime.blockReason : "None"),
         structure.pattern, structure.bias, (structure.bosConfirmed ? "YES" : "NO"),
         regime.emaCrossCount, InpMaxEMACrosses, regime.emaDistanceATR, InpMinEMADistanceATR,
         regime.ema9SlopeATR, regime.ema21SlopeATR, InpMinEMASlopeATR,
         regime.ema200CrossCount, InpMaxEMA200Crosses, structure.rangePosPct, (structure.inMiddleRange ? "YES" : "NO"),
         h1Str, qualityScore, decisionReason
      );
   } else {
      PrintFormat(
         "============================================================\n"
         "✅ [TRADE APPROVED] %s | %s | Direction: %s\n"
         "Regime: %s | Structure: %s (Bias: %s) | BOS: YES\n"
         "EMA 9/21 Separation: %.2f ATR | EMA 200 Crosses: %d\n"
         "Range Location: %.1f%% | H1 Trend: %s | Score: %d/100\n"
         "Decision: EXECUTE %s ORDER 🚀\n"
         "============================================================",
         sym, tfStr, dirStr,
         MarketRegimeToString(regime.regime), structure.pattern, structure.bias,
         regime.emaDistanceATR, regime.ema200CrossCount,
         structure.rangePosPct, h1Str, qualityScore,
         dirStr
      );
   }
}

ENUM_MARKET_REGIME DetermineMarketRegime(string sym, int idx) {
   if(IsNewsRiskActive(sym)) return REGIME_NEWS_RISK;

   RegimeEvaluation eval;
   if(EvaluateMarketRegimeDetails(idx, PERIOD_M5, eval)) {
      return eval.regime;
   }

   return REGIME_CHOPPY;
}

string MarketRegimeToString(ENUM_MARKET_REGIME regime) {
   switch(regime) {
      case REGIME_TRENDING_BULLISH: return "Trending Bullish";
      case REGIME_TRENDING_BEARISH: return "Trending Bearish";
      case REGIME_RANGING:          return "Ranging";
      case REGIME_CHOPPY:           return "Choppy";
      case REGIME_HIGH_VOLATILITY:  return "High Volatility";
      case REGIME_LOW_VOLATILITY:   return "Low Volatility";
      case REGIME_NEWS_RISK:        return "News Volatility Risk";
      case REGIME_UNCLEAR:          return "Unclear / Flat";
   }
   return "Neutral";
}

string SanitizeHashtag(string text) {
   string res = text;
   StringReplace(res, " ", "");
   StringReplace(res, "-", "");
   StringReplace(res, "_", "");
   StringReplace(res, "/", "");
   StringReplace(res, "&", "");
   StringReplace(res, ".", "");
   return "#" + res;
}

//====================================================================
// SECTION 8: HIGHER TIMEFRAME ALIGNMENT & CONFLUENCE
//====================================================================

ENUM_HTF_TREND DetermineH1Trend(int idx) {
   string sym = m_scanners[idx].resolvedSymbol;

   double ema9[], ema21[], ema200[], close[];
   ArraySetAsSeries(ema9, true); ArraySetAsSeries(ema21, true);
   ArraySetAsSeries(ema200, true); ArraySetAsSeries(close, true);

   if(CopyBuffer(m_scanners[idx].h_ema9_h1, 0, 1, 2, ema9) <= 0 ||
      CopyBuffer(m_scanners[idx].h_ema21_h1, 0, 1, 2, ema21) <= 0 ||
      CopyBuffer(m_scanners[idx].h_ema200_h1, 0, 1, 2, ema200) <= 0 ||
      CopyClose(sym, PERIOD_H1, 1, 2, close) <= 0) return HTF_TREND_NEUTRAL;

   // Proven TradingView Logic: H1 Close vs H1 EMA 200 + EMA 9/21 Alignment
   bool above200  = (close[0] > ema200[0]);
   bool below200  = (close[0] < ema200[0]);
   bool bullCross = (ema9[0] > ema21[0]);
   bool bearCross = (ema9[0] < ema21[0]);

   if(above200 && bullCross && ema9[0] > ema9[1]) return HTF_TREND_STRONG_BULLISH;
   if(above200 || bullCross) return HTF_TREND_BULLISH;

   if(below200 && bearCross && ema9[0] < ema9[1]) return HTF_TREND_STRONG_BEARISH;
   if(below200 || bearCross) return HTF_TREND_BEARISH;

   return HTF_TREND_NEUTRAL;
}

bool CheckVolumeExpansion(string sym, ENUM_TIMEFRAMES tf, int candleIndex = 1) {
   if(!InpUseVolumeFilter) return true;

   long vol[]; ArraySetAsSeries(vol, true);
   if(CopyRealVolume(sym, tf, candleIndex, InpVolumeLookback + 1, vol) <= 0) {
      if(CopyTickVolume(sym, tf, candleIndex, InpVolumeLookback + 1, vol) <= 0) return true;
   }

   double sum = 0;
   for(int i = 1; i <= InpVolumeLookback; i++) sum += (double)vol[i];
   double avgVol = sum / InpVolumeLookback;

   if(avgVol <= 0) return true;

   return ((double)vol[0] >= avgVol * InpVolumeMultiplier);
}

//====================================================================
// SECTION 9: CLEAN M5 9/21 EMA PULLBACK & RE-ENTRY ENGINE
//====================================================================

// Bullish Confirmation: Green candle + (High Break OR Engulfing) + Minimum Range
bool IsBullishConfirmation(const double &open[], const double &high[], const double &low[], const double &close[], double atr) {
   // Bar 0 is last closed bar (Shift 1), Bar 1 is prior closed bar (Shift 2)
   if(close[0] <= open[0]) return false; // Must be a green candle

   // Minimum candle range filter (prevents zero-range or micro noise bars)
   double candleRange = high[0] - low[0];
   if(atr > 0 && candleRange < (atr * InpMinCandleRangeATR)) return false;

   // Confirmation: Close > prior High (High Break) OR Bullish Engulfing
   bool highBreak = (close[0] > high[1]);
   bool bodyEngulfs = (open[0] <= MathMax(open[1], close[1])) && 
                      (close[0] >= MathMin(open[1], close[1])) && 
                      ((close[0] - open[0]) >= MathAbs(close[1] - open[1]) * 0.90);
   bool priorWasBearish = (close[1] < open[1]);

   if(InpRequireEngulfing) {
      return (highBreak || (bodyEngulfs && priorWasBearish));
   }
   return (highBreak || bodyEngulfs || (close[0] > open[1]));
}

// Bearish Confirmation: Red candle + (Low Break OR Engulfing) + Minimum Range
bool IsBearishConfirmation(const double &open[], const double &high[], const double &low[], const double &close[], double atr) {
   if(close[0] >= open[0]) return false; // Must be a red candle

   double candleRange = high[0] - low[0];
   if(atr > 0 && candleRange < (atr * InpMinCandleRangeATR)) return false;

   // Confirmation: Close < prior Low (Low Break) OR Bearish Engulfing
   bool lowBreak = (close[0] < low[1]);
   bool bodyEngulfs = (open[0] >= MathMin(open[1], close[1])) && 
                      (close[0] <= MathMax(open[1], close[1])) && 
                      ((open[0] - close[0]) >= MathAbs(close[1] - open[1]) * 0.90);
   bool priorWasBullish = (close[1] > open[1]);

   if(InpRequireEngulfing) {
      return (lowBreak || (bodyEngulfs && priorWasBullish));
   }
   return (lowBreak || bodyEngulfs || (close[0] < open[1]));
}

// EMA Health & Directional Slope Filter (Anti-Chop / Flat Market Filter)
//====================================================================
// QUANTITATIVE EMA HEALTH & VOLUME CONFIRMATION ENGINES
//====================================================================

ENUM_EMA_HEALTH_STATE EvaluateEMAHealthQuantitative(string sym, const double &ema9[], const double &ema21[], double atrVal, int lookback, double &outSepATR, double &outSlope9, int &outCrossCount) {
   if(atrVal <= 0 || !MathIsValidNumber(atrVal)) {
      outSepATR = 0.0;
      outSlope9 = 0.0;
      outCrossCount = 0;
      return EMA_HEALTH_FLAT_CHOPPY;
   }
   
   outSepATR = MathAbs(ema9[0] - ema21[0]) / atrVal;
   int lb = MathMin(lookback - 1, ArraySize(ema9) - 1);
   outSlope9 = (ema9[0] - ema9[lb]) / (lb * atrVal);
   
   outCrossCount = 0;
   int checkBars = MathMin(lookback, MathMin(ArraySize(ema9), ArraySize(ema21)) - 1);
   for(int b = 0; b < checkBars; b++) {
      if((ema9[b] - ema21[b]) * (ema9[b + 1] - ema21[b + 1]) < 0) {
         outCrossCount++;
      }
   }
   
   if(outCrossCount > EMA_Health_Max_Crosses || outSepATR < (EMA_Health_Min_Separation_ATR * 0.6)) {
      return EMA_HEALTH_FLAT_CHOPPY;
   }
   
   if(outSepATR >= EMA_Health_Min_Separation_ATR && MathAbs(outSlope9) >= 0.15) {
      return EMA_HEALTH_HEALTHY;
   }
   
   return EMA_HEALTH_WEAK;
}

ENUM_VOLUME_STATE EvaluateVolumeFilter(string sym, ENUM_TIMEFRAMES tf, int lookback, double minMult, double &outVolRatio) {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(sym, tf, 0, lookback + 2, rates);
   if(copied <= lookback + 1) {
      outVolRatio = 1.0;
      return VOLUME_CONFIRMED;
   }
   
   long sumVol = 0;
   for(int i = 1; i <= lookback; i++) {
      sumVol += rates[i].tick_volume;
   }
   double avgVol = (double)sumVol / (double)lookback;
   if(avgVol <= 0) {
      outVolRatio = 1.0;
      return VOLUME_CONFIRMED;
   }
   
   outVolRatio = (double)rates[1].tick_volume / avgVol;
   if(outVolRatio >= minMult) return VOLUME_CONFIRMED;
   if(outVolRatio >= 0.85) return VOLUME_AVERAGE;
   return VOLUME_WEAK;
}

bool CheckEMAHealthFilter(const double &ema9[], const double &ema21[], double atr, int dir, double &calculatedAngle, string &diagReason) {
   if(!InpEnableEMAHealthFilter) {
      calculatedAngle = 45.0;
      return true;
   }

   if(atr <= 0 || !MathIsValidNumber(atr)) {
      diagReason = "Invalid ATR for health check";
      return true;
   }

   int lookback = MathMax(1, InpEMAHealthLookbackBars);
   if(ArraySize(ema9) <= lookback || ArraySize(ema21) <= lookback) {
      diagReason = "Insufficient EMA buffer depth";
      return true;
   }

   // 1. Normalized Directional Delta over lookback
   double ema9Delta = (dir == ORDER_TYPE_BUY) ? (ema9[0] - ema9[lookback]) : (ema9[lookback] - ema9[0]);
   double ema21Delta = (dir == ORDER_TYPE_BUY) ? (ema21[0] - ema21[lookback]) : (ema21[lookback] - ema21[0]);

   // Dimension-independent slope ratio normalized to ATR
   double slopeRatio9 = ema9Delta / (lookback * atr);
   double slopeRatio21 = ema21Delta / (lookback * atr);

   // Convert to degree angle: atan(slopeRatio * 2.0) * (180.0 / PI)
   double angle9 = MathArctan(slopeRatio9 * 2.0) * (180.0 / M_PI);
   double angle21 = MathArctan(slopeRatio21 * 2.0) * (180.0 / M_PI);
   calculatedAngle = NormalizeDouble(MathMin(angle9, angle21), 1);

   // 2. Minimum Angle Threshold (Default: >= 30.0 degrees)
   if(angle9 < InpMinEMAHealthAngle) {
      diagReason = StringFormat("EMA9 Slope Angle (%.1f°) below Min Cap (%.1f°)", angle9, InpMinEMAHealthAngle);
      return false;
   }

   // 3. Directional Alignment: EMA9 must be on correct side of EMA21
   if(dir == ORDER_TYPE_BUY && ema9[0] <= ema21[0]) {
      diagReason = "EMA9 not strictly above EMA21";
      return false;
   }
   if(dir == ORDER_TYPE_SELL && ema9[0] >= ema21[0]) {
      diagReason = "EMA9 not strictly below EMA21";
      return false;
   }

   // 4. Separation & Cross Frequency (Chop Gate)
   double separation = MathAbs(ema9[0] - ema21[0]) / atr;
   if(separation < EMA_Health_Min_Separation_ATR) {
      diagReason = StringFormat("EMA Separation (%.2fx ATR) below Min (%.2fx ATR)", separation, EMA_Health_Min_Separation_ATR);
      return false;
   }

   int crossCount = 0;
   int checkBars = MathMin(EMA_Health_Lookback, MathMin(ArraySize(ema9), ArraySize(ema21)) - 1);
   for(int b = 0; b < checkBars; b++) {
      if((ema9[b] - ema21[b]) * (ema9[b + 1] - ema21[b + 1]) < 0) crossCount++;
   }
   if(crossCount > EMA_Health_Max_Crosses) {
      diagReason = StringFormat("EMA 9/21 Repeated Crosses (%d crosses > max %d) - Flat/Choppy", crossCount, EMA_Health_Max_Crosses);
      return false;
   }

   // 5. Anti-chop consistency: Both EMAs must be sloping in the trade direction
   if(ema9Delta <= 0 || ema21Delta < 0) {
      diagReason = "EMAs showing conflicting / flat directional trajectory";
      return false;
   }

   return true;
}

void ProcessEMAPullbackForCycle(int idx, ENUM_TIMEFRAMES tf, SymbolCycleState &cycle) {
   string sym = m_scanners[idx].resolvedSymbol;
   datetime currentBarTime = iTime(sym, tf, 1);

   // 1. Strict Duplicate Guard (Never re-process the exact same closed bar)
   if(currentBarTime == cycle.lastSignalBar && cycle.lastSignalBar > 0) return;

   // 2. Check High-Impact News Filter
   bool newsRisk = (InpEnableNewsFilter && IsNewsRiskActive(sym));
   if(newsRisk) {
      LogCoreSetupDiagnostic(false, sym, tf, (cycle.state == CYCLE_BEARISH ? ORDER_TYPE_SELL : ORDER_TYPE_BUY), cycle.pullbackLevel, false, true, false, false, 0, "REJECTED — NEWS FILTER (High-Impact Event Active)");
      return;
   }

   int hEMA9   = (tf == PERIOD_M1) ? m_scanners[idx].h_ema9_m1 : m_scanners[idx].h_ema9_m5;
   int hEMA21  = (tf == PERIOD_M1) ? m_scanners[idx].h_ema21_m1 : m_scanners[idx].h_ema21_m5;
   int hEMA200 = (tf == PERIOD_M1) ? m_scanners[idx].h_ema200_m1 : m_scanners[idx].h_ema200_m5;
   int hATR    = (tf == PERIOD_M1) ? m_scanners[idx].h_atr_m1 : m_scanners[idx].h_atr_m5;

   double ema9[], ema21[], ema200[], atr[], open[], high[], low[], close[];
   ArraySetAsSeries(ema9, true); ArraySetAsSeries(ema21, true); ArraySetAsSeries(ema200, true);
   ArraySetAsSeries(atr, true); ArraySetAsSeries(open, true); ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true); ArraySetAsSeries(close, true);

   if(CopyBuffer(hEMA9, 0, 1, 8, ema9) <= 0 ||
      CopyBuffer(hEMA21, 0, 1, 8, ema21) <= 0 ||
      CopyBuffer(hEMA200, 0, 1, 8, ema200) <= 0 ||
      CopyBuffer(hATR, 0, 1, 1, atr) <= 0 ||
      CopyOpen(sym, tf, 1, 8, open) <= 0 ||
      CopyHigh(sym, tf, 1, 8, high) <= 0 ||
      CopyLow(sym, tf, 1, 8, low) <= 0 ||
      CopyClose(sym, tf, 1, 8, close) <= 0) return;

   string tfLabel = (tf == PERIOD_M1) ? "M1" : "M5";

   // A. Detect Confirmed EMA 9 / EMA 21 Crossovers on Closed M5 Bar
   bool bullCrossNow = (ema9[0] > ema21[0] && ema9[1] <= ema21[1]);
   bool bearCrossNow = (ema9[0] < ema21[0] && ema9[1] >= ema21[1]);

   // B. Handle Cycle Initialization on Fresh Crossover
   if(bullCrossNow) {
      if(cycle.state == CYCLE_BEARISH) {
         ClosePositionsForSymbolAndType(sym, ORDER_TYPE_SELL, "Opposite EMA 9/21 Crossover");
      }
      cycle.state = CYCLE_BULLISH;
      cycle.cycleStartBar = currentBarTime;
      cycle.hasExpanded = false; // Require price expansion away before a valid retest can qualify
      cycle.pullbackActive = false;
      cycle.pullbackLevel = 0;
      cycle.primaryEntryDone = false;
      cycle.reEntriesCount = 0;
      cycle.lastSignalBar = 0;
      cycle.lastEntryPrice = close[0];
      return;
   }
   else if(bearCrossNow) {
      if(cycle.state == CYCLE_BULLISH) {
         ClosePositionsForSymbolAndType(sym, ORDER_TYPE_BUY, "Opposite EMA 9/21 Crossover");
      }
      cycle.state = CYCLE_BEARISH;
      cycle.cycleStartBar = currentBarTime;
      cycle.hasExpanded = false; // Require price expansion away before a valid retest can qualify
      cycle.pullbackActive = false;
      cycle.pullbackLevel = 0;
      cycle.primaryEntryDone = false;
      cycle.reEntriesCount = 0;
      cycle.lastSignalBar = 0;
      cycle.lastEntryPrice = close[0];
      return;
   }

   // C. Sensible Trend Invalidation Boundary (EMA 200 Closed-Bar Invalidation)
   if(cycle.state == CYCLE_BULLISH && InpUseEMA200Filter && close[0] < ema200[0]) {
      cycle.pullbackActive = false;
   }
   if(cycle.state == CYCLE_BEARISH && InpUseEMA200Filter && close[0] > ema200[0]) {
      cycle.pullbackActive = false;
   }

   // ================================================================
   // BULLISH CYCLE PIPELINE
   // ================================================================
   if(cycle.state == CYCLE_BULLISH) {
      // 1. Core EMA 200 Directional Gate
      if(InpUseEMA200Filter && close[0] <= ema200[0]) {
         LogCoreSetupDiagnostic(false, sym, tf, ORDER_TYPE_BUY, cycle.pullbackLevel, false, true, true, false, 0, "Price below M5 EMA 200");
         return;
      }

      // 2. Optional H1 Trend Filter (Default OFF)
      bool h1Pass = true;
      if(InpUseH1TrendFilter) {
         ENUM_HTF_TREND h1Trend = DetermineH1Trend(idx);
         if(h1Trend != HTF_TREND_BULLISH && h1Trend != HTF_TREND_STRONG_BULLISH) {
            h1Pass = false;
            LogCoreSetupDiagnostic(false, sym, tf, ORDER_TYPE_BUY, cycle.pullbackLevel, false, false, true, false, 0, "REJECTED — H1 FILTER (H1 Trend Bearish/Neutral)");
            return;
         }
      }

      // 3. Optional Legacy/Advanced Filters (Populate for Quality Scoring)
      RegimeEvaluation regimeInfo; ZeroMemory(regimeInfo);
      StructureEvaluation structInfo; ZeroMemory(structInfo);
      EvaluateMarketRegimeDetails(idx, tf, regimeInfo);
      EvaluateMarketStructureDetails(idx, tf, ORDER_TYPE_BUY, structInfo);

      if(InpEnableMarketRegimeFilter) {
         if(regimeInfo.isChoppy || regimeInfo.isRanging || regimeInfo.isFlat || regimeInfo.isCompressed || regimeInfo.isLowVol) {
            LogTradeDiagnostic(false, sym, tf, ORDER_TYPE_BUY, regimeInfo, structInfo, HTF_TREND_BULLISH, 0, regimeInfo.blockReason);
            return;
         }
      }
      if(InpEnableStructureFilter && structInfo.bias == "Bearish") return;
      if(InpEnableBOSFilter && !structInfo.bosConfirmed) return;
      if(InpEnableRangeFilter && structInfo.inMiddleRange) return;
      if(InpUseVolumeFilter && !CheckVolumeExpansion(sym, tf, 1)) {
         LogCoreSetupDiagnostic(false, sym, tf, ORDER_TYPE_BUY, cycle.pullbackLevel, false, h1Pass, true, false, 0, "Volume below multiplier threshold");
         return;
      }

      // 4. Trend Expansion Tracking (Ensure price moved out of crossover zone)
      if(!cycle.hasExpanded) {
         if(!cycle.primaryEntryDone) {
            if((close[0] > ema9[0] && high[0] > high[1]) || (close[0] > ema9[0] && close[0] > open[0])) {
               cycle.hasExpanded = true;
            } else {
               return;
            }
         } else {
            // For Re-entry: Require fresh push in trend direction above previous entry
            if(high[0] > cycle.lastEntryPrice || close[0] > ema9[0]) {
               cycle.hasExpanded = true;
            } else {
               return;
            }
         }
      }

      // 5. Multi-Level Pullback & Retest Detection (Levels 1 to 4)
      if(!cycle.pullbackActive) {
         bool touchedEMA9 = (low[0] <= ema9[0]);
         bool enteredZone = (low[0] <= MathMax(ema9[0], ema21[0]) && high[0] >= MathMin(ema9[0], ema21[0]));
         bool touchedEMA21 = (low[0] <= ema21[0]);
         bool deepPenetration = (low[0] < ema21[0]);

         if(deepPenetration && InpAllowDeepPullback) {
            cycle.pullbackActive = true;
            cycle.pullbackLevel = 4;
            cycle.lastPullbackBar = currentBarTime;
         } else if(touchedEMA21) {
            cycle.pullbackActive = true;
            cycle.pullbackLevel = 3;
            cycle.lastPullbackBar = currentBarTime;
         } else if(enteredZone) {
            cycle.pullbackActive = true;
            cycle.pullbackLevel = 2;
            cycle.lastPullbackBar = currentBarTime;
         } else if(touchedEMA9) {
            cycle.pullbackActive = true;
            cycle.pullbackLevel = 1;
            cycle.lastPullbackBar = currentBarTime;
         }
      }

      if(InpRequirePullbackAfterCross && !cycle.pullbackActive) {
         LogCoreSetupDiagnostic(false, sym, tf, ORDER_TYPE_BUY, 0, false, h1Pass, true, false, 0, "Awaiting Pullback into EMA 9/21 Value Zone");
         return;
      }

      // 6. Mandatory EMA Health & Trend Quality Gate (Anti-Chop Filter)
      double emaAngle = 0.0;
      string emaDiag = "";
      if(!CheckEMAHealthFilter(ema9, ema21, atr[0], ORDER_TYPE_BUY, emaAngle, emaDiag)) {
         LogCoreSetupDiagnostic(false, sym, tf, ORDER_TYPE_BUY, cycle.pullbackLevel, false, h1Pass, true, cycle.primaryEntryDone, 0, "REJECTED — EMA HEALTH: " + emaDiag);
         return;
      }

      // 7. Bullish Confirmation Candle Validation (Bar 1 Closed)
      bool confirmationValid = IsBullishConfirmation(open, high, low, close, atr[0]);
      if(!confirmationValid) {
         LogCoreSetupDiagnostic(false, sym, tf, ORDER_TYPE_BUY, cycle.pullbackLevel, (cycle.pullbackLevel == 4), h1Pass, true, false, 0, "No Bullish Confirmation (Awaiting Engulfing / High Break)");
         return;
      }

      // 7b. Volume Confirmation Filter Check & Terminal Rejection Log
      double volRatio = 1.0;
      ENUM_VOLUME_STATE volState = EvaluateVolumeFilter(sym, tf, Volume_Lookback, Volume_Min_Multiplier, volRatio);
      if(Use_Volume_Filter && volState == VOLUME_WEAK) {
         Print(StringFormat("%s | M5 | BUY REJECTED | EMA_HEALTH=HEALTHY | SEPARATION=%.2fATR | VOLUME=%.2fx (WEAK) | REASON=Weak Volume (< %.2fx SMA)", sym, (MathAbs(ema9[0]-ema21[0])/atr[0]), volRatio, Volume_Min_Multiplier));
         LogCoreSetupDiagnostic(false, sym, tf, ORDER_TYPE_BUY, cycle.pullbackLevel, (cycle.pullbackLevel == 4), h1Pass, true, false, 0, "REJECTED — WEAK VOLUME");
         return;
      }

      // 8. Determine Entry Type (Primary vs Re-Entry)
      bool isReEntry = cycle.primaryEntryDone;
      if(isReEntry) {
         if(!InpEnableReEntry || cycle.reEntriesCount >= InpMaxReEntriesPerCycle) {
            LogCoreSetupDiagnostic(false, sym, tf, ORDER_TYPE_BUY, cycle.pullbackLevel, (cycle.pullbackLevel == 4), h1Pass, true, true, 0, "Max Cycle Entries Reached (Re-Entries Disabled / Capped)");
            return;
         }
      }

      // 9. Stop Loss & Target Sizing
      double pointVal = SymbolInfoDouble(sym, SYMBOL_POINT);
      double slPrice = low[0] - (InpSLEngulfingBufferPoints * pointVal) - (atr[0] * InpSLBufferATR * 0.5);
      for(int b = 1; b < 3; b++) {
         if(low[b] < low[0] && low[b] > low[0] - (atr[0] * 1.5)) {
            slPrice = MathMin(slPrice, low[b] - (InpSLEngulfingBufferPoints * pointVal));
         }
      }

      double risk = close[0] - slPrice;
      if(risk <= 0) return;
      double tp1 = close[0] + (risk * 2.0);

      // 10. Execute Signal & Dispatch Telegram Alert
      double tradeRisk = isReEntry ? InpReEntryRiskPercent : InpRiskPercent;
      SignalQuality q = CalculateQualityScore(idx, ORDER_TYPE_BUY, HTF_TREND_BULLISH, close[0], slPrice, risk, atr[0], tf, structInfo, regimeInfo);

      string pullbackDesc = (cycle.pullbackLevel == 4 ? "Deep EMA21 Pullback" : (cycle.pullbackLevel == 3 ? "EMA21 Retest" : (cycle.pullbackLevel == 2 ? "Value Zone Pullback" : "EMA9 Retest")));
      string modeLabel = (InpTradeManagementMode == MODE_TREND_RUNNER_CROSSOVER) ? "Trend Runner (+1R BE)" : "Standard (2R TP1)";
      string triggerReason = StringFormat("%s %s + Bullish Engulfing\nMode: %s | Entry: %s (Risk: %.1f%%)", tfLabel, pullbackDesc, modeLabel, (isReEntry ? StringFormat("Re-Entry #%d", cycle.reEntriesCount + 1) : "Primary"), tradeRisk);

      LogCoreSetupDiagnostic(true, sym, tf, ORDER_TYPE_BUY, cycle.pullbackLevel, (cycle.pullbackLevel == 4), h1Pass, true, isReEntry, tradeRisk, "Core M5 Bullish Pullback Approved");
      ExecuteTradeSignal(idx, tf, ORDER_TYPE_BUY, close[0], slPrice, tp1, q, triggerReason, isReEntry);

      // Update State Tracking
      cycle.lastSignalBar = currentBarTime;
      cycle.lastEntryPrice = close[0];
      cycle.pullbackActive = false;
      cycle.pullbackLevel = 0;
      cycle.hasExpanded = false;
      if(!isReEntry) {
         cycle.primaryEntryDone = true;
      } else {
         cycle.reEntriesCount++;
      }
      return;
   }

   // ================================================================
   // BEARISH CYCLE PIPELINE
   // ================================================================
   if(cycle.state == CYCLE_BEARISH) {
      // 1. Core EMA 200 Directional Gate
      if(InpUseEMA200Filter && close[0] >= ema200[0]) {
         LogCoreSetupDiagnostic(false, sym, tf, ORDER_TYPE_SELL, cycle.pullbackLevel, false, true, true, false, 0, "Price above M5 EMA 200");
         return;
      }

      // 2. Optional H1 Trend Filter (Default OFF)
      bool h1Pass = true;
      if(InpUseH1TrendFilter) {
         ENUM_HTF_TREND h1Trend = DetermineH1Trend(idx);
         if(h1Trend != HTF_TREND_BEARISH && h1Trend != HTF_TREND_STRONG_BEARISH) {
            h1Pass = false;
            LogCoreSetupDiagnostic(false, sym, tf, ORDER_TYPE_SELL, cycle.pullbackLevel, false, false, true, false, 0, "REJECTED — H1 FILTER (H1 Trend Bullish/Neutral)");
            return;
         }
      }

      // 3. Optional Legacy/Advanced Filters (Populate for Quality Scoring)
      RegimeEvaluation regimeInfo; ZeroMemory(regimeInfo);
      StructureEvaluation structInfo; ZeroMemory(structInfo);
      EvaluateMarketRegimeDetails(idx, tf, regimeInfo);
      EvaluateMarketStructureDetails(idx, tf, ORDER_TYPE_SELL, structInfo);

      if(InpEnableMarketRegimeFilter) {
         if(regimeInfo.isChoppy || regimeInfo.isRanging || regimeInfo.isFlat || regimeInfo.isCompressed || regimeInfo.isLowVol) {
            LogTradeDiagnostic(false, sym, tf, ORDER_TYPE_SELL, regimeInfo, structInfo, HTF_TREND_BEARISH, 0, regimeInfo.blockReason);
            return;
         }
      }
      if(InpEnableStructureFilter && structInfo.bias == "Bullish") return;
      if(InpEnableBOSFilter && !structInfo.bosConfirmed) return;
      if(InpEnableRangeFilter && structInfo.inMiddleRange) return;
      if(InpUseVolumeFilter && !CheckVolumeExpansion(sym, tf, 1)) {
         LogCoreSetupDiagnostic(false, sym, tf, ORDER_TYPE_SELL, cycle.pullbackLevel, false, h1Pass, true, false, 0, "Volume below multiplier threshold");
         return;
      }

      // 4. Trend Expansion Tracking (Ensure price moved out of crossover zone)
      if(!cycle.hasExpanded) {
         if(!cycle.primaryEntryDone) {
            if((close[0] < ema9[0] && low[0] < low[1]) || (close[0] < ema9[0] && close[0] < open[0])) {
               cycle.hasExpanded = true;
            } else {
               return;
            }
         } else {
            // For Re-entry: Require fresh push in trend direction below previous entry
            if(low[0] < cycle.lastEntryPrice || close[0] < ema9[0]) {
               cycle.hasExpanded = true;
            } else {
               return;
            }
         }
      }

      // 5. Multi-Level Pullback & Retest Detection (Levels 1 to 4)
      if(!cycle.pullbackActive) {
         bool touchedEMA9 = (high[0] >= ema9[0]);
         bool enteredZone = (high[0] >= MathMin(ema9[0], ema21[0]) && low[0] <= MathMax(ema9[0], ema21[0]));
         bool touchedEMA21 = (high[0] >= ema21[0]);
         bool deepPenetration = (high[0] > ema21[0]);

         if(deepPenetration && InpAllowDeepPullback) {
            cycle.pullbackActive = true;
            cycle.pullbackLevel = 4;
            cycle.lastPullbackBar = currentBarTime;
         } else if(touchedEMA21) {
            cycle.pullbackActive = true;
            cycle.pullbackLevel = 3;
            cycle.lastPullbackBar = currentBarTime;
         } else if(enteredZone) {
            cycle.pullbackActive = true;
            cycle.pullbackLevel = 2;
            cycle.lastPullbackBar = currentBarTime;
         } else if(touchedEMA9) {
            cycle.pullbackActive = true;
            cycle.pullbackLevel = 1;
            cycle.lastPullbackBar = currentBarTime;
         }
      }

      if(InpRequirePullbackAfterCross && !cycle.pullbackActive) {
         LogCoreSetupDiagnostic(false, sym, tf, ORDER_TYPE_SELL, 0, false, h1Pass, true, false, 0, "Awaiting Pullback into EMA 9/21 Value Zone");
         return;
      }

      // 6. Mandatory EMA Health & Trend Quality Gate (Anti-Chop Filter)
      double emaAngle = 0.0;
      string emaDiag = "";
      if(!CheckEMAHealthFilter(ema9, ema21, atr[0], ORDER_TYPE_SELL, emaAngle, emaDiag)) {
         LogCoreSetupDiagnostic(false, sym, tf, ORDER_TYPE_SELL, cycle.pullbackLevel, false, h1Pass, true, cycle.primaryEntryDone, 0, "REJECTED — EMA HEALTH: " + emaDiag);
         return;
      }

      // 7. Bearish Confirmation Candle Validation (Bar 1 Closed)
      bool confirmationValid = IsBearishConfirmation(open, high, low, close, atr[0]);
      if(!confirmationValid) {
         LogCoreSetupDiagnostic(false, sym, tf, ORDER_TYPE_SELL, cycle.pullbackLevel, (cycle.pullbackLevel == 4), h1Pass, true, false, 0, "No Bearish Confirmation (Awaiting Engulfing / Low Break)");
         return;
      }

      // 7b. Volume Confirmation Filter Check & Terminal Rejection Log
      double volRatio = 1.0;
      ENUM_VOLUME_STATE volState = EvaluateVolumeFilter(sym, tf, Volume_Lookback, Volume_Min_Multiplier, volRatio);
      if(Use_Volume_Filter && volState == VOLUME_WEAK) {
         Print(StringFormat("%s | M5 | SELL REJECTED | EMA_HEALTH=HEALTHY | SEPARATION=%.2fATR | VOLUME=%.2fx (WEAK) | REASON=Weak Volume (< %.2fx SMA)", sym, (MathAbs(ema9[0]-ema21[0])/atr[0]), volRatio, Volume_Min_Multiplier));
         LogCoreSetupDiagnostic(false, sym, tf, ORDER_TYPE_SELL, cycle.pullbackLevel, (cycle.pullbackLevel == 4), h1Pass, true, false, 0, "REJECTED — WEAK VOLUME");
         return;
      }

      // 8. Determine Entry Type (Primary vs Re-Entry)
      bool isReEntry = cycle.primaryEntryDone;
      if(isReEntry) {
         if(!InpEnableReEntry || cycle.reEntriesCount >= InpMaxReEntriesPerCycle) {
            LogCoreSetupDiagnostic(false, sym, tf, ORDER_TYPE_SELL, cycle.pullbackLevel, (cycle.pullbackLevel == 4), h1Pass, true, true, 0, "Max Cycle Entries Reached (Re-Entries Disabled / Capped)");
            return;
         }
      }

      // 9. Stop Loss & Target Sizing
      double pointVal = SymbolInfoDouble(sym, SYMBOL_POINT);
      double slPrice = high[0] + (InpSLEngulfingBufferPoints * pointVal) + (atr[0] * InpSLBufferATR * 0.5);
      for(int b = 1; b < 3; b++) {
         if(high[b] > high[0] && high[b] < high[0] + (atr[0] * 1.5)) {
            slPrice = MathMax(slPrice, high[b] + (InpSLEngulfingBufferPoints * pointVal));
         }
      }

      double risk = slPrice - close[0];
      if(risk <= 0) return;
      double tp1 = close[0] - (risk * 2.0);

      // 10. Execute Signal & Dispatch Telegram Alert
      double tradeRisk = isReEntry ? InpReEntryRiskPercent : InpRiskPercent;
      SignalQuality q = CalculateQualityScore(idx, ORDER_TYPE_SELL, HTF_TREND_BEARISH, close[0], slPrice, risk, atr[0], tf, structInfo, regimeInfo);

      string pullbackDesc = (cycle.pullbackLevel == 4 ? "Deep EMA21 Pullback" : (cycle.pullbackLevel == 3 ? "EMA21 Retest" : (cycle.pullbackLevel == 2 ? "Value Zone Pullback" : "EMA9 Retest")));
      string modeLabel = (InpTradeManagementMode == MODE_TREND_RUNNER_CROSSOVER) ? "Trend Runner (+1R BE)" : "Standard (2R TP1)";
      string triggerReason = StringFormat("%s %s + Bearish Rejection\nMode: %s | Entry: %s (Risk: %.1f%%)", tfLabel, pullbackDesc, modeLabel, (isReEntry ? StringFormat("Re-Entry #%d", cycle.reEntriesCount + 1) : "Primary"), tradeRisk);

      LogCoreSetupDiagnostic(true, sym, tf, ORDER_TYPE_SELL, cycle.pullbackLevel, (cycle.pullbackLevel == 4), h1Pass, true, isReEntry, tradeRisk, "Core M5 Bearish Pullback Approved");
      ExecuteTradeSignal(idx, tf, ORDER_TYPE_SELL, close[0], slPrice, tp1, q, triggerReason, isReEntry);

      // Update State Tracking
      cycle.lastSignalBar = currentBarTime;
      cycle.lastEntryPrice = close[0];
      cycle.pullbackActive = false;
      cycle.pullbackLevel = 0;
      cycle.hasExpanded = false;
      if(!isReEntry) {
         cycle.primaryEntryDone = true;
      } else {
         cycle.reEntriesCount++;
      }
      return;
   }
}

void EvaluateEMAPullbackStrategy(int idx, ENUM_TIMEFRAMES tf) {
   if(tf == PERIOD_M1) {
      ProcessEMAPullbackForCycle(idx, tf, m_scanners[idx].cycleM1);
   } else {
      ProcessEMAPullbackForCycle(idx, tf, m_scanners[idx].cycleM5);
   }
}

//====================================================================
// SECTION 10: CONFLUENCE ENGINE & QUALITY SCORING
//====================================================================

SignalQuality CalculateQualityScore(int idx, int type, ENUM_HTF_TREND h1Trend, double entry, double sl, double risk, double atr, ENUM_TIMEFRAMES tf, const StructureEvaluation &structInfo, const RegimeEvaluation &regimeInfo) {
   SignalQuality q;
   ZeroMemory(q);

   // 1. H1 Trend Alignment (0 - 20 pts)
   if((type == ORDER_TYPE_BUY && h1Trend == HTF_TREND_STRONG_BULLISH) || (type == ORDER_TYPE_SELL && h1Trend == HTF_TREND_STRONG_BEARISH)) q.htfTrendScore = 20;
   else if((type == ORDER_TYPE_BUY && h1Trend == HTF_TREND_BULLISH) || (type == ORDER_TYPE_SELL && h1Trend == HTF_TREND_BEARISH)) q.htfTrendScore = 15;
   else if(h1Trend == HTF_TREND_NEUTRAL) q.htfTrendScore = 8;
   else q.htfTrendScore = 0;

   // 2. M5 Directional Structure (0 - 20 pts)
   if((type == ORDER_TYPE_BUY && structInfo.bias == "Bullish") || (type == ORDER_TYPE_SELL && structInfo.bias == "Bearish")) q.structureScore = 20;
   else if(structInfo.bias == "Neutral") q.structureScore = 10;
   else q.structureScore = 0;

   // 3. Confirmed BOS (0 - 15 pts)
   if(structInfo.bosConfirmed) q.bosScore = 15;
   else q.bosScore = 0;

   // 4. EMA 9/21 Separation Quality (0 - 10 pts)
   if(regimeInfo.emaDistanceATR >= 0.5) q.strategyScore = 10;
   else if(regimeInfo.emaDistanceATR >= 0.25) q.strategyScore = 7;
   else q.strategyScore = 3;

   // 5. EMA 200 Alignment (0 - 10 pts)
   if(regimeInfo.ema200CrossCount <= 1) q.ema200Score = 10;
   else if(regimeInfo.ema200CrossCount == 2) q.ema200Score = 5;
   else q.ema200Score = 0;

   // 6. ATR Volatility Quality (0 - 10 pts)
   if(regimeInfo.atrRatio >= 0.9 && regimeInfo.atrRatio <= 1.8) q.atrQualityScore = 10;
   else if(regimeInfo.atrRatio >= 0.6) q.atrQualityScore = 6;
   else q.atrQualityScore = 2;

   // 7. Engulfing Confirmation (0 - 10 pts)
   q.engulfingScore = 10;

   // 8. Room to Opposing S/R (0 - 5 pts)
   if(!structInfo.inMiddleRange) q.roomToSRScore = 5;
   else q.roomToSRScore = 2;

   // Auxiliary Volume & Momentum Score
   q.volumeScore = CheckVolumeExpansion(m_scanners[idx].resolvedSymbol, tf, 1) ? 15 : 8;
   q.momentumScore = 10;
   q.liquidityScore = 10;
   q.rrScore = 5;
   q.newsContextScore = 5;

   q.totalScore = q.htfTrendScore + q.structureScore + q.bosScore + q.strategyScore + q.ema200Score + q.atrQualityScore + q.engulfingScore + q.roomToSRScore;
   if(q.totalScore > 100) q.totalScore = 100;

   if(q.totalScore >= 90) q.ratingLabel = "Excellent";
   else if(q.totalScore >= 85) q.ratingLabel = "Very Strong";
   else if(q.totalScore >= 80) q.ratingLabel = "Strong";
   else if(q.totalScore >= 70) q.ratingLabel = "Moderate";
   else if(q.totalScore >= 55) q.ratingLabel = "Valid";
   else q.ratingLabel = "Weak";

   return q;
}

//====================================================================
// SECTION 11: RISK ENGINE & LOT SIZING
//====================================================================

double CalculateRiskLotSize(string sym, double slRiskDistance, bool isReEntry = false) {
   if(slRiskDistance <= 0 || !MathIsValidNumber(slRiskDistance)) return 0.01;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0 || !MathIsValidNumber(balance)) balance = 10000.0;

   double targetRisk = isReEntry ? InpReEntryRiskPercent : InpRiskPercent;
   double riskMoney = balance * (targetRisk / 100.0);

   double tickValue = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   double point     = SymbolInfoDouble(sym, SYMBOL_POINT);

   if(tickSize <= 0 || tickValue <= 0 || !MathIsValidNumber(tickValue) || !MathIsValidNumber(tickSize)) {
      tickSize  = (point > 0) ? point : 0.0001;
      tickValue = 1.0;
   }

   double slTicks = slRiskDistance / tickSize;
   if(slTicks <= 0) return 0.01;

   double lotSize = riskMoney / (slTicks * tickValue);
   if(!MathIsValidNumber(lotSize) || lotSize <= 0) return 0.01;

   double minLot  = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);

   if(stepLot > 0) lotSize = MathFloor(lotSize / stepLot) * stepLot;

   if(lotSize < minLot) lotSize = minLot;
   if(lotSize > maxLot) lotSize = maxLot;

   return NormalizeDouble(lotSize, 2);
}

//====================================================================
// SECTION 12: EXECUTION & SIGNAL DISPATCHER
//====================================================================

void ExecuteTradeSignal(int idx, ENUM_TIMEFRAMES tf, int type, double entry, double sl, double tp1, const SignalQuality &quality, string triggerReason, bool isReEntry) {
   string sym = m_scanners[idx].resolvedSymbol;
   int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);

   double riskDist = MathAbs(entry - sl);
   if(!MathIsValidNumber(riskDist) || riskDist <= 0) return;

   double lot = CalculateRiskLotSize(sym, riskDist, isReEntry);
   string strategyName = "921 EMA V1";

   // 1. Mandatory Real MT5 Order Execution (MT5 is the single source of truth)
   if(!InpAutoTradingEnabled) {
      Print("[921 EMA V1] Alerts Only Mode: No live MT5 trade opened for ", sym);
      return;
   }

   ResetLastError();
   bool success = false;
   if(type == ORDER_TYPE_BUY) {
      double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
      success = m_trade.Buy(lot, sym, ask, NormalizeDouble(sl, digits), 0.0, strategyName);
   } else {
      double bid = SymbolInfoDouble(sym, SYMBOL_BID);
      success = m_trade.Sell(lot, sym, bid, NormalizeDouble(sl, digits), 0.0, strategyName);
   }

   if(!success) {
      Print("[REAL MT5 ORDER FAILED] Symbol: ", sym, " Error: ", GetLastError());
      return;
   }

   // 2. Derive Actual Trade State from Confirmed Real MT5 Position
   ulong realTicket = m_trade.ResultOrder();
   if(realTicket <= 0) realTicket = m_trade.ResultDeal();

   if(!PositionSelect(sym)) {
      Print("[REAL MT5 WARNING] Position not selected immediately for ", sym, ". Checking by ticket.");
   }

   realTicket = PositionGetInteger(POSITION_TICKET);
   double realEntry = PositionGetDouble(POSITION_PRICE_OPEN);
   double realLot   = PositionGetDouble(POSITION_VOLUME);
   double realSL    = PositionGetDouble(POSITION_SL);
   datetime realOpenTime = (datetime)PositionGetInteger(POSITION_TIME);
   double realRiskDist = MathAbs(realEntry - realSL);
   if(realRiskDist <= 0) realRiskDist = riskDist;

   RealPositionMeta meta;
   ZeroMemory(meta);
   meta.ticket = realTicket;
   meta.brokerTicket = realTicket;
   meta.id = StringFormat("%s_%I64u", sym, realTicket);
   meta.symbol = sym;
   meta.strategy = STRATEGY_EMA_PULLBACK;
   meta.executionTF = tf;
   meta.type = type;
   meta.isReEntry = isReEntry;
   meta.initialLot = realLot;
   meta.currentLot = realLot;
   meta.entry = realEntry;
   meta.sl = realSL;
   meta.tp1 = NormalizeDouble(tp1, digits);
   meta.initialRiskDist = realRiskDist;
   meta.riskDistance = realRiskDist;
   meta.currentRR = 0.0;
   meta.maxRR = 0.0;
   meta.qualityScore = quality.totalScore;
   meta.qualityLabel = quality.ratingLabel;
   meta.triggerReason = triggerReason;
   AnalyzeMarketStructure(sym, meta.structure);
   meta.m5Pattern = meta.structure.m5Pattern;
   meta.h1Pattern = meta.structure.h1Pattern;
   meta.volumeDesc = "Confirmed";
   meta.dxyCorrelation = CalculateDXYCorrelation(sym);
   meta.openTime = realOpenTime;
   meta.status = STATUS_ACTIVE;
   meta.reachedTP1 = false;
   meta.reachedBE = false;
   meta.isRunner = false;
   meta.tp1RealizedProfit = 0.0;
   meta.tp1RealizedR = 0.0;
   meta.lastAlertedMilestoneR = 0;

   int vSize = ArraySize(m_activeTrades);
   ArrayResize(m_activeTrades, vSize + 1);
   m_activeTrades[vSize] = meta;
   m_isStateChanged = true;

   Print("[REAL MT5 ORDER CONFIRMED] Ticket: #", realTicket, " Symbol: ", sym, " Lot: ", realLot, " Entry: ", realEntry, " SL: ", realSL);

   // 3. Dispatch Mobile Telegram Alert ONLY AFTER Real Execution Confirmation
   SendSignalTelegramAlert(meta, quality, idx);

   if(InpDrawChartObjects) DrawSignalChartObjects(meta);
}

//====================================================================
// SECTION 13: BACKEND POSITION & PURE TREND RUNNER ENGINE
//====================================================================

void ManageActiveTrades(datetime currentTime) {
   // 1. Detect Real MT5 Positions Closed in Terminal
   for(int i = ArraySize(m_activeTrades) - 1; i >= 0; i--) {
      ulong ticket = m_activeTrades[i].ticket;
      if(ticket <= 0) ticket = m_activeTrades[i].brokerTicket;
      if(ticket <= 0) continue;

      if(!PositionSelectByTicket(ticket)) {
         // Real MT5 Position is now CLOSED. Query MT5 Deal History for True Execution Result.
         HistorySelectByPosition(ticket);
         double exitPrice = m_activeTrades[i].entry;
         double realProfit = 0.0;
         datetime closeTime = currentTime;
         string exitReason = "SL / Opposite Cross";

         int deals = HistoryDealsTotal();
         for(int d = deals - 1; d >= 0; d--) {
            ulong dt = HistoryDealGetTicket(d);
            if(HistoryDealGetInteger(dt, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
               exitPrice = HistoryDealGetDouble(dt, DEAL_PRICE);
               realProfit = HistoryDealGetDouble(dt, DEAL_PROFIT);
               closeTime = (datetime)HistoryDealGetInteger(dt, DEAL_TIME);
               long reasonCode = HistoryDealGetInteger(dt, DEAL_REASON);
               if(reasonCode == DEAL_REASON_SL) exitReason = m_activeTrades[i].reachedBE ? "Break Even Hit" : "Stop Loss Hit";
               else if(reasonCode == DEAL_REASON_TP) exitReason = "Take Profit Hit";
               else exitReason = (m_activeTrades[i].type == ORDER_TYPE_BUY ? "M5 EMA Bear Cross" : "M5 EMA Bull Cross");
               break;
            }
         }

         double finalR = (m_activeTrades[i].initialRiskDist > 0) ? 
            (m_activeTrades[i].type == ORDER_TYPE_BUY ? (exitPrice - m_activeTrades[i].entry) : (m_activeTrades[i].entry - exitPrice)) / m_activeTrades[i].initialRiskDist : 0.0;

         if(exitReason == "Break Even Hit" && finalR >= 0.5) {
            exitReason = "Trailing Stop / Profit Lock Hit";
         }

         HistoricalTrade ht;
         ZeroMemory(ht);
         ht.id = m_activeTrades[i].id;
         ht.symbol = m_activeTrades[i].symbol;
         ht.strategy = m_activeTrades[i].strategy;
         ht.executionTF = m_activeTrades[i].executionTF;
         ht.type = m_activeTrades[i].type;
         ht.isReEntry = m_activeTrades[i].isReEntry;
         ht.initialLot = m_activeTrades[i].initialLot;
         ht.finalLot = m_activeTrades[i].currentLot;
         ht.entry = m_activeTrades[i].entry;
         ht.sl = m_activeTrades[i].sl;
         ht.exitPrice = exitPrice;
         ht.openTime = m_activeTrades[i].openTime;
         ht.closeTime = closeTime;
         ht.resultProfit = realProfit;
         ht.resultRR = NormalizeDouble(finalR, 2);
         ht.maxRR = m_activeTrades[i].maxRR;
         ht.qualityScore = m_activeTrades[i].qualityScore;
         ht.qualityLabel = m_activeTrades[i].qualityLabel;
         ht.status = (realProfit > 0.5 ? STATUS_WON : (realProfit < -0.5 ? STATUS_LOST : STATUS_BE));
         ht.exitReason = exitReason;

         int hSize = ArraySize(m_historyTrades);
         ArrayResize(m_historyTrades, hSize + 1);
         m_historyTrades[hSize] = ht;

         // Send P1 Mobile Closed Alert from Real MT5 Deal
         SendIndividualTradeClosedAlert(ht);

         if(InpDrawChartObjects) RemoveSignalChartObjects(m_activeTrades[i]);

         // Clean up from active tracking
         for(int k = i; k < ArraySize(m_activeTrades) - 1; k++) m_activeTrades[k] = m_activeTrades[k + 1];
         ArrayResize(m_activeTrades, ArraySize(m_activeTrades) - 1);
         m_isStateChanged = true;
      }
   }

   // 2. Manage Still Open Real MT5 Positions (+1R BE & 2R TP1 Partial Close)
   for(int i = 0; i < ArraySize(m_activeTrades); i++) {
      ulong ticket = m_activeTrades[i].ticket;
      if(ticket <= 0) ticket = m_activeTrades[i].brokerTicket;
      if(!PositionSelectByTicket(ticket)) continue;

      string sym = m_activeTrades[i].symbol;
      int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
      bool isBuy = (m_activeTrades[i].type == ORDER_TYPE_BUY);
      double currentPrice = isBuy ? SymbolInfoDouble(sym, SYMBOL_BID) : SymbolInfoDouble(sym, SYMBOL_ASK);

      double riskDist = m_activeTrades[i].initialRiskDist;
      if(riskDist <= 0) continue;

      double currentR = isBuy ? (currentPrice - m_activeTrades[i].entry) / riskDist : (m_activeTrades[i].entry - currentPrice) / riskDist;
      m_activeTrades[i].currentRR = currentR;
      if(currentR > m_activeTrades[i].maxRR) m_activeTrades[i].maxRR = currentR;

      // Check +1R Break-Even
      if(Use_BreakEven && !m_activeTrades[i].reachedBE && currentR >= BreakEven_R) {
         double point = SymbolInfoDouble(sym, SYMBOL_POINT);
         double beOffset = MathMin(m_activeTrades[i].initialRiskDist * 0.05, BreakEven_Offset * point * (digits == 3 || digits == 5 ? 10 : 1));
         if(beOffset <= 0) beOffset = point * (digits == 3 || digits == 5 ? 10 : 1);
         double bePrice = isBuy ? (m_activeTrades[i].entry + beOffset) : (m_activeTrades[i].entry - beOffset);
         bePrice = NormalizeDouble(bePrice, digits);

         if(m_trade.PositionModify(ticket, bePrice, PositionGetDouble(POSITION_TP))) {
            m_activeTrades[i].reachedBE = true;
            m_activeTrades[i].sl = bePrice;
            m_activeTrades[i].lastAlertedMilestoneR = 1;
            m_isStateChanged = true;

            SendTrendRunnerMilestoneAlert(m_activeTrades[i], 1, true);
            if(InpDrawChartObjects) UpdateChartSLObject(m_activeTrades[i]);
         }
      }

      // Check Progressive Integer R Milestone Alerts (+2R, +3R, +4R...)
      int floorR = (int)MathFloor(currentR);
      if(floorR >= 2 && floorR > m_activeTrades[i].lastAlertedMilestoneR) {
         m_activeTrades[i].lastAlertedMilestoneR = floorR;
         SendTrendRunnerMilestoneAlert(m_activeTrades[i], floorR, false);
      }

      // Check 2R TP1 Partial Close (Standard Mode)
      if(InpTradeManagementMode == MODE_STANDARD_PARTIAL_2R && !m_activeTrades[i].reachedTP1 && currentR >= 2.0) {
         double partialLot = NormalizeDouble(m_activeTrades[i].initialLot * (InpPartialClosePercent / 100.0), 2);
         if(partialLot > 0 && partialLot < PositionGetDouble(POSITION_VOLUME)) {
            if(m_trade.PositionClosePartial(ticket, partialLot)) {
               m_activeTrades[i].reachedTP1 = true;
               m_activeTrades[i].reachedBE = true;
               m_activeTrades[i].currentLot = PositionGetDouble(POSITION_VOLUME);
               m_isStateChanged = true;

               SendTradeUpdateAlert("🎯 TP1 (2R)", m_activeTrades[i], currentR);
            }
         }
      }
   }
}

void ClosePositionsForSymbolAndType(string sym, int type, string exitReason) {
   int affectedCount = 0;
   long targetPosType = (type == ORDER_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;

   // 1. Scan MT5 terminal pool for live positions with matching symbol & magic
   int totalPositions = PositionsTotal();
   for(int i = totalPositions - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;

      ulong magic = PositionGetInteger(POSITION_MAGIC);
      if(magic != InpMagicNumber && magic != 0) continue;

      string pSym = PositionGetString(POSITION_SYMBOL);
      long pType = PositionGetInteger(POSITION_TYPE);

      if(pSym == sym && pType == targetPosType) {
         if(InpAutoTradingEnabled) {
            if(m_trade.PositionClose(ticket)) {
               affectedCount++;
               Print("[CYCLE REVERSAL] Closed position #", ticket, " on ", sym, " Reason: ", exitReason);
            }
         } else {
            affectedCount++;
         }
      }
   }

   // Count virtual active trades if no live terminal positions found
   if(affectedCount == 0) {
      for(int i = 0; i < ArraySize(m_activeTrades); i++) {
         if(m_activeTrades[i].symbol == sym && m_activeTrades[i].type == type) {
            affectedCount++;
         }
      }
   }

   if(affectedCount == 0) return;

   datetime ukTime = GetUKTime(TimeCurrent());
   MqlDateTime dtNow; TimeToStruct(ukTime, dtNow);
   string timeStr = StringFormat("%02d:%02d UK", dtNow.hour, dtNow.min);

   // 2. Send Dedicated Cycle Reversal Alert to Telegram (Exact User Format)
   string cycleStr = (type == ORDER_TYPE_BUY) ? "BULLISH" : "BEARISH";
   string signalStr = (type == ORDER_TYPE_BUY) ? "EMA 9 crossed BELOW EMA 21" : "EMA 9 crossed ABOVE EMA 21";
   string actionStr = (type == ORDER_TYPE_BUY) ? "Closing BUY runner position(s)" : "Closing SELL runner position(s)";

   string revMsg = StringFormat(
      "🔄 <b>CYCLE REVERSAL — %s</b>\n\n"
      "<b>Previous Cycle:</b> %s\n"
      "<b>Signal:</b> %s\n"
      "<b>Action:</b> %s\n\n"
      "<b>Open Positions Affected:</b> %d\n"
      "<b>Time:</b> %s\n"
      "━━━━━━━━━━━━━━━━━━",
      sym, cycleStr, signalStr, actionStr, affectedCount, timeStr
   );
   SendTelegramMessage(revMsg);

   // 3. Force Close Virtual Active Positions and Archive Performance
   for(int i = ArraySize(m_activeTrades) - 1; i >= 0; i--) {
      if(m_activeTrades[i].symbol == sym && m_activeTrades[i].type == type) {
         double bid = SymbolInfoDouble(sym, SYMBOL_BID);
         double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
         double exitPrice = (type == ORDER_TYPE_BUY) ? bid : ask;

         if(InpDrawChartObjects) RemoveSignalChartObjects(m_activeTrades[i]);
         ArchiveTrade(i, exitPrice, exitReason);
         m_isStateChanged = true;
      }
   }
}

void ForceCloseAllEAPositions(string reasonStr) {
   int totalPositions = PositionsTotal();
   for(int i = totalPositions - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;

      ulong magic = PositionGetInteger(POSITION_MAGIC);
      if(magic == InpMagicNumber || magic == 0) {
         string sym = PositionGetString(POSITION_SYMBOL);
         m_trade.PositionClose(ticket);
         Print("[SESSION PROTECTION] Force closed position #", ticket, " on ", sym, " Reason: ", reasonStr);
      }
   }

   for(int i = ArraySize(m_activeTrades) - 1; i >= 0; i--) {
      double bid = SymbolInfoDouble(m_activeTrades[i].symbol, SYMBOL_BID);
      double exitPrice = bid;
      ArchiveTrade(i, exitPrice, reasonStr);
   }

   ArrayResize(m_activeTrades, 0);
   m_isStateChanged = true;
}

void ArchiveTrade(int index, double exitPrice, string exitReason) {
   RealPositionMeta vt = m_activeTrades[index];
   bool isBuy = (vt.type == ORDER_TYPE_BUY);

   // Derive Real MT5 Deal History if Available
   double realDealProfit = 0.0;
   double realDealPrice  = exitPrice;
   datetime realCloseTime= TimeCurrent();
   bool foundRealDeal = false;

   ulong checkTicket = vt.ticket;
   if(checkTicket <= 0) checkTicket = vt.brokerTicket;

   if(checkTicket > 0 && HistorySelectByPosition(checkTicket)) {
      int deals = HistoryDealsTotal();
      for(int d = deals - 1; d >= 0; d--) {
         ulong dt = HistoryDealGetTicket(d);
         if(HistoryDealGetInteger(dt, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
            realDealPrice = HistoryDealGetDouble(dt, DEAL_PRICE);
            realDealProfit = HistoryDealGetDouble(dt, DEAL_PROFIT);
            realCloseTime = (datetime)HistoryDealGetInteger(dt, DEAL_TIME);
            long reasonCode = HistoryDealGetInteger(dt, DEAL_REASON);
            if(reasonCode == DEAL_REASON_SL) {
               if(vt.reachedBE && (isBuy ? (realDealPrice - vt.entry) : (vt.entry - realDealPrice)) > vt.initialRiskDist * 0.5) {
                  exitReason = "Trailing Stop / Profit Lock Hit";
               } else if(vt.reachedBE) {
                  exitReason = "Break Even Hit";
               } else {
                  exitReason = "Stop Loss Hit";
               }
            }
            else if(reasonCode == DEAL_REASON_TP) exitReason = "Take Profit Hit";
            foundRealDeal = true;
            break;
         }
      }
   }
   if(foundRealDeal) {
      exitPrice = realDealPrice;
   }

   double riskDist = vt.riskDistance;
   double runnerPips = isBuy ? (exitPrice - vt.entry) : (vt.entry - exitPrice);
   double runnerR = (riskDist > 0) ? (runnerPips / riskDist) : 0.0;
   if(!MathIsValidNumber(runnerR)) runnerR = 0.0;

   double tickValue = SymbolInfoDouble(vt.symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(vt.symbol, SYMBOL_TRADE_TICK_SIZE);
   double slTicks   = (tickSize > 0) ? (riskDist / tickSize) : 0;
   double initialRiskMoney = (tickValue > 0 && slTicks > 0) ? (vt.initialLot * slTicks * tickValue) : 25.0;
   if(!MathIsValidNumber(initialRiskMoney) || initialRiskMoney <= 0) initialRiskMoney = 25.0;

   double combinedRealizedR = 0.0;
   double combinedRealizedProfit = 0.0;

   if(foundRealDeal) {
      combinedRealizedProfit = realDealProfit;
      combinedRealizedR = (vt.initialRiskDist > 0) ? (isBuy ? (exitPrice - vt.entry) : (vt.entry - exitPrice)) / vt.initialRiskDist : runnerR;
   } else if(InpTradeManagementMode == MODE_TREND_RUNNER_CROSSOVER) {
      // 100% full position held throughout
      combinedRealizedR = runnerR;
      combinedRealizedProfit = initialRiskMoney * runnerR;
   } else {
      // Standard Model: 50% booked at TP1 (2R) + 50% runner
      double runnerLotRatio = (vt.initialLot > 0) ? (vt.currentLot / vt.initialLot) : 0.5;
      double runnerRealizedR = runnerLotRatio * runnerR;
      double runnerRealizedProfit = initialRiskMoney * runnerRealizedR;
      combinedRealizedR = vt.tp1RealizedR + runnerRealizedR;
      combinedRealizedProfit = vt.tp1RealizedProfit + runnerRealizedProfit;
   }

   HistoricalTrade ht;
   ZeroMemory(ht);
   ht.id = vt.id;
   ht.symbol = vt.symbol;
   ht.strategy = vt.strategy;
   ht.executionTF = vt.executionTF;
   ht.type = vt.type;
   ht.isReEntry = vt.isReEntry;
   ht.initialLot = vt.initialLot;
   ht.finalLot = vt.currentLot;
   ht.entry = vt.entry;
   ht.sl = vt.sl;
   ht.exitPrice = exitPrice;
   ht.resultRR = NormalizeDouble(combinedRealizedR, 2);
   ht.resultProfit = NormalizeDouble(combinedRealizedProfit, 2);
   ht.maxRR = vt.maxRR;
   ht.qualityScore = vt.qualityScore;
   ht.qualityLabel = vt.qualityLabel;
   ht.openTime = vt.openTime;
   ht.closeTime = TimeCurrent();

   if(combinedRealizedProfit > 0.5) ht.status = STATUS_WON;
   else if(combinedRealizedProfit < -0.5) ht.status = STATUS_LOST;
   else ht.status = STATUS_BE;

   ht.exitReason = exitReason;
   ht.lastAlertedMilestoneR = vt.lastAlertedMilestoneR;

   int hSize = ArraySize(m_historyTrades);
   ArrayResize(m_historyTrades, hSize + 1);
   m_historyTrades[hSize] = ht;

   SendIndividualTradeClosedAlert(ht);

   int aSize = ArraySize(m_activeTrades);
   for(int i = index; i < aSize - 1; i++) {
      m_activeTrades[i] = m_activeTrades[i + 1];
   }
   ArrayResize(m_activeTrades, aSize - 1);
}

//====================================================================
// SECTION 14: TELEGRAM INTELLIGENCE BOT & ALERT FORMAT ENGINE
//====================================================================

string SanitizeJson(string text) {
   StringReplace(text, "\\", "\\\\");
   StringReplace(text, "\"", "\\\"");
   StringReplace(text, "\r", "");
   StringReplace(text, "\n", "\\n");
   StringReplace(text, "\t", " ");
   return text;
}

bool SendTelegramMessage(string message) {
   if(!InpEnableTelegram || InpTelegramBotToken == "" || InpTelegramChatID == "") return false;

   if(StringFind(message, "inf") >= 0 || StringFind(message, "nan") >= 0 || StringFind(message, "13642067") >= 0) {
      Print("[TELEGRAM WARN] Corrupted data pattern detected in report payload. Sanitizing message...");
      StringReplace(message, "+$inf", "N/A");
      StringReplace(message, "-$inf", "N/A");
      StringReplace(message, "$inf", "N/A");
      StringReplace(message, "infR", "N/A");
      StringReplace(message, "-inf", "N/A");
      StringReplace(message, "nan", "N/A");
   }

   string url = "https://api.telegram.org/bot" + InpTelegramBotToken + "/sendMessage";
   string headers = "Content-Type: application/json\r\n";
   string payload = StringFormat("{\"chat_id\":\"%s\",\"text\":\"%s\",\"parse_mode\":\"HTML\"}", InpTelegramChatID, SanitizeJson(message));

   char data[];
   StringToCharArray(payload, data, 0, WHOLE_ARRAY, CP_UTF8);
   int dataSize = ArraySize(data);
   if(dataSize > 0 && data[dataSize - 1] == 0) ArrayResize(data, dataSize - 1);

   char result[]; string resultHeaders;
   ResetLastError();
   int res = WebRequest("POST", url, headers, 5000, data, result, resultHeaders);
   if(res != 200) {
      Print("[TELEGRAM ERROR] SendMessage failed. HTTP Code: ", res, " | Error: ", GetLastError());
   }
   return (res == 200);
}

//--- Unified Alert Dispatcher (MT5 Terminal, Sound, Mobile Push)
void DispatchTerminalAlert(string text) {
   if(InpEnableTerminalAlert) Alert(text);
   if(InpEnableSoundAlert) PlaySound("alert.wav");
   if(InpEnablePushAlert) SendNotification(text);
}

void SendSignalTelegramAlert(const RealPositionMeta &vt, const SignalQuality &quality, int idx) {
   if(!InpEnableTelegram) return;

   string headerEmoji = (vt.type == ORDER_TYPE_BUY) ? "🟢" : "🔴";
   string dirStr      = (vt.type == ORDER_TYPE_BUY) ? "BUY" : "SELL";
   int digits         = (int)SymbolInfoInteger(vt.symbol, SYMBOL_DIGITS);

   datetime ukTime = GetUKTime(TimeCurrent());
   MqlDateTime dtNow; TimeToStruct(ukTime, dtNow);
   string entryTimeStr = StringFormat("%02d:%02d UK", dtNow.hour, dtNow.min);

   // Re-Entry Template (Mobile-First)
   if(vt.isReEntry) {
      string reMsg = StringFormat(
         "🔁 <b>RE-ENTRY %s — %s</b>\n\n"
         "Entry: <code>%s</code>\n"
         "SL: <code>%s</code>\n"
         "Risk: %.1f%% | Lot: %.2f\n\n"
         "📊 M5: EMA Retest + Pinbar\n"
         "📈 H1: BOS Confirmed\n"
         "📦 Volume: Confirmed\n"
         "🟢 EMA Health: Healthy\n\n"
         "Score: %s | %d/100\n\n"
         "⏰ %s\n\n"
         "921 EMA V1",
         dirStr, vt.symbol,
         DoubleToString(vt.entry, digits),
         DoubleToString(vt.sl, digits),
         InpReEntryRiskPercent, vt.initialLot,
         vt.qualityLabel, vt.qualityScore,
         entryTimeStr
      );

      DispatchTerminalAlert(StringFormat("921 EMA RE-ENTRY %s %s @ %s", dirStr, vt.symbol, DoubleToString(vt.entry, digits)));

      // Single-event delivery: Chart Image with Alert as Photo Caption
      if(InpSendSignalChart) {
         SendChartScreenshotWithAlert(vt, reMsg);
      } else {
         SendTelegramMessage(reMsg);
      }
      return;
   }

   // Primary Entry Template (Mobile-First HTML Escaped)
   double riskPct = InpRiskPercent;
   // HTML Escape '<' and '>' to avoid Telegram HTML Parser 400 errors
   string h1Desc = (vt.type == ORDER_TYPE_BUY ? "9 &gt; 21 &gt; 200" : "9 &lt; 21 &lt; 200");
   string m5Desc = (vt.type == ORDER_TYPE_BUY ? "Bull Engulfing + EMA Retest" : "Bear Engulfing + EMA Retest");

   string msg = StringFormat(
      "%s <b>%s %s</b>\n\n"
      "Entry: <code>%s</code>\n"
      "SL: <code>%s</code>\n"
      "Risk: %.1f%% | Lot: %.2f\n"
      "Score: %s %d/100\n\n"
      "📊 M5: %s\n"
      "📈 H1: %s\n"
      "📦 Volume: %s\n"
      "💵 DXY: %+.2f\n\n"
      "⏰ %s\n\n"
      "921 EMA V1",
      headerEmoji, dirStr, vt.symbol,
      DoubleToString(vt.entry, digits),
      DoubleToString(vt.sl, digits),
      riskPct, vt.initialLot,
      vt.qualityLabel, vt.qualityScore,
      m5Desc,
      h1Desc,
      vt.volumeDesc,
      vt.dxyCorrelation,
      entryTimeStr
   );

   DispatchTerminalAlert(StringFormat("921 EMA %s %s @ %s | SL: %s", dirStr, vt.symbol, DoubleToString(vt.entry, digits), DoubleToString(vt.sl, digits)));

   // Single-event delivery: Chart Image with Alert as Photo Caption
   if(InpSendSignalChart) {
      SendChartScreenshotWithAlert(vt, msg);
   } else {
      SendTelegramMessage(msg);
   }
}

void SendIndividualTradeClosedAlert(const HistoricalTrade &ht) {
   if(!InpEnableTelegram) return;
   int digits = (int)SymbolInfoInteger(ht.symbol, SYMBOL_DIGITS);
   string dirStr = (ht.type == ORDER_TYPE_BUY) ? "BUY" : "SELL";

   datetime openUK = GetUKTime(ht.openTime);
   datetime closeUK = GetUKTime(ht.closeTime);
   MqlDateTime dtOpen, dtClose;
   TimeToStruct(openUK, dtOpen);
   TimeToStruct(closeUK, dtClose);

   string openTimeStr = StringFormat("%02d:%02d", dtOpen.hour, dtOpen.min);
   string closeTimeStr = StringFormat("%02d:%02d UK", dtClose.hour, dtClose.min);

   string pnlSign = (ht.resultProfit >= 0) ? "+$" : "-$";
   string rSign = (ht.resultRR >= 0) ? "+" : "";

   string outcomeEmoji = "🔴";
   if(ht.resultProfit > 0.5 || ht.resultRR >= 0.5) outcomeEmoji = "🟢";
   else if(ht.resultProfit >= -0.5 && ht.resultProfit <= 0.5) outcomeEmoji = "🎯";

   string msg = StringFormat(
      "%s <b>CLOSED — %s %s</b>\n\n"
      "Entry: <code>%s</code>\n"
      "Exit: <code>%s</code>\n"
      "Lots: %.2f\n\n"
      "💰 <b>%s%.2f | %s%.2fR</b>\n\n"
      "⏱ %s → %s\n\n"
      "Reason: %s",
      outcomeEmoji,
      ht.symbol, dirStr,
      DoubleToString(ht.entry, digits),
      DoubleToString(ht.exitPrice, digits),
      ht.initialLot,
      pnlSign, MathAbs(ht.resultProfit),
      rSign, ht.resultRR,
      openTimeStr, closeTimeStr,
      ht.exitReason
   );

   if(InpSendSignalChart) {
      SendChartScreenshotGeneral(ht.symbol, ht.executionTF, ht.type, ht.entry, ht.sl, ht.exitPrice, (ulong)ht.closeTime, msg);
   } else {
      SendTelegramMessage(msg);
   }
   DispatchTerminalAlert(StringFormat("921 EMA Closed: %s %s | %s%.2f (%s%.2fR)", ht.symbol, dirStr, pnlSign, MathAbs(ht.resultProfit), rSign, ht.resultRR));
}

bool GenerateCanvasChartImage(const VirtualTrade &vt, string filename, int width = 1280, int height = 720) {
   CCanvas canvas;
   string resName = "MSS_Signal_Canvas_" + vt.symbol;
   if(!canvas.Create(resName, width, height, COLOR_FORMAT_ARGB_NORMALIZE)) {
      return false;
   }

   canvas.Erase(0xFF12151E);

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(vt.symbol, vt.executionTF, 0, 45, rates);
   if(copied < 20) {
      canvas.Destroy();
      return false;
   }

   double maxPrice = rates[0].high;
   double minPrice = rates[0].low;
   for(int i = 0; i < copied; i++) {
      if(rates[i].high > maxPrice) maxPrice = rates[i].high;
      if(rates[i].low < minPrice)   minPrice = rates[i].low;
   }
   if(vt.entry > maxPrice) maxPrice = vt.entry;
   if(vt.entry < minPrice) minPrice = vt.entry;
   if(vt.sl > maxPrice)    maxPrice = vt.sl;
   if(vt.sl < minPrice)    minPrice = vt.sl;
   if(vt.tp1 > maxPrice)   maxPrice = vt.tp1;
   if(vt.tp1 < minPrice)   minPrice = vt.tp1;

   double range = maxPrice - minPrice;
   if(range <= 0) range = 1.0;
   maxPrice += (range * 0.06);
   minPrice -= (range * 0.06);
   range = maxPrice - minPrice;

   int marginLeft = 60;
   int marginRight = 160;
   int marginTop = 60;
   int marginBottom = 40;
   int chartWidth = width - marginLeft - marginRight;
   int chartHeight = height - marginTop - marginBottom;

   uint gridColor = 0xFF1E222D;
   for(int g = 1; g <= 5; g++) {
      int y = marginTop + (int)(g * (chartHeight / 6.0));
      canvas.Line(marginLeft, y, marginLeft + chartWidth, y, gridColor);
   }

   double barWidth = (double)chartWidth / copied;
   for(int i = 0; i < copied; i++) {
      int idx = copied - 1 - i;
      int x = marginLeft + (int)(i * barWidth + (barWidth / 2.0));
      int yHigh = marginTop + (int)(((maxPrice - rates[idx].high) / range) * chartHeight);
      int yLow  = marginTop + (int)(((maxPrice - rates[idx].low) / range) * chartHeight);
      int yOpen = marginTop + (int)(((maxPrice - rates[idx].open) / range) * chartHeight);
      int yClose= marginTop + (int)(((maxPrice - rates[idx].close) / range) * chartHeight);

      uint candleColor = (rates[idx].close >= rates[idx].open) ? 0xFF26A69A : 0xFFEF5350;

      canvas.Line(x, yHigh, x, yLow, candleColor);

      int bodyTop = MathMin(yOpen, yClose);
      int bodyBottom = MathMax(yOpen, yClose);
      if(bodyBottom - bodyTop < 2) bodyBottom = bodyTop + 2;
      int bodyLeft = x - (int)(barWidth * 0.35);
      int bodyRight = x + (int)(barWidth * 0.35);
      canvas.FillRectangle(bodyLeft, bodyTop, bodyRight, bodyBottom, candleColor);
   }

   int yEntry = marginTop + (int)(((maxPrice - vt.entry) / range) * chartHeight);
   int ySL    = marginTop + (int)(((maxPrice - vt.sl) / range) * chartHeight);
   int yTP1   = marginTop + (int)(((maxPrice - vt.tp1) / range) * chartHeight);

   uint clrEntry = (vt.type == ORDER_TYPE_BUY) ? 0xFF2196F3 : 0xFFE91E63;
   uint clrSL    = 0xFFEF5350;
   uint clrTP1   = 0xFFFFD700;

   canvas.Line(marginLeft, yEntry, marginLeft + chartWidth + 10, yEntry, clrEntry);
   canvas.TextOut(marginLeft + chartWidth + 15, yEntry - 8, StringFormat("ENTRY: %.5f", vt.entry), clrEntry, TA_LEFT|TA_TOP);

   canvas.Line(marginLeft, ySL, marginLeft + chartWidth + 10, ySL, clrSL);
   canvas.TextOut(marginLeft + chartWidth + 15, ySL - 8, StringFormat("SL: %.5f", vt.sl), clrSL, TA_LEFT|TA_TOP);

   canvas.Line(marginLeft, yTP1, marginLeft + chartWidth + 10, yTP1, clrTP1);
   canvas.TextOut(marginLeft + chartWidth + 15, yTP1 - 8, StringFormat("TP1 (2R): %.5f", vt.tp1), clrTP1, TA_LEFT|TA_TOP);

   string tfLabel = (vt.executionTF == PERIOD_M1) ? "M1" : "M5";
   string dirStr  = (vt.type == ORDER_TYPE_BUY) ? "BUY" : "SELL";
   string headerStr = StringFormat("%s %s | %s SIGNAL | Entry: %.5f | SL: %.5f | TP1: %.5f (Runner: UNLIMITED)", vt.symbol, tfLabel, dirStr, vt.entry, vt.sl, vt.tp1);
   canvas.TextOut(marginLeft, 18, headerStr, 0xFFFFFFFF, TA_LEFT|TA_TOP);

   bool saved = ResourceSave(canvas.ResourceName(), filename);
   canvas.Destroy();
   return saved;
}

//====================================================================
// CHART SCREENSHOT & TELEGRAM sendPhoto IMAGE ATTACHMENT ENGINE
//====================================================================

bool SendChartScreenshotGeneral(string symbol, ENUM_TIMEFRAMES tf, int orderType, double entry, double sl, double tp1, ulong ticket, string caption) {
   if(!InpSendSignalChart || InpTelegramBotToken == "" || InpTelegramChatID == "") {
      SendTelegramMessage(caption);
      return false;
   }

   string tfStr = (tf == PERIOD_M1 ? "M1" : "M5");
   string dirStr = (orderType == ORDER_TYPE_BUY ? "BUY" : "SELL");
   // NOTE: ChartScreenShot requires file name WITHOUT .png extension!
   string fileBase = StringFormat("921_EMA_%s_%s_%s_%I64u", symbol, tfStr, dirStr, ticket);
   string filename = fileBase + ".png";
   string mimeType = "image/png";

   // 1. Locate Existing MT5 Chart for this symbol or open dynamically
   long targetChartID = -1;
   long chartID = ChartFirst();
   while(chartID >= 0) {
      if(ChartSymbol(chartID) == symbol) {
         targetChartID = chartID;
         break;
      }
      chartID = ChartNext(chartID);
   }

   bool captured = false;
   if(targetChartID > 0) {
      ChartSetSymbolPeriod(targetChartID, symbol, tf);
      ChartSetInteger(targetChartID, CHART_MODE, CHART_CANDLES);
      ChartSetInteger(targetChartID, CHART_AUTOSCROLL, true);
      ChartSetInteger(targetChartID, CHART_SHIFT, true);
      ChartRedraw(targetChartID);
      Sleep(100);
      captured = ChartScreenShot(targetChartID, fileBase, InpScreenshotWidth, InpScreenshotHeight, ALIGN_RIGHT);
   } else {
      targetChartID = ChartOpen(symbol, tf);
      if(targetChartID > 0) {
         ChartSetInteger(targetChartID, CHART_MODE, CHART_CANDLES);
         ChartRedraw(targetChartID);
         Sleep(200);
         captured = ChartScreenShot(targetChartID, fileBase, InpScreenshotWidth, InpScreenshotHeight, ALIGN_RIGHT);
      } else {
         captured = ChartScreenShot(0, fileBase, InpScreenshotWidth, InpScreenshotHeight, ALIGN_RIGHT);
      }
   }

   // 2. Wait for Asynchronous ChartScreenShot to finish rendering & writing to disk (up to 2.0s)
   int fileHandle = INVALID_HANDLE;
   int fileSize = 0;
   for(int w = 0; w < 20; w++) {
      Sleep(100);
      if(FileIsExist(filename)) {
         ResetLastError();
         fileHandle = FileOpen(filename, FILE_READ | FILE_BIN);
         if(fileHandle != INVALID_HANDLE) {
            fileSize = (int)FileSize(fileHandle);
            if(fileSize > 1000) { // Valid non-empty PNG file (>1KB)
               break;
            }
            FileClose(fileHandle);
            fileHandle = INVALID_HANDLE;
         }
      }
   }

   // Fallback to Direct High-Res Canvas Rendering if screenshot is missing or zero bytes
   if(fileHandle == INVALID_HANDLE || fileSize <= 1000) {
      if(fileHandle != INVALID_HANDLE) FileClose(fileHandle);

      VirtualTrade tempVt;
      ZeroMemory(tempVt);
      tempVt.symbol = symbol;
      tempVt.executionTF = tf;
      tempVt.type = orderType;
      tempVt.entry = entry;
      tempVt.sl = sl;
      tempVt.tp1 = tp1;

      if(GenerateCanvasChartImage(tempVt, filename, InpScreenshotWidth, InpScreenshotHeight)) {
         fileHandle = FileOpen(filename, FILE_READ | FILE_BIN);
         if(fileHandle != INVALID_HANDLE) {
            fileSize = (int)FileSize(fileHandle);
         }
      }
   }

   if(fileHandle == INVALID_HANDLE || fileSize <= 0) {
      if(fileHandle != INVALID_HANDLE) FileClose(fileHandle);
      PrintFormat("[CHART SCREENSHOT WARN] Image %s could not be generated or read. Dispatching text alert fallback.", filename);
      SendTelegramMessage(caption);
      return false;
   }

   char photoBytes[];
   ArrayResize(photoBytes, fileSize);
   FileReadArray(fileHandle, photoBytes);
   FileClose(fileHandle);

   // 3. Ensure Caption fits within Telegram sendPhoto limit (1024 characters)
   string sendCaption = caption;
   if(StringLen(sendCaption) > 1000) {
      sendCaption = StringSubstr(sendCaption, 0, 995) + "...";
   }

   // 4. Build Multipart/Form-Data Payload for Telegram sendPhoto
   string boundary = "921EMAPhotoAttachmentBoundaryX921";
   string url = "https://api.telegram.org/bot" + InpTelegramBotToken + "/sendPhoto";
   string headers = "Content-Type: multipart/form-data; boundary=" + boundary + "\r\n";

   char body[];
   ArrayResize(body, 0);

   AddMultipartFormField(body, boundary, "chat_id", InpTelegramChatID);
   AddMultipartFormField(body, boundary, "parse_mode", "HTML");
   AddMultipartFormField(body, boundary, "caption", sendCaption);
   AddMultipartFileField(body, boundary, "photo", filename, mimeType, photoBytes);

   string endBoundary = "--" + boundary + "--\r\n";
   char endBytes[]; StringToCharArray(endBoundary, endBytes, 0, WHOLE_ARRAY, CP_UTF8);
   int eSize = ArraySize(endBytes); if(eSize > 0 && endBytes[eSize-1] == 0) ArrayResize(endBytes, eSize-1);
   int curSize = ArraySize(body);
   ArrayResize(body, curSize + eSize);
   ArrayCopy(body, endBytes, curSize, 0, eSize);

   // 5. Send with Retry & Fallback Mechanism (up to 3 attempts)
   int maxRetries = 3;
   bool uploadSuccess = false;

   for(int attempt = 1; attempt <= maxRetries; attempt++) {
      char result[]; string resultHeaders;
      ResetLastError();
      int lastHttpStatus = WebRequest("POST", url, headers, 15000, body, result, resultHeaders);
      int lastError      = GetLastError();

      if(lastHttpStatus == 200) {
         uploadSuccess = true;
         PrintFormat("[TELEGRAM sendPhoto SUCCESS] %s chart photo delivered to %s (Size: %d bytes)", 
            symbol, InpTelegramChatID, fileSize);
         break;
      } else {
         string respText = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
         PrintFormat("[TELEGRAM sendPhoto ERROR] Attempt %d/%d for %s failed HTTP %d (Err %d): %s", 
            attempt, maxRetries, symbol, lastHttpStatus, lastError, respText);

         // If HTTP 400 (Bad Request, e.g. HTML parse error or caption entity issue),
         // rebuild payload with plain short caption on retry so the photo is ALWAYS delivered!
         if(lastHttpStatus == 400 && attempt < maxRetries) {
            ArrayResize(body, 0);
            AddMultipartFormField(body, boundary, "chat_id", InpTelegramChatID);
            AddMultipartFormField(body, boundary, "caption", StringFormat("📊 %s %s Execution Chart", symbol, dirStr));
            AddMultipartFileField(body, boundary, "photo", filename, mimeType, photoBytes);
            
            curSize = ArraySize(body);
            ArrayResize(body, curSize + eSize);
            ArrayCopy(body, endBytes, curSize, 0, eSize);

            // Also send full text alert as follow-up
            SendTelegramMessage(caption);
         }
         Sleep(1000 * attempt);
      }
   }

   if(!uploadSuccess) {
      PrintFormat("[TELEGRAM sendPhoto FAILED] Falling back to text-only alert for %s", symbol);
      SendTelegramMessage(caption);
      return false;
   }

   return true;
}

bool SendChartScreenshotWithAlert(const RealPositionMeta &vt, string caption) {
   return SendChartScreenshotGeneral(vt.symbol, vt.executionTF, vt.type, vt.entry, vt.sl, vt.tp1, vt.ticket, caption);
}

bool CaptureAndSendChartScreenshot(const VirtualTrade &vt, string strategyName) {
   string shortCaption = StringFormat("📊 <b>%s %s Execution Chart</b>\nStrategy: %s | Score: %d/100",
      vt.symbol, (vt.type == ORDER_TYPE_BUY ? "BUY" : "SELL"), strategyName, vt.qualityScore);
   return SendChartScreenshotWithAlert(vt, shortCaption);
}

void AddMultipartFormField(char &body[], string boundary, string fieldName, string fieldValue) {
   string str = "--" + boundary + "\r\n" +
                "Content-Disposition: form-data; name=\"" + fieldName + "\"\r\n\r\n" +
                fieldValue + "\r\n";
   char bytes[]; StringToCharArray(str, bytes, 0, WHOLE_ARRAY, CP_UTF8);
   int bSize = ArraySize(bytes); if(bSize > 0 && bytes[bSize-1] == 0) ArrayResize(bytes, bSize-1);
   int curSize = ArraySize(body);
   ArrayResize(body, curSize + bSize);
   ArrayCopy(body, bytes, curSize, 0, bSize);
}

void AddMultipartFileField(char &body[], string boundary, string fieldName, string filename, string mimeType, const char &fileBytes[]) {
   string str = "--" + boundary + "\r\n" +
                "Content-Disposition: form-data; name=\"" + fieldName + "\"; filename=\"" + filename + "\"\r\n" +
                "Content-Type: " + mimeType + "\r\n\r\n";
   char bytes[]; StringToCharArray(str, bytes, 0, WHOLE_ARRAY, CP_UTF8);
   int bSize = ArraySize(bytes); if(bSize > 0 && bytes[bSize-1] == 0) ArrayResize(bytes, bSize-1);
   int curSize = ArraySize(body);
   ArrayResize(body, curSize + bSize);
   ArrayCopy(body, bytes, curSize, 0, bSize);

   int fSize = ArraySize(fileBytes);
   curSize = ArraySize(body);
   ArrayResize(body, curSize + fSize);
   ArrayCopy(body, fileBytes, curSize, 0, fSize);
   
   string crlf = "\r\n";
   char crlfBytes[]; StringToCharArray(crlf, crlfBytes, 0, WHOLE_ARRAY, CP_UTF8);
   int cSize = ArraySize(crlfBytes); if(cSize > 0 && crlfBytes[cSize-1] == 0) ArrayResize(crlfBytes, cSize-1);
   curSize = ArraySize(body);
   ArrayResize(body, curSize + cSize);
   ArrayCopy(body, crlfBytes, curSize, 0, cSize);
}

void SendTrendRunnerMilestoneAlert(const RealPositionMeta &vt, int milestoneR, bool isBE) {
   if(!InpEnableTelegram) return;
   int digits = (int)SymbolInfoInteger(vt.symbol, SYMBOL_DIGITS);
   bool isBuy = (vt.type == ORDER_TYPE_BUY);
   double nowPrice = isBuy ? SymbolInfoDouble(vt.symbol, SYMBOL_BID) : SymbolInfoDouble(vt.symbol, SYMBOL_ASK);

   string msg = "";
   if(isBE) {
      msg = StringFormat(
         "🎯 <b>+1R — %s</b>\n\n"
         "Entry: <code>%s</code>\n"
         "Now: <code>%s</code>\n"
         "R: +1.00R\n\n"
         "🔒 SL → <code>%s</code>\n"
         "Status: <b>RISK-FREE</b>",
         vt.symbol,
         DoubleToString(vt.entry, digits),
         DoubleToString(nowPrice, digits),
         DoubleToString(vt.sl, digits)
      );
   } else {
      msg = StringFormat(
         "🔥 <b>+%dR — %s</b>\n\n"
         "Entry: <code>%s</code>\n"
         "Now: <code>%s</code>\n"
         "Running: <b>+%.2fR</b>\n\n"
         "Status: Pure Trend Runner Active",
         milestoneR, vt.symbol,
         DoubleToString(vt.entry, digits),
         DoubleToString(nowPrice, digits),
         vt.currentRR
      );
   }

   if(InpSendSignalChart) {
      SendChartScreenshotGeneral(vt.symbol, vt.executionTF, vt.type, vt.entry, vt.sl, vt.tp1, vt.ticket, msg);
   } else {
      SendTelegramMessage(msg);
   }
   DispatchTerminalAlert(StringFormat("921 EMA +%dR: %s @ %s", milestoneR, vt.symbol, DoubleToString(nowPrice, digits)));
}

void SendTradeUpdateAlert(string title, const RealPositionMeta &vt, double currentRR) {
   if(!InpEnableTelegram) return;
   int digits = (int)SymbolInfoInteger(vt.symbol, SYMBOL_DIGITS);
   double closedLots = NormalizeDouble(vt.initialLot * (InpPartialClosePercent / 100.0), 2);
   double remainingLots = NormalizeDouble(vt.initialLot - closedLots, 2);

   double tickValue = SymbolInfoDouble(vt.symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(vt.symbol, SYMBOL_TRADE_TICK_SIZE);
   double slTicks   = (tickSize > 0) ? (vt.initialRiskDist / tickSize) : 0;
   double riskMoney = (tickValue > 0) ? (closedLots * slTicks * tickValue) : 25.0;
   double pnlMoney  = riskMoney * currentRR;

   string msg = StringFormat(
      "🎯 <b>TP1 — %s</b>\n\n"
      "Closed: %.2f lots\n"
      "Entry: <code>%s</code>\n"
      "Exit: <code>%s</code>\n"
      "Result: <b>+$%.2f | +%.1fR</b>\n\n"
      "Remaining: %.2f lots\n\n"
      "🔒 SL: BE",
      vt.symbol,
      closedLots,
      DoubleToString(vt.entry, digits),
      DoubleToString((vt.type == ORDER_TYPE_BUY ? SymbolInfoDouble(vt.symbol, SYMBOL_BID) : SymbolInfoDouble(vt.symbol, SYMBOL_ASK)), digits),
      pnlMoney, currentRR,
      remainingLots
   );

   SendTelegramMessage(msg);
   DispatchTerminalAlert(StringFormat("921 EMA TP1: %s Closed %.2f lots", vt.symbol, closedLots));
}

//====================================================================
// SECTION 15: EXTERNAL NEWS & OFFLINE CURRENCY STRENGTH MODULES
//====================================================================

void UpdateExternalFeeds(datetime currentTime) {
   if(InpEnableNewsFilter && (currentTime - m_lastNewsFetchTime >= 900)) {
      m_lastNewsFetchTime = currentTime;
      FetchForexFactoryNews();
   }

   if(InpEnableFearGreed && (currentTime - m_lastFearGreedFetchTime >= 3600)) {
      m_lastFearGreedFetchTime = currentTime;
      FetchAlternativeMeFearGreed();
   }
}

void FetchForexFactoryNews() {
   string url = "https://nfs.kineo.ai/forexfactory.json";
   string headers = "User-Agent: Mozilla/5.0\r\n";
   char data[], result[]; string resultHeaders;

   ResetLastError();
   int res = WebRequest("GET", url, headers, 4000, data, result, resultHeaders);
   if(res == 200 && ArraySize(result) > 0) {
      string json = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
      ParseForexFactoryJson(json);
      m_newsFetchFailed = false;
   } else {
      url = "https://nfs.kineo.ai/ff_calendar_thisweek.json";
      res = WebRequest("GET", url, headers, 4000, data, result, resultHeaders);
      if(res == 200 && ArraySize(result) > 0) {
         string json = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
         ParseForexFactoryJson(json);
         m_newsFetchFailed = false;
      } else {
         m_newsFetchFailed = true;
      }
   }
}

void ParseForexFactoryJson(string json) {
   ArrayResize(m_newsEvents, 0);
   int pos = 0;
   while((pos = StringFind(json, "\"title\":", pos)) >= 0) {
      int titleEnd = StringFind(json, "\",", pos + 9);
      if(titleEnd < 0) break;
      string title = StringSubstr(json, pos + 9, titleEnd - (pos + 9));

      int countryPos = StringFind(json, "\"country\":\"", titleEnd);
      string country = "";
      if(countryPos >= 0) {
         int countryEnd = StringFind(json, "\",", countryPos + 11);
         country = StringSubstr(json, countryPos + 11, countryEnd - (countryPos + 11));
      }

      int impactPos = StringFind(json, "\"impact\":\"", titleEnd);
      string impact = "";
      if(impactPos >= 0) {
         int impactEnd = StringFind(json, "\",", impactPos + 10);
         impact = StringSubstr(json, impactPos + 10, impactEnd - (impactPos + 10));
      }

      if(impact == "High") {
         int n = ArraySize(m_newsEvents);
         ArrayResize(m_newsEvents, n + 1);
         m_newsEvents[n].title = title;
         m_newsEvents[n].currency = country;
         m_newsEvents[n].impact = impact;
         m_newsEvents[n].time = TimeCurrent() + 900;
      }
      pos = titleEnd + 1;
   }
}

bool IsNewsRiskActive(string symbol) {
   if(ArraySize(m_newsEvents) == 0) return false;
   datetime now = TimeCurrent();

   for(int i = 0; i < ArraySize(m_newsEvents); i++) {
      if(StringFind(symbol, m_newsEvents[i].currency) >= 0 || m_newsEvents[i].currency == "USD") {
         if(now >= (m_newsEvents[i].time - (InpNewsPauseBefore * 60)) &&
            now <= (m_newsEvents[i].time + (InpNewsPauseAfter * 60))) {
            return true;
         }
      }
   }
   return false;
}

void FetchAlternativeMeFearGreed() {
   string url = "https://api.alternative.me/fng/";
   string headers = "User-Agent: Mozilla/5.0\r\n";
   char data[], result[]; string resultHeaders;

   int res = WebRequest("GET", url, headers, 4000, data, result, resultHeaders);
   if(res == 200 && ArraySize(result) > 0) {
      string json = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
      int valPos = StringFind(json, "\"value\":\"");
      if(valPos >= 0) {
         int valEnd = StringFind(json, "\",", valPos + 9);
         m_fearGreedScore = (int)StringToInteger(StringSubstr(json, valPos + 9, valEnd - (valPos + 9)));
      }
      int classPos = StringFind(json, "\"value_classification\":\"");
      if(classPos >= 0) {
         int classEnd = StringFind(json, "\",", classPos + 24);
         m_fearGreedLabel = StringSubstr(json, classPos + 24, classEnd - (classPos + 24));
      }
   }
}

string CalculateCurrencyStrength() {
   string majPairs[] = {"EURUSD", "GBPUSD", "USDJPY", "AUDUSD", "USDCAD", "USDCHF", "NZDUSD"};
   double changes[7]; ArrayInitialize(changes, 0.0);

   for(int i = 0; i < 7; i++) {
      string sym = ResolveBrokerSymbol(majPairs[i]);
      if(sym == "") continue;
      MqlRates r[]; ArraySetAsSeries(r, true);
      if(CopyRates(sym, PERIOD_D1, 0, 2, r) >= 2 && r[1].close > 0) {
         changes[i] = ((r[0].close - r[1].close) / r[1].close) * 100.0;
      }
   }

   double usdStr = 50.0 - (changes[0] + changes[1] + changes[3] + changes[6]) + (changes[2] + changes[4] + changes[5]);
   double eurStr = 50.0 + changes[0];
   double gbpStr = 50.0 + changes[1];
   double jpyStr = 50.0 - changes[2];

   usdStr = MathMax(0.0, MathMin(100.0, usdStr));
   eurStr = MathMax(0.0, MathMin(100.0, eurStr));
   gbpStr = MathMax(0.0, MathMin(100.0, gbpStr));
   jpyStr = MathMax(0.0, MathMin(100.0, jpyStr));

   return StringFormat("USD: %.0f | EUR: %.0f | GBP: %.0f | JPY: %.0f", usdStr, eurStr, gbpStr, jpyStr);
}

//====================================================================
// SECTION 16: QUANTITATIVE CORRELATION & ADR ENGINES
//====================================================================

double CalculateDXYCorrelation(string symbol) {
   if(InpDxySymbol == "") return 0.0;
   string resolvedDxy = ResolveBrokerSymbol(InpDxySymbol);
   if(resolvedDxy == "") return 0.0;

   double c1[], c2[];
   ArraySetAsSeries(c1, true); ArraySetAsSeries(c2, true);
   int count = 30;

   if(CopyClose(symbol, PERIOD_M5, 1, count, c1) < count || CopyClose(resolvedDxy, PERIOD_M5, 1, count, c2) < count) return 0.0;

   double sum1 = 0, sum2 = 0;
   for(int i = 0; i < count; i++) { sum1 += c1[i]; sum2 += c2[i]; }
   double mean1 = sum1 / count, mean2 = sum2 / count;

   double num = 0, den1 = 0, den2 = 0;
   for(int i = 0; i < count; i++) {
      double diff1 = c1[i] - mean1;
      double diff2 = c2[i] - mean2;
      num += (diff1 * diff2);
      den1 += (diff1 * diff1);
      den2 += (diff2 * diff2);
   }

   if(den1 <= 0 || den2 <= 0) return 0.0;
   double r = num / (MathSqrt(den1) * MathSqrt(den2));
   if(!MathIsValidNumber(r)) return 0.0;
   return NormalizeDouble(r, 2);
}

double CalculateADRPercentUsed(string symbol) {
   MqlRates ratesD1[]; ArraySetAsSeries(ratesD1, true);
   if(CopyRates(symbol, PERIOD_D1, 0, 15, ratesD1) < 15) return 0.0;

   double totalRange = 0;
   for(int i = 1; i <= 14; i++) {
      totalRange += (ratesD1[i].high - ratesD1[i].low);
   }
   double adr = totalRange / 14.0;
   if(adr <= 0 || !MathIsValidNumber(adr)) return 0.0;

   double todayRange = ratesD1[0].high - ratesD1[0].low;
   double res = (todayRange / adr) * 100.0;
   if(!MathIsValidNumber(res)) return 0.0;
   return NormalizeDouble(res, 1);
}

//====================================================================
// SECTION 17: SCHEDULED REPORTS & MT5 TERMINAL-DRIVEN REPORTING
//====================================================================

bool IsValidTradeData(const VirtualTrade &vt) {
   if(vt.symbol == "") return false;
   if(!MathIsValidNumber(vt.entry) || vt.entry <= 0) return false;
   if(!MathIsValidNumber(vt.sl) || vt.sl < 0) return false;
   if(!MathIsValidNumber(vt.tp1) || vt.tp1 < 0) return false;
   if(!MathIsValidNumber(vt.initialLot) || vt.initialLot <= 0 || vt.initialLot > 1000.0) return false;
   if(!MathIsValidNumber(vt.riskDistance) || vt.riskDistance < 0) return false;
   if(!MathIsValidNumber(vt.currentRR) || MathAbs(vt.currentRR) > 1000.0) return false;
   return true;
}

string GetLiveTradesReportBlock() {
   string msg = "\n━━━━━━━━━━━━━━━━━━\n💼 <b>LIVE POSITIONS</b>\n━━━━━━━━━━━━━━━━━━\n\n";
   int totalPositions = PositionsTotal();
   int liveCount = 0;
   double totalFloatingProfit = 0.0;
   double totalFloatingR = 0.0;

   for(int i = 0; i < totalPositions; i++) {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;

      ulong magic = PositionGetInteger(POSITION_MAGIC);
      if(magic != InpMagicNumber && magic != 0) continue;

      string sym = PositionGetString(POSITION_SYMBOL);
      long posType = PositionGetInteger(POSITION_TYPE);
      bool isBuy = (posType == POSITION_TYPE_BUY);
      double vol = PositionGetDouble(POSITION_VOLUME);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double profit = PositionGetDouble(POSITION_PROFIT);

      if(!MathIsValidNumber(vol) || vol <= 0 || !MathIsValidNumber(openPrice) || openPrice <= 0) continue;
      if(!MathIsValidNumber(profit)) profit = 0.0;

      int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
      double bid = SymbolInfoDouble(sym, SYMBOL_BID);
      double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
      double currentPrice = isBuy ? bid : ask;
      if(!MathIsValidNumber(currentPrice) || currentPrice <= 0) continue;

      double riskDist = MathAbs(openPrice - sl);
      double tickValue = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
      double tickSize  = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
      double riskMoney = 0.0;
      double rr = 0.0;

      if(sl > 0 && riskDist > 0 && tickSize > 0 && tickValue > 0) {
         double slTicks = riskDist / tickSize;
         riskMoney = vol * slTicks * tickValue;
         if(riskMoney > 0) {
            rr = profit / riskMoney;
         }
      }

      if(!MathIsValidNumber(rr) || MathAbs(rr) > 100.0) rr = 0.0;

      liveCount++;
      totalFloatingProfit += profit;
      totalFloatingR += rr;

      string slStr = (sl > 0 && MathIsValidNumber(sl)) ? DoubleToString(sl, digits) : "N/A";
      string rStr  = (riskMoney > 0) ? StringFormat("%s%.2fR", (rr>=0?"+":""), rr) : "N/A";
      string exitModeStr = (InpTradeManagementMode == MODE_TREND_RUNNER_CROSSOVER) ? "EMA Cross" : "2.0R (50%) -> Runner";

      msg += StringFormat(
         "%s <b>%s %s</b>\n"
         "• <b>Entry:</b> <code>%s</code> | <b>SL:</b> <code>%s</code>\n"
         "• <b>Exit:</b> %s | <b>Lots:</b> <code>%.2f</code>\n"
         "• <b>Running:</b> %s (<b>Floating:</b> %s$%.2f) | <b>Trade:</b> #%I64u\n\n",
         (isBuy ? "🟢" : "🔴"), sym, (isBuy ? "BUY" : "SELL"),
         DoubleToString(openPrice, digits), slStr,
         exitModeStr, vol,
         rStr, (profit>=0?"+":"-"), MathAbs(profit), ticket
      );
   }

   if(liveCount == 0) {
      msg += "<i>No active live positions running.</i>\n\n";
   } else {
      msg += StringFormat(
         "TOTAL LIVE TRADES: %d\n"
         "TOTAL FLOATING P/L: %s$%.2f\n"
         "TOTAL FLOATING R: %s%.2fR\n\n",
         liveCount, (totalFloatingProfit>=0?"+":"-"), MathAbs(totalFloatingProfit),
         (totalFloatingR>=0?"+":""), totalFloatingR
      );
   }

   return msg;
}

string GetTodaysSummaryBlock() {
   string msg = "━━━━━━━━━━━━━━━━━━\n📊 <b>TODAY'S SUMMARY</b>\n━━━━━━━━━━━━━━━━━━\n\n";

   datetime currentTime = TimeCurrent();
   datetime ukTime = GetUKTime(currentTime);

   MqlDateTime dtUK; TimeToStruct(ukTime, dtUK);
   datetime today07UK = ukTime - (dtUK.hour * 3600 + dtUK.min * 60 + dtUK.sec) + (InpDayOpenHour * 3600);
   if(ukTime < today07UK) today07UK -= 86400;

   int tTrades = 0, tWins = 0, tLosses = 0, tBE = 0;
   double totalNetProfit = 0.0;
   double totalNetR      = 0.0;

   // 1. Calculate from reconciled closed history trades recorded today
   for(int i = 0; i < ArraySize(m_historyTrades); i++) {
      datetime tradeUKClose = GetUKTime(m_historyTrades[i].closeTime);
      if(tradeUKClose >= today07UK) {
         totalNetProfit += m_historyTrades[i].resultProfit;
         totalNetR      += m_historyTrades[i].resultRR;
         if(m_historyTrades[i].resultProfit > 0.5) tWins++;
         else if(m_historyTrades[i].resultProfit < -0.5) tLosses++;
         else tBE++;
         tTrades++;
      }
   }

   // 2. Fallback to broker deals if history array is empty (e.g. fresh EA attachment)
   if(tTrades == 0 && HistorySelect(today07UK, currentTime)) {
      int totalDeals = HistoryDealsTotal();
      for(int i = 0; i < totalDeals; i++) {
         ulong dealTicket = HistoryDealGetTicket(i);
         if(dealTicket <= 0) continue;

         long magic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
         if(magic != InpMagicNumber && magic != 0) continue;

         long entryType = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
         if(entryType != DEAL_ENTRY_OUT && entryType != DEAL_ENTRY_INOUT) continue;

         double profit     = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
         double commission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
         double swap       = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
         double fee        = HistoryDealGetDouble(dealTicket, DEAL_FEE);
         double netDealProfit = profit + commission + swap + fee;

         if(!MathIsValidNumber(netDealProfit)) continue;

         tTrades++;
         totalNetProfit += netDealProfit;

         if(netDealProfit > 0.5) tWins++;
         else if(netDealProfit < -0.5) tLosses++;
         else tBE++;
      }
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      if(balance <= 0) balance = 10000.0;
      double baseRiskMoney = balance * (InpRiskPercent / 100.0);
      if(baseRiskMoney > 0) {
         totalNetR = totalNetProfit / baseRiskMoney;
      }
   }

   double winRate = (tTrades > 0) ? ((double)tWins / tTrades) * 100.0 : 0.0;

   msg += StringFormat(
      "Trades: %d\n"
      "Wins: %d\n"
      "Losses: %d\n"
      "BE: %d\n"
      "Win Rate: %.2f%%\n\n"
      "Total P/L Today: %s$%.2f\n"
      "Total R Today: %s%.2fR\n"
      "━━━━━━━━━━━━━━━━━━",
      tTrades, tWins, tLosses, tBE, winRate,
      (totalNetProfit >= 0 ? "+" : "-"), MathAbs(totalNetProfit),
      (totalNetR >= 0 ? "+" : ""), totalNetR
   );

   return msg;
}

string GetNewsStatusBlock(string symbol = "") {
   if(!InpEnableNewsFilter) return "📰 NEWS: DISABLED";

   if(m_newsFetchFailed && ArraySize(m_newsEvents) == 0) return "📰 NEWS: DATA UNAVAILABLE";

   if(ArraySize(m_newsEvents) == 0) return "📰 NEWS: NONE (No High Impact Events)";

   datetime now = TimeCurrent();
   for(int i = 0; i < ArraySize(m_newsEvents); i++) {
      if(symbol == "" || StringFind(symbol, m_newsEvents[i].currency) >= 0 || m_newsEvents[i].currency == "USD") {
         long minutesLeft = (m_newsEvents[i].time - now) / 60;
         if(minutesLeft >= -15 && minutesLeft <= 60) {
            return StringFormat("📰 HIGH IMPACT NEWS\nEvent: %s (%s)\nTime: %s (in %d mins)\nImpact: HIGH",
               m_newsEvents[i].title, m_newsEvents[i].currency,
               TimeToString(m_newsEvents[i].time, TIME_MINUTES), minutesLeft);
         }
      }
   }
   return "📰 NEWS: NONE";
}

void ProcessScheduledReports(datetime ukTime, const MqlDateTime &dtUK) {
   // 1. 30-Minute Market Report
   if(InpEnable30MReport && (dtUK.min == 0 || dtUK.min == 30) && m_last30MReportMin != dtUK.min) {
      m_last30MReportMin = dtUK.min;
      Send30MAnalysisReport();
      m_isStateChanged = true;
   }

   // 2. 1-Hour Market Analysis Report
   if(InpEnable1HReport && dtUK.min == 0 && m_lastReportHour != dtUK.hour) {
      m_lastReportHour = dtUK.hour;
      SendHourlyAnalysisReport();
      m_isStateChanged = true;
   }

   // 3. Trade Day Opening Report (07:00 UK - Trigger once per day when hour >= 7)
   bool isDayOpenWindow = (dtUK.hour > InpDayOpenHour || (dtUK.hour == InpDayOpenHour && dtUK.min >= 0));
   if(InpEnableDayOpenReport && isDayOpenWindow && m_lastDayOpenReportDay != dtUK.day) {
      m_lastDayOpenReportDay = dtUK.day;
      SendDayOpeningReport();
      m_isStateChanged = true;
   }

   // 4. Trade Day Closing Report (22:00 UK - Trigger once per day when hour >= 22)
   bool isDayCloseWindow = (dtUK.hour > InpDayCloseHour || (dtUK.hour == InpDayCloseHour && dtUK.min >= 0));
   if(InpEnableDayCloseReport && isDayCloseWindow && m_lastDayCloseReportDay != dtUK.day) {
      m_lastDayCloseReportDay = dtUK.day;
      SendDayClosingReport();
      m_isStateChanged = true;
   }
}

void Send30MAnalysisReport() {
   datetime ukTime = GetUKTime(TimeCurrent());
   MqlDateTime dtNow; TimeToStruct(ukTime, dtNow);
   string timeStr = StringFormat("%02d:%02d UK", dtNow.hour, dtNow.min);

   string msg = StringFormat(
      "⏱️ <b>30M MARKET UPDATE</b> | <b>Time: %s</b>\n\n"
      "<b>Market Snapshot:</b>\n",
      timeStr
   );

   for(int i = 0; i < m_totalSymbols; i++) {
      string sym = m_scanners[i].resolvedSymbol;
      MarketStructure ms; AnalyzeMarketStructure(sym, ms);
      msg += StringFormat("• <b>%s:</b> %s\n", sym, ms.h1Bias);
   }

   msg += GetLiveTradesReportBlock();
   msg += GetTodaysSummaryBlock();

   SendTelegramMessage(msg);
}

void SendDayOpeningReport() {
   if(!InpEnableTelegram || !Telegram_Send_Opening_Report) return;
   
   string symbolsBlock = "";
   for(int i = 0; i < m_totalSymbols; i++) {
      if(!m_scanners[i].isValid) continue;
      string sym = m_scanners[i].resolvedSymbol;
      string symEmoji = GetSymbolEmoji(sym);
      ENUM_HTF_TREND htf = DetermineH1Trend(i);
      string trendStr = (htf == HTF_TREND_STRONG_BULLISH || htf == HTF_TREND_BULLISH) ? "Bullish 📈" :
                        ((htf == HTF_TREND_STRONG_BEARISH || htf == HTF_TREND_BEARISH) ? "Bearish 📉" : "Neutral ⚖️");

      double e9[], e21[], e200[], cl[];
      ArraySetAsSeries(e9, true); ArraySetAsSeries(e21, true); ArraySetAsSeries(e200, true); ArraySetAsSeries(cl, true);
      string m5Status = "Retest / Value Zone";
      string emaHealth = "Healthy";

      if(CopyBuffer(m_scanners[i].h_ema9_m5, 0, 1, 1, e9) > 0 &&
         CopyBuffer(m_scanners[i].h_ema21_m5, 0, 1, 1, e21) > 0 &&
         CopyBuffer(m_scanners[i].h_ema200_m5, 0, 1, 1, e200) > 0 &&
         CopyClose(sym, PERIOD_M5, 1, 1, cl) > 0) {
         
         double spread = MathAbs(e9[0] - e21[0]);
         double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
         if(spread < (pt * 15)) {
            emaHealth = "Flat | ⚠️ Avoid Chop";
            m5Status = "Consolidation";
         } else if(cl[0] > e200[0]) {
            emaHealth = "Healthy";
            m5Status = (cl[0] >= MathMin(e9[0], e21[0]) && cl[0] <= MathMax(e9[0], e21[0])) ? "Value Zone" : "Above 200";
         } else {
            emaHealth = "Healthy";
            m5Status = (cl[0] >= MathMin(e9[0], e21[0]) && cl[0] <= MathMax(e9[0], e21[0])) ? "Value Zone" : "Below 200";
         }
      }

      symbolsBlock += StringFormat("%s <b>%s</b> — %s\nEMA: %s | M5: %s\n\n", symEmoji, sym, trendStr, emaHealth, m5Status);
   }

   if(symbolsBlock == "") {
      symbolsBlock = 
         "🟡 <b>XAUUSD</b> — Scanning 📈\n"
         "⚪ <b>XAGUSD</b> — Scanning 📈\n"
         "⚪ <b>US500</b> — Scanning ⚖️\n"
         "💻 <b>USTEC</b> — Scanning 📈\n\n";
   }

   string msg = 
      "🌅 <b>07:00 UK — OPENING RADAR</b>\n\n"
      "Market: London 🟢\n"
      "TF: M5 | HTF: H1\n\n" +
      symbolsBlock +
      "💼 Equity: " + StringFormat("$%.0f", AccountInfoDouble(ACCOUNT_EQUITY)) + "\n"
      "📌 Open Trades: " + IntegerToString(PositionsTotal()) + "\n\n"
      "<b>921 EMA V1 — SCANNING</b>";

   SendTelegramMessage(msg);
}

void SendHourlyAnalysisReport() {
   if(!InpEnableTelegram || !Telegram_Send_Hourly_Report) return;
   
   datetime ukTime = GetUKTime(TimeCurrent());
   MqlDateTime dtNow; TimeToStruct(ukTime, dtNow);
   string timeHeader = StringFormat("%02d:%02d UK", dtNow.hour, dtNow.min);

   int openCount = 0;
   double totalFloatPnl = 0.0;
   string openPositionsBlock = "";
   string bestRunnerStr = "Scanning";
   double bestRunnerR = -999.0;

   int totalPos = PositionsTotal();
   for(int i = 0; i < totalPos; i++) {
      ulong t = PositionGetTicket(i);
      if(t <= 0 || !PositionSelectByTicket(t)) continue;
      ulong m = PositionGetInteger(POSITION_MAGIC);
      if(m != InpMagicNumber && m != 0) continue;

      string sym = PositionGetString(POSITION_SYMBOL);
      long pType = PositionGetInteger(POSITION_TYPE);
      bool isBuy = (pType == POSITION_TYPE_BUY);
      double pnl = PositionGetDouble(POSITION_PROFIT);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double curPrice = isBuy ? SymbolInfoDouble(sym, SYMBOL_BID) : SymbolInfoDouble(sym, SYMBOL_ASK);

      // Retrieve Initial Risk Distance for accurate R calculation
      double riskDist = 0.0;
      for(int a = 0; a < ArraySize(m_activeTrades); a++) {
         if(m_activeTrades[a].ticket == t || m_activeTrades[a].brokerTicket == t) {
            riskDist = m_activeTrades[a].initialRiskDist;
            break;
         }
      }
      if(riskDist <= 0) {
         riskDist = MathAbs(openPrice - currentSL);
      }

      double curR = (riskDist > 0) ? (isBuy ? (curPrice - openPrice)/riskDist : (openPrice - curPrice)/riskDist) : 0.0;

      openCount++;
      totalFloatPnl += pnl;

      if(curR > bestRunnerR) {
         bestRunnerR = curR;
         bestRunnerStr = StringFormat("%s (%+0.2fR)", sym, curR);
      }

      string pnlSign = (pnl >= 0 ? "+$" : "-$");
      openPositionsBlock += StringFormat(
         "%s <b>%s %s</b>\n"
         "%+0.2fR | %s%.2f\n\n",
         (isBuy ? "🟢" : "🔴"), sym, (isBuy ? "BUY" : "SELL"),
         curR, pnlSign, MathAbs(pnl)
      );
   }

   string marketSentiment = "Neutral";
   if(m_fearGreedScore >= 55) marketSentiment = "Risk-On";
   else if(m_fearGreedScore >= 0 && m_fearGreedScore <= 45) marketSentiment = "Risk-Off";
   else {
      // Dynamic fallback based on floating performance if external sentiment feed unavailable
      marketSentiment = (totalFloatPnl >= 0) ? "Risk-On" : "Risk-Off";
   }

   string msg = StringFormat(
      "⏱ <b>%s — LIVE RADAR</b>\n\n"
      "OPEN TRADES: %d\n\n"
      "%s"
      "💰 <b>FLOATING: %s$%.2f</b>\n\n"
      "📊 Market: %s\n"
      "🔥 Best Runner: %s",
      timeHeader, openCount,
      (openCount > 0 ? openPositionsBlock : "<i>No open positions running.</i>\n\n"),
      (totalFloatPnl >= 0 ? "+" : "-"), MathAbs(totalFloatPnl),
      marketSentiment,
      (openCount > 0 ? bestRunnerStr : "Scanning")
   );

   SendTelegramMessage(msg);
}

void SendDayClosingReport() {
   if(!InpEnableTelegram || !Telegram_Send_Closing_Report) return;

   int wins = 0, losses = 0, bes = 0;
   double totalDayProfit = 0.0;
   double totalDayR = 0.0;
   string breakdown = "";

   for(int i = 0; i < ArraySize(m_historyTrades); i++) {
      if(m_historyTrades[i].resultProfit > 0) wins++;
      else if(m_historyTrades[i].resultProfit < 0) losses++;
      else bes++;

      totalDayProfit += m_historyTrades[i].resultProfit;
      totalDayR += m_historyTrades[i].resultRR;

      string symEmoji = GetSymbolEmoji(m_historyTrades[i].symbol);
      breakdown += StringFormat(
         "%s <b>%s</b>: %s$%.0f | %+0.2fR\n",
         symEmoji, m_historyTrades[i].symbol,
         (m_historyTrades[i].resultProfit >= 0 ? "+" : "-"), MathAbs(m_historyTrades[i].resultProfit),
         m_historyTrades[i].resultRR
      );
   }

   string msg = StringFormat(
      "🌙 <b>22:30 UK — DAY CLOSED</b>\n\n"
      "RESULT: %dW / %dL / %dBE\n\n"
      "%s\n"
      "🏆 <b>TOTAL: %s$%.2f | %+0.2fR</b>\n\n"
      "💼 Equity: $%.2f\n\n"
      "💤 Scanner: <b>SLEEP MODE</b>\n"
      "⏰ Resume: 07:00 UK",
      wins, losses, bes,
      (ArraySize(m_historyTrades) > 0 ? breakdown : "🟡 XAUUSD: Flat\n⚪ XAGUSD: Flat\n"),
      (totalDayProfit >= 0 ? "+" : "-"), MathAbs(totalDayProfit),
      totalDayR,
      AccountInfoDouble(ACCOUNT_EQUITY)
   );

   SendTelegramMessage(msg);
}

//====================================================================
// SECTION 18: PERSISTENCE ENGINE (FILE_COMMON in EMA_PRO_V2\)
//====================================================================

void SaveState(bool isShutdown) {
   string folder = "MultiPairScannerV1\\";

   int hScan = FileOpen(folder + "ScannerState.bin", FILE_WRITE | FILE_BIN | FILE_COMMON);
   if(hScan != INVALID_HANDLE) {
      FileWriteInteger(hScan, STATE_FILE_VERSION);
      FileWriteInteger(hScan, m_last30MReportMin);
      FileWriteInteger(hScan, m_lastReportHour);
      FileWriteInteger(hScan, m_lastDayOpenReportDay);
      FileWriteInteger(hScan, m_lastDayCloseReportDay);
      FileClose(hScan);
   }

   int hActive = FileOpen(folder + "ActiveTrades.bin", FILE_WRITE | FILE_BIN | FILE_COMMON);
   if(hActive != INVALID_HANDLE) {
      FileWriteInteger(hActive, STATE_FILE_VERSION);
      int size = ArraySize(m_activeTrades);
      FileWriteInteger(hActive, size);
      for(int i = 0; i < size; i++) {
         if(!IsValidTradeData(m_activeTrades[i])) continue;
         FileWriteStringSafe(hActive, m_activeTrades[i].id);
         FileWriteStringSafe(hActive, m_activeTrades[i].symbol);
         FileWriteInteger(hActive, (int)m_activeTrades[i].strategy);
         FileWriteInteger(hActive, (int)m_activeTrades[i].executionTF);
         FileWriteInteger(hActive, m_activeTrades[i].type);
         FileWriteInteger(hActive, m_activeTrades[i].isReEntry ? 1 : 0);
         FileWriteDouble(hActive, m_activeTrades[i].initialLot);
         FileWriteDouble(hActive, m_activeTrades[i].currentLot);
         FileWriteDouble(hActive, m_activeTrades[i].entry);
         FileWriteDouble(hActive, m_activeTrades[i].sl);
         FileWriteDouble(hActive, m_activeTrades[i].tp1);
         FileWriteDouble(hActive, m_activeTrades[i].riskDistance);
         FileWriteDouble(hActive, m_activeTrades[i].currentRR);
         FileWriteDouble(hActive, m_activeTrades[i].maxRR);
         FileWriteInteger(hActive, m_activeTrades[i].qualityScore);
         FileWriteStringSafe(hActive, m_activeTrades[i].qualityLabel);
         FileWriteStringSafe(hActive, m_activeTrades[i].triggerReason);
         FileWriteLong(hActive, (long)m_activeTrades[i].openTime);
         FileWriteInteger(hActive, (int)m_activeTrades[i].status);
         FileWriteInteger(hActive, m_activeTrades[i].reachedTP1 ? 1 : 0);
         FileWriteInteger(hActive, m_activeTrades[i].reachedBE ? 1 : 0);
         FileWriteInteger(hActive, m_activeTrades[i].isRunner ? 1 : 0);
         FileWriteDouble(hActive, m_activeTrades[i].tp1RealizedProfit);
         FileWriteDouble(hActive, m_activeTrades[i].tp1RealizedR);
         FileWriteLong(hActive, (long)m_activeTrades[i].brokerTicket);
      }
      FileClose(hActive);
   }

   int hHistory = FileOpen(folder + "TradeHistory.bin", FILE_WRITE | FILE_BIN | FILE_COMMON);
   if(hHistory != INVALID_HANDLE) {
      FileWriteInteger(hHistory, STATE_FILE_VERSION);
      int size = ArraySize(m_historyTrades);
      FileWriteInteger(hHistory, size);
      for(int i = 0; i < size; i++) {
         FileWriteStringSafe(hHistory, m_historyTrades[i].id);
         FileWriteStringSafe(hHistory, m_historyTrades[i].symbol);
         FileWriteInteger(hHistory, (int)m_historyTrades[i].strategy);
         FileWriteInteger(hHistory, (int)m_historyTrades[i].executionTF);
         FileWriteInteger(hHistory, m_historyTrades[i].type);
         FileWriteInteger(hHistory, m_historyTrades[i].isReEntry ? 1 : 0);
         FileWriteDouble(hHistory, m_historyTrades[i].initialLot);
         FileWriteDouble(hHistory, m_historyTrades[i].finalLot);
         FileWriteDouble(hHistory, m_historyTrades[i].entry);
         FileWriteDouble(hHistory, m_historyTrades[i].sl);
         FileWriteDouble(hHistory, m_historyTrades[i].exitPrice);
         FileWriteDouble(hHistory, m_historyTrades[i].resultRR);
         FileWriteDouble(hHistory, m_historyTrades[i].resultProfit);
         FileWriteDouble(hHistory, m_historyTrades[i].maxRR);
         FileWriteInteger(hHistory, m_historyTrades[i].qualityScore);
         FileWriteStringSafe(hHistory, m_historyTrades[i].qualityLabel);
         FileWriteLong(hHistory, (long)m_historyTrades[i].openTime);
         FileWriteLong(hHistory, (long)m_historyTrades[i].closeTime);
         FileWriteInteger(hHistory, (int)m_historyTrades[i].status);
         FileWriteStringSafe(hHistory, m_historyTrades[i].exitReason);
      }
      FileClose(hHistory);
   }

   if(isShutdown) Print("[PERSISTENCE] EA State & Report Guards safely written to FILE_COMMON/MultiPairScannerV1/");
}

void LoadState() {
   string folder = "MultiPairScannerV1\\";

   int hScan = FileOpen(folder + "ScannerState.bin", FILE_READ | FILE_BIN | FILE_COMMON);
   if(hScan != INVALID_HANDLE) {
      int ver = FileReadInteger(hScan);
      if(ver == STATE_FILE_VERSION) {
         m_last30MReportMin     = FileReadInteger(hScan);
         m_lastReportHour       = FileReadInteger(hScan);
         m_lastDayOpenReportDay = FileReadInteger(hScan);
         m_lastDayCloseReportDay= FileReadInteger(hScan);
      } else {
         Print("[PERSISTENCE WARN] ScannerState.bin version mismatch. Resetting report guards...");
      }
      FileClose(hScan);
   }

   int hActive = FileOpen(folder + "ActiveTrades.bin", FILE_READ | FILE_BIN | FILE_COMMON);
   if(hActive != INVALID_HANDLE) {
      int ver = FileReadInteger(hActive);
      if(ver != STATE_FILE_VERSION) {
         Print("[PERSISTENCE WARN] ActiveTrades.bin version mismatch. Purging legacy binary state file...");
         FileClose(hActive);
         FileDelete(folder + "ActiveTrades.bin", FILE_COMMON);
      } else {
         int size = FileReadInteger(hActive);
         ArrayResize(m_activeTrades, 0);
         for(int i = 0; i < size; i++) {
            VirtualTrade vt; ZeroMemory(vt);
            vt.id = FileReadStringSafe(hActive);
            vt.symbol = FileReadStringSafe(hActive);
            vt.strategy = (ENUM_STRATEGY_TYPE)FileReadInteger(hActive);
            vt.executionTF = (ENUM_TIMEFRAMES)FileReadInteger(hActive);
            vt.type = FileReadInteger(hActive);
            vt.isReEntry = (FileReadInteger(hActive) == 1);
            vt.initialLot = FileReadDouble(hActive);
            vt.currentLot = FileReadDouble(hActive);
            vt.entry = FileReadDouble(hActive);
            vt.sl = FileReadDouble(hActive);
            vt.tp1 = FileReadDouble(hActive);
            vt.riskDistance = FileReadDouble(hActive);
            vt.currentRR = FileReadDouble(hActive);
            vt.maxRR = FileReadDouble(hActive);
            vt.qualityScore = FileReadInteger(hActive);
            vt.qualityLabel = FileReadStringSafe(hActive);
            vt.triggerReason = FileReadStringSafe(hActive);
            vt.openTime = (datetime)FileReadLong(hActive);
            vt.status = (ENUM_VIRTUAL_STATUS)FileReadInteger(hActive);
            vt.reachedTP1 = (FileReadInteger(hActive) == 1);
            vt.reachedBE = (FileReadInteger(hActive) == 1);
            vt.isRunner = (FileReadInteger(hActive) == 1);
            vt.tp1RealizedProfit = FileReadDouble(hActive);
            vt.tp1RealizedR = FileReadDouble(hActive);
            vt.brokerTicket = (ulong)FileReadLong(hActive);

            if(IsValidTradeData(vt)) {
               int currLen = ArraySize(m_activeTrades);
               ArrayResize(m_activeTrades, currLen + 1);
               m_activeTrades[currLen] = vt;
            }
         }
         FileClose(hActive);
         Print("[PERSISTENCE] Restored ", ArraySize(m_activeTrades), " valid active trades from binary storage.");
      }
   }

   int hHistory = FileOpen(folder + "TradeHistory.bin", FILE_READ | FILE_BIN | FILE_COMMON);
   if(hHistory != INVALID_HANDLE) {
      int ver = FileReadInteger(hHistory);
      if(ver != STATE_FILE_VERSION) {
         Print("[PERSISTENCE WARN] TradeHistory.bin version mismatch. Purging legacy binary history file...");
         FileClose(hHistory);
         FileDelete(folder + "TradeHistory.bin", FILE_COMMON);
      } else {
         int size = FileReadInteger(hHistory);
         ArrayResize(m_historyTrades, 0);
         for(int i = 0; i < size; i++) {
            HistoricalTrade ht; ZeroMemory(ht);
            ht.id = FileReadStringSafe(hHistory);
            ht.symbol = FileReadStringSafe(hHistory);
            ht.strategy = (ENUM_STRATEGY_TYPE)FileReadInteger(hHistory);
            ht.executionTF = (ENUM_TIMEFRAMES)FileReadInteger(hHistory);
            ht.type = FileReadInteger(hHistory);
            ht.isReEntry = (FileReadInteger(hHistory) == 1);
            ht.initialLot = FileReadDouble(hHistory);
            ht.finalLot = FileReadDouble(hHistory);
            ht.entry = FileReadDouble(hHistory);
            ht.sl = FileReadDouble(hHistory);
            ht.exitPrice = FileReadDouble(hHistory);
            ht.resultRR = FileReadDouble(hHistory);
            ht.resultProfit = FileReadDouble(hHistory);
            ht.maxRR = FileReadDouble(hHistory);
            ht.qualityScore = FileReadInteger(hHistory);
            ht.qualityLabel = FileReadStringSafe(hHistory);
            ht.openTime = (datetime)FileReadLong(hHistory);
            ht.closeTime = (datetime)FileReadLong(hHistory);
            ht.status = (ENUM_VIRTUAL_STATUS)FileReadInteger(hHistory);
            ht.exitReason = FileReadStringSafe(hHistory);

            if(ht.symbol != "" && MathIsValidNumber(ht.entry) && ht.entry > 0) {
               int currLen = ArraySize(m_historyTrades);
               ArrayResize(m_historyTrades, currLen + 1);
               m_historyTrades[currLen] = ht;
            }
         }
         FileClose(hHistory);
      }
   }
}

void FileWriteStringSafe(int handle, string text) {
   int len = StringLen(text);
   FileWriteInteger(handle, len);
   if(len > 0) FileWriteString(handle, text, len);
}

string FileReadStringSafe(int handle) {
   int len = FileReadInteger(handle);
   return (len > 0) ? FileReadString(handle, len) : "";
}

//====================================================================
// SECTION 19: CHART VISUALIZATION & DASHBOARD OVERLAY
//====================================================================

void DrawSignalChartObjects(const VirtualTrade &vt) {
   if(!InpDrawChartObjects || vt.symbol != _Symbol) return;

   string pfx = "MSS_V1_" + vt.id + "_";
   color lineClr = (vt.type == ORDER_TYPE_BUY) ? clrDodgerBlue : clrDeepPink;

   ObjectCreate(0, pfx + "ENTRY", OBJ_HLINE, 0, 0, vt.entry);
   ObjectSetInteger(0, pfx + "ENTRY", OBJPROP_COLOR, lineClr);
   ObjectSetInteger(0, pfx + "ENTRY", OBJPROP_WIDTH, 2);

   ObjectCreate(0, pfx + "SL", OBJ_HLINE, 0, 0, vt.sl);
   ObjectSetInteger(0, pfx + "SL", OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, pfx + "SL", OBJPROP_STYLE, STYLE_DASH);

   ObjectCreate(0, pfx + "TP1", OBJ_HLINE, 0, 0, vt.tp1);
   ObjectSetInteger(0, pfx + "TP1", OBJPROP_COLOR, clrGold);
   ObjectSetInteger(0, pfx + "TP1", OBJPROP_STYLE, STYLE_DASH);

   ChartRedraw(0);
}

void UpdateChartSLObject(const VirtualTrade &vt) {
   if(!InpDrawChartObjects || vt.symbol != _Symbol) return;
   string pfx = "MSS_V1_" + vt.id + "_";
   if(ObjectFind(0, pfx + "SL") >= 0) {
      ObjectSetDouble(0, pfx + "SL", OBJPROP_PRICE, vt.sl);
      ObjectSetInteger(0, pfx + "SL", OBJPROP_COLOR, clrOrange);
   }
   ChartRedraw(0);
}

void RemoveSignalChartObjects(const VirtualTrade &vt) {
   string pfx = "MSS_V1_" + vt.id + "_";
   ObjectsDeleteAll(0, pfx);
   ChartRedraw(0);
}

void UpdateDashboard(datetime ukTime, bool isSessionActive) {
   if(!InpShowDashboard) return;

   uint tick = GetTickCount();
   if(tick - m_lastDashboardTick < 1000) return;
   m_lastDashboardTick = tick;

   string dash = "========================================\n";
   dash += " 921 EMA MULTIPAIR SCANNER V1\n";
   dash += "========================================\n";
   dash += "Session Status : " + (isSessionActive ? "ACTIVE (Scanning) 🟢" : "INACTIVE (Outside Session) 🔴") + "\n";
   dash += "UK Time        : " + TimeToString(ukTime, TIME_MINUTES|TIME_SECONDS) + "\n";
   dash += "Strategy       : EMA Pullback Continuation Engine\n";
   dash += "Execution TFs  : M5 (" + (InpEnableM5Execution ? "ON" : "OFF") + ") | M1 (" + (InpEnableM1Execution ? "ON" : "OFF") + ")\n";
   dash += "Mode           : " + (InpAutoTradingEnabled ? "Live Trade + Alerts" : "Alerts Only") + "\n";
   dash += "Active Symbols : " + IntegerToString(m_totalSymbols) + "\n";
   dash += "Live Positions : " + IntegerToString(PositionsTotal()) + "\n";
   dash += "History Trades : " + IntegerToString(ArraySize(m_historyTrades)) + "\n";
   dash += "Show Plotting  : " + (InpDrawChartObjects ? "ON" : "OFF") + "\n";
   if(InpEnableFearGreed) dash += "Fear & Greed   : " + m_fearGreedLabel + " (" + IntegerToString(m_fearGreedScore) + ")\n";
   dash += "========================================\n";

   Comment(dash);
}
//+------------------------------------------------------------------+
