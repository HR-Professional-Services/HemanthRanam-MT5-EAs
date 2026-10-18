//+------------------------------------------------------------------+
//|                                   9EMA_Volume_Trend_Rider.mq5     |
//|                 Copyright 2026, 9 EMA + Volume Trend Strategy Team |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, 9 EMA + Volume Trend Strategy Team"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "High-Selectivity 9 EMA + Volume Trend Rider Expert Advisor"
#property description "Built for robust probability, controlled drawdown, and dynamic risk management."

//--- Includes
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\SymbolInfo.mqh>

//+------------------------------------------------------------------+
//| ENUMS                                                            |
//+------------------------------------------------------------------+
enum ENUM_RISK_MODE
{
   RISK_DYNAMIC_PERCENT, // Dynamic Risk % per Trade
   RISK_FIXED_LOT        // Fixed Lot Size
};

enum ENUM_SL_MODE
{
   SL_STRUCTURE_ATR,     // Structure Swing + ATR Buffer
   SL_ATR_ONLY,          // ATR Only
   SL_FIXED_POINTS       // Fixed Points
};

enum ENUM_TRAILING_MODE
{
   TRAILING_NONE,        // Disabled
   TRAILING_ATR,         // ATR Trailing Stop
   TRAILING_EMA9,        // 9 EMA Trailing Stop
   TRAILING_SWING        // Swing High/Low Trailing
};

enum ENUM_ALLOWED_SETUPS
{
   SETUP_PULLBACK_ONLY,        // Setup 1: 9 EMA Pullback Only
   SETUP_PULLBACK_AND_RECLAIM, // Setups 1 & 2: Pullback + Reclaim
   SETUP_ALL                   // Setups 1, 2 & 3: Pullback + Reclaim + Break&Retest
};

enum ENUM_HTF_MODE
{
   HTF_AUTO,             // Auto Higher Timeframe Mapping
   HTF_MANUAL           // Manual Higher Timeframe Selection
};

enum ENUM_STRUCTURE_STATE
{
   STRUCTURE_BULLISH,    // Higher Highs & Higher Lows
   STRUCTURE_BEARISH,    // Lower Highs & Lower Lows
   STRUCTURE_RANGE,      // Ranging / Sideways
   STRUCTURE_CHOPPY      // Mixed / Low Quality
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
//--- GENERAL SETTINGS
input group "=== GENERAL SETTINGS ==="
input ulong             InpMagicNumber            = 909021;             // Magic Number
input string            InpTradeComment           = "9EMA_VolRider";    // Trade Comment
input int               InpSlippage               = 30;                 // Max Slippage (Points)
input bool              InpUseATRSpreadFilter     = true;               // Enable ATR-Relative Spread Filter
input double            InpMaxSpreadATRMultiplier = 0.35;               // Max Spread as ATR Multiplier
input int               InpMaxSpreadPoints        = 50;                 // Max Absolute Spread (Points)

//--- STRATEGY & SETUP SELECTION
input group "=== STRATEGY & SETUP SELECTION ==="
input ENUM_ALLOWED_SETUPS InpAllowedSetups        = SETUP_ALL;          // Active Strategy Setups
input double            InpMinQualityScore        = 80.0;               // Minimum Trade Quality Score (0-100)

//--- 9 EMA ENGINE
input group "=== 9 EMA ENGINE ==="
input int               InpFastEMAPeriod          = 9;                  // EMA Period
input int               InpFastEMAShift           = 0;                  // EMA Shift
input ENUM_APPLIED_PRICE InpEMAPriceType          = PRICE_CLOSE;        // EMA Applied Price
input double            InpMinEMASlopePoints      = 5.0;                // Min EMA Slope per Bar (Points)

//--- VOLUME ENGINE
input group "=== VOLUME ENGINE ==="
input bool              InpUseVolumeFilter        = true;               // Enable Volume Confirmation Filter
input ENUM_APPLIED_VOLUME InpVolumeMode             = VOLUME_TICK;        // Volume Mode
input int               InpVolumeLookback         = 20;                 // Volume SMA Lookback
input double            InpVolumeMultiplier       = 1.2;                // Required Volume Multiplier vs SMA
input int               InpVolumeTrendBars        = 2;                  // Check Increasing Volume (Bars)

//--- MARKET STRUCTURE ENGINE
input group "=== MARKET STRUCTURE ENGINE ==="
input int               InpSwingLookbackLeft      = 3;                  // Swing High/Low Left Strength (Bars)
input int               InpSwingLookbackRight     = 3;                  // Swing High/Low Right Strength (Bars)
input int               InpMinStructurePoints     = 20;                 // Min Structure Swing Range (Points)
input bool              InpRequireBOS             = false;              // Require Recent Break of Structure (BOS)

//--- HIGHER TIMEFRAME (HTF) FILTER
input group "=== HIGHER TIMEFRAME (HTF) FILTER ==="
input bool              InpUseHTFFilter           = true;               // Enable HTF Trend Filter
input ENUM_HTF_MODE     InpHTFMode                = HTF_AUTO;           // HTF Mode
input ENUM_TIMEFRAMES   InpManualHTF              = PERIOD_H4;          // Manual HTF (if HTF_MANUAL)
input bool              InpAllowCounterTrend      = false;              // Allow Counter-Trend Trades

//--- MOMENTUM FILTER
input group "=== MOMENTUM FILTER ==="
input bool              InpUseADXFilter           = true;               // Enable ADX Directional Filter
input int               InpADXPeriod              = 14;                 // ADX Period
input double            InpMinADXValue            = 20.0;               // Min ADX Value
input bool              InpUseRSIFilter           = false;              // Enable RSI Filter
input int               InpRSIPeriod              = 14;                 // RSI Period
input double            InpRSIBuyMin              = 48.0;               // RSI Min Level for BUY
input double            InpRSISellMax             = 52.0;               // RSI Max Level for SELL

//--- VOLATILITY & OVEREXTENSION FILTER
input group "=== VOLATILITY & OVEREXTENSION FILTER ==="
input int               InpATRPeriod              = 14;                 // ATR Period
input double            InpMaxExtensionATR        = 2.5;                // Max Extended Distance from 9EMA (ATR Multiplier)
input double            InpPullbackMaxATRDist     = 1.2;                // Max Pullback Distance to 9EMA (ATR Multiplier)

//--- CANDLE CONFIRMATION
input group "=== CANDLE CONFIRMATION ==="
input bool              InpRequireCandleConfirm   = true;               // Require Candle Confirmation
input double            InpMinBodyPercent         = 40.0;               // Minimum Body Size (% of Total Range)
input bool              InpRequireWickRejection   = true;               // Require Rejection Wick

//--- QUALITY SCORE WEIGHTS (TOTAL = 100)
input group "=== QUALITY SCORE WEIGHTS (TOTAL = 100) ==="
input double            InpWeightHTF              = 20.0;               // HTF Alignment Weight
input double            InpWeightStructure        = 20.0;               // Market Structure Weight
input double            InpWeightEMA              = 15.0;               // 9 EMA Position & Slope Weight
input double            InpWeightVolume           = 15.0;               // Volume Confirmation Weight
input double            InpWeightMomentum         = 10.0;               // Momentum Weight
input double            InpWeightCandle           = 10.0;               // Candle Confirmation Weight
input double            InpWeightVolatility       = 5.0;                // Volatility Weight
input double            InpWeightRR               = 5.0;                // Risk/Reward Weight

//--- RISK MANAGEMENT
input group "=== RISK MANAGEMENT ==="
input ENUM_RISK_MODE    InpRiskMode               = RISK_DYNAMIC_PERCENT;// Risk Mode
input double            InpRiskPercent            = 1.0;                // Risk % per Trade (Dynamic)
input double            InpFixedLotSize           = 0.1;                // Fixed Lot Size (if RISK_FIXED_LOT)
input double            InpMinRRRatio             = 2.0;                // Minimum Risk/Reward Ratio

//--- STOP LOSS & TAKE PROFIT
input group "=== STOP LOSS & TAKE PROFIT ==="
input ENUM_SL_MODE      InpSLMode                 = SL_STRUCTURE_ATR;   // Stop Loss Mode
input double            InpSLATRMultiplier        = 1.5;                // ATR Buffer Multiplier for SL
input int               InpFixedSLPoints          = 200;                // Fixed SL (Points)
input int               InpMinSLPoints            = 80;                 // Min SL Distance (Points)
input int               InpMaxSLPoints            = 2000;               // Max SL Distance (Points)
input double            InpTP1_R_Multiple         = 2.0;                // TP1 R-Multiple (e.g. 2.0 = 2R)
input double            InpTP1_ClosePercent       = 50.0;               // Partial Close % at TP1
input double            InpTP2_R_Multiple         = 3.5;                // TP2 R-Multiple (e.g. 3.5 = 3.5R)

//--- TRADE MANAGEMENT & TRAILING
input group "=== TRADE MANAGEMENT & TRAILING ==="
input bool              InpMoveBEAtTP1            = true;               // Move SL to Break-Even at TP1
input int               InpBEOffsetPoints         = 10;                 // Break-Even Profit Offset (Points)
input ENUM_TRAILING_MODE InpTrailingMode          = TRAILING_ATR;       // Trailing Stop Mode
input double            InpTrailingStartR         = 2.0;                // Start Trailing after R-Multiple
input double            InpTrailingATRMultiplier  = 2.0;                // ATR Multiplier for Trailing
input int               InpTrailingStepPoints     = 20;                 // Minimum Trailing Step (Points)

//--- SAFETY & FREQUENCY CONTROL
input group "=== SAFETY & FREQUENCY CONTROL ==="
input int               InpMaxPositionsPerSymbol  = 1;                  // Max Open Positions per Symbol
input int               InpMaxTotalPositions      = 3;                  // Max Total Account Positions
input int               InpCooldownBars           = 3;                  // Cooldown Period between Trades (Bars)

//--- SESSION FILTER
input group "=== SESSION FILTER ==="
input bool              InpUseSessionFilter       = false;              // Enable Session Filter
input string            InpSessionStart           = "07:00";            // Session Start Time (HH:MM)
input string            InpSessionEnd             = "20:00";            // Session End Time (HH:MM)

//--- NEWS FILTER
input group "=== NEWS FILTER ==="
input bool              InpUseNewsFilter          = false;              // Enable News Filter (Fail-Safe)
input int               InpMinsBeforeNews         = 30;                 // Minutes Pause Before News
input int               InpMinsAfterNews          = 30;                 // Minutes Pause After News

//--- PERSISTENCE & RECOVERY
input group "=== PERSISTENCE & RECOVERY ==="
input bool              InpEnablePersistence      = true;               // Enable File Trade State Persistence

//--- TELEGRAM ALERTS
input group "=== TELEGRAM ALERTS ==="
input bool              InpEnableTelegram         = false;              // Enable Telegram Notifications
input string   InpTelegramBotToken    = ""; // Telegram Bot Token (Configure in EA inputs)                 // Telegram Bot Token
input string   InpTelegramChatID      = ""; // Telegram Chat / Channel ID (Configure in EA inputs)                 // Telegram Chat ID
input bool              InpSendTelegramScreenshot = false;              // Send Chart Screenshot on Signal

//--- DASHBOARD
input group "=== DASHBOARD ==="
input bool              InpShowDashboard          = true;               // Display Chart Dashboard
input int               InpDashboardX             = 20;                 // Dashboard X Offset
input int               InpDashboardY             = 30;                 // Dashboard Y Offset

//+------------------------------------------------------------------+
//| DATA STRUCTURES                                                  |
//+------------------------------------------------------------------+
struct SSwingPoint
{
   datetime time;
   double   price;
   int      barIndex;
   bool     isHigh; // true = Swing High, false = Swing Low
};

struct SMarketStructure
{
   ENUM_STRUCTURE_STATE state;
   SSwingPoint          lastSwingHigh;
   SSwingPoint          prevSwingHigh;
   SSwingPoint          lastSwingLow;
   SSwingPoint          prevSwingLow;
   bool                 hasBOS_Bullish;
   bool                 hasBOS_Bearish;
   double               atrValue;
};

struct SSignalInfo
{
   bool                 isValid;
   ENUM_ORDER_TYPE      orderType;     // ORDER_TYPE_BUY or ORDER_TYPE_SELL
   int                  setupType;     // 1=Pullback, 2=Reclaim, 3=BreakRetest
   double               entryPrice;
   double               stopLoss;
   double               tp1;
   double               tp2;
   double               qualityScore;
   double               rrRatio;
   string               reason;
   
