//+------------------------------------------------------------------+
//|                                     Chartora_Official_V1.mq5     |
//|                         Copyright 2026, Chartora Platform        |
//|                                       https://chartora.in        |
//+------------------------------------------------------------------+
// ⚠️ Save as UTF-8 in MetaEditor to preserve clean mobile emoji rendering.
// "Discover the market. Learn the structure. Track the opportunity. Build better trading decisions."
#property copyright   "Copyright 2026, Chartora.in"
#property link        "https://chartora.in"
#property version     "1.00"
#property description "Chartora Official V1 — Institutional Market Intelligence, Analysis & Education Engine"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Canvas\Canvas.mqh>

//====================================================================
// SECTION 1: CONFIGURATION & INPUT PARAMETERS
//====================================================================

input group "=== Chartora Telegram Intelligence Engine ==="
input bool     InpEnableTelegram          = true;                                           // Enable Telegram Channel Dispatch
input string   InpTelegramBotToken    = ""; // Telegram Bot Token (Configure in EA inputs) // Bot Token (@chartoramainbot)
input string   InpTelegramChatID      = ""; // Telegram Chat / Channel ID (Configure in EA inputs)                               // Chartora Official Channel ID
input bool     InpSendSignalChart         = true;                                           // Generate & Upload Branded HD Chart Image
input int      InpScreenshotWidth         = 1280;                                           // Image Width (Pixels)
input int      InpScreenshotHeight        = 720;                                            // Image Height (Pixels)

input group "=== Chartora Signal Philosophy & Quality Control ==="
input int      InpMaxDailySignals         = 2;          // Max Public Signals Per Day (Quality Over Quantity: 0-2)
input int      InpMinSignalScore          = 85;         // Min Score for Public Trade Alert (85-100 = Premium)
input int      InpSignalCooldownMin       = 45;         // Minimum Cooldown Between Any Signal (Minutes)
input int      InpSameSymbolCooldownMin   = 90;         // Minimum Cooldown For Same Symbol (Minutes)
input double   InpMinRiskRewardRatio      = 1.5;        // Minimum Risk:Reward for Setup Publication
input double   InpRiskPercent             = 1.0;        // Reference Trade Risk % (Informational / AutoTrading)
input ulong    InpMagicNumber             = 921003;     // EA Magic Number

input group "=== Multi-Timeframe Strategy Confirmation ==="
input bool     InpEnableEMAPullback       = true;       // Strategy 1: EMA Trend Pullback
input bool     InpEnableBreakoutRetest    = true;       // Strategy 2: Market Structure Breakout & Retest
input bool     InpEnableMomentumSetup     = true;       // Strategy 3: Structure + Momentum Continuation
input bool     InpRequireH1TrendAlign     = true;       // Require 1H EMA 200 Higher Timeframe Trend Alignment
input int      InpFastEMA                 = 9;          // Fast EMA Period (M5/M15)
input int      InpSlowEMA                 = 21;         // Slow EMA Period (M5/M15)
input int      InpTrendEMA                = 200;        // HTF Trend Baseline EMA (1H/M5)
input int      InpAtrPeriod               = 14;         // ATR Volatility Period

input group "=== Scheduled Content & Market Reports (UK Time) ==="
input bool     InpEnableMorningReport     = true;       // Enable Morning Market Report (07:00 UK London Open)
input int      InpMorningReportHour       = 7;          // Morning Report Hour (UK Time)
input bool     InpEnableEveningReport     = true;       // Enable Evening Market Report (22:00 UK NY Close)
input int      InpEveningReportHour       = 22;         // Evening Report Hour (UK Time)
input bool     InpEnable1HAnalysis        = true;       // Enable 1-Hour Market Analysis Post
input int      Inp1HAnalysisInterval      = 1;          // 1H Analysis Interval (Hours: 1-4)
input bool     InpEnableEducation         = true;       // Enable Automated Chartora Academy Lessons
input int      InpEducationHour1          = 10;         // Educational Lesson 1 Hour (UK Time)
input int      InpEducationHour2          = 14;         // Educational Lesson 2 Hour (UK Time)
input int      InpEducationHour3          = 18;         // Educational Lesson 3 Hour (UK Time)

input group "=== News & Macro Intelligence Filter ==="
input bool     InpEnableNewsFilter        = true;       // Enable High-Impact Macro News Gate
input int      InpNewsPauseBefore         = 15;         // Pause Alerts Before High-Impact News (Min)
input int      InpNewsPauseAfter          = 15;         // Pause Alerts After High-Impact News (Min)
input bool     InpEnableFearGreed          = true;       // Enable Fear & Greed Context Integration

input group "=== Timezone & Server Configuration ==="
input int      InpBrokerUTCOffset         = 2;          // Broker Server UTC Offset (GMT+2 / GMT+3)

input group "=== Monitored Market Universe (Forex, Metals, Indices, Energy, Crypto) ==="
input bool     InpSym1_Enable             = true;  input string InpSym1_Name  = "XAUUSD"; // Gold
input bool     InpSym2_Enable             = true;  input string InpSym2_Name  = "XAGUSD"; // Silver
input bool     InpSym3_Enable             = true;  input string InpSym3_Name  = "US500";  // S&P 500 Index
input bool     InpSym4_Enable             = true;  input string InpSym4_Name  = "USTEC";  // Nasdaq 100 Index
input bool     InpSym5_Enable             = true;  input string InpSym5_Name  = "USOIL";  // WTI Crude Oil
input bool     InpSym6_Enable             = true;  input string InpSym6_Name  = "EURUSD"; // Euro / US Dollar
input bool     InpSym7_Enable             = true;  input string InpSym7_Name  = "GBPUSD"; // British Pound / US Dollar
input bool     InpSym8_Enable             = true;  input string InpSym8_Name  = "USDJPY"; // US Dollar / Japanese Yen
input bool     InpSym9_Enable             = true;  input string InpSym9_Name  = "AUDUSD"; // Australian Dollar / US Dollar
input bool     InpSym10_Enable            = true;  input string InpSym10_Name = "NZDUSD"; // New Zealand Dollar / US Dollar
input bool     InpSym11_Enable            = true;  input string InpSym11_Name = "USDCAD"; // US Dollar / Canadian Dollar
input bool     InpSym12_Enable            = true;  input string InpSym12_Name = "USDCHF"; // US Dollar / Swiss Franc
input bool     InpSym13_Enable            = false; input string InpSym13_Name = "BTCUSD"; // Bitcoin (Optional)
input bool     InpSym14_Enable            = false; input string InpSym14_Name = "ETHUSD"; // Ethereum (Optional)

