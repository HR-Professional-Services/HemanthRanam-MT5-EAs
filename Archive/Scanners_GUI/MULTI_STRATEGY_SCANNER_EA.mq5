//+------------------------------------------------------------------+
//|                  Multi_Strategy_Scanner_V1.mq5                   |
//|        Multi Strategy Scanner V1 - M5 9/21 EMA Pullback Production EA      |
//+------------------------------------------------------------------+
// ⚠️ Save this file as UTF-8 in MetaEditor before compiling to ensure 
// all emojis display correctly in Telegram alerts and reports!
#property copyright "Institutional Quantitative Engine"
#property link      ""
#property version   "1.00"
#property description "Multi Strategy Scanner V1 - Clean M5 9/21 EMA Pullback Continuation System"

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Canvas\Canvas.mqh>

//====================================================================
// SECTION 1: CONFIGURATION & INPUT PARAMETERS
//====================================================================

input group "=== Operation & Execution Mode ==="
input bool     InpAutoTradingEnabled        = true;      // Enable Live Auto Trading (False = Alerts Only)
input double   InpRiskPercent               = 1.0;       // Primary Trade Risk (% of Account Balance, Default: 1.0%)
input double   InpPartialClosePercent       = 50.0;      // TP1 2R Partial Profit Close % (Default: 50%)
input double   InpBEOffsetPips              = 1.0;       // Break Even SL Offset (Pips above/below Entry)
input ulong    InpMagicNumber               = 921002;    // EA Magic Number (Multi-Strategy Namespace)

input group "=== Strategy 1: Session VWAP Reclaim & Rejection ==="
input bool     InpEnableStrategy1_VWAP      = true;      // S1: Enable Session VWAP Reclaim Strategy
input int      InpSessionStartHour          = 8;         // S1: Session VWAP Anchor Start Hour (UK Time, Default: 8 for London Open)
input int      InpVWAPStretchLookback       = 6;         // S1: VWAP Stretch Discovery Lookback Window (Bars)
input double   InpVWAPStretchATR            = 0.75;      // S1: Minimum Stretch Beyond VWAP (x ATR)

input group "=== Strategy 2: Market Structure Break & Retest (BOS) ==="
input bool     InpEnableStrategy2_Structure = true;      // S2: Enable Market Structure BOS Retest Strategy
input double   InpBOSMinBreakATR            = 0.10;      // S2: Minimum Close Beyond Swing Point for BOS (x ATR)
input double   InpRetestToleranceATR        = 0.35;      // S2: Retest Zone Tolerance Buffer around Broken Level (x ATR)

input group "=== Strategy 3: Momentum Expansion & Controlled Pullback ==="
input bool     InpEnableStrategy3_Momentum  = true;      // S3: Enable Momentum Expansion Continuation Strategy
input double   InpMomentumExpansionATR      = 1.0;       // S3: Minimum Impulse Candle Range (x ATR)
input int      InpMaxPullbackBars           = 3;         // S3: Maximum Retest / Pullback Bars Lookback Window
input double   InpMaxPullbackDepthPct       = 50.0;      // S3: Maximum Allowed Retracement Depth (% of Expansion Candle)

input group "=== Centralized Multi-Strategy Risk & Position Limits ==="
input double   InpMaxTotalOpenRiskPercent   = 6.0;       // Max Aggregate Open Risk (% of Balance across all open positions)
input int      InpMaxTotalOpenPositions     = 5;         // Max Total Concurrent Open Positions
input int      InpMaxOpenPositionsPerSymbol = 2;         // Max Concurrent Open Positions Per Symbol

input group "=== Common Strategy Filters & SL Settings ==="
input bool     InpUseEMA200Filter           = true;      // Require Price on Correct Side of M5 EMA 200 (Default: TRUE)
input double   InpMinCandleRangeATR         = 0.25;      // Min Confirmation Candle Range vs ATR (Filter flat dojis, Default: 0.25)
input int      InpSLEngulfingBufferPoints   = 10;        // SL Buffer below/above Confirmation Candle (Points)
input int      InpAtrPeriod                 = 14;        // ATR Period for SL Buffer & Volatility
input double   InpSLBufferATR               = 0.5;       // ATR Safety Buffer Multiplier for SL

input group "=== Cycle Continuation & Re-Entry ==="
input bool     InpEnableReEntry             = true;      // Enable Continuation Re-Entry Model (Default: TRUE)
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

input group "=== Optional Volume Expansion Filter ==="
input bool     InpUseVolumeFilter           = true;      // Require Volume Expansion Confirmation (Anti-Fakeout)
input double   InpVolumeMultiplier          = 1.1;       // Minimum Volume Multiplier vs 20-period SMA
input int      InpVolumeLookback            = 20;        // Volume Rolling Average Lookback Period


input group "=== Diagnostics & Quality Scoring (Non-Gated) ==="
input bool     InpEnableDiagnostics         = true;      // Log Detailed Setup Rejection / Approval Diagnostics
input int      InpMinQualityScore           = 80;        // Confluence Score Rating Label Threshold (0-100, Informational)

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
input string   InpTelegramChatID      = ""; // Telegram Chat / Channel ID (Configure in EA inputs)                               // Telegram Chat / Channel ID
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
input bool     InpShowDashboard       = true;      // Show On-Chart Overlay Panel
input bool     InpDrawChartObjects    = false;     // Show Trade Plotting / MT5 Lines (Default: OFF)

//====================================================================
// SECTION 2: DATA STRUCTURES & ENUMS
//====================================================================

const int STATE_FILE_VERSION = 20260824;

enum ENUM_STRATEGY_TYPE {
   STRATEGY_NONE                  = 0,
   STRATEGY_VWAP_RECLAIM          = 1,   // Strategy 1: Session VWAP Reclaim
   STRATEGY_BREAKOUT_RETEST       = 2,   // Strategy 2: Market Structure Breakout & Retest
   STRATEGY_MOMENTUM_CONTINUATION = 3    // Strategy 3: Momentum Expansion & Pullback
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

struct Strategy1_VWAP_State {
   datetime lastSignalBar;
   double   lastEntryPrice;
   bool     primaryDone;
   int      reEntriesCount;
};

struct Strategy2_Structure_State {
   datetime lastSignalBar;
   double   lastEntryPrice;
   bool     primaryDone;
   int      reEntriesCount;
};

struct Strategy3_Momentum_State {
   datetime lastSignalBar;
   double   lastEntryPrice;
   bool     primaryDone;
   int      reEntriesCount;
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
};

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
   string                    rawName;
   string                    resolvedSymbol;
   bool                      isValid;
   int                       h_ema9_m5;
   int                       h_ema21_m5;
   int                       h_ema200_m5;
   int                       h_atr_m5;
   
   int                       h_ema9_m1;
   int                       h_ema21_m1;
   int                       h_ema200_m1;
   int                       h_atr_m1;

   int                       h_ema9_h1;
   int                       h_ema21_h1;
   int                       h_ema200_h1;
   
   datetime                  lastProcessedBarM5;
   datetime                  lastProcessedBarM1;
   datetime                  lastSignalTime;
   SessionLiquidity          liquidity;

   // 3 Independent Strategy States (M5 Execution)
   Strategy1_VWAP_State      stateS1_M5;
   Strategy2_Structure_State stateS2_M5;
   Strategy3_Momentum_State  stateS3_M5;

   // 3 Independent Strategy States (M1 Execution)
   Strategy1_VWAP_State      stateS1_M1;
   Strategy2_Structure_State stateS2_M1;
   Strategy3_Momentum_State  stateS3_M1;
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
void EvaluateStrategy1_VWAPReclaim(int idx, ENUM_TIMEFRAMES tf);
void EvaluateStrategy2_StructureRetest(int idx, ENUM_TIMEFRAMES tf);
void EvaluateStrategy3_MomentumContinuation(int idx, ENUM_TIMEFRAMES tf);
void EvaluateStrategiesForSymbol(int idx, ENUM_TIMEFRAMES tf);
void ExecuteTradeSignal(int idx, ENUM_TIMEFRAMES tf, int type, double entry, double sl, double tp1, const SignalQuality &quality, string triggerReason, bool isReEntry, ENUM_STRATEGY_TYPE stratType = STRATEGY_VWAP_RECLAIM);
double CalculateSessionVWAP(string sym, ENUM_TIMEFRAMES tf = PERIOD_M5);
double CalculateTotalOpenRiskPercent();
int CountOpenPositionsForSymbol(string sym);
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
   Print("[Multi Strategy Scanner V1] Initializing Production EA Engine (State Cycle & Pure Trend Runner)...");

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

   string reEntryStr = InpEnableReEntry ? StringFormat("Max %d", InpMaxReEntriesPerCycle) : "OFF";
   string startupMsg = StringFormat(
      "🚀 <b>MULTI-STRATEGY SCANNER V1 ONLINE</b>\n"
      "━━━━━━━━━━━━━━━━━━\n"
      "📡 %d Symbols | ⚡ %s\n"
      "📊 Multi-Strategy Scalping Engine (VWAP, Structure, Momentum)\n"
      "💰 Risk: %.1f%% (Re-Entry: %.1f%%, %s) | 🎯 TP1: 2R → 50%% → Runner\n"
      "⏱️ M5 %02d:00–%02d:00 | M1 %02d:00–%02d:00 UK\n"
      "🛡️ EMA200 Filter: %s | H1 Filter: %s\n\n"
      "📋 <b>Active Symbols (%d):</b>\n%s\n"
      "━━━━━━━━━━━━━━━━━━",
      m_totalSymbols, modeStr,
      InpRiskPercent, InpReEntryRiskPercent, reEntryStr,
      InpM5StartHour, InpM5EndHour,
      InpM1StartHour, InpM1EndHour,
      (InpUseEMA200Filter ? "ON" : "OFF"),
      (InpUseH1TrendFilter ? "ON" : "OFF"),
      m_totalSymbols, symbolsList
   );

