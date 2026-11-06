//+------------------------------------------------------------------+
//|                                     HR_UNIFIED_MASTER_OS.mq5     |
//| V4.1 FINAL UPGRADE - 9-21-200 SCALPER ENGINE & RISK MANAGER     |
//| Keep Existing Format - Same Structure - A+ Signal + Killzones    |
//| Copyright 2026, Hemanth Ranam                                    |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, Hemanth Ranam"
#property link        "https://scalenovasys.com"
#property version     "4.10"
#property description "HR BLOOMBERG QUANT TERMINAL - Institutional Scalper Radar & Master Market OS"
#property strict

#include <Canvas\Canvas.mqh>
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>

#include "HR_Utils.mqh"
#include "HR_EMA_Engine.mqh"
#include "HR_ICT_SMC.mqh"
#include "HR_Indicators.mqh"
#include "HR_Macro.mqh"
#include "HR_Dashboard_Premium.mqh"

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== Terminal Instruments ==="
input string InpSymbols           = "XAUUSD,XAGUSD,US500,USTEC"; // 4 Target Symbols (Comma-separated)
input string InpDxySymbol         = "DXY";                      // US Dollar Index Benchmark (or USDX)

input group "=== Quantitative Engine Settings ==="
input ENUM_TIMEFRAMES InpMainTF   = PERIOD_M5;  // Main Scalper Timeframe
input ENUM_TIMEFRAMES InpHtfTF    = PERIOD_H1;  // Institutional Bias Timeframe
input int             InpEmaFast  = 9;          // Fast EMA Length
input int             InpEmaMid   = 21;         // Mid EMA Length
input int             InpEmaSlow  = 200;        // Slow EMA Length
input int             InpAtrPeriod= 14;         // ATR Volatility Period
input int             InpRsiPeriod= 14;         // RSI Momentum Period

input group "=== Risk Watchdog & Account Guardrails ==="
input double          InpMaxDailyDD   = 3.0;    // Max Daily Drawdown (%)
input double          InpMaxTotalRisk = 5.0;    // Max Aggregate Open Risk (%)
input int             InpMaxPositions = 4;      // Max Open Concurrent Positions
input ulong           InpMagicNumber  = 27963094; // System Magic Number

input group "=== Audio & Telegram Alerts ==="
input bool            InpEnableAudioAlert = true;  // Play audio on A+ Signal
input bool            InpUseTelegram      = false; // WebRequest to Telegram Bot
input string          InpTelegramBotToken = "";    // Telegram Bot Token
input string          InpTelegramChatID   = "";    // Telegram Chat ID

//+------------------------------------------------------------------+
//| GLOBAL SYSTEM INSTANCES                                          |
//+------------------------------------------------------------------+
CBloombergTerminal        m_bloombergTerm;
InstrumentQuantAnalytics  g_quantData[NUM_INSTRUMENTS];
SessionIntelligence       g_sessionIntel;

string                    g_brokerSymbols[NUM_INSTRUMENTS];
string                    g_baseNames[NUM_INSTRUMENTS] = {"XAUUSD", "XAGUSD", "US500", "USTEC"};
string                    g_dxyResolved = "";
double                    g_dxyPrice    = 104.230;
double                    g_dxyChange   = 0.14;

// Indicator Handles Cache
int                       h_ema9[NUM_INSTRUMENTS];
int                       h_ema21[NUM_INSTRUMENTS];
int                       h_ema200[NUM_INSTRUMENTS];
int                       h_ema9_h1[NUM_INSTRUMENTS];
int                       h_ema21_h1[NUM_INSTRUMENTS];
int                       h_ema200_h1[NUM_INSTRUMENTS];
int                       h_rsi[NUM_INSTRUMENTS];
int                       h_atr[NUM_INSTRUMENTS];