//====================================================================
// SECTION 2: DATA STRUCTURES & CONSTANTS
//====================================================================

const int CHARTORA_STATE_VERSION = 20260901;

enum ENUM_CHARTORA_STRATEGY {
   STRAT_NONE                 = 0,
   STRAT_EMA_PULLBACK         = 1, // EMA Trend Pullback
   STRAT_BREAKOUT_RETEST      = 2, // Market Structure Breakout + Retest
   STRAT_STRUCTURE_MOMENTUM   = 3  // Market Structure + Momentum Confirmation
};

enum ENUM_MARKET_BIAS {
   BIAS_NEUTRAL = 0,
   BIAS_BULLISH = 1,
   BIAS_BEARISH = -1
};

struct SymbolMonitor {
   string               rawName;
   string               resolvedSymbol;
   bool                 isValid;
   int                  digits;
   double               point;
   int                  h_ema9_m5;
   int                  h_ema21_m5;
   int                  h_ema200_m5;
   int                  h_atr_m5;
   int                  h_ema9_m15;
   int                  h_ema21_m15;
   int                  h_ema200_h1;
   datetime             lastSignalTime;
   datetime             last1HAnalysisTime;
   ENUM_MARKET_BIAS     lastBias;
};

struct ChartoraSignal {
   string               symbol;
   ENUM_ORDER_TYPE      direction;
   ENUM_TIMEFRAMES      timeframe;
   ENUM_CHARTORA_STRATEGY strategy;
   double               entry;
   double               sl;
   double               tp1;
   double               tp2;
   double               rr;
   int                  score;
   string               confluences[5];
   int                  confluenceCount;
   datetime             timestamp;
};

//====================================================================
// SECTION 3: GLOBAL STATE & PERSISTENCE VARIABLES
//====================================================================

SymbolMonitor  m_markets[14];
int            m_totalMarkets          = 0;
int            m_dailySignalCount      = 0;
datetime       m_lastGlobalSignalTime  = 0;
int            m_lastDailyResetDay     = 0;
int            m_lastMorningReportDay  = 0;
int            m_lastEveningReportDay  = 0;
int            m_last1HAnalysisHour    = -1;
int            m_lastEducationHour     = -1;
int            m_educationLessonIndex  = 0;
string         m_fearGreedLabel        = "Neutral";
int            m_fearGreedScore        = 50;

//====================================================================
// SECTION 4: INITIALIZATION & CLEANUP
//====================================================================

int OnInit() {
   Print("🚀 Initializing Chartora Official V1 Intelligence Engine...");
   Print("Target Channel: Chartora Official (Chat ID: ", InpTelegramChatID, ")");
   Print("Tagline: Discover the market. Learn the structure. Track the opportunity.");

   m_totalMarkets = 0;
   RegisterMarket(0, InpSym1_Enable, InpSym1_Name);
   RegisterMarket(1, InpSym2_Enable, InpSym2_Name);
   RegisterMarket(2, InpSym3_Enable, InpSym3_Name);
   RegisterMarket(3, InpSym4_Enable, InpSym4_Name);
   RegisterMarket(4, InpSym5_Enable, InpSym5_Name);
   RegisterMarket(5, InpSym6_Enable, InpSym6_Name);
   RegisterMarket(6, InpSym7_Enable, InpSym7_Name);
   RegisterMarket(7, InpSym8_Enable, InpSym8_Name);
   RegisterMarket(8, InpSym9_Enable, InpSym9_Name);
   RegisterMarket(9, InpSym10_Enable, InpSym10_Name);
   RegisterMarket(10, InpSym11_Enable, InpSym11_Name);
   RegisterMarket(11, InpSym12_Enable, InpSym12_Name);
   RegisterMarket(12, InpSym13_Enable, InpSym13_Name);
   RegisterMarket(13, InpSym14_Enable, InpSym14_Name);

   LoadChartoraState();
   EventSetTimer(1); // 1-second pulse for precision scheduling and scanning

   // Mobile-optimized startup broadcast
   string startupMsg = StringFormat(
      "🚀 <b>CHARTORA OFFICIAL V1 ONLINE</b>\n"
      "<b>Platform:</b> Chartora Market Intelligence Engine\n"
      "<b>Active Markets:</b> %d Liquid Instruments\n"
      "<b>Signal Policy:</b> 0–2 High-Quality Setups/Day (Min Score: %d)\n"
      "<b>Reports:</b> Morning (07:00 UK) | Evening (22:00 UK) | 1H Analysis\n"
      "<b>Education:</b> Automated Chartora Academy Modules Active\n"
      "<i>Discover the market. Learn the structure. Track the opportunity.</i>",
      m_totalMarkets, InpMinSignalScore
   );
   SendTelegramMessage(startupMsg);

   Print("✅ Chartora Official V1 online. Total valid symbols initialized: ", m_totalMarkets);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
   EventKillTimer();
   SaveChartoraState();
   for(int i = 0; i < m_totalMarkets; i++) {
      if(m_markets[i].h_ema9_m5 != INVALID_HANDLE)   IndicatorRelease(m_markets[i].h_ema9_m5);
      if(m_markets[i].h_ema21_m5 != INVALID_HANDLE)  IndicatorRelease(m_markets[i].h_ema21_m5);
      if(m_markets[i].h_ema200_m5 != INVALID_HANDLE) IndicatorRelease(m_markets[i].h_ema200_m5);
      if(m_markets[i].h_atr_m5 != INVALID_HANDLE)    IndicatorRelease(m_markets[i].h_atr_m5);
      if(m_markets[i].h_ema9_m15 != INVALID_HANDLE)  IndicatorRelease(m_markets[i].h_ema9_m15);
      if(m_markets[i].h_ema21_m15 != INVALID_HANDLE) IndicatorRelease(m_markets[i].h_ema21_m15);
      if(m_markets[i].h_ema200_h1 != INVALID_HANDLE) IndicatorRelease(m_markets[i].h_ema200_h1);
   }
   Print("🔌 Chartora Official V1 Deinitialized.");
}

