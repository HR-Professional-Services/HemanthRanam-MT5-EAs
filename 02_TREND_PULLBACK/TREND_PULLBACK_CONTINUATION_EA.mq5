//+------------------------------------------------------------------+
//|                                TREND_PULLBACK_CONTINUATION_EA.mq5|
//|                                    Copyright 2026, Hemanth Ranam |
//|                             https://github.com/HR-Professional-Services |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, Hemanth Ranam"
#property link        "https://github.com/HR-Professional-Services/HemanthRanam-MT5-EAs"
#property version     "2.00"
#property description "Trend Pullback and Continuation Quantitative System."
#property description "Enforces macro 200 EMA regime bias with tactical 9/21 EMA corridor pullbacks."

// Include Core Architectural Modules
#include "..\Include\RiskManager.mqh"
#include "..\Include\SymbolScanner.mqh"
#include "..\Include\TradeExecutor.mqh"
#include "..\Include\MarketFilters.mqh"
#include "..\Include\Logger.mqh"

//--- Input Groups
input group "=== Watchlist & Multi-Symbol Scanning ==="
input string            InpWatchlist            = "XAUUSD,XAGUSD,US500,US100,USOIL,EURUSD,GBPUSD,USDJPY"; // Multi-Symbol List (CSV)
input int               InpMaxSpreadPoints      = 40;                     // Maximum Permitted Spread (Points)
input int               InpScanTimerSeconds     = 5;                      // Scanner Polling Interval (Seconds)

input group "=== Trend & Pullback Strategy Parameters ==="
input ENUM_TIMEFRAMES   InpExecutionTF          = PERIOD_M15;             // Execution Timeframe
input int               InpFastEMA              = 9;                      // Fast Pullback EMA Period (9)
input int               InpSlowEMA              = 21;                     // Slow Pullback EMA Period (21)
input int               InpMacroEMA             = 200;                    // Macro Structural Baseline EMA (200)
input double            InpRewardToRiskRatio    = 2.2;                    // Minimum Target R:R Ratio (1:2.2)
input int               InpMinPullbackBars      = 2;                      // Minimum Retracement Bars into Corridor

input group "=== Risk Management ==="
input double            InpRiskPercent          = 0.5;                    // Risk Percentage per Trade (Default 0.5%)
input double            InpMaxDailyDrawdown     = 2.0;                    // Max Daily Equity Drawdown Limit (%)
input double            InpMaxPortfolioRisk     = 1.5;                    // Max Aggregate Open Portfolio Risk (%)
input int               InpMaxTotalPositions    = 5;                      // Max Concurrent Positions Total
input int               InpMaxPositionsPerSymbol= 1;                      // Max Concurrent Positions Per Symbol

input group "=== Trade Execution & Protection ==="
input ulong             InpMagicNumber          = 102002;                 // EA Magic Number
input ulong             InpSlippagePoints       = 10;                     // Max Slippage (Points)
input bool              InpEnableBreakEven      = true;                   // Enable Break-Even at +1R
input double            InpBreakEvenTriggerR    = 1.0;                    // Break-Even Trigger (R)
input double            InpBreakEvenBufferPts   = 5.0;                    // Break-Even Buffer (Points)
input bool              InpEnableTrailing       = false;                  // Enable Trailing Stop
input double            InpTrailingStopPts      = 50.0;                   // Trailing Distance (Points)

input group "=== Market Filters & Session Timing ==="
input bool              InpEnableSessionFilter  = true;                   // Enable Session Filter
input int               InpBrokerGMTOffset      = 0;                      // Broker GMT Offset
input bool              InpTradeLondon          = true;                   // Trade London Session
input bool              InpTradeNewYork         = true;                   // Trade New York Session
input bool              InpTradeAsian           = false;                  // Trade Asian Session
input bool              InpRolloverBlackout     = true;                   // Enable Rollover Blackout (21:55-22:15 GMT)

//--- Module Instances
CRiskManager      ExtRisk;
CSymbolScanner    ExtScanner;
CTradeExecutor    ExtTrade;
CMarketFilters    ExtFilter;
CLogger           ExtLog;