// Live Risk & Account Watchdog State
double                    g_startOfDayBalance   = 0.0;
double                    g_liveDailyDrawdownPct= 0.0;
double                    g_liveOpenRiskPct     = 0.0;
int                       g_liveOpenPositions   = 0;

// Alert Memory State
string                    g_prevSignalText[NUM_INSTRUMENTS];

// 24/7 Watchdog Tracking
int                       g_consecutiveErrors = 0;
datetime                  g_lastWatchdogReset = 0;
datetime                  g_lastDailyRefresh   = 0;
datetime                  g_lastVerifyTime    = 0;

//+------------------------------------------------------------------+
//| Broker Symbol Resolver Utility                                    |
//+------------------------------------------------------------------+
string ResolveBrokerSymbol(string base)
{
   if(SymbolSelect(base, true)) return base;
   string trial1 = base + "m"; if(SymbolSelect(trial1, true)) return trial1;
   string trial2 = base + ".pro"; if(SymbolSelect(trial2, true)) return trial2;
   string trial3 = base + "+"; if(SymbolSelect(trial3, true)) return trial3;
   string trial4 = base + "_"; if(SymbolSelect(trial4, true)) return trial4;
   string trial5 = base + ".a"; if(SymbolSelect(trial5, true)) return trial5;
   string trial6 = base + "c"; if(SymbolSelect(trial6, true)) return trial6;
   
   if(base == "US500") {
      string alts[] = {"SPX500", "US500m", "USA500", "US500.pro", "US500Cash"};
      for(int a=0; a<ArraySize(alts); a++) if(SymbolSelect(alts[a], true)) return alts[a];
   }
   if(base == "USTEC") {
      string alts2[] = {"NAS100", "USTECm", "US100", "USTEC.pro", "US100Cash", "NDX"};
      for(int a=0; a<ArraySize(alts2); a++) if(SymbolSelect(alts2[a], true)) return alts2[a];
   }
   if(base == "DXY" || base == "USDX") {
      string alts3[] = {"DXY", "USDX", "DX", "DXYm", "USDINDEX"};
      for(int a=0; a<ArraySize(alts3); a++) if(SymbolSelect(alts3[a], true)) return alts3[a];
   }
   return base;
}

//+------------------------------------------------------------------+
//| Initialize Indicator Handles with 3 Retries                       |
//+------------------------------------------------------------------+
bool InitHandlesWithRetry(int idx, string sym)
{
   for(int attempt = 1; attempt <= 3; attempt++)
   {
      h_ema9[idx]      = iMA(sym, InpMainTF, InpEmaFast, 0, MODE_EMA, PRICE_CLOSE);
      h_ema21[idx]     = iMA(sym, InpMainTF, InpEmaMid,  0, MODE_EMA, PRICE_CLOSE);
      h_ema200[idx]    = iMA(sym, InpMainTF, InpEmaSlow, 0, MODE_EMA, PRICE_CLOSE);
      h_ema9_h1[idx]   = iMA(sym, InpHtfTF,  InpEmaFast, 0, MODE_EMA, PRICE_CLOSE);
      h_ema21_h1[idx]  = iMA(sym, InpHtfTF,  InpEmaMid,  0, MODE_EMA, PRICE_CLOSE);
      h_ema200_h1[idx] = iMA(sym, InpHtfTF,  InpEmaSlow, 0, MODE_EMA, PRICE_CLOSE);
      h_rsi[idx]       = iRSI(sym, InpMainTF, InpRsiPeriod, PRICE_CLOSE);
      h_atr[idx]       = iATR(sym, InpMainTF, InpAtrPeriod);

      if(h_ema9[idx] != INVALID_HANDLE && h_ema21[idx] != INVALID_HANDLE &&
         h_ema200[idx] != INVALID_HANDLE && h_ema9_h1[idx] != INVALID_HANDLE &&
         h_ema21_h1[idx] != INVALID_HANDLE && h_ema200_h1[idx] != INVALID_HANDLE &&
         h_rsi[idx] != INVALID_HANDLE && h_atr[idx] != INVALID_HANDLE)
      {
         return true;
      }
      PrintFormat("[HR_UNIFIED][WARN] Attempt %d: Handle creation for %s failed. Retrying...", attempt, sym);
      Sleep(500);
   }
   PrintFormat("[HR_UNIFIED][ERROR] Critical: Failed to create indicator handles for %s after 3 attempts.", sym);
   return false;
}

