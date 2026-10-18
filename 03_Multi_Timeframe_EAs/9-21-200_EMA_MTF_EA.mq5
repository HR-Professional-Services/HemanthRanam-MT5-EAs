//+------------------------------------------------------------------+
//|                                     Simple_XAUUSD_9_21_200.mq5 |
//|                                                      Gemini Pro |
//+------------------------------------------------------------------+
#property copyright "Gemini Pro"
#property version   "1.00"

#include <Trade\Trade.mqh>

//--- Simple Inputs
input double InpLotSize = 0.1;                               // Lot Size
input ENUM_TIMEFRAMES InpHTF = PERIOD_H1;                    // Higher Timeframe Trend Filter
input int InpSLPoints = 3000;                                // Stop Loss in Points (3000 = 30 pips usually)
input int InpTPPoints = 6000;                                // Take Profit in Points (6000 = 60 pips usually)

CTrade trade;
int h_ema9, h_ema21, h_ema200_HTF;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialize EMAs
    h_ema9 = iMA(_Symbol, PERIOD_CURRENT, 9, 0, MODE_EMA, PRICE_CLOSE);
    h_ema21 = iMA(_Symbol, PERIOD_CURRENT, 21, 0, MODE_EMA, PRICE_CLOSE);
    h_ema200_HTF = iMA(_Symbol, InpHTF, 200, 0, MODE_EMA, PRICE_CLOSE);
    
    trade.SetExpertMagicNumber(999);
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // 1. Only run once per new candle to avoid repainting/multiple entries
    if(!IsNewBar()) return;

    // 2. Prevent overtrading - only allow 1 trade open at a time for this EA
    bool hasPosition = false;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == 999)
        {
            hasPosition = true;
            break;
        }
    }
    if(hasPosition) return;

    // 3. Setup arrays to hold indicator data
    double ema9[], ema21[], ema200HTF[], closeHTF[];
    ArraySetAsSeries(ema9, true);
    ArraySetAsSeries(ema21, true);
    ArraySetAsSeries(ema200HTF, true);
    ArraySetAsSeries(closeHTF, true);

    // 4. Copy the latest indicator data
    if(CopyBuffer(h_ema9, 0, 0, 3, ema9) <= 0) return;
    if(CopyBuffer(h_ema21, 0, 0, 3, ema21) <= 0) return;
    if(CopyBuffer(h_ema200_HTF, 0, 0, 1, ema200HTF) <= 0) return;
    if(CopyClose(_Symbol, InpHTF, 0, 1, closeHTF) <= 0) return;

    // 5. STRATEGY LOGIC
    // Crossover Logic (Checking closed candle [1] crossing previous candle [2])
    bool buyCross = (ema9[1] > ema21[1]) && (ema9[2] <= ema21[2]);
    bool sellCross = (ema9[1] < ema21[1]) && (ema9[2] >= ema21[2]);

    // Trend Filter Logic (Is HTF price currently above/below HTF 200 EMA?)
    bool htfBullish = closeHTF[0] > ema200HTF[0];
    bool htfBearish = closeHTF[0] < ema200HTF[0];

    // 6. EXECUTE TRADES
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    if(buyCross && htfBullish)
    {
        double sl = ask - (InpSLPoints * point);
        double tp = ask + (InpTPPoints * point);
        trade.Buy(InpLotSize, _Symbol, ask, sl, tp, "Simple 9/21 Buy");
    }
    else if(sellCross && htfBearish)
    {
        double sl = bid + (InpSLPoints * point);
        double tp = bid - (InpTPPoints * point);
        trade.Sell(InpLotSize, _Symbol, bid, sl, tp, "Simple 9/21 Sell");
    }
}

//+------------------------------------------------------------------+
//| Helper: Check for new bar                                        |
//+------------------------------------------------------------------+
bool IsNewBar()
{
    static datetime lastBar = 0;
    datetime currentBar = (datetime)SeriesInfoInteger(_Symbol, PERIOD_CURRENT, SERIES_LASTBAR_DATE);
    if(currentBar != lastBar)
    {
        lastBar = currentBar;
        return true;
    }
    return false;
}
//+------------------------------------------------------------------+