datetime          ExtLastBarTimes[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   ExtLog.Init("TREND_PULLBACK_EA", true, false, false);
   ExtLog.Info("Initializing Trend Pullback and Continuation EA...");
   
   if(!ExtScanner.Init(InpWatchlist, InpMaxSpreadPoints))
   {
      ExtLog.Error("Failed to initialize symbol watchlist.");
      return INIT_FAILED;
   }
   
   ExtRisk.Init(InpRiskPercent, InpMaxDailyDrawdown, InpMaxPortfolioRisk, 
                InpMaxTotalPositions, InpMaxPositionsPerSymbol, 3, 60);
                
   ExtTrade.Init(InpMagicNumber, InpSlippagePoints, InpEnableBreakEven, 
                 InpBreakEvenTriggerR, InpBreakEvenBufferPts, 
                 InpEnableTrailing, InpTrailingStopPts, 10.0);
                 
   ExtFilter.Init(InpEnableSessionFilter, InpBrokerGMTOffset, InpTradeAsian, 
                  InpTradeLondon, InpTradeNewYork, InpRolloverBlackout, 30);
                  
   ArrayResize(ExtLastBarTimes, ExtScanner.GetSymbolCount());
   ArrayInitialize(ExtLastBarTimes, 0);

   EventSetTimer(InpScanTimerSeconds);
   
   ExtLog.Info(StringFormat("Initialization complete. Multi-symbol trend scanner active across %d instruments.",
               ExtScanner.GetSymbolCount()));
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   ExtLog.Info(StringFormat("EA Deinitialized. Reason code: %d", reason));
}

//+------------------------------------------------------------------+
//| Periodic Timer Event                                             |
//+------------------------------------------------------------------+
void OnTimer()
{
   string sessionReject = "";
   if(!ExtFilter.IsSessionAllowed(sessionReject))
      return;
      
   ExtRisk.CheckDailyReset();
   
   int totalSymbols = ExtScanner.GetSymbolCount();
   for(int i = 0; i < totalSymbols; i++)
   {
      string sym = ExtScanner.GetSymbol(i);
      ExtTrade.ManageOpenPositions(sym);
      ProcessSymbolPullbackStrategy(i, sym);
   }
}

//+------------------------------------------------------------------+
//| Tick Event Handler                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   ExtTrade.ManageOpenPositions(Symbol());
}