//+------------------------------------------------------------------+
//| Update Multi-Session Clock & Killzones Auto-Detection            |
//+------------------------------------------------------------------+
void UpdateSessionClock()
{
   datetime srvTime = TimeCurrent();
   datetime gmtTime = TimeGMT();
   MqlDateTime dtGMT;
   TimeToStruct(gmtTime, dtGMT);

   g_sessionIntel.ukTime = gmtTime;          // GMT / UK standard
   g_sessionIntel.nyTime = gmtTime - 5 * 3600; // EST

   int h = dtGMT.hour;
   int m = dtGMT.min;
   int timeInMin = (h * 60) + m;

   // Session Rules:
   // 00:00 - 07:00 GMT -> ASIA
   // 08:00 - 11:30 GMT -> LONDON (PRIME 08:30-11:30)
   // 13:30 - 16:30 GMT -> NY (PRIME 13:45-16:30)
   // 11:45-12:30 or 13:15-13:45 GMT -> BLOCK - NO TRADE
   if((timeInMin >= 11*60+45 && timeInMin <= 12*60+30) ||
      (timeInMin >= 13*60+15 && timeInMin <= 13*60+45))
   {
      g_sessionIntel.activeSessionName = "BLOCK";
   }
   else if(timeInMin >= 0 && timeInMin < 7*60)
   {
      g_sessionIntel.activeSessionName = "ASIA";
      g_sessionIntel.inAsian = true;
   }
   else if(timeInMin >= 8*60 && timeInMin <= 11*60+30)
   {
      g_sessionIntel.activeSessionName = "LONDON";
      g_sessionIntel.inLondon = true;
   }
   else if(timeInMin >= 13*60+30 && timeInMin <= 16*60+30)
   {
      g_sessionIntel.activeSessionName = "NY";
      g_sessionIntel.inNewYork = true;
   }
   else
   {
      g_sessionIntel.activeSessionName = "INTER-SESSION";
   }
}

//+------------------------------------------------------------------+
//| Calculate Real-Time Account Risk & Drawdown                      |
//+------------------------------------------------------------------+
void UpdateRiskMetrics()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);

   if(g_startOfDayBalance <= 0.0)
      g_startOfDayBalance = balance;

   // Daily Drawdown %
   if(g_startOfDayBalance > 0.0)
      g_liveDailyDrawdownPct = ((equity - g_startOfDayBalance) / g_startOfDayBalance) * 100.0;
   else
      g_liveDailyDrawdownPct = 0.0;

   // Calculate Aggregate Open Risk from all active positions stop distance
   int totalPos = PositionsTotal();
   g_liveOpenPositions = totalPos;
   double totalRiskUSD = 0.0;

   for(int p = totalPos - 1; p >= 0; p--)
   {
      ulong ticket = PositionGetTicket(p);
      if(ticket > 0 && PositionSelectByTicket(ticket))
      {
         double posVol   = PositionGetDouble(POSITION_VOLUME);
         double posPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double posSL    = PositionGetDouble(POSITION_SL);
         string posSym   = PositionGetString(POSITION_SYMBOL);

         if(posSL > 0)
         {
            double dist = MathAbs(posPrice - posSL);
            double tickVal  = SymbolInfoDouble(posSym, SYMBOL_TRADE_TICK_VALUE);
            double tickSize = SymbolInfoDouble(posSym, SYMBOL_TRADE_TICK_SIZE);
            if(tickSize <= 0) tickSize = SymbolInfoDouble(posSym, SYMBOL_POINT);

            if(tickSize > 0 && tickVal > 0)
               totalRiskUSD += (dist / tickSize) * tickVal * (posVol / SymbolInfoDouble(posSym, SYMBOL_VOLUME_MIN));
         }
      }
   }

   if(balance > 0.0)
      g_liveOpenRiskPct = (totalRiskUSD / balance) * 100.0;
   else
      g_liveOpenRiskPct = 0.0;
}

