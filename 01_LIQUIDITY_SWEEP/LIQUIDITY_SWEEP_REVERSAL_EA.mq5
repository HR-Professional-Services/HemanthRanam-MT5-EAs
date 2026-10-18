//+------------------------------------------------------------------+
//|                                   LIQUIDITY_SWEEP_REVERSAL_EA.mq5|
//|                                    Copyright 2026, Hemanth Ranam |
//|                             https://github.com/HR-Professional-Services |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, Hemanth Ranam"
#property link        "https://github.com/HR-Professional-Services/HemanthRanam-MT5-EAs"
#property version     "2.00"
#property description "Quantitative Liquidity Sweep and Mean Reversal Engine."
#property description "Detects failed breakouts past swing highs/lows with confirmed reclaim displacement."

// Include Core Architectural Modules
#include "..\Include\RiskManager.mqh"
#include "..\Include\SymbolScanner.mqh"
#include "..\Include\TradeExecutor.mqh"
#include "..\Include\MarketFilters.mqh"
#include "..\Include\Logger.mqh"

//--- Input Groups
input group "=== Watchlist & Multi-Symbol Scanning ==="
input string            InpWatchlist            = "XAUUSD,XAGUSD,US500,US100,USOIL,EURUSD,GBPUSD,USDJPY"; // Multi-Symbol List (CSV)
input int               InpMaxSpreadPoints      = 50;                     // Maximum Permitted Spread (Points)
input int               InpScanTimerSeconds     = 5;                      // Scanner Polling Interval (Seconds)

input group "=== Liquidity Sweep Strategy Parameters ==="
input ENUM_TIMEFRAMES   InpExecutionTF          = PERIOD_M15;             // Execution Timeframe
input int               InpSwingLookbackBars    = 24;                     // Swing High/Low Lookback Window (Bars)
input double            InpMinSweepPoints       = 15.0;                   // Minimum Sweep Penetration (Points)
input double            InpMaxSweepPoints       = 350.0;                  // Maximum Sweep Penetration (Points)
input double            InpMinDisplacementR     = 0.5;                    // Minimum Reversal Candle Body Ratio
input double            InpRewardToRiskRatio    = 2.5;                    // Target Reward-to-Risk Ratio (1:2.5)

input group "=== Risk Management ==="
input double            InpRiskPercent          = 0.5;                    // Risk Percentage per Trade (Default 0.5%)
input double            InpMaxDailyDrawdown     = 2.0;                    // Max Daily Equity Drawdown Limit (%)
input double            InpMaxPortfolioRisk     = 1.5;                    // Max Aggregate Open Portfolio Risk (%)
input int               InpMaxTotalPositions    = 5;                      // Max Concurrent Positions Total
input int               InpMaxPositionsPerSymbol= 1;                      // Max Concurrent Positions Per Symbol

input group "=== Trade Execution & Protection ==="
input ulong             InpMagicNumber          = 101001;                 // EA Magic Number
input ulong             InpSlippagePoints       = 10;                     // Max Slippage (Points)
input bool              InpEnableBreakEven      = true;                   // Enable Break-Even at +1R
input double            InpBreakEvenTriggerR    = 1.0;                    // Break-Even Trigger (R)
input double            InpBreakEvenBufferPts   = 5.0;                    // Break-Even Buffer (Points)
input bool              InpEnableTrailing       = false;                  // Enable Trailing Stop
input double            InpTrailingStopPts      = 60.0;                   // Trailing Distance (Points)

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
   ExtLog.Init("LIQUIDITY_SWEEP_EA", true, false, false);
   ExtLog.Info("Initializing Liquidity Sweep and Reversal EA...");
   
   // 1. Initialize Scanner
   if(!ExtScanner.Init(InpWatchlist, InpMaxSpreadPoints))
   {
      ExtLog.Error("Failed to initialize symbol watchlist.");
      return INIT_FAILED;
   }
   
   // 2. Initialize Risk Manager
   ExtRisk.Init(InpRiskPercent, InpMaxDailyDrawdown, InpMaxPortfolioRisk, 
                InpMaxTotalPositions, InpMaxPositionsPerSymbol, 3, 60);
                
   // 3. Initialize Trade Executor
   ExtTrade.Init(InpMagicNumber, InpSlippagePoints, InpEnableBreakEven, 
                 InpBreakEvenTriggerR, InpBreakEvenBufferPts, 
                 InpEnableTrailing, InpTrailingStopPts, 10.0);
                 
   // 4. Initialize Market Filters
   ExtFilter.Init(InpEnableSessionFilter, InpBrokerGMTOffset, InpTradeAsian, 
                  InpTradeLondon, InpTradeNewYork, InpRolloverBlackout, 30);
                  
   // Track Bar Times for closed-bar execution
   ArrayResize(ExtLastBarTimes, ExtScanner.GetSymbolCount());
   ArrayInitialize(ExtLastBarTimes, 0);

   // Setup Timer for asynchronous multi-symbol radar
   EventSetTimer(InpScanTimerSeconds);
   
   ExtLog.Info(StringFormat("Initialization complete. Monitoring %d instruments on %s timeframe.",
               ExtScanner.GetSymbolCount(), EnumToString(InpExecutionTF)));
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
//| Periodic Timer Event: Multi-Symbol Scanning Radar                |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Check Session Gate
   string sessionReject = "";
   if(!ExtFilter.IsSessionAllowed(sessionReject))
      return;
      
   // Maintain Daily Baseline
   ExtRisk.CheckDailyReset();
   
   // Scan All Configured Instruments
   int totalSymbols = ExtScanner.GetSymbolCount();
   for(int i = 0; i < totalSymbols; i++)
   {
      string sym = ExtScanner.GetSymbol(i);
      
      // Active Trade Management (Break-even, Trailing Stop)
      ExtTrade.ManageOpenPositions(sym);
      
      // Evaluate New Setup on Bar Close
      ProcessSymbolSweepStrategy(i, sym);
   }
}

