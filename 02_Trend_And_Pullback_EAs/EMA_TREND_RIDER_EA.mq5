//+------------------------------------------------------------------+
//|                                        EMA_Trend_Rider_PRO.mq5   |
//|                                  Copyright 2026, AI Collaborator |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, AI Collaborator"
#property link      "https://www.mql5.com"
#property version   "3.00"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//--- Input Parameters
input group "--- Risk & Capital Defense ---"
input double   InpRiskPercent       = 2.0;       // Risk % Per Trade (Dynamic Lot Sizing)
input double   InpMinRR             = 2.0;       // Minimum Risk-to-Reward allowed for Entry
input double   InpMaxTP             = 3.0;       // Core Target Profit Ratio (1:3)
input double   InpPartialRR         = 2.0;       // Partial Target Profit Ratio (1:2)
input double   InpPartialClosePct   = 0.5;       // % of volume to close at Partials (50%)
input double   InpMaxDailyDrawdown  = 5.0;       // Max Daily Loss % Circuit Breaker

input group "--- Core Indicators (Execution TF) ---"
input int      InpFastEMA           = 9;         // Fast EMA Period
input int      InpSlowEMA           = 21;        // Slow EMA Period

input group "--- Macro Trend Filter (Higher TF) ---"
input int      InpTrendEMA          = 200;       // Trend Filter EMA Period
input ENUM_TIMEFRAMES InpTrendTF    = PERIOD_H1; // Trend Filter Timeframe (1-Hour)

input group "--- Volatility & Momentum Filter ---"
input bool     InpUseVolFilters     = true;      // Filter out low-liquidity/chop markets
input int      InpAtrPeriod         = 14;        // ATR Filter Period
input int      InpVolumeMAPeriod    = 20;        // Volume MA Period

input group "--- Market Structure Protection ---"
input int      InpSwingBars         = 5;         // Structural candle lookback for Swing High/Low
input double   InpSlPaddingPips     = 2.0;       // Safety margin added to structural SL (Pips)

input group "--- Algorithmic Session Clock ---"
input int      InpStartHour         = 8;         // Broker Time: Start Session (08:00)
input int      InpEndHour           = 22;        // Broker Time: End Session (22:00)

//--- Global Variables
int      fastEmaHandle;
int      slowEmaHandle;
int      trendEmaHandle;
int      atrHandle;
datetime lastProcessedBarTime;
double   initialDayEquity;