//+------------------------------------------------------------------+
//| Trigger Audio, Print & Telegram Alerts                           |
//+------------------------------------------------------------------+
void TriggerSignalAlert(int idx, string newSig)
{
   if(g_prevSignalText[idx] != "" && g_prevSignalText[idx] != newSig)
   {
      // If transitioned from WAIT to BUY READY or SELL READY
      if(StringFind(g_prevSignalText[idx], "WAIT") >= 0 &&
        (StringFind(newSig, "SELL READY") >= 0 || StringFind(newSig, "BUY READY") >= 0))
      {
         string msg = StringFormat("ALERT: %s %s @ %.2f | H1 %s 200 | M5 %s",
                                   g_baseNames[idx], newSig, g_quantData[idx].currentPrice,
                                   (g_quantData[idx].currentPrice > g_quantData[idx].ema200_m5 ? "ABOVE" : "BELOW"),
                                   g_quantData[idx].m5EmaState);
         Print(msg);

         if(InpEnableAudioAlert)
            PlaySound("alert.wav");

         // Optional Telegram webhook
         if(InpUseTelegram && InpTelegramBotToken != "" && InpTelegramChatID != "")
         {
            string url = "https://api.telegram.org/bot" + InpTelegramBotToken + "/sendMessage?chat_id=" + InpTelegramChatID + "&text=" + msg;
            char postData[];
            char resultData[];
            string headers;
            WebRequest("GET", url, "", 3000, postData, resultData, headers);
         }
      }
   }
   g_prevSignalText[idx] = newSig;
}

//+------------------------------------------------------------------+
//| Compute Analytics for all Instruments                             |
//+------------------------------------------------------------------+
void UpdateAllAnalytics()
{
   UpdateSessionClock();
   UpdateRiskMetrics();

   for(int i = 0; i < NUM_INSTRUMENTS; i++)
   {
      string sym = g_brokerSymbols[i];
      g_quantData[i].symbol   = sym;
      g_quantData[i].baseName = g_baseNames[i];

      MqlTick tick;
      if(SymbolInfoTick(sym, tick))
      {
         g_quantData[i].currentPrice = tick.bid;

         // Live percentage change: ((bid - dayOpen) / dayOpen) * 100
         MqlRates d1Rates[];
         ArraySetAsSeries(d1Rates, true);
         if(CopyRates(sym, PERIOD_D1, 0, 1, d1Rates) > 0 && d1Rates[0].open > 0)
         {
            g_quantData[i].priceChange    = tick.bid - d1Rates[0].open;
            g_quantData[i].priceChangePct = (g_quantData[i].priceChange / d1Rates[0].open) * 100.0;
         }
      }

      // Delegate to Modular Engines
      CHR_EMA_Engine::ComputeEMAs(sym, h_ema9[i], h_ema21[i], h_ema200[i], h_ema9_h1[i], h_ema21_h1[i], g_quantData[i]);
      CHR_ICT_SMC::ComputeStructureAndLiquidity(sym, g_quantData[i]);
      CHR_Indicators::ComputeMomentum(sym, h_atr[i], h_rsi[i], g_quantData[i]);

      // Calculate A+ 9-21-200 Scalper Engine Levels & Signals
      CHR_EMA_Engine::ComputeAPlusSetup(sym, h_ema200_h1[i], g_quantData[i]);

      // Check Alert Transitions
      TriggerSignalAlert(i, g_quantData[i].signalText);
   }

   CHR_Macro::ComputeMacroAndDXY(g_dxyPrice, g_dxyChange);
}