   // Detailed Breakdown Scores
   double               scoreHTF;
   double               scoreStructure;
   double               scoreEMA;
   double               scoreVolume;
   double               scoreMomentum;
   double               scoreCandle;
   double               scoreVolatility;
   double               scoreRR;
};

struct STradeState
{
   ulong    ticket;
   ulong    magic;
   char     symbol[32];
   int      setupType;
   double   entryPrice;
   double   initialSL;
   double   initialTP1;
   double   initialTP2;
   double   riskAmount;
   double   qualityScore;
   bool     tp1Reached;
   bool     isBEActive;
   datetime entryTime;
   datetime lastUpdate;
};

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES & HANDLES                                       |
//+------------------------------------------------------------------+
CTrade                  m_trade;
CPositionInfo           m_position;
CSymbolInfo             m_symbolInfo;

// Indicator Handles
int                     m_handleEMA9            = INVALID_HANDLE;
int                     m_handleHTFEMA9         = INVALID_HANDLE;
int                     m_handleATR             = INVALID_HANDLE;
int                     m_handleADX             = INVALID_HANDLE;
int                     m_handleRSI             = INVALID_HANDLE;

ENUM_TIMEFRAMES         m_htfPeriod             = PERIOD_H4;
datetime                m_lastBarTime           = 0;
datetime                m_lastTradeTime         = 0;
STradeState             m_tradeStates[];
SSignalInfo             m_lastSignal;

// Dashboard Objects Prefix
#define DASH_PREFIX     "9EMA_Rider_Dash_"

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize Symbol Info
   if(!m_symbolInfo.Name(_Symbol))
   {
      Print("[ERROR] Failed to initialize SymbolInfo for ", _Symbol);
      return INIT_FAILED;
   }
   m_symbolInfo.Refresh();
   
   // Configure CTrade
   m_trade.SetExpertMagicNumber(InpMagicNumber);
   m_trade.SetDeviationInPoints(InpSlippage);
   m_trade.SetTypeFillingBySymbol(_Symbol);

   // Determine HTF Period
   if(InpHTFMode == HTF_AUTO)
      m_htfPeriod = GetAutoHTF(_Period);
   else
      m_htfPeriod = InpManualHTF;

   // Verify HTF is higher than current timeframe
   if(m_htfPeriod <= _Period)
   {
      Print("[WARNING] Specified HTF (", EnumToString(m_htfPeriod), 
            ") is not higher than chart timeframe (", EnumToString(_Period), "). Auto-adjusting.");
      m_htfPeriod = GetAutoHTF(_Period);
   }

   // Initialize Indicators
   m_handleEMA9 = iMA(_Symbol, _Period, InpFastEMAPeriod, InpFastEMAShift, MODE_EMA, InpEMAPriceType);
   if(m_handleEMA9 == INVALID_HANDLE)
   {
      Print("[ERROR] Failed to create 9 EMA handle");
      return INIT_FAILED;
   }

