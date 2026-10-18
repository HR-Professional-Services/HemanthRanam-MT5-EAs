//+------------------------------------------------------------------+
//|                                              XAUUSD_Scalper.mq5 |
//|                                                    Gemini 3.1 Pro|
//+------------------------------------------------------------------+
#property copyright "Your Name"
#property link      "https://yourwebsite.com"
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>

//--- Inputs
input double   InpRiskPercent       = 1.0;      // Risk per trade (%)
input double   InpStopLossPips      = 15.0;     // Fixed Stop Loss (Pips)
input double   InpTakeProfitPips    = 22.5;     // Take Profit (Pips - 1:1.5 RR)
input int      InpMaxSpread         = 25;       // Max Spread (Points)
input int      InpMaxDailyTrades    = 3;        // Max Trades per Day
input int      InpMagicNumber       = 123456;   // Magic Number
input int      InpTrailingStartPips = 10;       // Trailing Stop Start (Pips)
input int      InpTrailingStepPips  = 2;        // Trailing Stop Step (Pips)

// Session Inputs (Broker Server Time)
input string   InpSessionStart      = "08:00";  // London Open
input string   InpSessionEnd        = "18:00";  // NY Close (Adjust to broker time)

//--- Global Variables
CTrade         trade;
CPositionInfo  posInfo;
CSymbolInfo    symInfo;

int            handle_ema20_m5;
int            handle_ema50_m5;
int            handle_ema20_m1;
int            handle_rsi7_m1;

int            tradesToday = 0;
int            currentDay = -1;
datetime       lastBarTimeM1 = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagicNumber);
   symInfo.Name(_Symbol);

   // Initialize Indicators
   handle_ema20_m5 = iMA(_Symbol, PERIOD_M5, 20, 0, MODE_EMA, PRICE_CLOSE);
   handle_ema50_m5 = iMA(_Symbol, PERIOD_M5, 50, 0, MODE_EMA, PRICE_CLOSE);
   handle_ema20_m1 = iMA(_Symbol, PERIOD_M1, 20, 0, MODE_EMA, PRICE_CLOSE);
   handle_rsi7_m1  = iRSI(_Symbol, PERIOD_M1, 7, PRICE_CLOSE);

   if(handle_ema20_m5 == INVALID_HANDLE || handle_ema50_m5 == INVALID_HANDLE ||
      handle_ema20_m1 == INVALID_HANDLE || handle_rsi7_m1 == INVALID_HANDLE)
     {
      Print("Error initializing indicators.");
      return(INIT_FAILED);
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(handle_ema20_m5);
   IndicatorRelease(handle_ema50_m5);
   IndicatorRelease(handle_ema20_m1);
   IndicatorRelease(handle_rsi7_m1);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // 1. Only run logic on new M1 Bar (prevents tick-noise and repainting)
   datetime currentBarTime = iTime(_Symbol, PERIOD_M1, 0);
   if(currentBarTime == lastBarTimeM1) return; 

   // 2. Trailing Stop Management (Runs every tick/bar)
   ManageTrailingStop();

   // 3. Pre-Trade Filters
   if(!IsTradingSession()) return;
   if(GetSpread() > InpMaxSpread) return;
   
   CheckDailyTradeCount();
   if(tradesToday >= InpMaxDailyTrades) return;
   if(PositionsTotal() > 0) return; // Only 1 trade at a time

   // 4. Update Indicator Data (Shift 1 = Last Closed Bar)
   double ema20_m5[], ema50_m5[], ema20_m1[], rsi7_m1[];
   CopyBuffer(handle_ema20_m5, 0, 1, 2, ema20_m5);
   CopyBuffer(handle_ema50_m5, 0, 1, 2, ema50_m5);
   CopyBuffer(handle_ema20_m1, 0, 1, 2, ema20_m1);
   CopyBuffer(handle_rsi7_m1, 0, 1, 2, rsi7_m1);

   double m5_close = iClose(_Symbol, PERIOD_M5, 1);
   double m1_close = iClose(_Symbol, PERIOD_M1, 1);
   double m1_open  = iOpen(_Symbol, PERIOD_M1, 1);
   double m1_high  = iHigh(_Symbol, PERIOD_M1, 1);
   double m1_low   = iLow(_Symbol, PERIOD_M1, 1);

   // --- BUY LOGIC ---
   bool isM5Bullish = (m5_close > ema50_m5[0]) && (ema20_m5[0] > ema50_m5[0]) && CheckStructure(PERIOD_M5, 1); // 1 = Bullish
   bool isM1PullbackBuy = (m1_low <= ema20_m1[0]) && (rsi7_m1[0] >= 35 && rsi7_m1[0] <= 50); 
   bool isBuyConfirm = (m1_close > m1_open) && (m1_close > ema20_m1[0]); // Bullish candle closing above EMA20

   if(isM5Bullish && isM1PullbackBuy && isBuyConfirm)
     {
      ExecuteTrade(ORDER_TYPE_BUY);
      lastBarTimeM1 = currentBarTime;
      return;
     }

   // --- SELL LOGIC ---
   bool isM5Bearish = (m5_close < ema50_m5[0]) && (ema20_m5[0] < ema50_m5[0]) && CheckStructure(PERIOD_M5, -1); // -1 = Bearish
   bool isM1PullbackSell = (m1_high >= ema20_m1[0]) && (rsi7_m1[0] >= 50 && rsi7_m1[0] <= 65);
   bool isSellConfirm = (m1_close < m1_open) && (m1_close < ema20_m1[0]); // Bearish candle closing below EMA20

   if(isM5Bearish && isM1PullbackSell && isSellConfirm)
     {
      ExecuteTrade(ORDER_TYPE_SELL);
      lastBarTimeM1 = currentBarTime;
      return;
     }
  }