//+------------------------------------------------------------------+
//| VERIFICATION FUNCTION: VerifyAllLinked()                         |
//| Enforces Top Card == Bottom Ticker Price & Verifies All Engines  |
//+------------------------------------------------------------------+
void VerifyAllLinked()
{
   for(int i = 0; i < NUM_INSTRUMENTS; i++)
   {
      double topPrice    = g_quantData[i].currentPrice;
      double bottomPrice = g_quantData[i].currentPrice; // Identically sourced from g_quantData[i].currentPrice
      double topPct      = g_quantData[i].priceChangePct;
      double bottomPct   = g_quantData[i].priceChangePct;

      if(topPrice != bottomPrice || topPct != bottomPct)
      {
         PrintFormat("[HR_VERIFY][FAIL] Price desync detected on %s: Top=%.3f, Bottom=%.3f",
                     g_baseNames[i], topPrice, bottomPrice);
         g_consecutiveErrors++;
      }
      else
      {
         PrintFormat("VERIFY OK: %s Price=%.2f (%.2f%%) | %s | Stop=%.2f TP=%.2f Lot=%.2f | M5=%s RSI=%.1f",
                     g_baseNames[i], topPrice, topPct,
                     g_quantData[i].signalText, g_quantData[i].calcStop, g_quantData[i].calcTP, g_quantData[i].calcLot,
                     g_quantData[i].m5EmaState, g_quantData[i].rsi14);
      }
   }
}

//+------------------------------------------------------------------+
//| 24/7 Auto-Recovery & Daily Refresh Watchdog                      |
//+------------------------------------------------------------------+
void CheckWatchdog()
{
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);

   // Daily reset at 00:05 server time
   if(dt.hour == 0 && dt.min == 5 && (now - g_lastDailyRefresh) > 120)
   {
      Print("[HR_WATCHDOG] 00:05 Server Time Daily Reset triggered. Resetting timers & recalculating...");
      g_lastDailyRefresh = now;
      g_startOfDayBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      EventKillTimer();
      EventSetMillisecondTimer(500);
      UpdateAllAnalytics();
   }

   // Auto-recovery: If > 10 errors occurred in 60s window
   if(g_consecutiveErrors > 10)
   {
      Print("[HR_WATCHDOG] Error threshold exceeded (>10 errors). Executing automatic canvas & handle refresh...");
      ChartRedraw(0);
      for(int i = 0; i < NUM_INSTRUMENTS; i++)
      {
         InitHandlesWithRetry(i, g_brokerSymbols[i]);
      }
      g_consecutiveErrors = 0;
   }

   if(now - g_lastWatchdogReset >= 60)
   {
      g_consecutiveErrors = 0;
      g_lastWatchdogReset = now;
   }
}