//+------------------------------------------------------------------+
//| Tick Event Handler                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   // Quick management on current chart symbol
   ExtTrade.ManageOpenPositions(Symbol());
}

//+------------------------------------------------------------------+
//| Strategy Logic: Liquidity Sweep Detection & Execution            |
//+------------------------------------------------------------------+
void ProcessSymbolSweepStrategy(const int symIndex, const string sym)
{
   // Check if a new bar has closed
   datetime currentBarTime = (datetime)SeriesInfoInteger(sym, InpExecutionTF, SERIES_LASTBAR_DATE);
   if(currentBarTime == 0 || currentBarTime == ExtLastBarTimes[symIndex])
      return;
      
   // Pre-Trade Risk Check
   string riskReject = "";
   if(!ExtRisk.CanOpenNewTrade(sym, riskReject))
      return;
      
   // Spread and Trade Permissions Check
   string spreadReject = "";
   if(!ExtScanner.IsTradePermitted(symIndex, spreadReject))
      return;

   // Fetch Historical Bars (Need Lookback + 2 bars)
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(sym, InpExecutionTF, 1, InpSwingLookbackBars + 2, rates);
   if(copied < InpSwingLookbackBars + 2)
      return;
      
   ExtLastBarTimes[symIndex] = currentBarTime;

   // 1. Identify Prominent Swing High and Low from prior window (excluding most recent closed bar)
   double swingHigh = rates[1].high;
   double swingLow  = rates[1].low;
   
   for(int b = 2; b <= InpSwingLookbackBars; b++)
   {
      if(rates[b].high > swingHigh) swingHigh = rates[b].high;
      if(rates[b].low < swingLow)   swingLow  = rates[b].low;
   }
   
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   if(point <= 0.0) return;
   
   MqlRates triggerBar = rates[0]; // Most recently completed bar
   double barRange = triggerBar.high - triggerBar.low;
   if(barRange <= 0.0) return;

   // 2. BULLISH LIQUIDITY SWEEP & RECLAIM
   // Condition: Bar pierced below swingLow, but closed firmly back ABOVE swingLow
   if(triggerBar.low < swingLow && triggerBar.close > swingLow)
   {
      double sweepDepthPts = (swingLow - triggerBar.low) / point;
      if(sweepDepthPts >= InpMinSweepPoints && sweepDepthPts <= InpMaxSweepPoints)
      {
         // Verify Reversal Displacement: Close in upper 50% of bar range
         double bodyReversal = (triggerBar.close - triggerBar.low) / barRange;
         if(bodyReversal >= InpMinDisplacementR)
         {
            double entryPrice = SymbolInfoDouble(sym, SYMBOL_ASK);
            double slPrice = triggerBar.low - (5.0 * point); // Protective SL below sweep wick
            double slDistance = entryPrice - slPrice;
            
            if(slDistance > 0.0)
            {
               double tpPrice = entryPrice + (slDistance * InpRewardToRiskRatio);
               double volume = ExtRisk.CalculateLotSize(sym, entryPrice, slPrice);
               
               if(volume > 0.0)
               {
                  string comment = "SweepReversal_Buy";
                  ulong ticket = ExtTrade.ExecuteBuy(sym, volume, slPrice, tpPrice, comment);
                  if(ticket > 0)
                  {
                     ExtLog.Signal(sym, "BUY", entryPrice, slPrice, tpPrice, 
                                   StringFormat("Bullish sweep of %.5f (Depth: %.1f pts)", swingLow, sweepDepthPts));
                  }
               }
            }
         }
      }
   }
   
   // 3. BEARISH LIQUIDITY SWEEP & RECLAIM
   // Condition: Bar pierced above swingHigh, but closed firmly back BELOW swingHigh
   if(triggerBar.high > swingHigh && triggerBar.close < swingHigh)
   {
      double sweepDepthPts = (triggerBar.high - swingHigh) / point;
      if(sweepDepthPts >= InpMinSweepPoints && sweepDepthPts <= InpMaxSweepPoints)
      {
         // Verify Reversal Displacement: Close in lower 50% of bar range
         double bodyReversal = (triggerBar.high - triggerBar.close) / barRange;
         if(bodyReversal >= InpMinDisplacementR)
         {
            double entryPrice = SymbolInfoDouble(sym, SYMBOL_BID);
            double slPrice = triggerBar.high + (5.0 * point); // Protective SL above sweep wick
            double slDistance = slPrice - entryPrice;
            
            if(slDistance > 0.0)
            {
               double tpPrice = entryPrice - (slDistance * InpRewardToRiskRatio);
               double volume = ExtRisk.CalculateLotSize(sym, entryPrice, slPrice);
               
               if(volume > 0.0)
               {
                  string comment = "SweepReversal_Sell";
                  ulong ticket = ExtTrade.ExecuteSell(sym, volume, slPrice, tpPrice, comment);
                  if(ticket > 0)
                  {
                     ExtLog.Signal(sym, "SELL", entryPrice, slPrice, tpPrice, 
                                   StringFormat("Bearish sweep of %.5f (Depth: %.1f pts)", swingHigh, sweepDepthPts));
                  }
               }
            }
         }
      }
   }
}