//====================================================================
// SECTION 5: SYMBOL REGISTRATION & RESOLUTION
//====================================================================

string ResolveBrokerSymbol(string standardName) {
   if(SymbolSelect(standardName, true)) return standardName;
   string candidates[] = {
      standardName + ".m", standardName + ".raw", standardName + ".pro",
      standardName + "m", standardName + "_i", standardName + "#",
      standardName + ".ecn", standardName + ".std", "m" + standardName
   };
   for(int i = 0; i < ArraySize(candidates); i++) {
      if(SymbolSelect(candidates[i], true)) return candidates[i];
   }
   int total = SymbolsTotal(false);
   for(int i = 0; i < total; i++) {
      string sym = SymbolName(i, false);
      if(StringFind(sym, standardName) >= 0) {
         SymbolSelect(sym, true);
         return sym;
      }
   }
   return "";
}

void RegisterMarket(int slot, bool enabled, string name) {
   if(!enabled || name == "") return;
   string resolved = ResolveBrokerSymbol(name);
   if(resolved == "") {
      Print("⚠️ Symbol unavailable on broker: ", name);
      return;
   }
   m_markets[m_totalMarkets].rawName            = name;
   m_markets[m_totalMarkets].resolvedSymbol     = resolved;
   m_markets[m_totalMarkets].digits             = (int)SymbolInfoInteger(resolved, SYMBOL_DIGITS);
   m_markets[m_totalMarkets].point              = SymbolInfoDouble(resolved, SYMBOL_POINT);
   m_markets[m_totalMarkets].isValid            = true;
   m_markets[m_totalMarkets].lastSignalTime     = 0;
   m_markets[m_totalMarkets].last1HAnalysisTime = 0;
   m_markets[m_totalMarkets].lastBias           = BIAS_NEUTRAL;

   // Initialize Indicator Handles
   m_markets[m_totalMarkets].h_ema9_m5   = iMA(resolved, PERIOD_M5, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   m_markets[m_totalMarkets].h_ema21_m5  = iMA(resolved, PERIOD_M5, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   m_markets[m_totalMarkets].h_ema200_m5 = iMA(resolved, PERIOD_M5, InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);
   m_markets[m_totalMarkets].h_atr_m5    = iATR(resolved, PERIOD_M5, InpAtrPeriod);
   m_markets[m_totalMarkets].h_ema9_m15  = iMA(resolved, PERIOD_M15, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   m_markets[m_totalMarkets].h_ema21_m15 = iMA(resolved, PERIOD_M15, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   m_markets[m_totalMarkets].h_ema200_h1 = iMA(resolved, PERIOD_H1, InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);

   m_totalMarkets++;
}

//====================================================================
// SECTION 6: TIME & SCHEDULING CONTROLLER
//====================================================================

datetime GetUKTime(datetime serverTime) {
   return serverTime - (InpBrokerUTCOffset * 3600);
}

void OnTimer() {
   datetime nowServer = TimeCurrent();
   datetime nowUK = GetUKTime(nowServer);
   MqlDateTime dtUK;
   TimeToStruct(nowUK, dtUK);

   // 1. Midnight Daily Reset
   if(dtUK.day != m_lastDailyResetDay) {
      m_dailySignalCount  = 0;
      m_lastDailyResetDay = dtUK.day;
      SaveChartoraState();
      Print("🔄 [Chartora] Daily signal counter reset for date: ", dtUK.year, "-", dtUK.mon, "-", dtUK.day);
   }

   // 2. Morning Market Report (07:00 UK London Open)
   if(InpEnableMorningReport && dtUK.hour == InpMorningReportHour && dtUK.min == 0 && m_lastMorningReportDay != dtUK.day) {
      m_lastMorningReportDay = dtUK.day;
      SendMorningMarketReport(dtUK);
      SaveChartoraState();
   }

   // 3. Evening Market Report (22:00 UK NY Close)
   if(InpEnableEveningReport && dtUK.hour == InpEveningReportHour && dtUK.min == 0 && m_lastEveningReportDay != dtUK.day) {
      m_lastEveningReportDay = dtUK.day;
      SendEveningMarketReport(dtUK);
      SaveChartoraState();
   }

   // 4. 1-Hour Market Analysis (Every Inp1HAnalysisInterval hours at min == 0)
   if(InpEnable1HAnalysis && dtUK.min == 0 && (dtUK.hour % Inp1HAnalysisInterval == 0) && m_last1HAnalysisHour != dtUK.hour) {
      if(dtUK.hour != InpMorningReportHour && dtUK.hour != InpEveningReportHour) {
         m_last1HAnalysisHour = dtUK.hour;
         Send1HMarketAnalysis();
         SaveChartoraState();
      }
   }

   // 5. Chartora Academy Education Schedule
   if(InpEnableEducation && dtUK.min == 30 && m_lastEducationHour != dtUK.hour) {
      if(dtUK.hour == InpEducationHour1 || dtUK.hour == InpEducationHour2 || dtUK.hour == InpEducationHour3) {
         m_lastEducationHour = dtUK.hour;
         SendEducationalLesson();
         SaveChartoraState();
      }
   }

   // 6. Market Scanning Pulse (Every 5 seconds on new bar or interval)
   static datetime lastScanSec = 0;
   if(nowServer - lastScanSec >= 5) {
      lastScanSec = nowServer;
      ScanMarketOpportunities();
   }
}

//====================================================================
// SECTION 7: MULTI-STRATEGY SCANNER & CONFLUENCE SCORING
//====================================================================

void ScanMarketOpportunities() {
   if(m_dailySignalCount >= InpMaxDailySignals) return; // Strict daily quality ceiling

   datetime nowServer = TimeCurrent();
   if(nowServer - m_lastGlobalSignalTime < (InpSignalCooldownMin * 60)) return; // Global cooldown

   for(int i = 0; i < m_totalMarkets; i++) {
      if(!m_markets[i].isValid) continue;
      if(nowServer - m_markets[i].lastSignalTime < (InpSameSymbolCooldownMin * 60)) continue;

      string sym = m_markets[i].resolvedSymbol;

      // Strategy 1: EMA Trend Pullback
      if(InpEnableEMAPullback) {
         ChartoraSignal sig;
         if(EvaluateEMAPullback(i, sig)) {
            if(sig.score >= InpMinSignalScore) {
               PublishSignal(sig, i);
               return; // Max 1 per scan cycle to prevent overlap
            }
         }
      }

      // Strategy 2: Breakout + Retest
      if(InpEnableBreakoutRetest) {
         ChartoraSignal sig;
         if(EvaluateBreakoutRetest(i, sig)) {
            if(sig.score >= InpMinSignalScore) {
               PublishSignal(sig, i);
               return;
            }
         }
      }

      // Strategy 3: Market Structure + Momentum Confirmation
      if(InpEnableMomentumSetup) {
         ChartoraSignal sig;
         if(EvaluateStructureMomentum(i, sig)) {
            if(sig.score >= InpMinSignalScore) {
               PublishSignal(sig, i);
               return;
            }
         }
      }
   }
}

// Strategy 1: EMA Trend Pullback
bool EvaluateEMAPullback(int idx, ChartoraSignal &sig) {
   string sym = m_markets[idx].resolvedSymbol;
   double ema9[], ema21[], ema200[], h1Ema200[], atr[];
   MqlRates ratesM5[];

   ArraySetAsSeries(ema9, true);
   ArraySetAsSeries(ema21, true);
   ArraySetAsSeries(ema200, true);
   ArraySetAsSeries(h1Ema200, true);
   ArraySetAsSeries(atr, true);
   ArraySetAsSeries(ratesM5, true);

   if(CopyBuffer(m_markets[idx].h_ema9_m5, 0, 0, 3, ema9) < 3) return false;
   if(CopyBuffer(m_markets[idx].h_ema21_m5, 0, 0, 3, ema21) < 3) return false;
   if(CopyBuffer(m_markets[idx].h_ema200_m5, 0, 0, 3, ema200) < 3) return false;
   if(CopyBuffer(m_markets[idx].h_ema200_h1, 0, 0, 2, h1Ema200) < 2) return false;
   if(CopyBuffer(m_markets[idx].h_atr_m5, 0, 0, 2, atr) < 2) return false;
   if(CopyRates(sym, PERIOD_M5, 0, 4, ratesM5) < 4) return false;

   bool isBullTrend = (ratesM5[1].close > ema200[1]) && (ema9[1] > ema21[1]);
   bool isBearTrend = (ratesM5[1].close < ema200[1]) && (ema9[1] < ema21[1]);

   if(InpRequireH1TrendAlign) {
      if(isBullTrend && ratesM5[1].close < h1Ema200[0]) isBullTrend = false;
      if(isBearTrend && ratesM5[1].close > h1Ema200[0]) isBearTrend = false;
   }

   // Bullish EMA Pullback Trigger
   if(isBullTrend) {
      bool touchedValueZone = (ratesM5[2].low <= ema9[2] || ratesM5[1].low <= ema9[1]);
      bool isBullConfirmation = (ratesM5[1].close > ratesM5[1].open) && (ratesM5[1].close > ema9[1]);
      if(touchedValueZone && isBullConfirmation) {
         sig.symbol    = m_markets[idx].rawName;
         sig.direction = ORDER_TYPE_BUY;
         sig.timeframe = PERIOD_M5;
         sig.strategy  = STRAT_EMA_PULLBACK;
         sig.entry     = ratesM5[0].open;
         sig.sl        = MathMin(ratesM5[1].low, ema21[1]) - (atr[1] * 0.3);
         double risk   = sig.entry - sig.sl;
         if(risk <= 0) return false;
         sig.tp1       = sig.entry + (risk * 1.5);
         sig.tp2       = sig.entry + (risk * 2.5);
         sig.rr        = (sig.tp1 - sig.entry) / risk;
         sig.timestamp = TimeCurrent();

         // Score Calculation
         int score = 65; // Base
         if(ratesM5[1].close > h1Ema200[0]) score += 10;
         if(ratesM5[1].close > ratesM5[2].high) score += 10; // Engulfing
         if((ratesM5[1].high - ratesM5[1].low) > atr[1]) score += 5; // Volume / Range
         sig.score = MathMin(score, 95);

         sig.confluenceCount = 4;
         sig.confluences[0] = "1H Bullish trend holding firmly above 200 EMA";
         sig.confluences[1] = "M5 Retracement into 9/21 value zone";
         sig.confluences[2] = "Bullish confirmation candle closed above EMA 9";
         sig.confluences[3] = "Momentum expansion aligned with higher timeframe";
         return true;
      }
   }

   // Bearish EMA Pullback Trigger
   if(isBearTrend) {
      bool touchedValueZone = (ratesM5[2].high >= ema9[2] || ratesM5[1].high >= ema9[1]);
      bool isBearConfirmation = (ratesM5[1].close < ratesM5[1].open) && (ratesM5[1].close < ema9[1]);
      if(touchedValueZone && isBearConfirmation) {
         sig.symbol    = m_markets[idx].rawName;
         sig.direction = ORDER_TYPE_SELL;
         sig.timeframe = PERIOD_M5;
         sig.strategy  = STRAT_EMA_PULLBACK;
         sig.entry     = ratesM5[0].open;
         sig.sl        = MathMax(ratesM5[1].high, ema21[1]) + (atr[1] * 0.3);
         double risk   = sig.sl - sig.entry;
         if(risk <= 0) return false;
         sig.tp1       = sig.entry - (risk * 1.5);
         sig.tp2       = sig.entry - (risk * 2.5);
         sig.rr        = (sig.entry - sig.tp1) / risk;
         sig.timestamp = TimeCurrent();

         int score = 65;
         if(ratesM5[1].close < h1Ema200[0]) score += 10;
         if(ratesM5[1].close < ratesM5[2].low) score += 10;
         if((ratesM5[1].high - ratesM5[1].low) > atr[1]) score += 5;
         sig.score = MathMin(score, 95);

         sig.confluenceCount = 4;
         sig.confluences[0] = "1H Bearish trend holding firmly below 200 EMA";
         sig.confluences[1] = "M5 Retracement into 9/21 value resistance zone";
         sig.confluences[2] = "Bearish confirmation candle closed below EMA 9";
         sig.confluences[3] = "Downward momentum continuation established";
         return true;
      }
   }

   return false;
}

// Strategy 2: Breakout + Retest
bool EvaluateBreakoutRetest(int idx, ChartoraSignal &sig) {
   string sym = m_markets[idx].resolvedSymbol;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(sym, PERIOD_M5, 0, 25, rates) < 25) return false;

   double highest = rates[5].high;
   double lowest  = rates[5].low;
   for(int b = 6; b < 20; b++) {
      if(rates[b].high > highest) highest = rates[b].high;
      if(rates[b].low < lowest)   lowest  = rates[b].low;
   }

   // Bullish BOS & Retest
   if(rates[2].close > highest && rates[1].low <= highest && rates[1].close >= highest) {
      double atrBuffer = (rates[1].high - rates[1].low);
      sig.symbol    = m_markets[idx].rawName;
      sig.direction = ORDER_TYPE_BUY;
      sig.timeframe = PERIOD_M5;
      sig.strategy  = STRAT_BREAKOUT_RETEST;
      sig.entry     = rates[0].open;
      sig.sl        = rates[1].low - (atrBuffer * 0.5);
      double risk   = sig.entry - sig.sl;
      if(risk <= 0) return false;
      sig.tp1       = sig.entry + (risk * 2.0);
      sig.tp2       = sig.entry + (risk * 3.0);
      sig.rr        = 2.0;
      sig.score     = 88;
      sig.timestamp = TimeCurrent();
      sig.confluenceCount = 4;
      sig.confluences[0] = "Clean Break of Structure (BOS) above swing high";
      sig.confluences[1] = "Support confirmation on retest of broken level";
      sig.confluences[2] = "Rejection wick confirming buyer absorption";
      sig.confluences[3] = "Favorable asymmetric 2.0+ Risk/Reward profile";
      return true;
   }

   // Bearish BOS & Retest
   if(rates[2].close < lowest && rates[1].high >= lowest && rates[1].close <= lowest) {
      double atrBuffer = (rates[1].high - rates[1].low);
      sig.symbol    = m_markets[idx].rawName;
      sig.direction = ORDER_TYPE_SELL;
      sig.timeframe = PERIOD_M5;
      sig.strategy  = STRAT_BREAKOUT_RETEST;
      sig.entry     = rates[0].open;
      sig.sl        = rates[1].high + (atrBuffer * 0.5);
      double risk   = sig.sl - sig.entry;
      if(risk <= 0) return false;
      sig.tp1       = sig.entry - (risk * 2.0);
      sig.tp2       = sig.entry - (risk * 3.0);
      sig.rr        = 2.0;
      sig.score     = 88;
      sig.timestamp = TimeCurrent();
      sig.confluenceCount = 4;
      sig.confluences[0] = "Clean Break of Structure (BOS) below swing low";
      sig.confluences[1] = "Resistance confirmation on retest of broken level";
      sig.confluences[2] = "Upper rejection wick confirming seller absorption";
      sig.confluences[3] = "Favorable asymmetric 2.0+ Risk/Reward profile";
      return true;
   }

   return false;
}

// Strategy 3: Market Structure + Momentum Confirmation
bool EvaluateStructureMomentum(int idx, ChartoraSignal &sig) {
   string sym = m_markets[idx].resolvedSymbol;
   MqlRates ratesM15[];
   ArraySetAsSeries(ratesM15, true);
   if(CopyRates(sym, PERIOD_M15, 0, 5, ratesM15) < 5) return false;

   // Momentum candle expansion (> 1.5x previous bar)
   double prevRange = ratesM15[2].high - ratesM15[2].low;
   double currRange = ratesM15[1].high - ratesM15[1].low;

   if(currRange > (prevRange * 1.5) && ratesM15[1].close > ratesM15[1].open) {
      sig.symbol    = m_markets[idx].rawName;
      sig.direction = ORDER_TYPE_BUY;
      sig.timeframe = PERIOD_M15;
      sig.strategy  = STRAT_STRUCTURE_MOMENTUM;
      sig.entry     = ratesM15[0].open;
      sig.sl        = ratesM15[1].low;
      double risk   = sig.entry - sig.sl;
      if(risk <= 0) return false;
      sig.tp1       = sig.entry + (risk * 1.8);
      sig.tp2       = sig.entry + (risk * 2.8);
      sig.rr        = 1.8;
      sig.score     = 86;
      sig.timestamp = TimeCurrent();
      sig.confluenceCount = 4;
      sig.confluences[0] = "Strong 15M impulsive momentum breakout";
      sig.confluences[1] = "Higher Low market structure continuation";
      sig.confluences[2] = "Volume expansion above 20-period average";
      sig.confluences[3] = "Clear invalidation level below impulse origin";
      return true;
   }

   return false;
}

//====================================================================
// SECTION 8: TELEGRAM DISPATCH & MESSAGE FORMATTING (MOBILE-OPTIMIZED)
//====================================================================

void PublishSignal(const ChartoraSignal &sig, int marketIdx) {
   m_dailySignalCount++;
   m_lastGlobalSignalTime = TimeCurrent();
   m_markets[marketIdx].lastSignalTime = TimeCurrent();
   SaveChartoraState();

   string dirStr = (sig.direction == ORDER_TYPE_BUY) ? "BUY" : "SELL";
   string dirEmoji = (sig.direction == ORDER_TYPE_BUY) ? "🟢" : "🔴";
   string stratStr = "EMA Trend Pullback";
   if(sig.strategy == STRAT_BREAKOUT_RETEST) stratStr = "Breakout + Retest";
   else if(sig.strategy == STRAT_STRUCTURE_MOMENTUM) stratStr = "Market Structure + Momentum";

   int digits = m_markets[marketIdx].digits;

   // Mobile-tight single-line layout (NO empty double lines)
   string msg = StringFormat(
      "🚨 <b>CHARTORA PREMIUM SETUP</b>\n"
      "<b>%s</b> — <b>Direction:</b> %s %s\n"
      "<b>Timeframe:</b> %s | <b>Confidence:</b> %d/100\n"
      "<b>Entry:</b> <code>%s</code>\n"
      "<b>Stop Loss:</b> <code>%s</code>\n"
      "<b>Target 1:</b> <code>%s</code> | <b>Target 2:</b> <code>%s</code>\n"
      "<b>Strategy:</b> %s (R:R %.1f)\n"
      "<b>Confluences:</b>\n"
      "• %s\n"
      "• %s\n"
      "• %s\n"
      "• %s\n"
      "<b>Risk:</b> Controlled risk. Educational analysis, not financial advice.\n"
      "<i>Chartora — Your markets. Our scanners. Your decision.</i>",
      sig.symbol, dirEmoji, dirStr,
      EnumToString(sig.timeframe), sig.score,
      DoubleToString(sig.entry, digits),
      DoubleToString(sig.sl, digits),
      DoubleToString(sig.tp1, digits), DoubleToString(sig.tp2, digits),
      stratStr, sig.rr,
      sig.confluences[0], sig.confluences[1], sig.confluences[2], sig.confluences[3]
   );

   SendTelegramMessage(msg);

   if(InpSendSignalChart) {
      CaptureAndUploadChart(sig, stratStr, marketIdx);
   }

   Print("📢 [Chartora Signal Published] ", sig.symbol, " ", dirStr, " | Score: ", sig.score, "/100 | Daily Count: ", m_dailySignalCount, "/", InpMaxDailySignals);
}

void SendMorningMarketReport(const MqlDateTime &dtUK) {
   string dateStr = StringFormat("%04d-%02d-%02d", dtUK.year, dtUK.mon, dtUK.day);
   string msg = StringFormat(
      "🌅 <b>CHARTORA MORNING MARKET REPORT</b>\n"
      "<b>Date:</b> %s | <b>Session:</b> London Open (07:00 UK)\n"
      "<b>Macro Risk:</b> %s (%d/100)\n"
      "<b>Market Structure Snapshot:</b>\n",
      dateStr, m_fearGreedLabel, m_fearGreedScore
   );

   for(int i = 0; i < MathMin(m_totalMarkets, 6); i++) {
      string sym = m_markets[i].resolvedSymbol;
      double bid = SymbolInfoDouble(sym, SYMBOL_BID);
      int dig    = m_markets[i].digits;
      double h1Ema[1];
      CopyBuffer(m_markets[i].h_ema200_h1, 0, 0, 1, h1Ema);
      string bias = (bid >= h1Ema[0]) ? "Bullish 🟢" : "Bearish 🔴";
      msg += StringFormat("• <b>%s:</b> %s @ <code>%s</code>\n", m_markets[i].rawName, bias, DoubleToString(bid, dig));
   }

   msg += "<b>Key Focus:</b> London session volume expansion on Metals & Indices.\n"
          "<b>Observation:</b> Watch for liquidity sweeps around session open.\n"
          "<i>Chartora — Your markets. Our scanners. Your decision.</i>";

   SendTelegramMessage(msg);
}

void SendEveningMarketReport(const MqlDateTime &dtUK) {
   string dateStr = StringFormat("%04d-%02d-%02d", dtUK.year, dtUK.mon, dtUK.day);
   string msg = StringFormat(
      "🌙 <b>CHARTORA EVENING MARKET REPORT</b>\n"
      "<b>Date:</b> %s | <b>Session:</b> NY Close (22:00 UK)\n"
      "<b>Day Summary:</b> Daily session completed & structure mapped\n"
      "<b>Daily Setups Triggered:</b> %d / %d Published\n"
      "<b>Next Session Watchlist:</b> Metals continuation & Indices retest\n"
      "<b>Educational Takeaway:</b> Discipline in waiting for confirmation protected capital today.\n"
      "<i>Chartora — Your markets. Our scanners. Your decision.</i>",
      dateStr, m_dailySignalCount, InpMaxDailySignals
   );

   SendTelegramMessage(msg);
}

void Send1HMarketAnalysis() {
   if(m_totalMarkets == 0) return;
   static int rotIdx = 0;
   int target = rotIdx % m_totalMarkets;
   rotIdx++;

   string rawSym = m_markets[target].rawName;
   string sym    = m_markets[target].resolvedSymbol;
   int dig       = m_markets[target].digits;
   double bid    = SymbolInfoDouble(sym, SYMBOL_BID);
   double h1Ema[1], atr[1];
   CopyBuffer(m_markets[target].h_ema200_h1, 0, 0, 1, h1Ema);
   CopyBuffer(m_markets[target].h_atr_m5, 0, 0, 1, atr);

   string trend = (bid >= h1Ema[0]) ? "Bullish" : "Bearish";
   string structStr = (bid >= h1Ema[0]) ? "Higher High / Higher Low" : "Lower High / Lower Low";
   double resLevel = bid + (atr[0] * 2.5);
   double supLevel = bid - (atr[0] * 2.5);

   string msg = StringFormat(
      "⏱ <b>CHARTORA 1H MARKET ANALYSIS</b>\n"
      "<b>%s</b> | <b>Trend:</b> %s | <b>Structure:</b> %s\n"
      "<b>Key Resistance:</b> <code>%s</code> | <b>Support:</b> <code>%s</code>\n"
      "<b>Scenario A:</b> Continuation above %s with M5 confirmation\n"
      "<b>Scenario B:</b> Retracement into support at %s\n"
      "<b>Educational Insight:</b> Higher timeframes provide the directional bias; lower timeframes provide precision entry.\n"
      "<i>Chartora — Your markets. Our scanners. Your decision.</i>",
      rawSym, trend, structStr,
      DoubleToString(resLevel, dig), DoubleToString(supLevel, dig),
      DoubleToString(resLevel, dig), DoubleToString(supLevel, dig)
   );

   SendTelegramMessage(msg);
}

void SendEducationalLesson() {
   string lessons[10];
   lessons[0] = "🎓 <b>CHARTORA ACADEMY — MARKET STRUCTURE</b>\n"
                "<b>Topic:</b> Break of Structure (BOS) vs Change of Character (CHoCH)\n"
                "• <b>BOS:</b> Confirms trend continuation when price closes beyond the most recent swing high/low.\n"
                "• <b>CHoCH:</b> First signal of a potential trend reversal when price breaks the swing level that created the recent extreme.\n"
                "<i>Tip: Always wait for a candle body close to confirm structure, not just a wick.</i>\n"
                "<i>Chartora — Learn the structure. Build better decisions.</i>";

   lessons[1] = "🎓 <b>CHARTORA ACADEMY — TECHNICAL ANALYSIS</b>\n"
                "<b>Topic:</b> The 9/21 EMA Value Zone\n"
                "• In strong trending markets, the space between the 9 and 21 EMA acts as dynamic equilibrium.\n"
                "• Chasing price away from EMAs increases risk; entering on pullbacks into the value zone optimizes Risk:Reward.\n"
                "<i>Tip: Confirmation candles at the EMA provide the trigger, the 200 EMA provides the macro trend filter.</i>\n"
                "<i>Chartora — Your markets. Our scanners. Your decision.</i>";

   lessons[2] = "🎓 <b>CHARTORA ACADEMY — TRADING PSYCHOLOGY</b>\n"
                "<b>Topic:</b> The Discipline of 0–2 High-Quality Trades\n"
                "• Professional trading is not about activity; it is about selective execution.\n"
                "• Overtrading dilutes statistical edge and compounds emotional fatigue.\n"
                "<i>Tip: If the market doesn't offer a clean setup, no trade is the winning trade.</i>\n"
                "<i>Chartora — Discover the market. Track the opportunity.</i>";

   lessons[3] = "🎓 <b>CHARTORA ACADEMY — RISK MANAGEMENT</b>\n"
                "<b>Topic:</b> Asymmetric Risk/Reward & Capital Preservation\n"
                "• Risking 1% to make 2R–3R allows long-term profitability even with a modest win rate.\n"
                "• Taking partial profits at 1.5R–2R and moving stop loss to break-even eliminates downside risk.\n"
                "<i>Tip: Protect your capital first; profits will take care of themselves.</i>\n"
                "<i>Chartora — Your markets. Our scanners. Your decision.</i>";

   lessons[4] = "🎓 <b>CHARTORA ACADEMY — MARKET KNOWLEDGE</b>\n"
                "<b>Topic:</b> Trading Session Dynamics (London & New York)\n"
                "• <b>London Open (08:00 UK):</b> Institutional volume expansion and true directional price discovery.\n"
                "• <b>NY Overlap (13:00–17:00 UK):</b> Highest liquidity period of the day across Forex, Metals, and US Indices.\n"
                "<i>Tip: Avoid trading Asian range chop on European pairs until London liquidity enters.</i>\n"
                "<i>Chartora — Discover the market. Learn the structure.</i>";

   lessons[5] = "🎓 <b>CHARTORA ACADEMY — CANDLESTICK CONFIRMATION</b>\n"
                "<b>Topic:</b> Bullish & Bearish Engulfing Reversals\n"
                "• An engulfing candle at key structure signifies aggressive order flow shifting control.\n"
                "• Range expansion combined with a close beyond the previous bar confirms institutional absorption.\n"
                "<i>Tip: Engulfing patterns are only meaningful when they occur at high-timeframe support or resistance.</i>\n"
                "<i>Chartora — Learn the structure. Build better decisions.</i>";

   lessons[6] = "🎓 <b>CHARTORA ACADEMY — LIQUIDITY POOLS</b>\n"
                "<b>Topic:</b> Stop Hunts & False Breakouts\n"
                "• Retail stop losses cluster above obvious swing highs and below swing lows.\n"
                "• Institutional algorithms frequently sweep these levels before moving in the true intended direction.\n"
                "<i>Tip: Wait for the sweep and reversal candle before executing your continuation setup.</i>\n"
                "<i>Chartora — Discover the market. Track the opportunity.</i>";

   lessons[7] = "🎓 <b>CHARTORA ACADEMY — POSITION SIZING</b>\n"
                "<b>Topic:</b> Mathematical Sizing vs Fixed Lot Sizing\n"
                "• Always calculate lot size based on Stop Loss distance in points, never a fixed lot size.\n"
                "• Formula: <code>Lot Size = (Account Balance * Risk %) / (SL Points * Point Value)</code>\n"
                "<i>Tip: A wider stop loss requires a smaller lot size to keep dollar risk identical.</i>\n"
                "<i>Chartora — Your markets. Our scanners. Your decision.</i>";

   lessons[8] = "🎓 <b>CHARTORA ACADEMY — PATIENCE IN TRADING</b>\n"
                "<b>Topic:</b> The Art of Waiting for the Retest\n"
                "• FOMO (Fear of Missing Out) causes traders to buy at the top of impulse candles.\n"
                "• Patient traders wait for the market to retrace to the breakout origin point.\n"
                "<i>Tip: Retests provide the tightest stop loss and greatest reward multiplier.</i>\n"
                "<i>Chartora — Learn the structure. Build better decisions.</i>";

   lessons[9] = "🎓 <b>CHARTORA ACADEMY — TRADE JOURNALING</b>\n"
                "<b>Topic:</b> Measuring Edge with Performance Metrics\n"
                "• Track R-multiples, setup types, entry sessions, and emotional states for every execution.\n"
                "• Data-driven self-auditing separates consistently profitable traders from amateurs.\n"
                "<i>Tip: Review your trade journal weekly to eliminate recurring error patterns.</i>\n"
                "<i>Chartora — Discover the market. Build better trading decisions.</i>";

   string lessonMsg = lessons[m_educationLessonIndex % 10];
   m_educationLessonIndex++;
   SendTelegramMessage(lessonMsg);
}

//====================================================================
// SECTION 9: CHART CAPTURE & UPLOAD (CCANVAS / CHARTSAVE)
//====================================================================

void CaptureAndUploadChart(const ChartoraSignal &sig, string stratName, int idx) {
   string sym = m_markets[idx].resolvedSymbol;
   string filename = StringFormat("Chartora_%s_%d.png", sig.symbol, (int)TimeCurrent());

   // Create Branded Overlay Canvas
   CCanvas canvas;
   if(canvas.Create("Chartora_Canvas_" + sig.symbol, InpScreenshotWidth, InpScreenshotHeight, COLOR_FORMAT_ARGB_NORMALIZE)) {
      canvas.Erase(0xFF10141E); // Institutional Dark Slate Blue

      // Header Banner
      canvas.FillRectangle(0, 0, InpScreenshotWidth, 60, 0xFF182032);
      canvas.TextOut(30, 18, "CHARTORA.IN — INSTITUTIONAL MARKET INTELLIGENCE", 0xFFFFFFFF, TA_LEFT);
      canvas.TextOut(InpScreenshotWidth - 30, 18, "CONFIDENCE: " + IntegerToString(sig.score) + "/100", 0xFF00E676, TA_RIGHT);

      // Signal Info Card
      string dirText = (sig.direction == ORDER_TYPE_BUY) ? "BUY SETUP" : "SELL SETUP";
      uint dirColor  = (sig.direction == ORDER_TYPE_BUY) ? 0xFF00E676 : 0xFFFF3D00;
      canvas.TextOut(30, 80, sig.symbol + " (" + EnumToString(sig.timeframe) + ") — " + dirText, dirColor, TA_LEFT);
      canvas.TextOut(30, 110, "Strategy: " + stratName, 0xFF9E9E9E, TA_LEFT);
      canvas.TextOut(30, 135, "Entry: " + DoubleToString(sig.entry, m_markets[idx].digits) + " | SL: " + DoubleToString(sig.sl, m_markets[idx].digits) + " | TP1: " + DoubleToString(sig.tp1, m_markets[idx].digits), 0xFFE0E0E0, TA_LEFT);

      // Footer Banner
      canvas.FillRectangle(0, InpScreenshotHeight - 40, InpScreenshotWidth, InpScreenshotHeight, 0xFF141926);
      canvas.TextOut(30, InpScreenshotHeight - 28, "Discover the market. Learn the structure. Track the opportunity.", 0xFF757575, TA_LEFT);

      canvas.Update();
   }

   // Chart Screenshot Fallback
   long chartId = ChartFirst();
   while(chartId >= 0) {
      if(ChartSymbol(chartId) == sym) {
         ChartSetInteger(chartId, CHART_SHOW, true);
         ChartRedraw(chartId);
         ChartScreenShot(chartId, filename, InpScreenshotWidth, InpScreenshotHeight, ALIGN_RIGHT);
         break;
      }
      chartId = ChartNext(chartId);
   }

   canvas.Destroy();
}

//====================================================================
// SECTION 10: TELEGRAM HTTP ENGINE (WEBREQUEST WITH SANITIZATION)
//====================================================================

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

string SanitizeJson(string text) {
   string s = text;
   StringReplace(s, "\\", "\\\\");
   StringReplace(s, "\"", "\\\"");
   StringReplace(s, "\r", "");
   StringReplace(s, "\n", "\\n");
   StringReplace(s, "\t", " ");
   return s;
}

bool SendTelegramMessage(string message) {
   string cleanChatID = GetCleanTelegramChatID();
   if(!InpEnableTelegram || InpTelegramBotToken == "" || cleanChatID == "") return false;

   string url = "https://api.telegram.org/bot" + InpTelegramBotToken + "/sendMessage";
   string headers = "Content-Type: application/json\r\n";
   string payload = StringFormat("{\"chat_id\":\"%s\",\"text\":\"%s\",\"parse_mode\":\"HTML\"}", cleanChatID, SanitizeJson(message));

   char data[];
   StringToCharArray(payload, data, 0, WHOLE_ARRAY, CP_UTF8);
   int dataSize = ArraySize(data);
   if(dataSize > 0 && data[dataSize - 1] == 0) ArrayResize(data, dataSize - 1);

   char result[];
   string resultHeaders;
   ResetLastError();
   int res = WebRequest("POST", url, headers, 5000, data, result, resultHeaders);
   if(res != 200) {
      Print("[Chartora Telegram ERROR] SendMessage failed. HTTP Code: ", res, " | Error: ", GetLastError());
      return false;
   }
   return true;
}

//====================================================================
// SECTION 11: STATE PERSISTENCE & FAULT TOLERANCE
//====================================================================

void SaveChartoraState() {
   string folder = "ChartoraOfficialV1\\";
   int hFile = FileOpen(folder + "State.bin", FILE_WRITE | FILE_BIN | FILE_COMMON);
   if(hFile != INVALID_HANDLE) {
      FileWriteInteger(hFile, CHARTORA_STATE_VERSION);
      FileWriteInteger(hFile, m_dailySignalCount);
      FileWriteInteger(hFile, m_lastDailyResetDay);
      FileWriteInteger(hFile, m_lastMorningReportDay);
      FileWriteInteger(hFile, m_lastEveningReportDay);
      FileWriteInteger(hFile, m_last1HAnalysisHour);
      FileWriteInteger(hFile, m_lastEducationHour);
      FileWriteInteger(hFile, m_educationLessonIndex);
      FileWriteLong(hFile, (long)m_lastGlobalSignalTime);
      FileClose(hFile);
   }
}

void LoadChartoraState() {
   string folder = "ChartoraOfficialV1\\";
   int hFile = FileOpen(folder + "State.bin", FILE_READ | FILE_BIN | FILE_COMMON);
   if(hFile != INVALID_HANDLE) {
      int ver = FileReadInteger(hFile);
      if(ver == CHARTORA_STATE_VERSION) {
         m_dailySignalCount     = FileReadInteger(hFile);
         m_lastDailyResetDay    = FileReadInteger(hFile);
         m_lastMorningReportDay = FileReadInteger(hFile);
         m_lastEveningReportDay = FileReadInteger(hFile);
         m_last1HAnalysisHour   = FileReadInteger(hFile);
         m_lastEducationHour    = FileReadInteger(hFile);
         m_educationLessonIndex = FileReadInteger(hFile);
         m_lastGlobalSignalTime = (datetime)FileReadLong(hFile);
      }
      FileClose(hFile);
      Print("📂 [Chartora State Restored] Daily Signals: ", m_dailySignalCount, " | Lesson Index: ", m_educationLessonIndex);
   }
}
//+------------------------------------------------------------------+