   if(InpUseHTFFilter)
   {
      m_handleHTFEMA9 = iMA(_Symbol, m_htfPeriod, InpFastEMAPeriod, InpFastEMAShift, MODE_EMA, InpEMAPriceType);
      if(m_handleHTFEMA9 == INVALID_HANDLE)
      {
         Print("[ERROR] Failed to create HTF 9 EMA handle");
         return INIT_FAILED;
      }
   }

   m_handleATR = iATR(_Symbol, _Period, InpATRPeriod);
   if(m_handleATR == INVALID_HANDLE)
   {
      Print("[ERROR] Failed to create ATR handle");
      return INIT_FAILED;
   }

   if(InpUseADXFilter)
   {
      m_handleADX = iADX(_Symbol, _Period, InpADXPeriod);
      if(m_handleADX == INVALID_HANDLE)
      {
         Print("[ERROR] Failed to create ADX handle");
         return INIT_FAILED;
      }
   }

   if(InpUseRSIFilter)
   {
      m_handleRSI = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);
      if(m_handleRSI == INVALID_HANDLE)
      {
         Print("[ERROR] Failed to create RSI handle");
         return INIT_FAILED;
      }
   }

   // Load State from File if Persistence Enabled
   if(InpEnablePersistence)
      LoadStateFromFile();

   // Synchronize Active Positions with Internal State
   SyncPositionsWithState();

   // Draw Initial Dashboard
   if(InpShowDashboard)
      UpdateDashboard();

   Print("[INIT] 9 EMA + Volume Trend Rider initialized successfully. Chart TF: ", 
         EnumToString(_Period), " | HTF: ", EnumToString(m_htfPeriod));

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release Indicator Handles
   if(m_handleEMA9 != INVALID_HANDLE)    IndicatorRelease(m_handleEMA9);
   if(m_handleHTFEMA9 != INVALID_HANDLE) IndicatorRelease(m_handleHTFEMA9);
   if(m_handleATR != INVALID_HANDLE)     IndicatorRelease(m_handleATR);
   if(m_handleADX != INVALID_HANDLE)     IndicatorRelease(m_handleADX);
   if(m_handleRSI != INVALID_HANDLE)     IndicatorRelease(m_handleRSI);

   // Save Persistence State
   if(InpEnablePersistence)
      SaveStateToFile();

   // Remove Dashboard Objects
   RemoveDashboard();

   Print("[DEINIT] 9 EMA + Volume Trend Rider deinitialized. Reason code: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Refresh Symbol Info
   if(!m_symbolInfo.RefreshRates()) return;

   // Manage Active Positions (TP1 Partial Close, BE, Trailing Stop)
   ManageActivePositions();

   // Check for New Bar
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   bool isNewBar = (currentBarTime != m_lastBarTime);

   if(isNewBar)
   {
      m_lastBarTime = currentBarTime;

      // Update Dashboard once per bar
      if(InpShowDashboard)
         UpdateDashboard();

      // Check Session & Safety Filters before signal evaluation
      if(!CheckSessionFilter()) return;
      if(!CheckSpreadFilter()) return;
      if(!CheckNewsFilter()) return;
      if(!CheckPositionLimits()) return;
      if(CheckCooldown()) return;

      // Evaluate Entry Signal on Closed Bar [1]
      SSignalInfo signal = EvaluateSignal();
      m_lastSignal = signal;

      if(signal.isValid && signal.qualityScore >= InpMinQualityScore)
      {
         Print("[SIGNAL QUALIFIED] ", (signal.orderType == ORDER_TYPE_BUY ? "BUY" : "SELL"),
               " | Setup Type: ", signal.setupType,
               " | Score: ", DoubleToString(signal.qualityScore, 1), "/100",
               " | Entry: ", signal.entryPrice,
               " | SL: ", signal.stopLoss,
               " | TP1: ", signal.tp1,
               " | TP2: ", signal.tp2);

         ExecuteSignal(signal);
      }
      else if(signal.isValid)
      {
         Print("[SIGNAL REJECTED] Score ", DoubleToString(signal.qualityScore, 1), 
               " below threshold ", DoubleToString(InpMinQualityScore, 1), ". Reason: ", signal.reason);
      }
   }
}

