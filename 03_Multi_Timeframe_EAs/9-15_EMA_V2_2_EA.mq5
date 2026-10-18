 //+------------------------------------------------------------------+
//|                                     9-15 EMA EA V2.1.mq5         |
//|                                  Fixed & Live-Ready Version      |
//+------------------------------------------------------------------+
#property strict
#property version "3.01"

#include <Trade/Trade.mqh>
#include <Trade/SymbolInfo.mqh>

CTrade trade;
CSymbolInfo m_symbol;

//---------------- INPUTS ----------------//
input group "EMA Settings"
input int FastEMA = 9;
input int SlowEMA = 15;
input ENUM_TIMEFRAMES HTF = PERIOD_H4;

input group "Risk Management"
input double RiskPercent = 0.5;
input double RewardRatio = 2.5;

input group "Filters"
input int MaxSpreadPoints = 40;
input int LondonOpen = 7;
input int NewYorkClose = 21;

input group "Trailing Stop"
input bool UseTrailing = true;
input int TrailingPoints = 300;
input int TrailingStep = 50;

input group "ATR"
input int ATRPeriod = 14;
input double ATRMultiplier = 1.5; // Increased for realistic Gold volatility

//---------------- GLOBALS ----------------//
int hFastEMA, hSlowEMA, hHTFEMA, hATR;
datetime lastBarTime;

//+------------------------------------------------------------------+
int OnInit()
{
   if(!m_symbol.Name(_Symbol)) return(INIT_FAILED);
   
   hFastEMA = iMA(_Symbol, _Period, FastEMA, 0, MODE_EMA, PRICE_CLOSE);
   hSlowEMA = iMA(_Symbol, _Period, SlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   hHTFEMA  = iMA(_Symbol, HTF, 50, 0, MODE_EMA, PRICE_CLOSE);
   hATR     = iATR(_Symbol, _Period, ATRPeriod);

   if(hFastEMA == INVALID_HANDLE || hSlowEMA == INVALID_HANDLE || hHTFEMA == INVALID_HANDLE || hATR == INVALID_HANDLE)
      return INIT_FAILED;

   trade.SetExpertMagicNumber(9152026);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(hFastEMA);
   IndicatorRelease(hSlowEMA);
   IndicatorRelease(hHTFEMA);
   IndicatorRelease(hATR);
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(UseTrailing) ManageTrailing();

   datetime barTime = iTime(_Symbol, _Period, 0);
   if(barTime == lastBarTime) return;
   lastBarTime = barTime;

   if(!TradingSession()) return;
   if(PositionsTotal() > 0) return;
   
   m_symbol.RefreshRates();
   if(CurrentSpread() > MaxSpreadPoints) return;

   CheckEntries();
}

//+------------------------------------------------------------------+
void CheckEntries()
{
   double emaFast[], emaSlow[], atr[], htfEMA[];
   MqlRates rates[];

   ArraySetAsSeries(emaFast, true);
   ArraySetAsSeries(emaSlow, true);
   ArraySetAsSeries(rates, true);

   if(CopyBuffer(hFastEMA, 0, 0, 3, emaFast) < 3) return;
   if(CopyBuffer(hSlowEMA, 0, 0, 3, emaSlow) < 3) return;
   if(CopyBuffer(hATR, 0, 0, 1, atr) < 1) return;
   if(CopyBuffer(hHTFEMA, 0, 0, 1, htfEMA) < 1) return;
   if(CopyRates(_Symbol, _Period, 0, 3, rates) < 3) return;

   double htfClose = iClose(_Symbol, HTF, 1);
   bool HTFBull = htfClose > htfEMA[0];
   bool HTFBear = htfClose < htfEMA[0];

   // -------- BUY LOGIC -------- //
   if(HTFBull && emaFast[1] > emaSlow[1])
   {
      bool pullback = rates[1].low <= emaSlow[1];
      // Engulfing or Bullish Pin Bar Check
      bool isEngulfing = rates[1].close > rates[2].high;
      bool isPinBar = (rates[1].close > rates[1].open) && (rates[1].open - rates[1].low) > (rates[1].high - rates[1].low) * 0.6;

      if(pullback && (isEngulfing || isPinBar))
      {
         ExecuteBuy(atr[0]);
      }
   }

   // -------- SELL LOGIC -------- //
   if(!HTFBull && emaFast[1] < emaSlow[1])
   {
      bool pullback = rates[1].high >= emaSlow[1];
      bool isEngulfing = rates[1].close < rates[2].low;
      bool isPinBar = (rates[1].close < rates[1].open) && (rates[1].high - rates[1].open) > (rates[1].high - rates[1].low) * 0.6;

      if(pullback && (isEngulfing || isPinBar))
      {
         ExecuteSell(atr[0]);
      }
   }
}

//+------------------------------------------------------------------+
void ExecuteBuy(double atrValue)
{
   double ask = m_symbol.Ask();
   double sl = ask - (atrValue * ATRMultiplier);
   double slDist = ask - sl;
   double tp = ask + (slDist * RewardRatio);

   double lot = CalculateLot(slDist);
   if(lot > 0) trade.Buy(lot, _Symbol, ask, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits));
}

//+------------------------------------------------------------------+
void ExecuteSell(double atrValue)
{
   double bid = m_symbol.Bid();
   double sl = bid + (atrValue * ATRMultiplier);
   double slDist = sl - bid;
   double tp = bid - (slDist * RewardRatio);

   double lot = CalculateLot(slDist);
   if(lot > 0) trade.Sell(lot, _Symbol, bid, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits));
}

//+------------------------------------------------------------------+
double CalculateLot(double slDistance)
{
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercent / 100.0;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(slDistance <= 0 || tickValue <= 0) return 0;

   // Correct formula for MT5
   double lot = riskMoney / ((slDistance / tickSize) * tickValue);
   
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lot = MathFloor(lot / step) * step;
   
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   return NormalizeDouble(MathMax(minLot, MathMin(lot, maxLot)), 2);
}

//+------------------------------------------------------------------+
void ManageTrailing()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != 9152026) continue;

      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);
      long type   = PositionGetInteger(POSITION_TYPE);

      m_symbol.RefreshRates();

      if(type == POSITION_TYPE_BUY)
      {
         double newSL = m_symbol.Bid() - TrailingPoints * _Point;
         if(m_symbol.Bid() > open + TrailingPoints * _Point)
         {
            if(newSL > sl + (TrailingStep * _Point))
               trade.PositionModify(ticket, NormalizeDouble(newSL, _Digits), tp);
         }
      }
      else if(type == POSITION_TYPE_SELL)
      {
         double newSL = m_symbol.Ask() + TrailingPoints * _Point;
         if(m_symbol.Ask() < open - TrailingPoints * _Point)
         {
            if((newSL < sl || sl == 0) && (sl - newSL > TrailingStep * _Point))
               trade.PositionModify(ticket, NormalizeDouble(newSL, _Digits), tp);
         }
      }
   }
}

//+------------------------------------------------------------------+
bool TradingSession()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   return (dt.hour >= LondonOpen && dt.hour <= NewYorkClose);
}

//+------------------------------------------------------------------+
double CurrentSpread()
{
   return (m_symbol.Ask() - m_symbol.Bid()) / _Point;
}


