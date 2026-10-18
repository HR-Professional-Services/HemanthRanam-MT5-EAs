//+------------------------------------------------------------------+
//|                               MARKET_STRUCTURE_MOMENTUM_EA.mq5   |
//|                                    Copyright 2026, Hemanth Ranam |
//|                             https://github.com/HR-Professional-Services |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, Hemanth Ranam"
#property link        "https://github.com/HR-Professional-Services/HemanthRanam-MT5-EAs"
#property version     "2.00"
#property description "Market Structure Shift (BOS/CHoCH) and Momentum Engine."
#property description "Trades structural fractal pivot breaks confirmed by momentum impulse."

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

input group "=== Market Structure Parameters ==="
input ENUM_TIMEFRAMES   InpExecutionTF          = PERIOD_M15;             // Execution Timeframe
input int               InpPivotStrength        = 3;                      // Pivot Bars Left/Right (e.g. 3 bars left, 3 right)
input int               InpLookbackWindow       = 40;                     // Max Bars to search for valid Structure Pivots
input int               InpRSIPeriod            = 14;                     // Momentum RSI Period
input double            InpBullishRSIMin        = 53.0;                   // Bullish Breakout Min RSI
input double            InpBearishRSIMax        = 47.0;                   // Bearish Breakout Max RSI
input double            InpRewardToRiskRatio    = 2.4;                    // Minimum R:R Target (1:2.4)

input group "=== Risk Management ==="
input double            InpRiskPercent          = 0.5;                    // Risk Percentage per Trade (Default 0.5%)
input double            InpMaxDailyDrawdown     = 2.0;                    // Max Daily Equity Drawdown Limit (%)
input double            InpMaxPortfolioRisk     = 1.5;                    // Max Aggregate Open Portfolio Risk (%)
input int               InpMaxTotalPositions    = 5;                      // Max Concurrent Positions Total
input int               InpMaxPositionsPerSymbol= 1;                      // Max Concurrent Positions Per Symbol