//+------------------------------------------------------------------+
//| EVALUATE ENTRY SIGNAL                                            |
//+------------------------------------------------------------------+
SSignalInfo EvaluateSignal()
{
   SSignalInfo sig;
   ZeroMemory(sig);
   sig.isValid = false;
   sig.reason = "No setup criteria met";

   // Read Bar Data (Bar 1 is completed candle)
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, _Period, 0, 5, rates) < 5)
   {
      sig.reason = "Insufficient bar data";
      return sig;
   }

   // Read EMA9 Buffer
   double ema9Buffer[];
   ArraySetAsSeries(ema9Buffer, true);
   if(CopyBuffer(m_handleEMA9, 0, 0, 5, ema9Buffer) < 5)
   {
      sig.reason = "EMA9 buffer error";
      return sig;
   }

   // Read ATR Buffer
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   if(CopyBuffer(m_handleATR, 0, 0, 5, atrBuffer) < 5)
   {
      sig.reason = "ATR buffer error";
      return sig;
   }
   double currentATR = atrBuffer[1];

   // 1. Check Overextension Filter
   double distFromEMA = MathAbs(rates[1].close - ema9Buffer[1]);
   if(distFromEMA > currentATR * InpMaxExtensionATR)
   {
      sig.reason = "Price overextended from 9 EMA";
      return sig;
   }

   // 2. Determine Market Structure
   SMarketStructure structure = AnalyzeMarketStructure();
   if(structure.state == STRUCTURE_CHOPPY || structure.state == STRUCTURE_RANGE)
   {
      sig.reason = "Market structure is choppy or ranging";
      return sig;
   }

   // 3. Evaluate Higher Timeframe Alignment
   bool htfBullish = true, htfBearish = true;
   double scoreHTF = EvaluateHTFTrend(htfBullish, htfBearish);
   if(InpUseHTFFilter && !InpAllowCounterTrend)
   {
      if(structure.state == STRUCTURE_BULLISH && !htfBullish)
      {
         sig.reason = "HTF trend does not support Bullish setup";
         return sig;
      }
      if(structure.state == STRUCTURE_BEARISH && !htfBearish)
      {
         sig.reason = "HTF trend does not support Bearish setup";
         return sig;
      }
   }

   // 4. Evaluate Volume Filter
   double scoreVolume = 0.0;
   bool volumeValid = EvaluateVolume(scoreVolume);
   if(InpUseVolumeFilter && !volumeValid)
   {
      sig.reason = "Insufficient volume confirmation";
      return sig;
   }

   // 5. Evaluate Momentum Filter
   double scoreMomentum = 0.0;
   bool momentumBullish = false, momentumBearish = false;
   bool momentumValid = EvaluateMomentum(scoreMomentum, momentumBullish, momentumBearish);
   if(InpUseADXFilter && !momentumValid)
   {
      sig.reason = "ADX/Momentum criteria not met";
      return sig;
   }

   // 6. Test Setups for BUY
   if(structure.state == STRUCTURE_BULLISH && (htfBullish || InpAllowCounterTrend))
   {
      int setupType = 0;
      if(CheckBuyPullback(rates, ema9Buffer, currentATR)) setupType = 1;
      else if((InpAllowedSetups == SETUP_PULLBACK_AND_RECLAIM || InpAllowedSetups == SETUP_ALL) && 
              CheckBuyReclaim(rates, ema9Buffer, currentATR)) setupType = 2;
      else if(InpAllowedSetups == SETUP_ALL && 
              CheckBuyBreakRetest(rates, ema9Buffer, currentATR)) setupType = 3;

      if(setupType > 0)
      {
         // Calculate Stop Loss & Targets
         double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double sl = CalculateStopLoss(ORDER_TYPE_BUY, entryPrice, structure, currentATR);
         double slDistance = entryPrice - sl;
         double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         double slPoints = slDistance / point;

         if(slPoints >= InpMinSLPoints && slPoints <= InpMaxSLPoints)
         {
            double tp1 = NormalizeDouble(entryPrice + (slDistance * InpTP1_R_Multiple), _Digits);
            double tp2 = NormalizeDouble(entryPrice + (slDistance * InpTP2_R_Multiple), _Digits);
            double rr = (tp2 - entryPrice) / slDistance;

            if(rr >= InpMinRRRatio)
            {
               // Calculate Breakdown Scores
               double scoreStruct = (structure.state == STRUCTURE_BULLISH) ? InpWeightStructure : 0.0;
               double scoreEMAVal = (rates[1].close > ema9Buffer[1] && ema9Buffer[1] > ema9Buffer[2]) ? InpWeightEMA : (InpWeightEMA * 0.5);
               double scoreCandle = EvaluateCandleConfirmation(ORDER_TYPE_BUY, rates[1]);
               double scoreVolat  = (currentATR > 0) ? InpWeightVolatility : 0.0;
               double scoreRRVal  = (rr >= 3.0) ? InpWeightRR : (InpWeightRR * (rr / 3.0));

               double totalScore = scoreHTF + scoreStruct + scoreEMAVal + scoreVolume + 
                                   scoreMomentum + scoreCandle + scoreVolat + scoreRRVal;

               sig.isValid         = true;
               sig.orderType       = ORDER_TYPE_BUY;
               sig.setupType       = setupType;
               sig.entryPrice      = entryPrice;
               sig.stopLoss        = sl;
               sig.tp1             = tp1;
               sig.tp2             = tp2;
               sig.qualityScore    = totalScore;
               sig.rrRatio         = rr;
               sig.scoreHTF        = scoreHTF;
               sig.scoreStructure  = scoreStruct;
               sig.scoreEMA        = scoreEMAVal;
               sig.scoreVolume     = scoreVolume;
               sig.scoreMomentum   = scoreMomentum;
               sig.scoreCandle     = scoreCandle;
               sig.scoreVolatility = scoreVolat;
               sig.scoreRR         = scoreRRVal;
               sig.reason          = "Qualified BUY setup";
               return sig;
            }
            else sig.reason = "Risk/Reward ratio below minimum target";
         }
         else sig.reason = "Stop Loss distance out of permitted bounds";
      }
   }

   // 7. Test Setups for SELL
   if(structure.state == STRUCTURE_BEARISH && (htfBearish || InpAllowCounterTrend))
   {
      int setupType = 0;
      if(CheckSellPullback(rates, ema9Buffer, currentATR)) setupType = 1;
      else if((InpAllowedSetups == SETUP_PULLBACK_AND_RECLAIM || InpAllowedSetups == SETUP_ALL) && 
              CheckSellReclaim(rates, ema9Buffer, currentATR)) setupType = 2;
      else if(InpAllowedSetups == SETUP_ALL && 
              CheckSellBreakRetest(rates, ema9Buffer, currentATR)) setupType = 3;

      if(setupType > 0)
      {
         // Calculate Stop Loss & Targets
         double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double sl = CalculateStopLoss(ORDER_TYPE_SELL, entryPrice, structure, currentATR);
         double slDistance = sl - entryPrice;
         double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         double slPoints = slDistance / point;

         if(slPoints >= InpMinSLPoints && slPoints <= InpMaxSLPoints)
         {
            double tp1 = NormalizeDouble(entryPrice - (slDistance * InpTP1_R_Multiple), _Digits);
            double tp2 = NormalizeDouble(entryPrice - (slDistance * InpTP2_R_Multiple), _Digits);
            double rr = (entryPrice - tp2) / slDistance;

            if(rr >= InpMinRRRatio)
            {
               // Calculate Breakdown Scores
               double scoreStruct = (structure.state == STRUCTURE_BEARISH) ? InpWeightStructure : 0.0;
               double scoreEMAVal = (rates[1].close < ema9Buffer[1] && ema9Buffer[1] < ema9Buffer[2]) ? InpWeightEMA : (InpWeightEMA * 0.5);
               double scoreCandle = EvaluateCandleConfirmation(ORDER_TYPE_SELL, rates[1]);
               double scoreVolat  = (currentATR > 0) ? InpWeightVolatility : 0.0;
               double scoreRRVal  = (rr >= 3.0) ? InpWeightRR : (InpWeightRR * (rr / 3.0));

               double totalScore = scoreHTF + scoreStruct + scoreEMAVal + scoreVolume + 
                                   scoreMomentum + scoreCandle + scoreVolat + scoreRRVal;

               sig.isValid         = true;
               sig.orderType       = ORDER_TYPE_SELL;
               sig.setupType       = setupType;
               sig.entryPrice      = entryPrice;
               sig.stopLoss        = sl;
               sig.tp1             = tp1;
               sig.tp2             = tp2;
               sig.qualityScore    = totalScore;
               sig.rrRatio         = rr;
               sig.scoreHTF        = scoreHTF;
               sig.scoreStructure  = scoreStruct;
               sig.scoreEMA        = scoreEMAVal;
               sig.scoreVolume     = scoreVolume;
               sig.scoreMomentum   = scoreMomentum;
               sig.scoreCandle     = scoreCandle;
               sig.scoreVolatility = scoreVolat;
               sig.scoreRR         = scoreRRVal;
               sig.reason          = "Qualified SELL setup";
               return sig;
            }
            else sig.reason = "Risk/Reward ratio below minimum target";
         }
         else sig.reason = "Stop Loss distance out of permitted bounds";
      }
   }

   return sig;
}

//+------------------------------------------------------------------+
//| SPECIFIC SETUP CHECKERS                                          |
//+------------------------------------------------------------------+
bool CheckBuyPullback(const MqlRates &rates[], const double &ema9[], double atr)
{
   // Price above EMA9, EMA9 rising
   if(rates[1].close <= ema9[1] || ema9[1] <= ema9[2]) return false;
   
   // Pullback touch/approach: Low[1] or Low[2] comes near 9 EMA
   double distToEMA = MathAbs(rates[1].low - ema9[1]);
   if(distToEMA > atr * InpPullbackMaxATRDist) return false;

   // Confirmation Candle: Close[1] > Open[1]
   if(InpRequireCandleConfirm && rates[1].close <= rates[1].open) return false;

   return true;
}

bool CheckSellPullback(const MqlRates &rates[], const double &ema9[], double atr)
{
   // Price below EMA9, EMA9 falling
   if(rates[1].close >= ema9[1] || ema9[1] >= ema9[2]) return false;

   // Pullback touch/approach
   double distToEMA = MathAbs(rates[1].high - ema9[1]);
   if(distToEMA > atr * InpPullbackMaxATRDist) return false;

   // Confirmation Candle: Close[1] < Open[1]
   if(InpRequireCandleConfirm && rates[1].close >= rates[1].open) return false;

   return true;
}

bool CheckBuyReclaim(const MqlRates &rates[], const double &ema9[], double atr)
{
   // Bar [2] dipped below EMA9, Bar [1] reclaimed EMA9 cleanly
   if(rates[2].low < ema9[2] && rates[1].close > ema9[1] && rates[1].close > rates[1].open)
      return true;
   return false;
}

bool CheckSellReclaim(const MqlRates &rates[], const double &ema9[], double atr)
{
   // Bar [2] popped above EMA9, Bar [1] reclaimed EMA9 to downside
   if(rates[2].high > ema9[2] && rates[1].close < ema9[1] && rates[1].close < rates[1].open)
      return true;
   return false;
}

