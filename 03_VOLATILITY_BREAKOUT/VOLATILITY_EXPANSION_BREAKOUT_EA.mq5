//+------------------------------------------------------------------+
//|                               VOLATILITY_EXPANSION_BREAKOUT_EA.mq5|
//|                                    Copyright 2026, Hemanth Ranam |
//|                             https://github.com/HR-Professional-Services |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, Hemanth Ranam"
#property link        "https://github.com/HR-Professional-Services/HemanthRanam-MT5-EAs"
#property version     "2.00"
#property description "Volatility Expansion and Range Breakout System."
#property description "Detects narrow-range consolidation squeezes followed by explosive volume breakouts."

// Include Core Architectural Modules
#include "..\Include\RiskManager.mqh"
#include "..\Include\SymbolScanner.mqh"
#include "..\Include\TradeExecutor.mqh"
#include "..\Include\MarketFilters.mqh"
#include "..\Include\Logger.mqh"

//--- Input Groups
input group "=== Watchlist & Multi-Symbol Scanning ==="
input string            InpWatchlist            = "XAUUSD,XAGUSD,US500,US100,USOIL,EURUSD,GBPUSD,USDJPY"; // Multi-Symbol List (CSV)
input int               InpMaxSpreadPoints      = 45;                     // Maximum Permitted Spread (Points)
input int               InpScanTimerSeconds     = 5;                      // Scanner Polling Interval (Seconds)

input group "=== Volatility Breakout Parameters ==="
input ENUM_TIMEFRAMES   InpExecutionTF          = PERIOD_M15;             // Execution Timeframe
input int               InpCompressionBars      = 20;                     // Compression Lookback Window (Bars)
input double            InpMaxCompressionATR    = 1.8;                    // Max Allowed Range / ATR Ratio (Squeeze)
input double            InpMinVolumeMultiplier  = 1.25;                   // Minimum Breakout Volume vs Average
input double            InpRewardToRiskRatio    = 2.5;                    // Target R:R Ratio (1:2.5)

input group "=== Risk Management ==="
input double            InpRiskPercent          = 0.5;                    // Risk Percentage per Trade (Default 0.5%)
input double            InpMaxDailyDrawdown     = 2.0;                    // Max Daily Equity Drawdown Limit (%)
input double            InpMaxPortfolioRisk     = 1.5;                    // Max Aggregate Open Portfolio Risk (%)
input int               InpMaxTotalPositions    = 5;                      // Max Concurrent Positions Total
input int               InpMaxPositionsPerSymbol= 1;                      // Max Concurrent Positions Per Symbol

