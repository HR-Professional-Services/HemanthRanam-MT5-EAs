//+------------------------------------------------------------------+
//|                                   ADAPTIVE_MARKET_REGIME_EA.mq5  |
//|                                    Copyright 2026, Hemanth Ranam |
//|                             https://github.com/HR-Professional-Services |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, Hemanth Ranam"
#property link        "https://github.com/HR-Professional-Services/HemanthRanam-MT5-EAs"
#property version     "2.00"
#property description "Adaptive Quantitative Market-Regime Strategy."
#property description "Dynamically classifies Trend, Range, and Squeeze states, routing execution to validated regime sub-modules."

// Include Core Architectural Modules
#include "..\Include\RiskManager.mqh"
#include "..\Include\SymbolScanner.mqh"
#include "..\Include\TradeExecutor.mqh"
#include "..\Include\MarketFilters.mqh"
#include "..\Include\RegimeClassifier.mqh"
#include "..\Include\Logger.mqh"

//--- Input Groups
input group "=== Watchlist & Multi-Symbol Scanning ==="
input string            InpWatchlist            = "XAUUSD,XAGUSD,US500,US100,USOIL,EURUSD,GBPUSD,USDJPY"; // Multi-Symbol List (CSV)
input int               InpMaxSpreadPoints      = 40;                     // Maximum Permitted Spread (Points)
input int               InpScanTimerSeconds     = 5;                      // Scanner Polling Interval (Seconds)

input group "=== Regime Classification Settings ==="
input ENUM_TIMEFRAMES   InpExecutionTF          = PERIOD_M15;             // Execution Timeframe
input int               InpADXPeriod            = 14;                     // ADX Trend Strength Period
input double            InpTrendADXThreshold    = 25.0;                   // Minimum ADX for Trend Regime (>25)
input double            InpRangeADXThreshold    = 20.0;                   // Maximum ADX for Ranging Regime (<20)
input int               InpFastEMA              = 9;                      // Fast Trend EMA
input int               InpSlowEMA              = 21;                     // Slow Trend EMA
input int               InpBaselineEMA          = 200;                    // Macro Baseline EMA
input double            InpRewardToRiskRatio    = 2.2;                    // Minimum Target R:R Ratio (1:2.2)

input group "=== Risk Management ==="
input double            InpRiskPercent          = 0.5;                    // Risk Percentage per Trade (Default 0.5%)
input double            InpMaxDailyDrawdown     = 2.0;                    // Max Daily Equity Drawdown Limit (%)
input double            InpMaxPortfolioRisk     = 1.5;                    // Max Aggregate Open Portfolio Risk (%)
input int               InpMaxTotalPositions    = 5;                      // Max Concurrent Positions Total
input int               InpMaxPositionsPerSymbol= 1;                      // Max Concurrent Positions Per Symbol

input group "=== Trade Execution & Protection ==="
input ulong             InpMagicNumber          = 105005;                 // EA Magic Number
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
CRegimeClassifier ExtClassifier;
CLogger           ExtLog;