//+------------------------------------------------------------------+
//| Execute Trade with Risk Management                               |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE type)
  {
   double price = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl_dist = InpStopLossPips * 10 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tp_dist = InpTakeProfitPips * 10 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   double sl = (type == ORDER_TYPE_BUY) ? price - sl_dist : price + sl_dist;
   double tp = (type == ORDER_TYPE_BUY) ? price + tp_dist : price - tp_dist;

   double lotSize = CalculateLotSize(sl_dist);

   if(type == ORDER_TYPE_BUY)
      trade.Buy(lotSize, _Symbol, price, sl, tp, "XAU Scalp Buy");
   else
      trade.Sell(lotSize, _Symbol, price, sl, tp, "XAU Scalp Sell");

   tradesToday++;
  }

//+------------------------------------------------------------------+
//| Calculate Lot Size based on Account Risk                         |
//+------------------------------------------------------------------+
double CalculateLotSize(double sl_distance)
  {
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * (InpRiskPercent / 100.0);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   double sl_ticks = sl_distance / tickSize;
   double lotSize = riskAmount / (sl_ticks * tickValue);
   
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lotSize = MathRound(lotSize / stepLot) * stepLot;
   if(lotSize < minLot) lotSize = minLot;
   if(lotSize > maxLot) lotSize = maxLot;

   return lotSize;
  }

//+------------------------------------------------------------------+
//| Filter: Market Structure Proxy (Higher Highs / Lower Lows)       |
//+------------------------------------------------------------------+
bool CheckStructure(ENUM_TIMEFRAMES tf, int direction)
  {
   double high1 = iHigh(_Symbol, tf, 1); double high2 = iHigh(_Symbol, tf, 2);
   double low1 = iLow(_Symbol, tf, 1);   double low2 = iLow(_Symbol, tf, 2);

   if(direction == 1) return (high1 > high2 && low1 > low2); // Bullish
   if(direction == -1) return (low1 < low2 && high1 < high2); // Bearish
   return false;
  }

//+------------------------------------------------------------------+
//| Filter: Trading Sessions                                         |
//+------------------------------------------------------------------+
bool IsTradingSession()
  {
   MqlDateTime tm;
   TimeCurrent(tm);
   
   int currentMins = tm.hour * 60 + tm.min;
   
   string startSplit[]; StringSplit(InpSessionStart, ':', startSplit);
   string endSplit[];   StringSplit(InpSessionEnd, ':', endSplit);
   
   int startMins = (int)StringToInteger(startSplit[0]) * 60 + (int)StringToInteger(startSplit[1]);
   int endMins = (int)StringToInteger(endSplit[0]) * 60 + (int)StringToInteger(endSplit[1]);

   if(startMins < endMins) return (currentMins >= startMins && currentMins <= endMins);
   else return (currentMins >= startMins || currentMins <= endMins); // Spans midnight
  }

//+------------------------------------------------------------------+
//| Utility: Get Spread in Points                                    |
//+------------------------------------------------------------------+
int GetSpread()
  {
   return (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
  }

//+------------------------------------------------------------------+
//| Utility: Reset Daily Trade Counter                               |
//+------------------------------------------------------------------+
void CheckDailyTradeCount()
  {
   MqlDateTime tm;
   TimeCurrent(tm);
   if(tm.day_of_year != currentDay)
     {
      currentDay = tm.day_of_year;
      tradesToday = 0;
     }
  }

//+------------------------------------------------------------------+
//| Manage Trailing Stop                                             |
//+------------------------------------------------------------------+
void ManageTrailingStop()
  {
   if(InpTrailingStartPips <= 0) return;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double ts_start = InpTrailingStartPips * 10 * point;
   double ts_step = InpTrailingStepPips * 10 * point;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(posInfo.SelectByIndex(i))
        {
         if(posInfo.Symbol() == _Symbol && posInfo.Magic() == InpMagicNumber)
           {
            double currentPrice = (posInfo.PositionType() == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double openPrice = posInfo.PriceOpen();
            double sl = posInfo.StopLoss();

            if(posInfo.PositionType() == POSITION_TYPE_BUY)
              {
               if(currentPrice - openPrice >= ts_start)
                 {
                  double newSL = currentPrice - ts_step;
                  if(newSL > sl + point) trade.PositionModify(posInfo.Ticket(), newSL, posInfo.TakeProfit());
                 }
              }
            else if(posInfo.PositionType() == POSITION_TYPE_SELL)
              {
               if(openPrice - currentPrice >= ts_start)
                 {
                  double newSL = currentPrice + ts_step;
                  if(newSL < sl - point || sl == 0) trade.PositionModify(posInfo.Ticket(), newSL, posInfo.TakeProfit());
                 }
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+