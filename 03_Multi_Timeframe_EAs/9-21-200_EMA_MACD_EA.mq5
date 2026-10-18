//+------------------------------------------------------------------+
//| Simple 9-21 EMA + MACD EA (Active Version)                       |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>

CTrade trade;

// Inputs
input double RiskPercent = 1.0;
input int FastEMA = 9;
input int MidEMA = 21;
input int SlowEMA = 200;

input double RR = 3.0;
input int Slippage = 5;

// Handles
int emaFastHandle, emaMidHandle, emaSlowHandle, macdHandle;

// Buffers
double emaFast[], emaMid[], emaSlow[];
double macdMain[], macdSignal[];

//+------------------------------------------------------------------+
int OnInit()
{
   emaFastHandle = iMA(_Symbol,_Period,FastEMA,0,MODE_EMA,PRICE_CLOSE);
   emaMidHandle  = iMA(_Symbol,_Period,MidEMA,0,MODE_EMA,PRICE_CLOSE);
   emaSlowHandle = iMA(_Symbol,_Period,SlowEMA,0,MODE_EMA,PRICE_CLOSE);

   macdHandle = iMACD(_Symbol,_Period,12,26,9,PRICE_CLOSE);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(!IsNewCandle()) return;
   if(PositionSelect(_Symbol)) return;

   // Get data
   CopyBuffer(emaFastHandle,0,0,2,emaFast);
   CopyBuffer(emaMidHandle,0,0,2,emaMid);
   CopyBuffer(emaSlowHandle,0,0,2,emaSlow);

   CopyBuffer(macdHandle,0,0,2,macdMain);
   CopyBuffer(macdHandle,1,0,2,macdSignal);

   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);

   // --- SIMPLIFIED LOGIC ---

   // Buy: trend + momentum (no strict crossover needed)
   if(emaFast[0] > emaMid[0] && emaMid[0] > emaSlow[0] && macdMain[0] > macdSignal[0])
   {
      OpenTrade(ORDER_TYPE_BUY, ask);
   }

   // Sell
   if(emaFast[0] < emaMid[0] && emaMid[0] < emaSlow[0] && macdMain[0] < macdSignal[0])
   {
      OpenTrade(ORDER_TYPE_SELL, bid);
   }
}

//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE type, double price)
{
   double sl, tp;

   double stopPoints = 300 * _Point; // fixed SL (works better for backtest visibility)

   if(type == ORDER_TYPE_BUY)
   {
      sl = price - stopPoints;
      tp = price + stopPoints * RR;
   }
   else
   {
      sl = price + stopPoints;
      tp = price - stopPoints * RR;
   }

   double lot = CalculateLot(price, sl);

   trade.SetDeviationInPoints(Slippage);

   if(type == ORDER_TYPE_BUY)
      trade.Buy(lot,_Symbol,price,sl,tp);
   else
      trade.Sell(lot,_Symbol,price,sl,tp);
}

//+------------------------------------------------------------------+
double CalculateLot(double price, double sl)
{
   double risk = AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercent / 100.0;

   double tick_val = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);

   double stop = MathAbs(price - sl);

   double lot = risk / (stop / tick_size * tick_val);

   return NormalizeDouble(lot,2);
}

//+------------------------------------------------------------------+
bool IsNewCandle()
{
   static datetime lastTime=0;
   datetime t=iTime(_Symbol,_Period,0);

   if(t!=lastTime)
   {
      lastTime=t;
      return true;
   }
   return false;
}
//+------------------------------------------------------------------+