   SendTelegramMessage(startupMsg);
   Print("[Multi Strategy Scanner V1] Startup completed successfully. Active symbols: ", m_totalSymbols);

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

   ZeroMemory(sym.stateS1_M5);
   ZeroMemory(sym.stateS2_M5);
   ZeroMemory(sym.stateS3_M5);
   ZeroMemory(sym.stateS1_M1);
   ZeroMemory(sym.stateS2_M1);
   ZeroMemory(sym.stateS3_M1);

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
   datetime utc = TimeGMT();
   if(utc <= 0) {
      if(serverTime <= 0) serverTime = TimeCurrent();
      utc = serverTime - (InpBrokerUTCOffset * 3600);
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
            EvaluateStrategiesForSymbol(i, PERIOD_M5);
         }
      }

      // Process 1M Execution Bar (13:00-17:00 UK Overlap Window)
      if(isM1Active) {
         datetime barM1 = iTime(m_scanners[i].resolvedSymbol, PERIOD_M1, 0);
         if(barM1 != m_scanners[i].lastProcessedBarM1 && barM1 > 0) {
            m_scanners[i].lastProcessedBarM1 = barM1;
            EvaluateStrategiesForSymbol(i, PERIOD_M1);
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
// SECTION 9: TRUE 3-STRATEGY SCALPING ENGINES
//====================================================================

// Common Bullish Confirmation: Green candle + (High Break OR Engulfing)
bool IsBullishConfirmation(const double &open[], const double &high[], const double &low[], const double &close[], double atr) {
   if(close[0] <= open[0]) return false; // Green candle required
   double candleRange = high[0] - low[0];
   if(atr > 0 && candleRange < (atr * InpMinCandleRangeATR)) return false;

   bool highBreak = (close[0] > high[1]);
   bool bodyEngulfs = (open[0] <= MathMax(open[1], close[1])) && 
                      (close[0] >= MathMin(open[1], close[1])) && 
                      ((close[0] - open[0]) >= MathAbs(close[1] - open[1]) * 0.85);
   return (highBreak || bodyEngulfs || (close[0] > open[1]));
}

// Common Bearish Confirmation: Red candle + (Low Break OR Engulfing)
bool IsBearishConfirmation(const double &open[], const double &high[], const double &low[], const double &close[], double atr) {
   if(close[0] >= open[0]) return false; // Red candle required
   double candleRange = high[0] - low[0];
   if(atr > 0 && candleRange < (atr * InpMinCandleRangeATR)) return false;

   bool lowBreak = (close[0] < low[1]);
   bool bodyEngulfs = (open[0] >= MathMin(open[1], close[1])) && 
                      (close[0] <= MathMax(open[1], close[1])) && 
                      ((open[0] - close[0]) >= MathAbs(close[1] - open[1]) * 0.85);
   return (lowBreak || bodyEngulfs || (close[0] < open[1]));
}

// Session VWAP Calculation Engine
double CalculateSessionVWAP(string sym, ENUM_TIMEFRAMES tf = PERIOD_M5) {
   datetime currentTime = TimeCurrent();
   datetime ukTime = GetUKTime(currentTime);
   MqlDateTime dtUK; TimeToStruct(ukTime, dtUK);
   datetime sessionStartUK = ukTime - (dtUK.hour * 3600 + dtUK.min * 60 + dtUK.sec) + (InpSessionStartHour * 3600);
   if(ukTime < sessionStartUK) sessionStartUK -= 86400;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(sym, tf, 1, 300, rates);
   if(copied <= 0) return 0.0;

   double cumulativeTPV = 0.0;
   double cumulativeVol = 0.0;

   for(int i = copied - 1; i >= 0; i--) {
      datetime barUK = GetUKTime(rates[i].time);
      if(barUK < sessionStartUK) continue;

      double typicalPrice = (rates[i].high + rates[i].low + rates[i].close) / 3.0;
      double vol = (double)((rates[i].real_volume > 0) ? rates[i].real_volume : rates[i].tick_volume);
      if(vol <= 0) vol = 1.0;

      cumulativeTPV += (typicalPrice * vol);
      cumulativeVol += vol;
   }

   if(cumulativeVol <= 0) return rates[0].close;
   return (cumulativeTPV / cumulativeVol);
}

// Global Total Portfolio Open Risk Percentage
double CalculateTotalOpenRiskPercent() {
   double totalRisk = 0.0;
   int size = ArraySize(m_activeTrades);
   for(int i = 0; i < size; i++) {
      if(m_activeTrades[i].status == STATUS_ACTIVE || m_activeTrades[i].status == STATUS_PARTIAL_CLOSED) {
         totalRisk += (m_activeTrades[i].isReEntry ? InpReEntryRiskPercent : InpRiskPercent);
      }
   }
   return totalRisk;
}

// Count Open Positions for Symbol
int CountOpenPositionsForSymbol(string sym) {
   int cnt = 0;
   int size = ArraySize(m_activeTrades);
   for(int i = 0; i < size; i++) {
      if((m_activeTrades[i].status == STATUS_ACTIVE || m_activeTrades[i].status == STATUS_PARTIAL_CLOSED) && m_activeTrades[i].symbol == sym) {
         cnt++;
      }
   }
   return cnt;
}

//+------------------------------------------------------------------+
//| STRATEGY 1: SESSION VWAP RECLAIM / MEAN REVERSION ENGINE          |
//+------------------------------------------------------------------+
void ProcessStrategy1_VWAP(int idx, ENUM_TIMEFRAMES tf, Strategy1_VWAP_State &state) {
   string sym = m_scanners[idx].resolvedSymbol;
   datetime currentBarTime = iTime(sym, tf, 1);

   if(currentBarTime == state.lastSignalBar && state.lastSignalBar > 0) return;

   // Check High-Impact News
   if(InpEnableNewsFilter && IsNewsRiskActive(sym)) return;

   int hEMA200 = (tf == PERIOD_M1) ? m_scanners[idx].h_ema200_m1 : m_scanners[idx].h_ema200_m5;
   int hATR    = (tf == PERIOD_M1) ? m_scanners[idx].h_atr_m1 : m_scanners[idx].h_atr_m5;

   double ema200[], atr[], open[], high[], low[], close[];
   ArraySetAsSeries(ema200, true); ArraySetAsSeries(atr, true);
   ArraySetAsSeries(open, true); ArraySetAsSeries(high, true); ArraySetAsSeries(low, true); ArraySetAsSeries(close, true);

   if(CopyBuffer(hEMA200, 0, 1, 6, ema200) <= 0 || CopyBuffer(hATR, 0, 1, 1, atr) <= 0 ||
      CopyOpen(sym, tf, 1, 6, open) <= 0 || CopyHigh(sym, tf, 1, 6, high) <= 0 ||
      CopyLow(sym, tf, 1, 6, low) <= 0 || CopyClose(sym, tf, 1, 6, close) <= 0) return;

   double vwap = CalculateSessionVWAP(sym, tf);
   if(vwap <= 0) return;

   string tfLabel = (tf == PERIOD_M1) ? "M1" : "M5";
   double pointVal = SymbolInfoDouble(sym, SYMBOL_POINT);

   // A. BULLISH VWAP RECLAIM SETUP
   // 1. Detect Stretch Below VWAP
   bool wasStretchedBelow = false;
   double lowestStretchPrice = low[0];
   for(int b = 1; b < MathMin(6, InpVWAPStretchLookback); b++) {
      if(low[b] <= (vwap - (atr[0] * InpVWAPStretchATR))) {
         wasStretchedBelow = true;
         if(low[b] < lowestStretchPrice) lowestStretchPrice = low[b];
      }
   }

   // 2. Reclaim: Price crosses back and closes ABOVE VWAP
   bool vwapReclaimedBull = wasStretchedBelow && (close[0] > vwap) && (low[1] < vwap || close[1] <= vwap);

   if(vwapReclaimedBull) {
      // Directional Filters
      if(InpUseEMA200Filter && close[0] <= ema200[0]) return;
      if(InpUseH1TrendFilter) {
         ENUM_HTF_TREND h1Trend = DetermineH1Trend(idx);
         if(h1Trend != HTF_TREND_BULLISH && h1Trend != HTF_TREND_STRONG_BULLISH) return;
      }

      // Confirmation & Anti-Fakeout Volume Check
      if(!IsBullishConfirmation(open, high, low, close, atr[0])) return;
      if(InpUseVolumeFilter && !CheckVolumeExpansion(sym, tf, 1)) return;


      bool isReEntry = state.primaryDone;
      if(isReEntry && (!InpEnableReEntry || state.reEntriesCount >= InpMaxReEntriesPerCycle)) return;

      double slPrice = lowestStretchPrice - (InpSLEngulfingBufferPoints * pointVal) - (atr[0] * InpSLBufferATR);
      double riskDist = close[0] - slPrice;
      if(riskDist <= 0) return;
      double tp1 = close[0] + (riskDist * 2.0);

      double tradeRisk = isReEntry ? InpReEntryRiskPercent : InpRiskPercent;
      StructureEvaluation structInfo; ZeroMemory(structInfo);
      RegimeEvaluation regimeInfo; ZeroMemory(regimeInfo);
      SignalQuality q = CalculateQualityScore(idx, ORDER_TYPE_BUY, HTF_TREND_BULLISH, close[0], slPrice, riskDist, atr[0], tf, structInfo, regimeInfo);

      string triggerReason = StringFormat("S1 VWAP Reclaim Bullish (VWAP: %.5f)\nEntry: %s (Risk: %.1f%%)", vwap, (isReEntry ? StringFormat("Re-Entry #%d", state.reEntriesCount + 1) : "Primary"), tradeRisk);

      ExecuteTradeSignal(idx, tf, ORDER_TYPE_BUY, close[0], slPrice, tp1, q, triggerReason, isReEntry, STRATEGY_VWAP_RECLAIM);

      state.lastSignalBar = currentBarTime;
      state.lastEntryPrice = close[0];
      if(!isReEntry) state.primaryDone = true;
      else state.reEntriesCount++;
      return;
   }

   // B. BEARISH VWAP REJECTION SETUP
   // 1. Detect Stretch Above VWAP
   bool wasStretchedAbove = false;
   double highestStretchPrice = high[0];
   for(int b = 1; b < MathMin(6, InpVWAPStretchLookback); b++) {
      if(high[b] >= (vwap + (atr[0] * InpVWAPStretchATR))) {
         wasStretchedAbove = true;
         if(high[b] > highestStretchPrice) highestStretchPrice = high[b];
      }
   }

   // 2. Loss: Price crosses back and closes BELOW VWAP
   bool vwapLostBear = wasStretchedAbove && (close[0] < vwap) && (high[1] > vwap || close[1] >= vwap);

   if(vwapLostBear) {
      if(InpUseEMA200Filter && close[0] >= ema200[0]) return;
      if(InpUseH1TrendFilter) {
         ENUM_HTF_TREND h1Trend = DetermineH1Trend(idx);
         if(h1Trend != HTF_TREND_BEARISH && h1Trend != HTF_TREND_STRONG_BEARISH) return;
      }

      if(!IsBearishConfirmation(open, high, low, close, atr[0])) return;
      if(InpUseVolumeFilter && !CheckVolumeExpansion(sym, tf, 1)) return;


      bool isReEntry = state.primaryDone;
      if(isReEntry && (!InpEnableReEntry || state.reEntriesCount >= InpMaxReEntriesPerCycle)) return;

      double slPrice = highestStretchPrice + (InpSLEngulfingBufferPoints * pointVal) + (atr[0] * InpSLBufferATR);
      double riskDist = slPrice - close[0];
      if(riskDist <= 0) return;
      double tp1 = close[0] - (riskDist * 2.0);

      double tradeRisk = isReEntry ? InpReEntryRiskPercent : InpRiskPercent;
      StructureEvaluation structInfo; ZeroMemory(structInfo);
      RegimeEvaluation regimeInfo; ZeroMemory(regimeInfo);
      SignalQuality q = CalculateQualityScore(idx, ORDER_TYPE_SELL, HTF_TREND_BEARISH, close[0], slPrice, riskDist, atr[0], tf, structInfo, regimeInfo);

      string triggerReason = StringFormat("S1 VWAP Rejection Bearish (VWAP: %.5f)\nEntry: %s (Risk: %.1f%%)", vwap, (isReEntry ? StringFormat("Re-Entry #%d", state.reEntriesCount + 1) : "Primary"), tradeRisk);

      ExecuteTradeSignal(idx, tf, ORDER_TYPE_SELL, close[0], slPrice, tp1, q, triggerReason, isReEntry, STRATEGY_VWAP_RECLAIM);

      state.lastSignalBar = currentBarTime;
      state.lastEntryPrice = close[0];
      if(!isReEntry) state.primaryDone = true;
      else state.reEntriesCount++;
      return;
   }
}

void EvaluateStrategy1_VWAPReclaim(int idx, ENUM_TIMEFRAMES tf) {
   if(!InpEnableStrategy1_VWAP) return;
   if(tf == PERIOD_M1) ProcessStrategy1_VWAP(idx, tf, m_scanners[idx].stateS1_M1);
   else                ProcessStrategy1_VWAP(idx, tf, m_scanners[idx].stateS1_M5);
}

//+------------------------------------------------------------------+
//| STRATEGY 2: MARKET STRUCTURE BREAKOUT + RETEST ENGINE             |
//+------------------------------------------------------------------+
void ProcessStrategy2_Structure(int idx, ENUM_TIMEFRAMES tf, Strategy2_Structure_State &state) {
   string sym = m_scanners[idx].resolvedSymbol;
   datetime currentBarTime = iTime(sym, tf, 1);

   if(currentBarTime == state.lastSignalBar && state.lastSignalBar > 0) return;
   if(InpEnableNewsFilter && IsNewsRiskActive(sym)) return;

   int hEMA200 = (tf == PERIOD_M1) ? m_scanners[idx].h_ema200_m1 : m_scanners[idx].h_ema200_m5;
   int hATR    = (tf == PERIOD_M1) ? m_scanners[idx].h_atr_m1 : m_scanners[idx].h_atr_m5;

   int lookback = InpStructureLookbackBars;
   double h[], l[], c[], o[], ema200[], atr[];
   ArraySetAsSeries(h, true); ArraySetAsSeries(l, true); ArraySetAsSeries(c, true); ArraySetAsSeries(o, true);
   ArraySetAsSeries(ema200, true); ArraySetAsSeries(atr, true);

   if(CopyHigh(sym, tf, 1, lookback, h) < lookback || CopyLow(sym, tf, 1, lookback, l) < lookback ||
      CopyClose(sym, tf, 1, lookback, c) < lookback || CopyOpen(sym, tf, 1, lookback, o) < lookback ||
      CopyBuffer(hEMA200, 0, 1, 6, ema200) <= 0 || CopyBuffer(hATR, 0, 1, 1, atr) <= 0) return;

   // 1. Discover Swing Highs and Lows (3-Bar Fractal)
   double swingHighs[], swingLows[];
   ArrayResize(swingHighs, 0); ArrayResize(swingLows, 0);
   int lr = InpSwingLookback;

   for(int i = lr; i < lookback - lr; i++) {
      bool isH = true, isL = true;
      for(int j = 1; j <= lr; j++) {
         if(h[i] <= h[i - j] || h[i] <= h[i + j]) isH = false;
         if(l[i] >= l[i - j] || l[i] >= l[i + j]) isL = false;
      }
      if(isH) { int sz = ArraySize(swingHighs); ArrayResize(swingHighs, sz + 1); swingHighs[sz] = h[i]; }
      if(isL) { int sz = ArraySize(swingLows);  ArrayResize(swingLows, sz + 1);  swingLows[sz]  = l[i]; }
   }

   if(ArraySize(swingHighs) == 0 || ArraySize(swingLows) == 0) return;
   double lastSwingHigh = swingHighs[0];
   double lastSwingLow  = swingLows[0];
   double pointVal = SymbolInfoDouble(sym, SYMBOL_POINT);

   // A. BULLISH STRUCTURE BREAKOUT & RETEST
   // Breakout bar occurred 1 to 5 bars ago
   bool breakoutBullFound = false;
   int breakBarIdx = -1;
   for(int b = 1; b < 6; b++) {
      if(c[b] > (lastSwingHigh + (atr[0] * InpBOSMinBreakATR))) {
         breakoutBullFound = true;
         breakBarIdx = b;
         break;
      }
   }

   if(breakoutBullFound && breakBarIdx >= 1) {
      // Check Retest into broken level (+/- tolerance)
      bool retested = false;
      for(int b = 0; b <= breakBarIdx; b++) {
         if(l[b] <= (lastSwingHigh + (atr[0] * InpRetestToleranceATR)) && l[b] >= (lastSwingHigh - (atr[0] * 0.50))) {
            retested = true;
            break;
         }
      }

      if(retested) {
         if(InpUseEMA200Filter && c[0] <= ema200[0]) return;
         if(InpUseH1TrendFilter) {
            ENUM_HTF_TREND h1Trend = DetermineH1Trend(idx);
            if(h1Trend != HTF_TREND_BULLISH && h1Trend != HTF_TREND_STRONG_BULLISH) return;
         }

         if(!IsBullishConfirmation(o, h, l, c, atr[0])) return;
         if(InpUseVolumeFilter && !CheckVolumeExpansion(sym, tf, 1)) return;


         bool isReEntry = state.primaryDone;
         if(isReEntry && (!InpEnableReEntry || state.reEntriesCount >= InpMaxReEntriesPerCycle)) return;

         double slPrice = (lastSwingHigh - (atr[0] * InpSLBufferATR)) - (InpSLEngulfingBufferPoints * pointVal);
         double riskDist = c[0] - slPrice;
         if(riskDist <= 0) return;
         double tp1 = c[0] + (riskDist * 2.0);

         double tradeRisk = isReEntry ? InpReEntryRiskPercent : InpRiskPercent;
         StructureEvaluation structInfo; ZeroMemory(structInfo);
         RegimeEvaluation regimeInfo; ZeroMemory(regimeInfo);
         SignalQuality q = CalculateQualityScore(idx, ORDER_TYPE_BUY, HTF_TREND_BULLISH, c[0], slPrice, riskDist, atr[0], tf, structInfo, regimeInfo);

         string triggerReason = StringFormat("S2 Structure BOS Retest Bullish (Level: %.5f)\nEntry: %s (Risk: %.1f%%)", lastSwingHigh, (isReEntry ? StringFormat("Re-Entry #%d", state.reEntriesCount + 1) : "Primary"), tradeRisk);

         ExecuteTradeSignal(idx, tf, ORDER_TYPE_BUY, c[0], slPrice, tp1, q, triggerReason, isReEntry, STRATEGY_BREAKOUT_RETEST);

         state.lastSignalBar = currentBarTime;
         state.lastEntryPrice = c[0];
         if(!isReEntry) state.primaryDone = true;
         else state.reEntriesCount++;
         return;
      }
   }

   // B. BEARISH STRUCTURE BREAKOUT & RETEST
   bool breakoutBearFound = false;
   int breakBearBarIdx = -1;
   for(int b = 1; b < 6; b++) {
      if(c[b] < (lastSwingLow - (atr[0] * InpBOSMinBreakATR))) {
         breakoutBearFound = true;
         breakBearBarIdx = b;
         break;
      }
   }

   if(breakoutBearFound && breakBearBarIdx >= 1) {
      bool retested = false;
      for(int b = 0; b <= breakBearBarIdx; b++) {
         if(h[b] >= (lastSwingLow - (atr[0] * InpRetestToleranceATR)) && h[b] <= (lastSwingLow + (atr[0] * 0.50))) {
            retested = true;
            break;
         }
      }

      if(retested) {
         if(InpUseEMA200Filter && c[0] >= ema200[0]) return;
         if(InpUseH1TrendFilter) {
            ENUM_HTF_TREND h1Trend = DetermineH1Trend(idx);
            if(h1Trend != HTF_TREND_BEARISH && h1Trend != HTF_TREND_STRONG_BEARISH) return;
         }

         if(!IsBearishConfirmation(o, h, l, c, atr[0])) return;
         if(InpUseVolumeFilter && !CheckVolumeExpansion(sym, tf, 1)) return;


         bool isReEntry = state.primaryDone;
         if(isReEntry && (!InpEnableReEntry || state.reEntriesCount >= InpMaxReEntriesPerCycle)) return;

         double slPrice = (lastSwingLow + (atr[0] * InpSLBufferATR)) + (InpSLEngulfingBufferPoints * pointVal);
         double riskDist = slPrice - c[0];
         if(riskDist <= 0) return;
         double tp1 = c[0] - (riskDist * 2.0);

         double tradeRisk = isReEntry ? InpReEntryRiskPercent : InpRiskPercent;
         StructureEvaluation structInfo; ZeroMemory(structInfo);
         RegimeEvaluation regimeInfo; ZeroMemory(regimeInfo);
         SignalQuality q = CalculateQualityScore(idx, ORDER_TYPE_SELL, HTF_TREND_BEARISH, c[0], slPrice, riskDist, atr[0], tf, structInfo, regimeInfo);

         string triggerReason = StringFormat("S2 Structure BOS Retest Bearish (Level: %.5f)\nEntry: %s (Risk: %.1f%%)", lastSwingLow, (isReEntry ? StringFormat("Re-Entry #%d", state.reEntriesCount + 1) : "Primary"), tradeRisk);

         ExecuteTradeSignal(idx, tf, ORDER_TYPE_SELL, c[0], slPrice, tp1, q, triggerReason, isReEntry, STRATEGY_BREAKOUT_RETEST);

         state.lastSignalBar = currentBarTime;
         state.lastEntryPrice = c[0];
         if(!isReEntry) state.primaryDone = true;
         else state.reEntriesCount++;
         return;
      }
   }
}

void EvaluateStrategy2_StructureRetest(int idx, ENUM_TIMEFRAMES tf) {
   if(!InpEnableStrategy2_Structure) return;
   if(tf == PERIOD_M1) ProcessStrategy2_Structure(idx, tf, m_scanners[idx].stateS2_M1);
   else                ProcessStrategy2_Structure(idx, tf, m_scanners[idx].stateS2_M5);
}

//+------------------------------------------------------------------+
//| STRATEGY 3: MOMENTUM EXPANSION + PULLBACK ENGINE                  |
//+------------------------------------------------------------------+
void ProcessStrategy3_Momentum(int idx, ENUM_TIMEFRAMES tf, Strategy3_Momentum_State &state) {
   string sym = m_scanners[idx].resolvedSymbol;
   datetime currentBarTime = iTime(sym, tf, 1);

   if(currentBarTime == state.lastSignalBar && state.lastSignalBar > 0) return;
   if(InpEnableNewsFilter && IsNewsRiskActive(sym)) return;

   int hEMA200 = (tf == PERIOD_M1) ? m_scanners[idx].h_ema200_m1 : m_scanners[idx].h_ema200_m5;
   int hATR    = (tf == PERIOD_M1) ? m_scanners[idx].h_atr_m1 : m_scanners[idx].h_atr_m5;

   double h[], l[], c[], o[], ema200[], atr[];
   ArraySetAsSeries(h, true); ArraySetAsSeries(l, true); ArraySetAsSeries(c, true); ArraySetAsSeries(o, true);
   ArraySetAsSeries(ema200, true); ArraySetAsSeries(atr, true);

   if(CopyHigh(sym, tf, 1, 8, h) < 8 || CopyLow(sym, tf, 1, 8, l) < 8 ||
      CopyClose(sym, tf, 1, 8, c) < 8 || CopyOpen(sym, tf, 1, 8, o) < 8 ||
      CopyBuffer(hEMA200, 0, 1, 6, ema200) <= 0 || CopyBuffer(hATR, 0, 1, 1, atr) <= 0) return;

   double pointVal = SymbolInfoDouble(sym, SYMBOL_POINT);

   // A. BULLISH MOMENTUM EXPANSION & PULLBACK
   // Look for expansion candle 1 to 4 bars ago
   bool expansionBullFound = false;
   int expBarIdx = -1;
   double expRange = 0.0;

   for(int b = 1; b <= InpMaxPullbackBars + 1; b++) {
      double rng = h[b] - l[b];
      double body = c[b] - o[b];
      if(rng >= (atr[0] * InpMomentumExpansionATR) && body >= (rng * 0.55) && c[b] > o[b]) {
         expansionBullFound = true;
         expBarIdx = b;
         expRange = rng;
         break;
      }
   }

   if(expansionBullFound && expBarIdx >= 1) {
      // Verify subsequent pullback bars remained controlled (above 50% retracement)
      bool pullbackControlled = true;
      double minPullbackLow = l[0];
      double maxAllowedRetracement = h[expBarIdx] - (expRange * (InpMaxPullbackDepthPct / 100.0));

      for(int b = 0; b < expBarIdx; b++) {
         if(l[b] < maxAllowedRetracement) {
            pullbackControlled = false;
            break;
         }
         if(l[b] < minPullbackLow) minPullbackLow = l[b];
      }

      if(pullbackControlled) {
         if(InpUseEMA200Filter && c[0] <= ema200[0]) return;
         if(InpUseH1TrendFilter) {
            ENUM_HTF_TREND h1Trend = DetermineH1Trend(idx);
            if(h1Trend != HTF_TREND_BULLISH && h1Trend != HTF_TREND_STRONG_BULLISH) return;
         }

         if(!IsBullishConfirmation(o, h, l, c, atr[0])) return;
         if(InpUseVolumeFilter && !CheckVolumeExpansion(sym, tf, 1)) return;


         bool isReEntry = state.primaryDone;
         if(isReEntry && (!InpEnableReEntry || state.reEntriesCount >= InpMaxReEntriesPerCycle)) return;

         double slPrice = minPullbackLow - (InpSLEngulfingBufferPoints * pointVal) - (atr[0] * InpSLBufferATR);
         double riskDist = c[0] - slPrice;
         if(riskDist <= 0) return;
         double tp1 = c[0] + (riskDist * 2.0);

         double tradeRisk = isReEntry ? InpReEntryRiskPercent : InpRiskPercent;
         StructureEvaluation structInfo; ZeroMemory(structInfo);
         RegimeEvaluation regimeInfo; ZeroMemory(regimeInfo);
         SignalQuality q = CalculateQualityScore(idx, ORDER_TYPE_BUY, HTF_TREND_BULLISH, c[0], slPrice, riskDist, atr[0], tf, structInfo, regimeInfo);

         string triggerReason = StringFormat("S3 Momentum Expansion Continuation Bullish (Exp: %.1fx ATR)\nEntry: %s (Risk: %.1f%%)", (expRange/atr[0]), (isReEntry ? StringFormat("Re-Entry #%d", state.reEntriesCount + 1) : "Primary"), tradeRisk);

         ExecuteTradeSignal(idx, tf, ORDER_TYPE_BUY, c[0], slPrice, tp1, q, triggerReason, isReEntry, STRATEGY_MOMENTUM_CONTINUATION);

         state.lastSignalBar = currentBarTime;
         state.lastEntryPrice = c[0];
         if(!isReEntry) state.primaryDone = true;
         else state.reEntriesCount++;
         return;
      }
   }

   // B. BEARISH MOMENTUM EXPANSION & PULLBACK
   bool expansionBearFound = false;
   int expBearBarIdx = -1;
   double expBearRange = 0.0;

   for(int b = 1; b <= InpMaxPullbackBars + 1; b++) {
      double rng = h[b] - l[b];
      double body = o[b] - c[b];
      if(rng >= (atr[0] * InpMomentumExpansionATR) && body >= (rng * 0.55) && c[b] < o[b]) {
         expansionBearFound = true;
         expBearBarIdx = b;
         expBearRange = rng;
         break;
      }
   }

   if(expansionBearFound && expBearBarIdx >= 1) {
      bool pullbackControlled = true;
      double maxPullbackHigh = h[0];
      double minAllowedRetracement = l[expBearBarIdx] + (expBearRange * (InpMaxPullbackDepthPct / 100.0));

      for(int b = 0; b < expBearBarIdx; b++) {
         if(h[b] > minAllowedRetracement) {
            pullbackControlled = false;
            break;
         }
         if(h[b] > maxPullbackHigh) maxPullbackHigh = h[b];
      }

      if(pullbackControlled) {
         if(InpUseEMA200Filter && c[0] >= ema200[0]) return;
         if(InpUseH1TrendFilter) {
            ENUM_HTF_TREND h1Trend = DetermineH1Trend(idx);
            if(h1Trend != HTF_TREND_BEARISH && h1Trend != HTF_TREND_STRONG_BEARISH) return;
         }

         if(!IsBearishConfirmation(o, h, l, c, atr[0])) return;
         if(InpUseVolumeFilter && !CheckVolumeExpansion(sym, tf, 1)) return;


         bool isReEntry = state.primaryDone;
         if(isReEntry && (!InpEnableReEntry || state.reEntriesCount >= InpMaxReEntriesPerCycle)) return;

         double slPrice = maxPullbackHigh + (InpSLEngulfingBufferPoints * pointVal) + (atr[0] * InpSLBufferATR);
         double riskDist = slPrice - c[0];
         if(riskDist <= 0) return;
         double tp1 = c[0] - (riskDist * 2.0);

         double tradeRisk = isReEntry ? InpReEntryRiskPercent : InpRiskPercent;
         StructureEvaluation structInfo; ZeroMemory(structInfo);
         RegimeEvaluation regimeInfo; ZeroMemory(regimeInfo);
         SignalQuality q = CalculateQualityScore(idx, ORDER_TYPE_SELL, HTF_TREND_BEARISH, c[0], slPrice, riskDist, atr[0], tf, structInfo, regimeInfo);

         string triggerReason = StringFormat("S3 Momentum Expansion Continuation Bearish (Exp: %.1fx ATR)\nEntry: %s (Risk: %.1f%%)", (expBearRange/atr[0]), (isReEntry ? StringFormat("Re-Entry #%d", state.reEntriesCount + 1) : "Primary"), tradeRisk);

         ExecuteTradeSignal(idx, tf, ORDER_TYPE_SELL, c[0], slPrice, tp1, q, triggerReason, isReEntry, STRATEGY_MOMENTUM_CONTINUATION);

         state.lastSignalBar = currentBarTime;
         state.lastEntryPrice = c[0];
         if(!isReEntry) state.primaryDone = true;
         else state.reEntriesCount++;
         return;
      }
   }
}

void EvaluateStrategy3_MomentumContinuation(int idx, ENUM_TIMEFRAMES tf) {
   if(!InpEnableStrategy3_Momentum) return;
   if(tf == PERIOD_M1) ProcessStrategy3_Momentum(idx, tf, m_scanners[idx].stateS3_M1);
   else                ProcessStrategy3_Momentum(idx, tf, m_scanners[idx].stateS3_M5);
}

// Master Evaluation Function for Symbol
void EvaluateStrategiesForSymbol(int idx, ENUM_TIMEFRAMES tf) {
   EvaluateStrategy1_VWAPReclaim(idx, tf);
   EvaluateStrategy2_StructureRetest(idx, tf);
   EvaluateStrategy3_MomentumContinuation(idx, tf);
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
   else if(q.totalScore >= 70) q.ratingLabel = "Weak";
   else q.ratingLabel = "Reject";

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

void ExecuteTradeSignal(int idx, ENUM_TIMEFRAMES tf, int type, double entry, double sl, double tp1, const SignalQuality &quality, string triggerReason, bool isReEntry, ENUM_STRATEGY_TYPE stratType = STRATEGY_VWAP_RECLAIM) {
   string sym = m_scanners[idx].resolvedSymbol;
   int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);

   double riskDist = MathAbs(entry - sl);
   if(!MathIsValidNumber(riskDist) || riskDist <= 0) return;

   // 0. Global Portfolio Exposure & Risk Checks
   double totalRisk = CalculateTotalOpenRiskPercent();
   double newTradeRisk = isReEntry ? InpReEntryRiskPercent : InpRiskPercent;
   if(totalRisk + newTradeRisk > InpMaxTotalOpenRiskPercent) {
      PrintFormat("⛔ [PORTFOLIO RISK GUARD] %s | Trade Blocked: Total Open Risk (%.1f%% + %.1f%%) exceeds Max Cap (%.1f%%)", sym, totalRisk, newTradeRisk, InpMaxTotalOpenRiskPercent);
      return;
   }

   if(CountOpenPositionsForSymbol(sym) >= InpMaxOpenPositionsPerSymbol) {
      PrintFormat("⛔ [SYMBOL POSITION GUARD] %s | Max Open Positions for Symbol reached (%d)", sym, InpMaxOpenPositionsPerSymbol);
      return;
   }

   int activePositions = 0;
   for(int k = 0; k < ArraySize(m_activeTrades); k++) {
      if(m_activeTrades[k].status == STATUS_ACTIVE || m_activeTrades[k].status == STATUS_PARTIAL_CLOSED) activePositions++;
   }
   if(activePositions >= InpMaxTotalOpenPositions || (InpAutoTradingEnabled && PositionsTotal() >= InpMaxTotalOpenPositions)) {
      PrintFormat("⛔ [TOTAL POSITION GUARD] Max Open Positions reached (%d)", InpMaxTotalOpenPositions);
      return;
   }

   double lot = CalculateRiskLotSize(sym, riskDist, isReEntry);
   string strategyName = "VWAP Reclaim";
   if(stratType == STRATEGY_BREAKOUT_RETEST) strategyName = "Structure BOS Retest";
   else if(stratType == STRATEGY_MOMENTUM_CONTINUATION) strategyName = "Momentum Continuation";

   string id = StringFormat("%s_%s_%d", sym, (tf == PERIOD_M1 ? "M1" : "M5"), TimeCurrent());

   VirtualTrade vt;
   ZeroMemory(vt);
   vt.id = id;
   vt.symbol = sym;
   vt.strategy = stratType;
   vt.executionTF = tf;
   vt.type = type;
   vt.isReEntry = isReEntry;
   vt.initialLot = lot;
   vt.currentLot = lot;
   vt.entry = NormalizeDouble(entry, digits);
   vt.sl = NormalizeDouble(sl, digits);
   vt.tp1 = NormalizeDouble(tp1, digits);
   vt.riskDistance = riskDist;
   vt.currentRR = 0.0;
   vt.maxRR = 0.0;
   vt.qualityScore = quality.totalScore;
   vt.qualityLabel = quality.ratingLabel;
   vt.triggerReason = triggerReason;
   AnalyzeMarketStructure(sym, vt.structure);
   vt.openTime = TimeCurrent();
   vt.status = STATUS_ACTIVE;
   vt.reachedTP1 = false;
   vt.reachedBE = false;
   vt.isRunner = false;
   vt.tp1RealizedProfit = 0.0;
   vt.tp1RealizedR = 0.0;
   vt.brokerTicket = 0;

   // 1. Live Automated Execution (No Fixed TP2!)
   if(InpAutoTradingEnabled) {
      ResetLastError();
      bool success = false;
      if(type == ORDER_TYPE_BUY) {
         success = m_trade.Buy(lot, sym, vt.entry, vt.sl, 0.0, strategyName);
      } else {
         success = m_trade.Sell(lot, sym, vt.entry, vt.sl, 0.0, strategyName);
      }

      if(success) {
         vt.brokerTicket = m_trade.ResultOrder();
         Print("[TRADE EXECUTION] Order placed successfully on ", sym, " Ticket: ", vt.brokerTicket, " (ReEntry: ", isReEntry, ")");
      } else {
         Print("[TRADE ERROR] Order failed on ", sym, " Error: ", GetLastError());
      }
   }

   // 2. Track Trade State if Valid
   if(IsValidTradeData(vt)) {
      int vSize = ArraySize(m_activeTrades);
      ArrayResize(m_activeTrades, vSize + 1);
      m_activeTrades[vSize] = vt;
      m_isStateChanged = true;
   }

   // 3. Send Dedicated Telegram Intelligence Alert & Chart Image
   SendSignalTelegramAlert(vt, quality, idx);

   // 4. Draw Chart Objects on Main Workspace (Only if enabled)
   if(InpDrawChartObjects) DrawSignalChartObjects(vt);
}

//====================================================================
// SECTION 13: BACKEND POSITION & PURE TREND RUNNER ENGINE
//====================================================================

void ManageActiveTrades(datetime currentTime) {
   for(int i = ArraySize(m_activeTrades) - 1; i >= 0; i--) {
      if(!IsValidTradeData(m_activeTrades[i])) {
         int aSize = ArraySize(m_activeTrades);
         for(int k = i; k < aSize - 1; k++) m_activeTrades[k] = m_activeTrades[k + 1];
         ArrayResize(m_activeTrades, aSize - 1);
         m_isStateChanged = true;
         continue;
      }

      string sym = m_activeTrades[i].symbol;
      int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);

      double bid = SymbolInfoDouble(sym, SYMBOL_BID);
      double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
      bool isBuy = (m_activeTrades[i].type == ORDER_TYPE_BUY);
      double currentPrice = isBuy ? bid : ask;

      double currentRiskPips = m_activeTrades[i].riskDistance;
      if(currentRiskPips <= 0 || !MathIsValidNumber(currentRiskPips)) continue;

      double floatingPips = isBuy ? (currentPrice - m_activeTrades[i].entry) : (m_activeTrades[i].entry - currentPrice);
      double rr = floatingPips / currentRiskPips;
      if(!MathIsValidNumber(rr) || MathAbs(rr) > 1000.0) rr = 0.0;

      m_activeTrades[i].currentRR = rr;
      if(rr > m_activeTrades[i].maxRR) m_activeTrades[i].maxRR = rr;

      bool isClosed = false;
      double exitPrice = currentPrice;
      string exitReason = "";

      // A. TP1 (2R) REACHED -> BOOK 50% PARTIAL & ENTER UNLIMITED TREND RUNNER MODE
      if(!m_activeTrades[i].reachedTP1 && rr >= 2.0) {
         m_activeTrades[i].reachedTP1 = true;
         m_activeTrades[i].reachedBE  = true;
         m_activeTrades[i].isRunner   = true;

         double point = SymbolInfoDouble(sym, SYMBOL_POINT);
         double bePrice = isBuy ? (m_activeTrades[i].entry + (InpBEOffsetPips * point * 10)) : (m_activeTrades[i].entry - (InpBEOffsetPips * point * 10));
         m_activeTrades[i].sl = NormalizeDouble(bePrice, digits);
         m_isStateChanged = true;

         double initialLot = m_activeTrades[i].initialLot;
         double closeVolume = NormalizeDouble(initialLot * (InpPartialClosePercent / 100.0), 2);
         double minVol = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
         if(closeVolume < minVol) closeVolume = minVol;

         if(InpAutoTradingEnabled && m_activeTrades[i].brokerTicket > 0) {
            if(PositionSelectByTicket(m_activeTrades[i].brokerTicket)) {
               double posVolume = PositionGetDouble(POSITION_VOLUME);
               if(posVolume > closeVolume) {
                  m_trade.PositionClosePartial(m_activeTrades[i].brokerTicket, closeVolume);
               }
               m_trade.PositionModify(m_activeTrades[i].brokerTicket, m_activeTrades[i].sl, 0.0);
            }
         }

         m_activeTrades[i].currentLot = NormalizeDouble(initialLot - closeVolume, 2);

         double tickValue = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
         double tickSize  = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
         double slTicks   = (tickSize > 0) ? (m_activeTrades[i].riskDistance / tickSize) : 0;
         double initialRiskMoney = (tickValue > 0 && slTicks > 0) ? (initialLot * slTicks * tickValue) : 25.0;

         m_activeTrades[i].tp1RealizedProfit = initialRiskMoney * 1.0; // 50% * 2R = 100% initial risk money
         m_activeTrades[i].tp1RealizedR      = (closeVolume / initialLot) * 2.0; // ~ +1.0R

         SendTradeUpdateAlert("🎯 <b>TP1 (2R) REACHED</b>", m_activeTrades[i], 2.0);
         if(InpDrawChartObjects) UpdateChartSLObject(m_activeTrades[i]);
      }

      // B. STOP LOSS / BREAK EVEN HIT
      if(!isClosed) {
         bool slHit = isBuy ? (currentPrice <= m_activeTrades[i].sl) : (currentPrice >= m_activeTrades[i].sl);
         if(slHit) {
            exitPrice = m_activeTrades[i].sl;
            isClosed = true;
            exitReason = m_activeTrades[i].reachedBE ? "Break Even Hit" : "Stop Loss Hit";

            m_activeTrades[i].status = m_activeTrades[i].reachedBE ? STATUS_BE : STATUS_LOST;

            if(InpAutoTradingEnabled && m_activeTrades[i].brokerTicket > 0) {
               if(PositionSelectByTicket(m_activeTrades[i].brokerTicket)) {
                  m_trade.PositionClose(m_activeTrades[i].brokerTicket);
               }
            }
         }
      }

      // C. ARCHIVE CLOSED TRADES
      if(isClosed) {
         if(InpDrawChartObjects) RemoveSignalChartObjects(m_activeTrades[i]);
         ArchiveTrade(i, exitPrice, exitReason);
         m_isStateChanged = true;
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

         m_activeTrades[i].status = STATUS_WON;
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
   VirtualTrade vt = m_activeTrades[index];

   double riskDist = vt.riskDistance;
   bool isBuy = (vt.type == ORDER_TYPE_BUY);
   double runnerPips = isBuy ? (exitPrice - vt.entry) : (vt.entry - exitPrice);
   double runnerR = (riskDist > 0) ? (runnerPips / riskDist) : 0.0;
   if(!MathIsValidNumber(runnerR)) runnerR = 0.0;

   double tickValue = SymbolInfoDouble(vt.symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(vt.symbol, SYMBOL_TRADE_TICK_SIZE);
   double slTicks   = (tickSize > 0) ? (riskDist / tickSize) : 0;
   double initialRiskMoney = (tickValue > 0 && slTicks > 0) ? (vt.initialLot * slTicks * tickValue) : 25.0;

   double runnerLotRatio = (vt.initialLot > 0) ? (vt.currentLot / vt.initialLot) : 0.5;
   double runnerRealizedR = runnerLotRatio * runnerR;
   double runnerRealizedProfit = initialRiskMoney * runnerRealizedR;

   double combinedRealizedR = vt.tp1RealizedR + runnerRealizedR;
   double combinedRealizedProfit = vt.tp1RealizedProfit + runnerRealizedProfit;

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
   ht.resultRR = combinedRealizedR;
   ht.resultProfit = combinedRealizedProfit;
   ht.maxRR = vt.maxRR;
   ht.qualityScore = vt.qualityScore;
   ht.qualityLabel = vt.qualityLabel;
   ht.openTime = vt.openTime;
   ht.closeTime = TimeCurrent();
   ht.status = vt.status;
   ht.exitReason = exitReason;

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

string GetCleanTelegramChatID() {
   string chatId = InpTelegramChatID;
   StringTrimLeft(chatId);
   StringTrimRight(chatId);
   if(chatId == "") return "";
   if(StringFind(chatId, "100") == 0 && StringFind(chatId, "-") < 0) {
      chatId = "-" + chatId;
   }
   return chatId;
}

bool SendTelegramMessage(string message) {
   string cleanChatID = GetCleanTelegramChatID();
   if(!InpEnableTelegram || InpTelegramBotToken == "" || cleanChatID == "") return false;

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
   string payload = StringFormat("{\"chat_id\":\"%s\",\"text\":\"%s\",\"parse_mode\":\"HTML\"}", cleanChatID, SanitizeJson(message));

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

void SendSignalTelegramAlert(const VirtualTrade &vt, const SignalQuality &quality, int idx) {
   if(!InpEnableTelegram) return;

   string headerEmoji = (vt.type == ORDER_TYPE_BUY) ? "🟢" : "🔴";
   string dirStr      = (vt.type == ORDER_TYPE_BUY) ? "BUY" : "SELL";
   int digits         = (int)SymbolInfoInteger(vt.symbol, SYMBOL_DIGITS);

   datetime ukTime = GetUKTime(TimeCurrent());
   MqlDateTime dtNow; TimeToStruct(ukTime, dtNow);
   string entryTimeStr = StringFormat("%02d:%02d UK", dtNow.hour, dtNow.min);

   string tfLabel = (vt.executionTF == PERIOD_M1) ? "M1" : "M5";
   string stratName = "Session VWAP Reclaim";
   if(vt.strategy == STRATEGY_BREAKOUT_RETEST) stratName = "Market Structure BOS Retest";
   else if(vt.strategy == STRATEGY_MOMENTUM_CONTINUATION) stratName = "Momentum Expansion Continuation";

   string h1Str = InpUseH1TrendFilter ? "ON" : "OFF";
   string newsStr = InpEnableNewsFilter ? (IsNewsRiskActive(vt.symbol) ? "PAUSED (News Event)" : "PASS") : "OFF";
   double tradeRisk = vt.isReEntry ? InpReEntryRiskPercent : InpRiskPercent;

   string msg = StringFormat(
      "━━━━━━━━━━━━━━━━━━\n"
      "%s <b>MULTI-STRATEGY SIGNAL | %s</b>\n"
      "━━━━━━━━━━━━━━━━━━\n\n"
      "<b>Symbol:</b> %s\n"
      "<b>TF:</b> %s\n\n"
      "<b>Strategy:</b> %s\n"
      "<b>Direction:</b> <b>%s</b>\n"
      "<b>Entry Type:</b> %s\n\n"
      "💰 <b>Entry:</b> <code>%s</code>\n"
      "🛑 <b>SL:</b> <code>%s</code>\n"
      "🎯 <b>TP1:</b> <code>%s</code> (2R -> 50%%)\n"
      "🏃 <b>Runner:</b> TRAILING (3.5R+)\n\n"
      "⚖️ <b>Risk:</b> %.1f%% | <b>Lots:</b> <code>%.2f</code>\n"
      "🛡️ <b>H1 Filter:</b> %s | <b>News:</b> %s\n"
      "⏰ <b>Time:</b> %s\n"
      "━━━━━━━━━━━━━━━━━━",
      headerEmoji, dirStr,
      vt.symbol, tfLabel,
      stratName, dirStr,
      (vt.isReEntry ? "RE-ENTRY (0.5% Risk)" : "PRIMARY (1.0% Risk)"),
      DoubleToString(vt.entry, digits),
      DoubleToString(vt.sl, digits),
      DoubleToString(vt.tp1, digits),
      tradeRisk, vt.initialLot,
      h1Str, newsStr,
      entryTimeStr
   );

   SendTelegramMessage(msg);

   if(InpSendSignalChart) {
      CaptureAndSendChartScreenshot(vt, stratName);
   }
}

void SendIndividualTradeClosedAlert(const HistoricalTrade &ht) {
   if(!InpEnableTelegram) return;

   int digits = (int)SymbolInfoInteger(ht.symbol, SYMBOL_DIGITS);
   string dirStr = (ht.type == ORDER_TYPE_BUY) ? "BUY" : "SELL";
   string labelStr = ht.isReEntry ? "RE-ENTRY CLOSED" : "TRADE CLOSED";

   datetime openUK = GetUKTime(ht.openTime);
   datetime closeUK = GetUKTime(ht.closeTime);
   MqlDateTime dtOpen, dtClose;
   TimeToStruct(openUK, dtOpen); TimeToStruct(closeUK, dtClose);

   string openTimeStr = StringFormat("%02d:%02d UK", dtOpen.hour, dtOpen.min);
   string closeTimeStr = StringFormat("%02d:%02d UK", dtClose.hour, dtClose.min);

   string pnlStr = (ht.resultProfit >= 0) ? StringFormat("+$%.2f", ht.resultProfit) : StringFormat("-$%.2f", MathAbs(ht.resultProfit));
   string rStr   = (ht.resultRR >= 0) ? StringFormat("+%.2fR", ht.resultRR) : StringFormat("%.2fR", ht.resultRR);

   string msg = StringFormat(
      "🔴 <b>%s — %s %s</b> | <b>Lots: %.2f</b>\n\n"
      "<b>Reason:</b> %s\n"
      "<b>Entry:</b> <code>%s</code>\n"
      "<b>Final Exit:</b> <code>%s</code>\n\n"
      "<b>Entry Time:</b> %s\n"
      "<b>Exit Time:</b> %s\n\n"
      "<b>Realised P/L:</b> %s\n"
      "<b>Total Realised R:</b> %s\n\n"
      "<b>Status:</b> CLOSED",
      labelStr, ht.symbol, dirStr, ht.initialLot,
      ht.exitReason,
      DoubleToString(ht.entry, digits),
      DoubleToString(ht.exitPrice, digits),
      openTimeStr, closeTimeStr,
      pnlStr, rStr
   );

   SendTelegramMessage(msg);
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

bool CaptureAndSendChartScreenshot(const VirtualTrade &vt, string strategyName) {
   string cleanChatID = GetCleanTelegramChatID();
   if(!InpSendSignalChart || InpTelegramBotToken == "" || cleanChatID == "") return false;

   string filename = "MSS_Signal_" + vt.symbol + ".png";
   string mimeType = "image/png";

   // 1. Capture Native HD MT5 Chart Screenshot (.png)
   bool captured = false;
   long targetChartID = 0;
   long chartID = ChartFirst();
   while(chartID >= 0) {
      if(ChartSymbol(chartID) == vt.symbol) {
         targetChartID = chartID;
         break;
      }
      chartID = ChartNext(chartID);
   }

   if(targetChartID > 0) {
      captured = ChartScreenShot(targetChartID, filename, InpScreenshotWidth, InpScreenshotHeight, ALIGN_RIGHT);
   } else {
      captured = ChartScreenShot(0, filename, InpScreenshotWidth, InpScreenshotHeight, ALIGN_RIGHT);
   }

   // 2. Fallback to Canvas Image (.bmp) if ChartScreenShot fails
   if(!captured) {
      filename = "MSS_Signal_" + vt.symbol + ".bmp";
      mimeType = "image/bmp";
      captured = GenerateCanvasChartImage(vt, filename, InpScreenshotWidth, InpScreenshotHeight);
   }

   if(!captured) {
      Print("[CHART IMAGE WARN] Chart screenshot capture failed for ", vt.symbol);
      return false;
   }

   // 3. Open File & Read Binary Bytes
   int fileHandle = FileOpen(filename, FILE_READ | FILE_BIN);
   if(fileHandle == INVALID_HANDLE) {
      Print("[CHART IMAGE ERROR] FileOpen failed for screenshot image: ", filename);
      return false;
   }

   int fileSize = (int)FileSize(fileHandle);
   if(fileSize <= 0) {
      Print("[CHART IMAGE ERROR] Screenshot image file size is 0 bytes for ", filename);
      FileClose(fileHandle);
      return false;
   }

   char photoBytes[];
   ArrayResize(photoBytes, fileSize);
   FileReadArray(fileHandle, photoBytes);
   FileClose(fileHandle);

   // 4. Short Caption (< 100 chars)
   string tfLabel = (vt.executionTF == PERIOD_M1) ? "M1" : "M5";
   string dirStr  = (vt.type == ORDER_TYPE_BUY) ? "BUY" : "SELL";
   string shortCaption = StringFormat("📊 <b>%s %s %s Execution Chart</b>\nStrategy: %s | Score: %d/100",
      vt.symbol, dirStr, tfLabel, strategyName, vt.qualityScore);

   // 5. Send Photo to Telegram via sendPhoto WebRequest
   string boundary = "----WebKitFormBoundaryMSSV1Engine7MA4YW";
   string url = "https://api.telegram.org/bot" + InpTelegramBotToken + "/sendPhoto";
   string headers = "Content-Type: multipart/form-data; boundary=" + boundary + "\r\n";

   char body[];
   ArrayResize(body, 0);

   AddMultipartFormField(body, boundary, "chat_id", cleanChatID);
   AddMultipartFormField(body, boundary, "parse_mode", "HTML");
   AddMultipartFormField(body, boundary, "caption", shortCaption);
   AddMultipartFileField(body, boundary, "photo", filename, mimeType, photoBytes);

   string endBoundary = "--" + boundary + "--\r\n";
   char endBytes[]; StringToCharArray(endBoundary, endBytes, 0, WHOLE_ARRAY, CP_UTF8);
   int eSize = ArraySize(endBytes); if(eSize > 0 && endBytes[eSize-1] == 0) ArrayResize(endBytes, eSize-1);
   int curSize = ArraySize(body);
   ArrayResize(body, curSize + eSize);
   ArrayCopy(body, endBytes, curSize, 0, eSize);

   char result[]; string resultHeaders;
   ResetLastError();
   int res = WebRequest("POST", url, headers, 8000, body, result, resultHeaders);

   if(res == 200) {
      Print("[CHART IMAGE SUCCESS] HD Chart Screenshot (", fileSize, " bytes) uploaded to Telegram for ", vt.symbol);
      return true;
   } else {
      Print("[CHART IMAGE ERROR] Telegram sendPhoto WebRequest returned HTTP ", res, " | Error: ", GetLastError());
      return false;
   }
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

void SendTradeUpdateAlert(string title, const VirtualTrade &vt, double currentRR) {
   if(!InpEnableTelegram) return;
   string emoji = GetSymbolEmoji(vt.symbol);
   int digits = (int)SymbolInfoInteger(vt.symbol, SYMBOL_DIGITS);

   double tickValue = SymbolInfoDouble(vt.symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(vt.symbol, SYMBOL_TRADE_TICK_SIZE);
   double slTicks   = (tickSize > 0) ? (vt.riskDistance / tickSize) : 0;
   double riskMoney = (tickValue > 0) ? (vt.initialLot * slTicks * tickValue) : 25.0;
   if(!MathIsValidNumber(riskMoney) || riskMoney <= 0) riskMoney = 25.0;

   double profitMoney = riskMoney * currentRR;
   if(!MathIsValidNumber(profitMoney)) profitMoney = 0.0;

   string pnlStr = (currentRR >= 0) ? StringFormat("+$%.2f (+%.1fR)", profitMoney, currentRR) : StringFormat("-$%.2f (%.1fR)", MathAbs(profitMoney), currentRR);
   string tfLabel = (vt.executionTF == PERIOD_M1) ? "M1" : "M5";

   string msg = StringFormat(
      "%s\n\n"
      "💰 <b>50%% BOOKED & RUNNER ACTIVE</b>\n\n"
      "%s <b>%s</b> (%s %s)\n"
      "• <b>Entry:</b> <code>%s</code> | <b>Current SL:</b> <code>%s</code>\n"
      "• <b>P/L Outcome:</b> %s\n"
      "• <b>Quality Score:</b> %s (%d/100)",
      title, emoji, vt.symbol, (vt.type==ORDER_TYPE_BUY?"BUY":"SELL"), tfLabel,
      DoubleToString(vt.entry, digits), DoubleToString(vt.sl, digits),
      pnlStr,
      vt.qualityLabel, vt.qualityScore
   );
   SendTelegramMessage(msg);
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
      double tp = PositionGetDouble(POSITION_TP);
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
      string tpStr = (tp > 0 && MathIsValidNumber(tp)) ? DoubleToString(tp, digits) : "UNLIMITED";
      string rStr  = (riskMoney > 0) ? StringFormat("%s%.2fR", (rr>=0?"+":""), rr) : "N/A";

      msg += StringFormat(
         "%s <b>%s %s</b>\n"
         "• Lots: <code>%.2f</code> | Ticket: #%I64u\n"
         "• Entry: <code>%s</code> | Current: <code>%s</code>\n"
         "• SL: <code>%s</code> | TP: <code>%s</code>\n"
         "• Floating: %s$%.2f | R: %s\n"
         "• Status: RUNNING\n\n",
         (isBuy ? "🟢" : "🔴"), sym, (isBuy ? "BUY" : "SELL"), vol, ticket,
         DoubleToString(openPrice, digits), DoubleToString(currentPrice, digits),
         slStr, tpStr,
         (profit>=0?"+":"-"), MathAbs(profit), rStr
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

   if(HistorySelect(today07UK, currentTime)) {
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
   }

   for(int i = 0; i < ArraySize(m_historyTrades); i++) {
      datetime tradeUKClose = GetUKTime(m_historyTrades[i].closeTime);
      if(tradeUKClose >= today07UK) {
         double rr = m_historyTrades[i].resultRR;
         if(MathIsValidNumber(rr)) totalNetR += rr;
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

void SendHourlyAnalysisReport() {
   datetime ukTime = GetUKTime(TimeCurrent());
   MqlDateTime dtNow; TimeToStruct(ukTime, dtNow);
   string timeStr = StringFormat("%02d:00 UK", dtNow.hour);

   string msg = StringFormat(
      "⏱️ <b>1H MARKET REPORT</b> | <b>Time: %s</b>\n\n"
      "<b>MARKET BIAS & STRUCTURE</b>\n\n",
      timeStr
   );

   for(int i = 0; i < m_totalSymbols; i++) {
      string sym = m_scanners[i].resolvedSymbol;
      string emoji = GetSymbolEmoji(sym);
      double bid = SymbolInfoDouble(sym, SYMBOL_BID);
      int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);

      MarketStructure ms; AnalyzeMarketStructure(sym, ms);
      KeyLevels kl; CalculateKeyLevels(sym, i, kl);
      ENUM_MARKET_REGIME regime = DetermineMarketRegime(sym, i);
      ENUM_HTF_TREND h1Trend = DetermineH1Trend(i);

      string contextLine = "";
      if(h1Trend == HTF_TREND_STRONG_BULLISH || h1Trend == HTF_TREND_BULLISH) {
         if(bid <= kl.ema21 + (bid * 0.001)) {
            contextLine = "Holding above H1 structure; pulling back to EMA21 value zone for continuation.";
         } else if(bid >= kl.r1 - (bid * 0.001)) {
            contextLine = "Buyers in control; currently testing key intraday resistance.";
         } else {
            contextLine = "Bullish momentum active; price holding firmly above intraday support.";
         }
      } else if(h1Trend == HTF_TREND_STRONG_BEARISH || h1Trend == HTF_TREND_BEARISH) {
         if(bid >= kl.ema21 - (bid * 0.001)) {
            contextLine = "Holding below H1 structure; pulling back to EMA21 resistance zone.";
         } else if(bid <= kl.s1 + (bid * 0.001)) {
            contextLine = "Sellers in control; currently testing key intraday support.";
         } else {
            contextLine = "Bearish momentum active; price holding firmly below intraday resistance.";
         }
      } else {
         contextLine = "Consolidating in neutral range between key EMAs; awaiting directional expansion.";
      }

      msg += StringFormat(
         "%s <b>%s</b>: %s @ <code>%s</code>\n"
         "• M5 Structure: %s\n"
         "• H1 Structure: %s\n"
         "• Support / Resistance: <code>%s</code> / <code>%s</code>\n"
         "• Market Condition: %s\n"
         "• Context: %s\n\n",
         emoji, sym, ms.h1Bias, DoubleToString(bid, digits),
         ms.m5Pattern, ms.h1Pattern,
         DoubleToString(kl.s1, digits), DoubleToString(kl.r1, digits),
         MarketRegimeToString(regime),
         contextLine
      );
   }

   msg += GetNewsStatusBlock() + "\n\n";
   msg += GetLiveTradesReportBlock();
   msg += GetTodaysSummaryBlock();

   SendTelegramMessage(msg);
}

void SendDayOpeningReport() {
   datetime ukTime = GetUKTime(TimeCurrent());
   MqlDateTime dtNow; TimeToStruct(ukTime, dtNow);
   string dateStr = StringFormat("%04d-%02d-%02d", dtNow.year, dtNow.mon, dtNow.day);

   string msg = StringFormat(
      "🌅 <b>MARKET OPENING REPORT</b> | <b>Date: %s</b>\n\n"
      "Session Context: London Open (%02d:00 UK)\n"
      "Fear & Greed: %s (%d/100)\n\n"
      "📅 <b>MARKET BIAS & STRUCTURE</b>\n\n",
      dateStr, InpDayOpenHour, m_fearGreedLabel, m_fearGreedScore
   );

   for(int i = 0; i < m_totalSymbols; i++) {
      string sym = m_scanners[i].resolvedSymbol;
      string emoji = GetSymbolEmoji(sym);
      double bid = SymbolInfoDouble(sym, SYMBOL_BID);
      int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);

      MultiTimeframeAnalysis mtf; GetMultiTimeframeAnalysis(sym, i, mtf);
      MarketStructure ms; AnalyzeMarketStructure(sym, ms);
      KeyLevels kl; CalculateKeyLevels(sym, i, kl);

      string biasIcon = (mtf.dailyBias == BIAS_BULLISH) ? "Bullish 🟢" : ((mtf.dailyBias == BIAS_BEARISH) ? "Bearish 🔴" : "Neutral 🟡");

      msg += StringFormat(
         "%s <b>%s</b>: %s @ <code>%s</code>\n"
         "• M5: %s | H1: %s\n"
         "• Support: <code>%s</code> | Resistance: <code>%s</code>\n\n",
         emoji, sym, biasIcon, DoubleToString(bid, digits),
         ms.m5Pattern, ms.h1Pattern,
         DoubleToString(kl.s1, digits), DoubleToString(kl.r1, digits)
      );
   }

   msg += GetNewsStatusBlock() + "\n\n";
   msg += GetLiveTradesReportBlock();
   msg += GetTodaysSummaryBlock();

   SendTelegramMessage(msg);
}

void SendDayClosingReport() {
   datetime ukTime = GetUKTime(TimeCurrent());
   MqlDateTime dtNow; TimeToStruct(ukTime, dtNow);
   string dateStr = StringFormat("%04d-%02d-%02d", dtNow.year, dtNow.mon, dtNow.day);

   string msg = StringFormat(
      "🌙 <b>MARKET CLOSING REPORT</b> | <b>Date: %s</b>\n\n",
      dateStr
   );

   msg += GetTodaysSummaryBlock() + "\n\n"
          "🧠 <b>SESSION SUMMARY</b>\n"
          "• Market Session Closed & Journal Persisted";

   msg += GetLiveTradesReportBlock();

   SendTelegramMessage(msg);
}

//====================================================================
// SECTION 18: PERSISTENCE ENGINE (FILE_COMMON in EMA_PRO_V2\)
//====================================================================

void SaveState(bool isShutdown) {
   string folder = "MultiStrategyScannerV1\\";

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

   if(isShutdown) Print("[PERSISTENCE] EA State & Report Guards safely written to FILE_COMMON/MultiStrategyScannerV1/");
}

void LoadState() {
   string folder = "MultiStrategyScannerV1\\";

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
   dash += " MULTI STRATEGY SCANNER V1\n";
   dash += "========================================\n";
   dash += "Session Status : " + (isSessionActive ? "ACTIVE (Scanning) 🟢" : "INACTIVE (Outside Session) 🔴") + "\n";
   dash += "UK Time        : " + TimeToString(ukTime, TIME_MINUTES|TIME_SECONDS) + "\n";
   dash += "Strategies     : S1:VWAP | S2:Structure | S3:Momentum\n";
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