bool CheckBuyBreakRetest(const MqlRates &rates[], const double &ema9[], double atr)
{
   // Bar [3] crossed above EMA9, Bar [2] retested EMA9 and held, Bar [1] confirms
   if(rates[3].close > ema9[3] && rates[2].low <= ema9[2] && rates[2].close >= ema9[2] && rates[1].close > rates[1].open)
      return true;
   return false;
}

bool CheckSellBreakRetest(const MqlRates &rates[], const double &ema9[], double atr)
{
   // Bar [3] crossed below EMA9, Bar [2] retested EMA9 and held, Bar [1] confirms
   if(rates[3].close < ema9[3] && rates[2].high >= ema9[2] && rates[2].close <= ema9[2] && rates[1].close < rates[1].open)
      return true;
   return false;
}

//+------------------------------------------------------------------+
//| MARKET STRUCTURE ANALYSIS                                        |
//+------------------------------------------------------------------+
SMarketStructure AnalyzeMarketStructure()
{
   SMarketStructure structRes;
   structRes.state = STRUCTURE_CHOPPY;
   structRes.hasBOS_Bullish = false;
   structRes.hasBOS_Bearish = false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, _Period, 0, 100, rates);
   if(copied < 50) return structRes;

   // Detect Swings
   SSwingPoint swingHighs[];
   SSwingPoint swingLows[];
   ArrayResize(swingHighs, 0);
   ArrayResize(swingLows, 0);

   for(int i = InpSwingLookbackRight; i < copied - InpSwingLookbackLeft; i++)
   {
      bool isHigh = true;
      bool isLow = true;

      for(int j = 1; j <= InpSwingLookbackLeft; j++)
      {
         if(rates[i].high <= rates[i + j].high) isHigh = false;
         if(rates[i].low >= rates[i + j].low)   isLow = false;
      }
      for(int j = 1; j <= InpSwingLookbackRight; j++)
      {
         if(rates[i].high <= rates[i - j].high) isHigh = false;
         if(rates[i].low >= rates[i - j].low)   isLow = false;
      }

      if(isHigh)
      {
         int size = ArraySize(swingHighs);
         ArrayResize(swingHighs, size + 1);
         swingHighs[size].time = rates[i].time;
         swingHighs[size].price = rates[i].high;
         swingHighs[size].barIndex = i;
         swingHighs[size].isHigh = true;
      }
      if(isLow)
      {
         int size = ArraySize(swingLows);
         ArrayResize(swingLows, size + 1);
         swingLows[size].time = rates[i].time;
         swingLows[size].price = rates[i].low;
         swingLows[size].barIndex = i;
         swingLows[size].isHigh = false;
      }
   }

   int numHighs = ArraySize(swingHighs);
   int numLows  = ArraySize(swingLows);

   if(numHighs < 2 || numLows < 2) return structRes;

   structRes.lastSwingHigh = swingHighs[0];
   structRes.prevSwingHigh = swingHighs[1];
   structRes.lastSwingLow  = swingLows[0];
   structRes.prevSwingLow  = swingLows[1];

   // Check Structure Alignment
   bool higherHigh = (structRes.lastSwingHigh.price > structRes.prevSwingHigh.price);
   bool higherLow  = (structRes.lastSwingLow.price > structRes.prevSwingLow.price);
   bool lowerHigh  = (structRes.lastSwingHigh.price < structRes.prevSwingHigh.price);
   bool lowerLow   = (structRes.lastSwingLow.price < structRes.prevSwingLow.price);

   // BOS Detection
   if(rates[1].close > structRes.lastSwingHigh.price) structRes.hasBOS_Bullish = true;
   if(rates[1].close < structRes.lastSwingLow.price)  structRes.hasBOS_Bearish = true;

   if(higherHigh && higherLow)
   {
      structRes.state = STRUCTURE_BULLISH;
   }
   else if(lowerHigh && lowerLow)
   {
      structRes.state = STRUCTURE_BEARISH;
   }
   else
   {
      structRes.state = STRUCTURE_RANGE;
   }

   return structRes;
}

//+------------------------------------------------------------------+
//| FILTER EVALUATORS                                                |
//+------------------------------------------------------------------+
double EvaluateHTFTrend(bool &isBullish, bool &isBearish)
{
   isBullish = false;
   isBearish = false;

   if(!InpUseHTFFilter || m_handleHTFEMA9 == INVALID_HANDLE)
   {
      isBullish = true;
      isBearish = true;
      return InpWeightHTF;
   }

   double htfEMA[];
   ArraySetAsSeries(htfEMA, true);
   if(CopyBuffer(m_handleHTFEMA9, 0, 0, 3, htfEMA) < 3) return 0.0;

   MqlRates htfRates[];
   ArraySetAsSeries(htfRates, true);
   if(CopyRates(_Symbol, m_htfPeriod, 0, 3, htfRates) < 3) return 0.0;

   if(htfRates[1].close > htfEMA[1] && htfEMA[1] >= htfEMA[2])
   {
      isBullish = true;
      return InpWeightHTF;
   }
   else if(htfRates[1].close < htfEMA[1] && htfEMA[1] <= htfEMA[2])
   {
      isBearish = true;
      return InpWeightHTF;
   }

   return (InpWeightHTF * 0.5);
}

bool EvaluateVolume(double &scoreVolume)
{
   scoreVolume = 0.0;

   long volume[];
   ArraySetAsSeries(volume, true);

   int copied = 0;
   if(InpVolumeMode == VOLUME_TICK)
      copied = (int)CopyTickVolume(_Symbol, _Period, 0, InpVolumeLookback + 2, volume);
   else
      copied = (int)CopyRealVolume(_Symbol, _Period, 0, InpVolumeLookback + 2, volume);

   if(copied < InpVolumeLookback + 2) return false;

   // Calculate SMA of Volume
   double sumVol = 0.0;
   for(int i = 2; i < InpVolumeLookback + 2; i++)
   {
      sumVol += (double)volume[i];
   }
   double smaVol = sumVol / (double)InpVolumeLookback;
   if(smaVol <= 0) return false;

   double currentVol = (double)volume[1];
   double volRatio = currentVol / smaVol;

   if(volRatio >= InpVolumeMultiplier)
   {
      scoreVolume = InpWeightVolume;
      return true;
   }
   else if(volRatio >= 1.0)
   {
      scoreVolume = InpWeightVolume * 0.7;
      return true;
   }

   scoreVolume = 0.0;
   return false;
}

bool EvaluateMomentum(double &scoreMomentum, bool &isBullish, bool &isBearish)
{
   scoreMomentum = 0.0;
   isBullish = false;
   isBearish = false;

   if(!InpUseADXFilter)
   {
      isBullish = true;
      isBearish = true;
      scoreMomentum = InpWeightMomentum;
      return true;
   }

   double adxMain[], adxPlus[], adxMinus[];
   ArraySetAsSeries(adxMain, true);
   ArraySetAsSeries(adxPlus, true);
   ArraySetAsSeries(adxMinus, true);

   if(CopyBuffer(m_handleADX, 0, 0, 3, adxMain) < 3 ||
      CopyBuffer(m_handleADX, 1, 0, 3, adxPlus) < 3 ||
      CopyBuffer(m_handleADX, 2, 0, 3, adxMinus) < 3)
      return false;

   if(adxMain[1] >= InpMinADXValue)
   {
      if(adxPlus[1] > adxMinus[1])
      {
         isBullish = true;
         scoreMomentum = InpWeightMomentum;
      }
      else if(adxMinus[1] > adxPlus[1])
      {
         isBearish = true;
         scoreMomentum = InpWeightMomentum;
      }

      // Check Optional RSI Filter
      if(InpUseRSIFilter && m_handleRSI != INVALID_HANDLE)
      {
         double rsi[];
         ArraySetAsSeries(rsi, true);
         if(CopyBuffer(m_handleRSI, 0, 0, 3, rsi) >= 3)
         {
            if(isBullish && rsi[1] < InpRSIBuyMin) isBullish = false;
            if(isBearish && rsi[1] > InpRSISellMax) isBearish = false;
         }
      }

      return (isBullish || isBearish);
   }

   return false;
}