//+------------------------------------------------------------------+
//| Strategy Logic: Trend Alignment & Pullback Confirmation          |
//+------------------------------------------------------------------+
void ProcessSymbolPullbackStrategy(const int symIndex, const string sym)
{
   datetime currentBarTime = (datetime)SeriesInfoInteger(sym, InpExecutionTF, SERIES_LASTBAR_DATE);
   if(currentBarTime == 0 || currentBarTime == ExtLastBarTimes[symIndex])
      return;
      
   string riskReject = "";
   if(!ExtRisk.CanOpenNewTrade(sym, riskReject))
      return;
      
   string spreadReject = "";
   if(!ExtScanner.IsTradePermitted(symIndex, spreadReject))
      return;

   // Indicator Handles
   int fastEmaH = iMA(sym, InpExecutionTF, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   int slowEmaH = iMA(sym, InpExecutionTF, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   int baseEmaH = iMA(sym, InpExecutionTF, InpMacroEMA, 0, MODE_EMA, PRICE_CLOSE);
   
   if(fastEmaH == INVALID_HANDLE || slowEmaH == INVALID_HANDLE || baseEmaH == INVALID_HANDLE)
   {
      if(fastEmaH != INVALID_HANDLE) IndicatorRelease(fastEmaH);
      if(slowEmaH != INVALID_HANDLE) IndicatorRelease(slowEmaH);
      if(baseEmaH != INVALID_HANDLE) IndicatorRelease(baseEmaH);
      return;
   }
   
   double fastBuf[3], slowBuf[3], baseBuf[3];
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   bool copiedOk = true;
   if(CopyBuffer(fastEmaH, 0, 1, 3, fastBuf) < 3) copiedOk = false;
   if(CopyBuffer(slowEmaH, 0, 1, 3, slowBuf) < 3) copiedOk = false;
   if(CopyBuffer(baseEmaH, 0, 1, 3, baseBuf) < 3) copiedOk = false;
   if(CopyRates(sym, InpExecutionTF, 1, 5, rates) < 5) copiedOk = false;
   
   IndicatorRelease(fastEmaH);
   IndicatorRelease(slowEmaH);
   IndicatorRelease(baseEmaH);
   
   if(!copiedOk)
      return;
      
   ExtLastBarTimes[symIndex] = currentBarTime;

   double fastEma = fastBuf[2]; // completed bar 1
   double slowEma = slowBuf[2];
   double baseEma = baseBuf[2];
   
   MqlRates triggerBar = rates[0]; // bar 1
   MqlRates prevBar    = rates[1]; // bar 2
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   if(point <= 0.0) return;

   // 1. BULLISH TREND PULLBACK
   // Macro Condition: Fast EMA > Slow EMA > 200 EMA and Price > 200 EMA
   bool isBullishMacro = (fastEma > slowEma && slowEma > baseEma && triggerBar.close > baseEma);
   if(isBullishMacro)
   {
      // Pullback condition: Previous bar low touched or penetrated the 9/21 EMA corridor
      bool touchedCorridor = (prevBar.low <= fastEma || triggerBar.low <= fastEma);
      
      // Resumption Trigger: Trigger bar closes bullish (green) and above Fast EMA
      bool resumptionCandle = (triggerBar.close > triggerBar.open && triggerBar.close > fastEma);
      
      if(touchedCorridor && resumptionCandle)
      {
         double entryPrice = SymbolInfoDouble(sym, SYMBOL_ASK);
         // Protective SL placed below the recent pullback low or below slow EMA
         double swingLow = MathMin(triggerBar.low, prevBar.low);
         double slPrice = MathMin(swingLow, slowEma) - (5.0 * point);
         double slDistance = entryPrice - slPrice;
         
         if(slDistance > 0.0)
         {
            double tpPrice = entryPrice + (slDistance * InpRewardToRiskRatio);
            double volume = ExtRisk.CalculateLotSize(sym, entryPrice, slPrice);
            
            if(volume > 0.0)
            {
               string comment = "TrendPullback_Buy";
               ulong ticket = ExtTrade.ExecuteBuy(sym, volume, slPrice, tpPrice, comment);
               if(ticket > 0)
               {
                  ExtLog.Signal(sym, "BUY", entryPrice, slPrice, tpPrice,
                                StringFormat("Bullish 9/21 corridor resumption above 200 EMA (SL: %.1f pts)", slDistance/point));
               }
            }
         }
      }
   }

   // 2. BEARISH TREND PULLBACK
   // Macro Condition: Fast EMA < Slow EMA < 200 EMA and Price < 200 EMA
   bool isBearishMacro = (fastEma < slowEma && slowEma < baseEma && triggerBar.close < baseEma);
   if(isBearishMacro)
   {
      // Pullback condition: Previous bar high touched or penetrated the 9/21 EMA corridor
      bool touchedCorridor = (prevBar.high >= fastEma || triggerBar.high >= fastEma);
      
      // Resumption Trigger: Trigger bar closes bearish (red) and below Fast EMA
      bool resumptionCandle = (triggerBar.close < triggerBar.open && triggerBar.close < fastEma);
      
      if(touchedCorridor && resumptionCandle)
      {
         double entryPrice = SymbolInfoDouble(sym, SYMBOL_BID);
         // Protective SL placed above the recent pullback high or above slow EMA
         double swingHigh = MathMax(triggerBar.high, prevBar.high);
         double slPrice = MathMax(swingHigh, slowEma) + (5.0 * point);
         double slDistance = slPrice - entryPrice;
         
         if(slDistance > 0.0)
         {
            double tpPrice = entryPrice - (slDistance * InpRewardToRiskRatio);
            double volume = ExtRisk.CalculateLotSize(sym, entryPrice, slPrice);
            
            if(volume > 0.0)
            {
               string comment = "TrendPullback_Sell";
               ulong ticket = ExtTrade.ExecuteSell(sym, volume, slPrice, tpPrice, comment);
               if(ticket > 0)
               {
                  ExtLog.Signal(sym, "SELL", entryPrice, slPrice, tpPrice,
                                StringFormat("Bearish 9/21 corridor resumption below 200 EMA (SL: %.1f pts)", slDistance/point));
               }
            }
         }
      }
   }
}