datetime          ExtLastBarTimes[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   ExtLog.Init("ADAPTIVE_REGIME_EA", true, false, false);
   ExtLog.Info("Initializing Adaptive Market-Regime Strategy EA...");
   
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
                  
   ExtClassifier.Init(InpADXPeriod, InpTrendADXThreshold, InpFastEMA, InpSlowEMA, InpBaselineEMA);
   
   ArrayResize(ExtLastBarTimes, ExtScanner.GetSymbolCount());
   ArrayInitialize(ExtLastBarTimes, 0);

   EventSetTimer(InpScanTimerSeconds);
   
   ExtLog.Info(StringFormat("Initialization complete. Active across %d instruments.", ExtScanner.GetSymbolCount()));
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
      ProcessAdaptiveRegimeStrategy(i, sym);
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
//| Strategy Logic: Dynamic Regime Classification & Routing          |
//+------------------------------------------------------------------+
void ProcessAdaptiveRegimeStrategy(const int symIndex, const string sym)
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

   // 1. Detect Objective Market Regime
   ENUM_MARKET_REGIME currentRegime = ExtClassifier.DetectRegime(sym, InpExecutionTF);
   
   // Safety: If unstable or high-risk whipsaw, strictly stand aside
   if(currentRegime == REGIME_UNSTABLE_HIGH_RISK || currentRegime == REGIME_UNKNOWN)
      return;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(sym, InpExecutionTF, 1, 10, rates) < 10)
      return;
      
   ExtLastBarTimes[symIndex] = currentBarTime;

   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   if(point <= 0.0) return;
   
   MqlRates triggerBar = rates[0]; // bar 1
   MqlRates prevBar    = rates[1]; // bar 2

   // ------------------------------------------------------------------
   // MODULE A: TREND CONTINUATION REGIME (REGIME_TREND_BULL / BEAR)
   // ------------------------------------------------------------------
   if(currentRegime == REGIME_TREND_BULL)
   {
      // Bullish Trend Module: Enter on shallow pullback to 9 EMA
      int fastHandle = iMA(sym, InpExecutionTF, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
      if(fastHandle != INVALID_HANDLE)
      {
         double fastBuf[2];
         if(CopyBuffer(fastHandle, 0, 1, 2, fastBuf) == 2)
         {
            double fastEma = fastBuf[1];
            // Condition: bar tested 9 EMA and closed green above it
            if(triggerBar.low <= fastEma && triggerBar.close > fastEma && triggerBar.close > triggerBar.open)
            {
               double entryPrice = SymbolInfoDouble(sym, SYMBOL_ASK);
               double slPrice = triggerBar.low - (5.0 * point);
               double slDistance = entryPrice - slPrice;
               
               if(slDistance > 0.0)
               {
                  double tpPrice = entryPrice + (slDistance * InpRewardToRiskRatio);
                  double volume = ExtRisk.CalculateLotSize(sym, entryPrice, slPrice);
                  if(volume > 0.0)
                  {
                     string comment = "Adaptive_TrendBuy";
                     ulong ticket = ExtTrade.ExecuteBuy(sym, volume, slPrice, tpPrice, comment);
                     if(ticket > 0)
                     {
                        ExtLog.Signal(sym, "BUY", entryPrice, slPrice, tpPrice, "Adaptive Bull Trend Module Triggered");
                     }
                  }
               }
            }
         }
         IndicatorRelease(fastHandle);
      }
   }
   else if(currentRegime == REGIME_TREND_BEAR)
   {
      // Bearish Trend Module: Enter on shallow pullback to 9 EMA
      int fastHandle = iMA(sym, InpExecutionTF, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
      if(fastHandle != INVALID_HANDLE)
      {
         double fastBuf[2];
         if(CopyBuffer(fastHandle, 0, 1, 2, fastBuf) == 2)
         {
            double fastEma = fastBuf[1];
            // Condition: bar tested 9 EMA and closed red below it
            if(triggerBar.high >= fastEma && triggerBar.close < fastEma && triggerBar.close < triggerBar.open)
            {
               double entryPrice = SymbolInfoDouble(sym, SYMBOL_BID);
               double slPrice = triggerBar.high + (5.0 * point);
               double slDistance = slPrice - entryPrice;
               
               if(slDistance > 0.0)
               {
                  double tpPrice = entryPrice - (slDistance * InpRewardToRiskRatio);
                  double volume = ExtRisk.CalculateLotSize(sym, entryPrice, slPrice);
                  if(volume > 0.0)
                  {
                     string comment = "Adaptive_TrendSell";
                     ulong ticket = ExtTrade.ExecuteSell(sym, volume, slPrice, tpPrice, comment);
                     if(ticket > 0)
                     {
                        ExtLog.Signal(sym, "SELL", entryPrice, slPrice, tpPrice, "Adaptive Bear Trend Module Triggered");
                     }
                  }
               }
            }
         }
         IndicatorRelease(fastHandle);
      }
   }
   
   // ------------------------------------------------------------------
   // MODULE B: MEAN REVERSION IN RANGING REGIME (REGIME_RANGING)
   // ------------------------------------------------------------------
   else if(currentRegime == REGIME_RANGING)
   {
      // Mean reversion using Bollinger Bands & RSI in flat regime
      int bandsHandle = iBands(sym, InpExecutionTF, 20, 0, 2.0, PRICE_CLOSE);
      int rsiHandle   = iRSI(sym, InpExecutionTF, 14, PRICE_CLOSE);
      
      if(bandsHandle != INVALID_HANDLE && rsiHandle != INVALID_HANDLE)
      {
         double upperBand[2], lowerBand[2], rsiBuf[2];
         if(CopyBuffer(bandsHandle, 1, 1, 2, upperBand) == 2 &&
            CopyBuffer(bandsHandle, 2, 1, 2, lowerBand) == 2 &&
            CopyBuffer(rsiHandle, 0, 1, 2, rsiBuf) == 2)
         {
            double rsi = rsiBuf[1];
            
            // Overextended at Lower Band with Oversold RSI -> Mean Reversion BUY
            if(triggerBar.low <= lowerBand[1] && triggerBar.close > lowerBand[1] && rsi <= 35.0)
            {
               double entryPrice = SymbolInfoDouble(sym, SYMBOL_ASK);
               double slPrice = triggerBar.low - (5.0 * point);
               double slDistance = entryPrice - slPrice;
               
               if(slDistance > 0.0)
               {
                  double tpPrice = entryPrice + (slDistance * InpRewardToRiskRatio);
                  double volume = ExtRisk.CalculateLotSize(sym, entryPrice, slPrice);
                  if(volume > 0.0)
                  {
                     string comment = "Adaptive_RangeBuy";
                     ulong ticket = ExtTrade.ExecuteBuy(sym, volume, slPrice, tpPrice, comment);
                     if(ticket > 0)
                     {
                        ExtLog.Signal(sym, "BUY", entryPrice, slPrice, tpPrice, "Adaptive Range Reversion Buy");
                     }
                  }
               }
            }
            // Overextended at Upper Band with Overbought RSI -> Mean Reversion SELL
            else if(triggerBar.high >= upperBand[1] && triggerBar.close < upperBand[1] && rsi >= 65.0)
            {
               double entryPrice = SymbolInfoDouble(sym, SYMBOL_BID);
               double slPrice = triggerBar.high + (5.0 * point);
               double slDistance = slPrice - entryPrice;
               
               if(slDistance > 0.0)
               {
                  double tpPrice = entryPrice - (slDistance * InpRewardToRiskRatio);
                  double volume = ExtRisk.CalculateLotSize(sym, entryPrice, slPrice);
                  if(volume > 0.0)
                  {
                     string comment = "Adaptive_RangeSell";
                     ulong ticket = ExtTrade.ExecuteSell(sym, volume, slPrice, tpPrice, comment);
                     if(ticket > 0)
                     {
                        ExtLog.Signal(sym, "SELL", entryPrice, slPrice, tpPrice, "Adaptive Range Reversion Sell");
                     }
                  }
               }
            }
         }
         IndicatorRelease(bandsHandle);
         IndicatorRelease(rsiHandle);
      }
   }
}