input group "=== Trade Execution & Protection ==="
input ulong             InpMagicNumber          = 103003;                 // EA Magic Number
input ulong             InpSlippagePoints       = 10;                     // Max Slippage (Points)
input bool              InpEnableBreakEven      = true;                   // Enable Break-Even at +1R
input double            InpBreakEvenTriggerR    = 1.0;                    // Break-Even Trigger (R)
input double            InpBreakEvenBufferPts   = 5.0;                    // Break-Even Buffer (Points)
input bool              InpEnableTrailing       = true;                   // Enable Trailing Stop
input double            InpTrailingStopPts      = 55.0;                   // Trailing Distance (Points)

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
   ExtLog.Init("VOLATILITY_BREAKOUT_EA", true, false, false);
   ExtLog.Info("Initializing Volatility Expansion Breakout EA...");
   
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
   
   ExtLog.Info(StringFormat("Initialization complete. Monitoring %d instruments for volatility squeezes.",
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
      ProcessSymbolBreakoutStrategy(i, sym);
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
//| Strategy Logic: Volatility Squeeze & Expansion Breakout          |
//+------------------------------------------------------------------+
void ProcessSymbolBreakoutStrategy(const int symIndex, const string sym)
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

   // Copy Historical Rates (Window + 2 bars)
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int neededBars = InpCompressionBars + 3;
   if(CopyRates(sym, InpExecutionTF, 1, neededBars, rates) < neededBars)
      return;
      
   // ATR Handle for Volatility Benchmark
   int atrHandle = iATR(sym, InpExecutionTF, 14);
   if(atrHandle == INVALID_HANDLE)
      return;
      
   double atrBuf[1];
   if(CopyBuffer(atrHandle, 0, 1, 1, atrBuf) < 1)
   {
      IndicatorRelease(atrHandle);
      return;
   }
   IndicatorRelease(atrHandle);
   
   ExtLastBarTimes[symIndex] = currentBarTime;

   double currentAtr = atrBuf[0];
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   if(point <= 0.0 || currentAtr <= 0.0) return;

   // 1. Identify Consolidation Range prior to the trigger bar (bars 2 to InpCompressionBars)
   double boxHigh = rates[1].high;
   double boxLow  = rates[1].low;
   long   totalVolume = 0;
   
   for(int b = 2; b < InpCompressionBars; b++)
   {
      if(rates[b].high > boxHigh) boxHigh = rates[b].high;
      if(rates[b].low < boxLow)   boxLow  = rates[b].low;
      totalVolume += rates[b].tick_volume;
   }
   
   double avgVolume = (double)totalVolume / (double)(InpCompressionBars - 2);
   double boxHeight = boxHigh - boxLow;
   
   // 2. Volatility Compression Check (Squeeze Criterion)
   // The prior consolidation range must not exceed InpMaxCompressionATR multiples of ATR
   bool isCompressed = (boxHeight <= (currentAtr * InpMaxCompressionATR));
   if(!isCompressed)
      return;

   MqlRates triggerBar = rates[0]; // Completed breakout bar
   bool isVolumeExpanded = (triggerBar.tick_volume >= (long)(avgVolume * InpMinVolumeMultiplier));
   if(!isVolumeExpanded)
      return;

   // 3. BULLISH BREAKOUT
   // Condition: Trigger bar opened inside/near the box and closed firmly ABOVE boxHigh
   if(triggerBar.close > boxHigh && triggerBar.close > triggerBar.open)
   {
      double entryPrice = SymbolInfoDouble(sym, SYMBOL_ASK);
      // Protective SL placed at box midpoint or below trigger bar low
      double boxMid = (boxHigh + boxLow) / 2.0;
      double slPrice = MathMax(boxMid, triggerBar.low) - (5.0 * point);
      double slDistance = entryPrice - slPrice;
      
      if(slDistance > 0.0)
      {
         double tpPrice = entryPrice + (slDistance * InpRewardToRiskRatio);
         double volume = ExtRisk.CalculateLotSize(sym, entryPrice, slPrice);
         
         if(volume > 0.0)
         {
            string comment = "VolBreakout_Buy";
            ulong ticket = ExtTrade.ExecuteBuy(sym, volume, slPrice, tpPrice, comment);
            if(ticket > 0)
            {
               ExtLog.Signal(sym, "BUY", entryPrice, slPrice, tpPrice,
                             StringFormat("Bullish squeeze breakout above %.5f (Vol: %.1fx avg)", 
                             boxHigh, (double)triggerBar.tick_volume / avgVolume));
            }
         }
      }
   }

   // 4. BEARISH BREAKOUT
   // Condition: Trigger bar opened inside/near the box and closed firmly BELOW boxLow
   if(triggerBar.close < boxLow && triggerBar.close < triggerBar.open)
   {
      double entryPrice = SymbolInfoDouble(sym, SYMBOL_BID);
      // Protective SL placed at box midpoint or above trigger bar high
      double boxMid = (boxHigh + boxLow) / 2.0;
      double slPrice = MathMin(boxMid, triggerBar.high) + (5.0 * point);
      double slDistance = slPrice - entryPrice;
      
      if(slDistance > 0.0)
      {
         double tpPrice = entryPrice - (slDistance * InpRewardToRiskRatio);
         double volume = ExtRisk.CalculateLotSize(sym, entryPrice, slPrice);
         
         if(volume > 0.0)
         {
            string comment = "VolBreakout_Sell";
            ulong ticket = ExtTrade.ExecuteSell(sym, volume, slPrice, tpPrice, comment);
            if(ticket > 0)
            {
               ExtLog.Signal(sym, "SELL", entryPrice, slPrice, tpPrice,
                             StringFormat("Bearish squeeze breakout below %.5f (Vol: %.1fx avg)", 
                             boxLow, (double)triggerBar.tick_volume / avgVolume));
            }
         }
      }
   }
}