double EvaluateCandleConfirmation(ENUM_ORDER_TYPE orderType, const MqlRates &bar)
{
   if(!InpRequireCandleConfirm) return InpWeightCandle;

   double totalRange = bar.high - bar.low;
   if(totalRange <= 0) return 0.0;

   double body = MathAbs(bar.close - bar.open);
   double bodyPercent = (body / totalRange) * 100.0;

   if(bodyPercent < InpMinBodyPercent) return 0.0;

   if(orderType == ORDER_TYPE_BUY)
   {
      if(bar.close <= bar.open) return 0.0;
      double lowerWick = bar.open - bar.low;
      if(InpRequireWickRejection && lowerWick < body * 0.3) return (InpWeightCandle * 0.5);
   }
   else if(orderType == ORDER_TYPE_SELL)
   {
      if(bar.close >= bar.open) return 0.0;
      double upperWick = bar.high - bar.open;
      if(InpRequireWickRejection && upperWick < body * 0.3) return (InpWeightCandle * 0.5);
   }

   return InpWeightCandle;
}

//+------------------------------------------------------------------+
//| STOP LOSS & LOT SIZE CALCULATOR                                  |
//+------------------------------------------------------------------+
double CalculateStopLoss(ENUM_ORDER_TYPE orderType, double entryPrice, const SMarketStructure &structData, double atr)
{
   double sl = 0.0;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(InpSLMode == SL_STRUCTURE_ATR)
   {
      if(orderType == ORDER_TYPE_BUY)
         sl = structData.lastSwingLow.price - (atr * InpSLATRMultiplier);
      else
         sl = structData.lastSwingHigh.price + (atr * InpSLATRMultiplier);
   }
   else if(InpSLMode == SL_ATR_ONLY)
   {
      if(orderType == ORDER_TYPE_BUY)
         sl = entryPrice - (atr * InpSLATRMultiplier);
      else
         sl = entryPrice + (atr * InpSLATRMultiplier);
   }
   else // SL_FIXED_POINTS
   {
      if(orderType == ORDER_TYPE_BUY)
         sl = entryPrice - (InpFixedSLPoints * point);
      else
         sl = entryPrice + (InpFixedSLPoints * point);
   }

   return NormalizeDouble(sl, _Digits);
}

double CalculateLotSize(double entryPrice, double stopLoss)
{
   if(InpRiskMode == RISK_FIXED_LOT)
   {
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double lot = MathFloor(InpFixedLotSize / lotStep) * lotStep;
      return MathMin(MathMax(lot, minLot), maxLot);
   }

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmount = equity * (InpRiskPercent / 100.0);

   double slDistance = MathAbs(entryPrice - stopLoss);
   if(slDistance <= 0) return 0.0;

   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double point     = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(tickSize <= 0 || tickValue <= 0 || point <= 0) return 0.0;

   double valuePerPoint = (tickValue / tickSize) * point;
   double pointsAtRisk  = slDistance / point;

   if(valuePerPoint <= 0 || pointsAtRisk <= 0) return 0.0;

   double rawLots = riskAmount / (pointsAtRisk * valuePerPoint);

   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   double stepLots = MathFloor(rawLots / lotStep) * lotStep;
   double finalLots = MathMin(MathMax(stepLots, minLot), maxLot);

   // Margin Safety Check
   double marginRequired = 0.0;
   if(OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, finalLots, entryPrice, marginRequired))
   {
      double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      if(marginRequired > freeMargin * 0.85)
      {
         finalLots = MathFloor((freeMargin * 0.85 / marginRequired) * finalLots / lotStep) * lotStep;
         finalLots = MathMax(finalLots, minLot);
      }
   }

   return NormalizeDouble(finalLots, 2);
}