struct PositionState
{
   ulong ticket;
   bool  partialTaken;
   bool  breakevenSet;
};
PositionState posStates[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   lastProcessedBarTime = 0;
   initialDayEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   // Initialize technical indicator pipelines
   fastEmaHandle  = iMA(_Symbol, _Period, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   slowEmaHandle  = iMA(_Symbol, _Period, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   trendEmaHandle = iMA(_Symbol, InpTrendTF, InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);
   atrHandle      = iATR(_Symbol, _Period, InpAtrPeriod);
   
   if(fastEmaHandle == INVALID_HANDLE || slowEmaHandle == INVALID_HANDLE || 
      trendEmaHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE)
   {
      Print("CRITICAL ERROR: Failed to initialize indicator handles.");
      return(INIT_FAILED);
   }
   
   trade.SetExpertMagicNumber(9212003);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(fastEmaHandle);
   IndicatorRelease(slowEmaHandle);
   IndicatorRelease(trendEmaHandle);
   IndicatorRelease(atrHandle);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 1. Structural Management Loop running in real-time on every incoming price tick
   ManageActiveTrades();

   // 2. Risk Management Circuit Breaker Check
   ResetDailyEquityCheck();
   if(IsDrawdownLimitExceeded()) return;

   // 3. BAR STATE LOCK: Restricts trade entries to candle closing ticks only
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime == lastProcessedBarTime) return; 
   
   // 4. Time Window Restrictions (08:00 to 22:00 Session Block)
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour < InpStartHour || dt.hour >= InpEndHour) return;
   
   // 5. Volume-Volatility Filter (Cancels execution if market environment is compressed/flat)
   if(InpUseVolFilters)
   {
      if(!IsVolumeAboveAverage() || !IsVolatilityHealthy()) return;
   }
   
   // 6. Data Buffer Allocation from Closed Candles (Index 1 = Previous Bar, Index 2 = Signal Bar)
   double fastEMA[], slowEMA[], trendEMA[];
   ArraySetAsSeries(fastEMA, true);
   ArraySetAsSeries(slowEMA, true);
   ArraySetAsSeries(trendEMA, true);
   
   if(CopyBuffer(fastEmaHandle, 0, 1, 2, fastEMA) < 2) return;
   if(CopyBuffer(slowEmaHandle, 0, 1, 2, slowEMA) < 2) return;
   if(CopyBuffer(trendEmaHandle, 0, 1, 1, trendEMA) < 1) return;
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double macroTrendEMA = trendEMA[0]; // Validated closed 1H Filter line
   
   // Clean execution logic based strictly on confirmed candle data
   bool crossAbove = (fastEMA[1] <= slowEMA[1] && fastEMA[0] > slowEMA[0]);
   bool crossBelow = (fastEMA[1] >= slowEMA[1] && fastEMA[0] < slowEMA[0]);
   
   // 7. Entry Execution Core Routing
   //--- BULLISH REGIME
   if(crossAbove && currentPrice > macroTrendEMA)
   {
      if(PositionsTotal() == 0) // Strict single position constraint
      {
         double swingLow = GetSwingLow(InpSwingBars);
         double padding = InpSlPaddingPips * _Point * 10;
         double stopLoss = swingLow - padding;
         double riskPoints = currentPrice - stopLoss;
         
         if(riskPoints > 0)
         {
            double tpPrice = currentPrice + (riskPoints * InpMaxTP);
            // Verify Risk-to-Reward Ratio fits requirements before deploying capital
            if((tpPrice - currentPrice) / riskPoints >= InpMinRR)
            {
               double lotSize = CalculateLotSize(riskPoints);
               if(lotSize > 0 && trade.Buy(lotSize, _Symbol, currentPrice, stopLoss, tpPrice, "9-21 PRO Long"))
               {
                  lastProcessedBarTime = currentBarTime; // Activate lock for the current candle cycle
               }
            }
         }
      }
   }
   
   //--- BEARISH REGIME
   if(crossBelow && currentPrice < macroTrendEMA)
   {
      if(PositionsTotal() == 0)
      {
         double swingHigh = GetSwingHigh(InpSwingBars);
         double padding = InpSlPaddingPips * _Point * 10;
         double stopLoss = swingHigh + padding;
         double riskPoints = stopLoss - currentPrice;
         
         if(riskPoints > 0)
         {
            double tpPrice = currentPrice - (riskPoints * InpMaxTP);
            if((currentPrice - tpPrice) / riskPoints >= InpMinRR)
            {
               double lotSize = CalculateLotSize(riskPoints);
               if(lotSize > 0 && trade.Sell(lotSize, _Symbol, currentPrice, stopLoss, tpPrice, "9-21 PRO Short"))
               {
                  lastProcessedBarTime = currentBarTime; // Activate lock for the current candle cycle
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Active Portfolio Lifecycle Engine (Management & Exits)           |
//+------------------------------------------------------------------+
void ManageActiveTrades()
{
   double fastEMA[], slowEMA[];
   ArraySetAsSeries(fastEMA, true);
   ArraySetAsSeries(slowEMA, true);
   if(CopyBuffer(fastEmaHandle, 0, 0, 1, fastEMA) < 1) return;
   if(CopyBuffer(slowEmaHandle, 0, 0, 1, slowEMA) < 1) return;
   
   bool crossAbove = (fastEMA[0] > slowEMA[0]);
   bool crossBelow = (fastEMA[0] < slowEMA[0]);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == 9212003)
      {
         ulong ticket = PositionGetInteger(POSITION_TICKET);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentSL = PositionGetDouble(POSITION_SL);
         double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
         double initialVolume = PositionGetDouble(POSITION_VOLUME);
         long type = PositionGetInteger(POSITION_TYPE);
         
         int idx = GetOrCreateStateIndex(ticket);
         double initialRiskPoints = MathAbs(openPrice - currentSL);
         if(initialRiskPoints <= 0) continue;
         
         // TREND INVALIDATION: Close the entire trade immediately on an opposite EMA crossover
         if((type == POSITION_TYPE_BUY && crossBelow) || (type == POSITION_TYPE_SELL && crossAbove))
         {
            trade.PositionClose(ticket);
            continue;
         }

         //--- LONG POSITION AUTOMATION
         if(type == POSITION_TYPE_BUY)