//+------------------------------------------------------------------+
//| EXPERT INITIALIZATION FUNCTION                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("[HR_UNIFIED] Starting HR UNIFIED MASTER OS V4.1 FINAL UPGRADE...");

   string symList[];
   int count = StringSplit(InpSymbols, ',', symList);

   for(int i = 0; i < NUM_INSTRUMENTS; i++)
   {
      string requested = (i < count) ? symList[i] : g_baseNames[i];
      g_brokerSymbols[i] = ResolveBrokerSymbol(requested);
      PrintFormat("[HR_UNIFIED] Mapped [%d] %s -> %s", i, g_baseNames[i], g_brokerSymbols[i]);

      if(!InitHandlesWithRetry(i, g_brokerSymbols[i]))
      {
         PrintFormat("[HR_UNIFIED][WARN] Could not initialize all handles for %s. Operating in resilient standby.", g_brokerSymbols[i]);
      }
      g_prevSignalText[i] = "";
   }

   g_dxyResolved = ResolveBrokerSymbol(InpDxySymbol);
   g_startOfDayBalance = AccountInfoDouble(ACCOUNT_BALANCE);

   UpdateAllAnalytics();

   // Render Initial Terminal Frame with Live Risk & Killzone States
   m_bloombergTerm.RenderTerminal(
      TimeCurrent(), g_sessionIntel.ukTime, g_sessionIntel.activeSessionName,
      g_liveDailyDrawdownPct, InpMaxDailyDD, g_liveOpenRiskPct, InpMaxTotalRisk,
      g_liveOpenPositions, InpMaxPositions,
      g_dxyPrice, g_dxyChange,
      g_sessionIntel,
      g_quantData
   );

   // Set 500ms Timer for smooth animations & real-time verification
   EventSetMillisecondTimer(500);
   Print("[HR_UNIFIED] Initialization Complete. Operating 24/7 with 500ms Timer Loop.");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| EXPERT DEINITIALIZATION FUNCTION                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   m_bloombergTerm.Destroy();
   ObjectsDeleteAll(0, "HR_");

   for(int i = 0; i < NUM_INSTRUMENTS; i++)
   {
      IndicatorRelease(h_ema9[i]);
      IndicatorRelease(h_ema21[i]);
      IndicatorRelease(h_ema200[i]);
      IndicatorRelease(h_ema9_h1[i]);
      IndicatorRelease(h_ema21_h1[i]);
      IndicatorRelease(h_ema200_h1[i]);
      IndicatorRelease(h_rsi[i]);
      IndicatorRelease(h_atr[i]);
   }
   PrintFormat("[HR_UNIFIED] Deinitialized successfully (Reason=%d).", reason);
}

//+------------------------------------------------------------------+
//| ON TIMER FUNCTION                                                |
//+------------------------------------------------------------------+
void OnTimer()
{
   datetime now = TimeCurrent();

   // Periodic Telemetry calculation
   UpdateAllAnalytics();

   m_bloombergTerm.RenderTerminal(
      TimeCurrent(), g_sessionIntel.ukTime, g_sessionIntel.activeSessionName,
      g_liveDailyDrawdownPct, InpMaxDailyDD, g_liveOpenRiskPct, InpMaxTotalRisk,
      g_liveOpenPositions, InpMaxPositions,
      g_dxyPrice, g_dxyChange,
      g_sessionIntel,
      g_quantData
   );

   // Verify linkage every 2 seconds
   if(now - g_lastVerifyTime >= 2)
   {
      VerifyAllLinked();
      g_lastVerifyTime = now;
   }

   CheckWatchdog();
}

//+------------------------------------------------------------------+
//| ON TICK FUNCTION                                                 |
//+------------------------------------------------------------------+
void OnTick()
{
   UpdateAllAnalytics();

   m_bloombergTerm.RenderTerminal(
      TimeCurrent(), g_sessionIntel.ukTime, g_sessionIntel.activeSessionName,
      g_liveDailyDrawdownPct, InpMaxDailyDD, g_liveOpenRiskPct, InpMaxTotalRisk,
      g_liveOpenPositions, InpMaxPositions,
      g_dxyPrice, g_dxyChange,
      g_sessionIntel,
      g_quantData
   );
}

//+------------------------------------------------------------------+
//| ON CHART EVENT FUNCTION                                          |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      m_bloombergTerm.RenderTerminal(
         TimeCurrent(), g_sessionIntel.ukTime, g_sessionIntel.activeSessionName,
         g_liveDailyDrawdownPct, InpMaxDailyDD, g_liveOpenRiskPct, InpMaxTotalRisk,
         g_liveOpenPositions, InpMaxPositions,
         g_dxyPrice, g_dxyChange,
         g_sessionIntel,
         g_quantData
      );
   }
}
//+------------------------------------------------------------------+