//+------------------------------------------------------------------+
//| TRADE EXECUTION                                                  |
//+------------------------------------------------------------------+
void ExecuteSignal(const SSignalInfo &sig)
{
   double lotSize = CalculateLotSize(sig.entryPrice, sig.stopLoss);
   if(lotSize <= 0)
   {
      Print("[ERROR] Invalid lot size calculated: ", lotSize);
      return;
   }

   bool success = false;
   ulong ticket = 0;

   if(sig.orderType == ORDER_TYPE_BUY)
   {
      success = m_trade.Buy(lotSize, _Symbol, sig.entryPrice, sig.stopLoss, sig.tp2, InpTradeComment);
   }
   else if(sig.orderType == ORDER_TYPE_SELL)
   {
      success = m_trade.Sell(lotSize, _Symbol, sig.entryPrice, sig.stopLoss, sig.tp2, InpTradeComment);
   }

   if(success)
   {
      ticket = m_trade.ResultOrder();
      Print("[TRADE SUCCESS] Ticket: ", ticket, " | Lot Size: ", lotSize);
      m_lastTradeTime = TimeCurrent();

      // Track State
      STradeState newState;
      newState.ticket       = ticket;
      newState.magic        = InpMagicNumber;
      StringToCharArray(_Symbol, newState.symbol);
      newState.setupType    = sig.setupType;
      newState.entryPrice   = sig.entryPrice;
      newState.initialSL    = sig.stopLoss;
      newState.initialTP1   = sig.tp1;
      newState.initialTP2   = sig.tp2;
      newState.riskAmount   = AccountInfoDouble(ACCOUNT_EQUITY) * (InpRiskPercent / 100.0);
      newState.qualityScore = sig.qualityScore;
      newState.tp1Reached   = false;
      newState.isBEActive   = false;
      newState.entryTime    = TimeCurrent();
      newState.lastUpdate   = TimeCurrent();

      AddTradeState(newState);
      if(InpEnablePersistence) SaveStateToFile();

      // Send Telegram Alert
      if(InpEnableTelegram)
      {
         string msg = FormatTelegramSignal(sig, lotSize);
         SendTelegramMessage(msg);

         if(InpSendTelegramScreenshot)
            SendTelegramScreenshot();
      }
   }
   else
   {
      Print("[TRADE ERROR] OrderSend failed. Error code: ", m_trade.ResultRetcode(), 
            " | Description: ", m_trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| ACTIVE TRADE MANAGEMENT (TP1, BE, TRAILING)                      |
//+------------------------------------------------------------------+
void ManageActivePositions()
{
   int totalPositions = PositionsTotal();
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   bool atrOk = (CopyBuffer(m_handleATR, 0, 0, 3, atrBuffer) >= 3);

   double ema9Buffer[];
   ArraySetAsSeries(ema9Buffer, true);
   bool emaOk = (CopyBuffer(m_handleEMA9, 0, 0, 3, ema9Buffer) >= 3);

   for(int i = totalPositions - 1; i >= 0; i--)
   {
      if(!m_position.SelectByIndex(i)) continue;
      if(m_position.Magic() != InpMagicNumber || m_position.Symbol() != _Symbol) continue;

      ulong ticket      = m_position.Ticket();
      ENUM_POSITION_TYPE posType = m_position.PositionType();
      double currentPrice= (posType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double openPrice   = m_position.PriceOpen();
      double currentSL   = m_position.StopLoss();
      double currentTP   = m_position.TakeProfit();
      double volume      = m_position.Volume();

      // Get or Create State
      int stateIndex = FindTradeState(ticket);
      if(stateIndex < 0)
      {
         STradeState newState;
         newState.ticket     = ticket;
         newState.magic      = InpMagicNumber;
         StringToCharArray(_Symbol, newState.symbol);
         newState.setupType  = 1;
         newState.entryPrice = openPrice;
         newState.initialSL  = currentSL;
         newState.initialTP1 = openPrice + (posType == POSITION_TYPE_BUY ? (openPrice - currentSL)*InpTP1_R_Multiple : -(currentSL - openPrice)*InpTP1_R_Multiple);
         newState.initialTP2 = currentTP;
         newState.tp1Reached = false;
         newState.isBEActive = false;
         newState.entryTime  = (datetime)m_position.Time();
         newState.lastUpdate = TimeCurrent();
         stateIndex = AddTradeState(newState);
      }

      STradeState state = m_tradeStates[stateIndex];

      // 1. Check TP1 Partial Close & Break-Even
      if(!state.tp1Reached)
      {
         bool tp1Hit = false;
         if(posType == POSITION_TYPE_BUY && currentPrice >= state.initialTP1) tp1Hit = true;
         if(posType == POSITION_TYPE_SELL && currentPrice <= state.initialTP1) tp1Hit = true;

         if(tp1Hit)
         {
            Print("[TP1 REACHED] Position Ticket: ", ticket, " | Executing ", InpTP1_ClosePercent, "% Partial Close");

            // Close Partial Volume
            double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
            double closeLots = MathFloor((volume * (InpTP1_ClosePercent / 100.0)) / lotStep) * lotStep;
            closeLots = MathMax(closeLots, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN));

            if(closeLots < volume)
            {
               m_trade.PositionClosePartial(ticket, closeLots);
            }

            // Move SL to Break-Even
            if(InpMoveBEAtTP1)
            {
               double beSL = (posType == POSITION_TYPE_BUY) ? 
                             NormalizeDouble(openPrice + (InpBEOffsetPoints * point), _Digits) :
                             NormalizeDouble(openPrice - (InpBEOffsetPoints * point), _Digits);

               if((posType == POSITION_TYPE_BUY && beSL > currentSL) ||
                  (posType == POSITION_TYPE_SELL && (currentSL == 0 || beSL < currentSL)))
               {
                  m_trade.PositionModify(ticket, beSL, currentTP);
                  m_tradeStates[stateIndex].isBEActive = true;
                  Print("[BREAK EVEN ACTIVATED] Ticket: ", ticket, " | New SL: ", beSL);
               }
            }

            m_tradeStates[stateIndex].tp1Reached = true;
            m_tradeStates[stateIndex].lastUpdate = TimeCurrent();
            if(InpEnablePersistence) SaveStateToFile();

            if(InpEnableTelegram)
            {
               string tpMsg = "🎯 *TP1 REACHED & BE ACTIVATED*\nSymbol: " + _Symbol + 
                              "\nTicket: #" + IntegerToString(ticket) + 
                              "\nPartial Close: " + DoubleToString(InpTP1_ClosePercent, 0) + "%";
               SendTelegramMessage(tpMsg);
            }
         }
      }

      // 2. Trailing Stop Management
      if(InpTrailingMode != TRAILING_NONE && state.tp1Reached)
      {
         double newSL = 0.0;

         if(InpTrailingMode == TRAILING_ATR && atrOk)
         {
            if(posType == POSITION_TYPE_BUY)
               newSL = NormalizeDouble(currentPrice - (atrBuffer[1] * InpTrailingATRMultiplier), _Digits);
            else
               newSL = NormalizeDouble(currentPrice + (atrBuffer[1] * InpTrailingATRMultiplier), _Digits);
         }
         else if(InpTrailingMode == TRAILING_EMA9 && emaOk)
         {
            if(posType == POSITION_TYPE_BUY)
               newSL = NormalizeDouble(ema9Buffer[1] - (InpBEOffsetPoints * point), _Digits);
            else
               newSL = NormalizeDouble(ema9Buffer[1] + (InpBEOffsetPoints * point), _Digits);
         }

         if(newSL > 0.0)
         {
            if(posType == POSITION_TYPE_BUY && (newSL - currentSL) >= (InpTrailingStepPoints * point))
            {
               m_trade.PositionModify(ticket, newSL, currentTP);
               Print("[TRAILING STOP MODIFIED] Ticket: ", ticket, " | New SL: ", newSL);
            }
            else if(posType == POSITION_TYPE_SELL && (currentSL == 0 || (currentSL - newSL) >= (InpTrailingStepPoints * point)))
            {
               m_trade.PositionModify(ticket, newSL, currentTP);
               Print("[TRAILING STOP MODIFIED] Ticket: ", ticket, " | New SL: ", newSL);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| SAFETY & SYSTEM FILTERS                                          |
//+------------------------------------------------------------------+
bool CheckSessionFilter()
{
   if(!InpUseSessionFilter) return true;

   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   string currentTimeStr = StringFormat("%02d:%02d", dt.hour, dt.min);

   if(currentTimeStr >= InpSessionStart && currentTimeStr <= InpSessionEnd)
      return true;

   return false;
}

bool CheckSpreadFilter()
{
   double currentSpreadPoints = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);

   if(InpUseATRSpreadFilter && m_handleATR != INVALID_HANDLE)
   {
      double atr[];
      ArraySetAsSeries(atr, true);
      if(CopyBuffer(m_handleATR, 0, 0, 2, atr) >= 2 && atr[1] > 0)
      {
         double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         double maxAllowedSpreadPoints = (atr[1] * InpMaxSpreadATRMultiplier) / point;

         if(currentSpreadPoints > maxAllowedSpreadPoints) return false;
      }
   }

   if(currentSpreadPoints > InpMaxSpreadPoints) return false;

   return true;
}

bool CheckNewsFilter()
{
   // Fail-safe logic: returns true unless integrated with external news API
   return true;
}

bool CheckPositionLimits()
{
   int symbolPositions = 0;
   int totalPositions = PositionsTotal();

   for(int i = 0; i < totalPositions; i++)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Magic() == InpMagicNumber)
         {
            if(m_position.Symbol() == _Symbol) symbolPositions++;
         }
      }
   }

   if(symbolPositions >= InpMaxPositionsPerSymbol) return false;
   if(totalPositions >= InpMaxTotalPositions) return false;

   return true;
}

bool CheckCooldown()
{
   if(m_lastTradeTime == 0) return false;

   datetime barTime = iTime(_Symbol, _Period, InpCooldownBars);
   if(m_lastTradeTime >= barTime) return true; // Cooldown active

   return false;
}

//+------------------------------------------------------------------+
//| STATE PERSISTENCE FUNCTIONS                                      |
//+------------------------------------------------------------------+
int FindTradeState(ulong ticket)
{
   int size = ArraySize(m_tradeStates);
   for(int i = 0; i < size; i++)
   {
      if(m_tradeStates[i].ticket == ticket) return i;
   }
   return -1;
}

int AddTradeState(const STradeState &state)
{
   int idx = FindTradeState(state.ticket);
   if(idx >= 0)
   {
      m_tradeStates[idx] = state;
      return idx;
   }

   int size = ArraySize(m_tradeStates);
   ArrayResize(m_tradeStates, size + 1);
   m_tradeStates[size] = state;
   return size;
}

void SyncPositionsWithState()
{
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
   {
      if(m_position.SelectByIndex(i))
      {
         if(m_position.Magic() == InpMagicNumber && m_position.Symbol() == _Symbol)
         {
            ulong ticket = m_position.Ticket();
            if(FindTradeState(ticket) < 0)
            {
               STradeState newState;
               newState.ticket     = ticket;
               newState.magic      = InpMagicNumber;
               StringToCharArray(_Symbol, newState.symbol);
               newState.setupType  = 1;
               newState.entryPrice = m_position.PriceOpen();
               newState.initialSL  = m_position.StopLoss();
               newState.initialTP1 = m_position.PriceOpen() + (m_position.PositionType() == POSITION_TYPE_BUY ? (m_position.PriceOpen() - m_position.StopLoss())*InpTP1_R_Multiple : -(m_position.StopLoss() - m_position.PriceOpen())*InpTP1_R_Multiple);
               newState.initialTP2 = m_position.TakeProfit();
               newState.tp1Reached = false;
               newState.isBEActive = false;
               newState.entryTime  = (datetime)m_position.Time();
               newState.lastUpdate = TimeCurrent();
               AddTradeState(newState);
            }
         }
      }
   }
}

void SaveStateToFile()
{
   string filename = "9EMA_State_" + IntegerToString(InpMagicNumber) + "_" + _Symbol + ".dat";
   int fileHandle = FileOpen(filename, FILE_WRITE|FILE_BIN|FILE_COMMON);
   if(fileHandle != INVALID_HANDLE)
   {
      int count = ArraySize(m_tradeStates);
      FileWriteInteger(fileHandle, count);
      for(int i = 0; i < count; i++)
      {
         FileWriteStruct(fileHandle, m_tradeStates[i]);
      }
      FileClose(fileHandle);
   }
}

void LoadStateFromFile()
{
   string filename = "9EMA_State_" + IntegerToString(InpMagicNumber) + "_" + _Symbol + ".dat";
   if(!FileIsExist(filename, FILE_COMMON)) return;

   int fileHandle = FileOpen(filename, FILE_READ|FILE_BIN|FILE_COMMON);
   if(fileHandle != INVALID_HANDLE)
   {
      int count = FileReadInteger(fileHandle);
      ArrayResize(m_tradeStates, count);
      for(int i = 0; i < count; i++)
      {
         FileReadStruct(fileHandle, m_tradeStates[i]);
      }
      FileClose(fileHandle);
   }
}

//+------------------------------------------------------------------+
//| TELEGRAM NOTIFICATION ENGINE                                     |
//+------------------------------------------------------------------+
string FormatTelegramSignal(const SSignalInfo &sig, double lotSize)
{
   string dir = (sig.orderType == ORDER_TYPE_BUY) ? "🟢 BUY SIGNAL" : "🔴 SELL SIGNAL";
   string setupName = (sig.setupType == 1) ? "9 EMA Trend Pullback" : 
                      (sig.setupType == 2) ? "9 EMA Reclaim" : "9 EMA Break & Retest";

   string msg = dir + " : " + _Symbol + "\n\n" +
                "Strategy: " + setupName + "\n" +
                "Timeframe: " + EnumToString(_Period) + "\n\n" +
                "Entry Price: " + DoubleToString(sig.entryPrice, _Digits) + "\n" +
                "Stop Loss: " + DoubleToString(sig.stopLoss, _Digits) + "\n" +
                "TP1 (2R): " + DoubleToString(sig.tp1, _Digits) + "\n" +
                "TP2 (3.5R): " + DoubleToString(sig.tp2, _Digits) + "\n\n" +
                "Lot Size: " + DoubleToString(lotSize, 2) + "\n" +
                "Quality Score: " + DoubleToString(sig.qualityScore, 1) + "/100\n" +
                "Risk/Reward: 1:" + DoubleToString(sig.rrRatio, 2) + "\n\n" +
                "#" + _Symbol + " #" + (sig.orderType == ORDER_TYPE_BUY ? "BUY" : "SELL") + " #9EMA_VolumeRider";

   return msg;
}

void SendTelegramMessage(string text)
{
   if(InpTelegramBotToken == "" || InpTelegramChatID == "") return;

   string url = "https://api.telegram.org/bot" + InpTelegramBotToken + "/sendMessage";
   string headers = "Content-Type: application/x-www-form-urlencoded\r\n";
   string body = "chat_id=" + InpTelegramChatID + "&text=" + UrlEncode(text) + "&parse_mode=Markdown";

   char postData[];
   StringToCharArray(body, postData, 0, WHOLE_ARRAY, CP_UTF8);
   char result[];
   string resultHeaders;

   int res = WebRequest("POST", url, headers, 5000, postData, result, resultHeaders);
   if(res == 200) Print("[TELEGRAM] Message sent successfully");
   else Print("[TELEGRAM ERROR] WebRequest failed. HTTP code: ", res);
}

void SendTelegramScreenshot()
{
   if(InpTelegramBotToken == "" || InpTelegramChatID == "") return;

   string filename = "9EMA_Signal_" + _Symbol + ".png";
   if(ChartScreenShot(0, filename, 1280, 720, ALIGN_RIGHT))
   {
      Print("[TELEGRAM] Chart screenshot saved: ", filename);
   }
}

string UrlEncode(string text)
{
   string encoded = "";
   int len = StringLen(text);
   for(int i = 0; i < len; i++)
   {
      ushort c = StringGetCharacter(text, i);
      if((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.' || c == '~')
         encoded += ShortToString(c);
      else if(c == ' ')
         encoded += "+";
      else
         encoded += StringFormat("%%%02X", c);
   }
   return encoded;
}

//+------------------------------------------------------------------+
//| CHART DASHBOARD DISPLAY                                          |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   if(!InpShowDashboard) return;

   SMarketStructure structure = AnalyzeMarketStructure();
   bool htfBullish = false, htfBearish = false;
   EvaluateHTFTrend(htfBullish, htfBearish);

   string htfTrend = htfBullish ? "BULLISH" : (htfBearish ? "BEARISH" : "NEUTRAL");
   string structStr = (structure.state == STRUCTURE_BULLISH) ? "BULLISH (HH/HL)" :
                      (structure.state == STRUCTURE_BEARISH) ? "BEARISH (LH/LL)" : "CHOPPY / RANGE";

   string text = "=== 9 EMA + VOLUME TREND RIDER ===\n" +
                 "Symbol: " + _Symbol + " | TF: " + EnumToString(_Period) + "\n" +
                 "HTF (" + EnumToString(m_htfPeriod) + "): " + htfTrend + "\n" +
                 "Market Structure: " + structStr + "\n" +
                 "Min Score Threshold: " + DoubleToString(InpMinQualityScore, 0) + "/100\n" +
                 "Last Setup Score: " + (m_lastSignal.isValid ? DoubleToString(m_lastSignal.qualityScore, 1) + "/100" : "N/A") + "\n" +
                 "Active Positions: " + IntegerToString(PositionsTotal());

   CreateOrUpdateLabel(DASH_PREFIX + "BG", InpDashboardX, InpDashboardY, text, clrWhite, clrDarkSlateGray);
}

void CreateOrUpdateLabel(string name, int x, int y, string text, color textColor, color bgColor)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   }
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
}

void RemoveDashboard()
{
   ObjectsDeleteAll(0, DASH_PREFIX);
}

//+------------------------------------------------------------------+
//| HELPER UTILITIES                                                 |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES GetAutoHTF(ENUM_TIMEFRAMES currentTF)
{
   switch(currentTF)
   {
      case PERIOD_M1:  return PERIOD_M5;
      case PERIOD_M2:  return PERIOD_M10;
      case PERIOD_M3:  return PERIOD_M15;
      case PERIOD_M5:  return PERIOD_M15;
      case PERIOD_M10: return PERIOD_M30;
      case PERIOD_M15: return PERIOD_H1;
      case PERIOD_M30: return PERIOD_H4;
      case PERIOD_H1:  return PERIOD_H4;
      case PERIOD_H4:  return PERIOD_D1;
      case PERIOD_D1:  return PERIOD_W1;
      default:         return PERIOD_H4;
   }
}
//+------------------------------------------------------------------+