input group "=== Trade Execution & Protection ==="
input ulong             InpMagicNumber          = 104004;                 // EA Magic Number
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
   ExtLog.Init("MARKET_STRUCTURE_EA", true, false, false);
   ExtLog.Info("Initializing Market Structure and Momentum EA...");
   
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
   
   ExtLog.Info(StringFormat("Initialization complete. Tracking structure shifts across %d instruments.",
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
      ProcessSymbolStructureStrategy(i, sym);
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
//| Strategy Logic: Break of Structure (BOS) & Momentum Filter       |
//+------------------------------------------------------------------+
void ProcessSymbolStructureStrategy(const int symIndex, const string sym)
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

   // Need sufficient history to detect confirmed pivots
   int neededBars = InpLookbackWindow + (InpPivotStrength * 2) + 2;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(sym, InpExecutionTF, 1, neededBars, rates) < neededBars)
      return;
      
   // RSI Handle for Momentum Confirmation
   int rsiHandle = iRSI(sym, InpExecutionTF, InpRSIPeriod, PRICE_CLOSE);
   if(rsiHandle == INVALID_HANDLE)
      return;
      
   double rsiBuf[2];
   if(CopyBuffer(rsiHandle, 0, 1, 2, rsiBuf) < 2)
   {
      IndicatorRelease(rsiHandle);
      return;
   }
   IndicatorRelease(rsiHandle);
   
   ExtLastBarTimes[symIndex] = currentBarTime;

   double currentRsi = rsiBuf[1];
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   if(point <= 0.0) return;

   MqlRates triggerBar = rates[0]; // Completed bar 1
   MqlRates prevBar    = rates[1]; // Completed bar 2

   // Find the most recent confirmed structural swing high and swing low
   double recentPivotHigh = 0.0;
   double recentPivotLow  = 0.0;
   int pivotHighIdx = -1;
   int pivotLowIdx  = -1;
   
   for(int i = InpPivotStrength + 1; i <= InpLookbackWindow; i++)
   {
      // Check Swing High Pivot
      bool isHighPivot = true;
      for(int k = 1; k <= InpPivotStrength; k++)
      {
         if(rates[i].high <= rates[i-k].high || rates[i].high <= rates[i+k].high)
         {
            isHighPivot = false;
            break;
         }
      }
      if(isHighPivot && recentPivotHigh == 0.0)
      {
         recentPivotHigh = rates[i].high;
         pivotHighIdx = i;
      }
      
      // Check Swing Low Pivot
      bool isLowPivot = true;
      for(int k = 1; k <= InpPivotStrength; k++)
      {
         if(rates[i].low >= rates[i-k].low || rates[i].low >= rates[i+k].low)
         {
            isLowPivot = false;
            break;
         }
      }
      if(isLowPivot && recentPivotLow == 0.0)
      {
         recentPivotLow = rates[i].low;
         pivotLowIdx = i;
      }
      
      if(recentPivotHigh > 0.0 && recentPivotLow > 0.0)
         break;
   }

   // 1. BULLISH BREAK OF STRUCTURE (BOS)
   // Condition: Prior bar was below or at pivot high, trigger bar breaks and closes strictly ABOVE confirmed pivot high
   if(recentPivotHigh > 0.0 && prevBar.close <= recentPivotHigh && triggerBar.close > recentPivotHigh)
   {
      // Momentum confirmation
      if(currentRsi >= InpBullishRSIMin)
      {
         double entryPrice = SymbolInfoDouble(sym, SYMBOL_ASK);
         // Protective SL placed below the pivot low or trigger bar low
         double slPrice = (recentPivotLow > 0.0) ? recentPivotLow : triggerBar.low;
         slPrice -= (5.0 * point);
         double slDistance = entryPrice - slPrice;
         
         if(slDistance > 0.0)
         {
            double tpPrice = entryPrice + (slDistance * InpRewardToRiskRatio);
            double volume = ExtRisk.CalculateLotSize(sym, entryPrice, slPrice);
            
            if(volume > 0.0)
            {
               string comment = "StructBOS_Buy";
               ulong ticket = ExtTrade.ExecuteBuy(sym, volume, slPrice, tpPrice, comment);
               if(ticket > 0)
               {
                  ExtLog.Signal(sym, "BUY", entryPrice, slPrice, tpPrice,
                                StringFormat("Bullish BOS break of %.5f with RSI %.1f", recentPivotHigh, currentRsi));
               }
            }
         }
      }
   }

   // 2. BEARISH BREAK OF STRUCTURE (BOS)
   // Condition: Prior bar was above or at pivot low, trigger bar breaks and closes strictly BELOW confirmed pivot low
   if(recentPivotLow > 0.0 && prevBar.close >= recentPivotLow && triggerBar.close < recentPivotLow)
   {
      // Momentum confirmation
      if(currentRsi <= InpBearishRSIMax)
      {
         double entryPrice = SymbolInfoDouble(sym, SYMBOL_BID);
         // Protective SL placed above the pivot high or trigger bar high
         double slPrice = (recentPivotHigh > 0.0) ? recentPivotHigh : triggerBar.high;
         slPrice += (5.0 * point);
         double slDistance = slPrice - entryPrice;
         
         if(slDistance > 0.0)
         {
            double tpPrice = entryPrice - (slDistance * InpRewardToRiskRatio);
            double volume = ExtRisk.CalculateLotSize(sym, entryPrice, slPrice);
            
            if(volume > 0.0)
            {
               string comment = "StructBOS_Sell";
               ulong ticket = ExtTrade.ExecuteSell(sym, volume, slPrice, tpPrice, comment);
               if(ticket > 0)
               {
                  ExtLog.Signal(sym, "SELL", entryPrice, slPrice, tpPrice,
                                StringFormat("Bearish BOS break of %.5f with RSI %.1f", recentPivotLow, currentRsi));
               }
            }
         }
      }
   }
}
