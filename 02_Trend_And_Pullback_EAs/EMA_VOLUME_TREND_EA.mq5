//+------------------------------------------------------------------+
//|                                                    EMA + Volume EA.mq5|
//|                                  Copyright 2026, AI Trading Corp |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026"
#property link      "https://www.mql5.com"
#property version   "3.01"

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>

//--- Input Parameters
input int      InpEMAPeriod   = 9;          // EMA Period
input double   InpRiskPercent = 2.0;        // Strict Risk % per Trade (Account Balance)
input int      InpTPRatio     = 3;          // Reward to Risk Ratio
input bool     InpUseBE       = true;       // Use Break-Even
input int      InpBEPips      = 100;        // Points to trigger BE

//--- Volume Filter Parameters
input int      InpVolumePeriod = 14;        // Period for Volume EMA Filter

//--- Session Filtering Inputs (UK Time / GMT-BST)
input bool     InpFilterSessions = true;     // Restrict trading to specific sessions
input int      InpLondonStartHour= 13;       // London Open (08:00 UK)
input int      InpNYCloseHour    = 17;       // New York Business End (21:00 UK)

//--- Global Variables
int            handleEMA_LTF;               // Current TF handle
int            handleEMA_HTF;               // 1H TF handle
int            handleVolume;                // Volume Indicator handle
CTrade         trade;
CSymbolInfo    m_symbol;
datetime       lastBarTime;                 // Track candle transitions

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   m_symbol.Name(_Symbol);
   lastBarTime = 0;
   
   // Initialize EMA Handles
   handleEMA_LTF = iMA(_Symbol, _Period, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   handleEMA_HTF = iMA(_Symbol, PERIOD_H1, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   
   // Initialize Volume Handle
   handleVolume  = iVolumes(_Symbol, _Period, VOLUME_TICK);
   
   if(handleEMA_LTF == INVALID_HANDLE || handleEMA_HTF == INVALID_HANDLE || handleVolume == INVALID_HANDLE)
   {
      Print("Error creating indicator handles");
      return(INIT_FAILED);
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(handleEMA_LTF);
   IndicatorRelease(handleEMA_HTF);
   IndicatorRelease(handleVolume);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 1. Manage active positions first
   if(PositionsTotal() > 0) 
   {
      ManageTrailingStop();
      return; 
   }

   // 2. Strict Session Control (London & NY Windows Only)
   if(!IsMarketInSession()) return;

   // 3. New Candle Filter (Evaluate setups exclusively at the open of a fresh bar)
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime == lastBarTime) return;

   // 4. Retrieve indicator buffers safely
   double emaLTF[3], emaHTF[2];
   double volumeBuf[30]; // FIXED: Changed from 'long' to 'double' to comply with CopyBuffer requirements
   
   if(CopyBuffer(handleEMA_LTF, 0, 0, 3, emaLTF) < 3 || 
      CopyBuffer(handleEMA_HTF, 0, 0, 2, emaHTF) < 2 ||
      CopyBuffer(handleVolume, 0, 0, InpVolumePeriod + 1, volumeBuf) < (InpVolumePeriod + 1)) 
   {
      return;
   }
   
   // Calculate Moving Average of Volume dynamically
   double sumVolume = 0;
   for(int i = 1; i <= InpVolumePeriod; i++)
   {
      sumVolume += volumeBuf[i];
   }
   double avgVolume = sumVolume / InpVolumePeriod;
   double triggerCandleVolume = volumeBuf[1]; // Volume of the completed breakout candle (Candle 1)
   
   // Volume Filter condition
   bool isVolumeSpike = (triggerCandleVolume > avgVolume);
   
   // Get completed price structures
   double closePrice1 = iClose(_Symbol, _Period, 1);
   double openPrice1  = iOpen(_Symbol, _Period, 1);
   double closePrice2 = iClose(_Symbol, _Period, 2);
   double htfClose1   = iClose(_Symbol, PERIOD_H1, 1); 
   
   // 5. Multi-Timeframe Bias Confirmation (HTF Trend Validation)
   bool isBullishBias = (htfClose1 > emaHTF[1]);
   bool isBearishBias = (htfClose1 < emaHTF[1]);

   // 6. High-Quality Breakout Setup Filter with Volume Spike Requirement
   bool isHighQualityBuy  = isBullishBias && isVolumeSpike && (closePrice1 > emaLTF[1] && closePrice2 <= emaLTF[2] && closePrice1 > openPrice1);
   bool isHighQualitySell = isBearishBias && isVolumeSpike && (closePrice1 < emaLTF[1] && closePrice2 >= emaLTF[2] && closePrice1 < openPrice1);

   // 7. Orders Execution
   if(isHighQualityBuy)
   {
      if(ExecuteTrade(ORDER_TYPE_BUY)) lastBarTime = currentBarTime;
   }
   else if(isHighQualitySell)
   {
      if(ExecuteTrade(ORDER_TYPE_SELL)) lastBarTime = currentBarTime;
   }
}

//+------------------------------------------------------------------+
//| Verify Session Allowed Hours (Normalized to UK Time/Local Feed)  |
//+------------------------------------------------------------------+
bool IsMarketInSession()
{
   if(!InpFilterSessions) return true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   if(dt.hour < InpLondonStartHour || dt.hour >= InpNYCloseHour)
   {
      return false; 
   }
   
   if(dt.day_of_week == 0 || dt.day_of_week == 6) return false;

   return true;
}

//+------------------------------------------------------------------+
//| Calculate Lot Size strictly based on Account Balance & SL Pips   |
//+------------------------------------------------------------------+
double CalculateLotSize(double slDistancePoints)
{
   if(slDistancePoints <= 0) return 0.01;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (InpRiskPercent / 100.0);
   
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double lotStep   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   if(tickSize == 0 || tickValue == 0) return 0.01;

   double slDistanceTicks = slDistancePoints * (_Point / tickSize);
   double lot = riskAmount / (slDistanceTicks * tickValue);
   
   lot = MathFloor(lot / lotStep) * lotStep;
   
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   
   return MathMin(maxLot, MathMax(minLot, lot));
}

//+------------------------------------------------------------------+
//| Execute Trade with Dynamic Contract Sizing                       |
//+------------------------------------------------------------------+
bool ExecuteTrade(ENUM_ORDER_TYPE type)
{
   double price = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   double sl = (type == ORDER_TYPE_BUY) ? iLow(_Symbol, _Period, 1) : iHigh(_Symbol, _Period, 1);
   double diffPoints = MathAbs(price - sl);
   
   if(diffPoints < _Point * 100) diffPoints = _Point * 100; 
   
   if (type == ORDER_TYPE_BUY) sl = price - diffPoints;
   else                        sl = price + diffPoints;

   double tp = (type == ORDER_TYPE_BUY) ? price + (diffPoints * InpTPRatio) : price - (diffPoints * InpTPRatio);
   
   double lots = CalculateLotSize(diffPoints / _Point);

   if(trade.PositionOpen(_Symbol, type, lots, price, sl, tp, "High Quality 9 EMA + Vol"))
   {
      Alert("High-Volume Setup Executed! Type: ", EnumToString(type), " Lots: ", lots, " | Risking 2% Balance");
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Trailing Stop & Break-Even Logic                                 |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentSL = PositionGetDouble(POSITION_SL);
         double curPrice  = PositionGetDouble(POSITION_PRICE_CURRENT);
         
         // Break-Even Protection Engine
         if(InpUseBE && currentSL != openPrice)
         {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && (curPrice - openPrice) > InpBEPips * _Point)
               trade.PositionModify(ticket, openPrice, PositionGetDouble(POSITION_TP));
               
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && (openPrice - curPrice) > InpBEPips * _Point)
               trade.PositionModify(ticket, openPrice, PositionGetDouble(POSITION_TP));
         }
         
         // Trailing structure tracking candles
         double newSL;
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         {
            newSL = iLow(_Symbol, _Period, 1);
            if(newSL > currentSL + (_Point * 10)) trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
         }
         else
         {
            newSL = iHigh(_Symbol, _Period, 1);
            if(newSL < currentSL - (_Point * 10) || currentSL == 0) trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
         }
      }
   }
}

