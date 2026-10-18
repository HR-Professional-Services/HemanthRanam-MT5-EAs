//+------------------------------------------------------------------+
//|                               Auto_Pilot_EMA_921_Pullback_PRO.mq5 |
//|                                Copyright 2026, Auto Pilot Systems |
//|                                       https://www.mql5.com        |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, Auto Pilot Systems"
#property link        "https://www.mql5.com"
#property version     "1.00"
#property description "Auto Pilot EMA 9-21 Pullback PRO - Multi-Pair EA Strategy"
#property description "Combines EMA 9/21 execution with H1 EMA 200 Trend Filter"
#property description "Fully automatic, alerts only, and confirmation modes"

//+------------------------------------------------------------------+
//| ENUM DEFINITIONS                                                 |
//+------------------------------------------------------------------+
enum ENUM_TRADING_MODE
{
   ALERT_ONLY,         // Alerts Only (No execution)
   AUTO_TRADE,         // Automatic Trading
   CONFIRMATION_MODE   // Manual Confirmation Mode
};

enum ENUM_SL_METHOD
{
   SL_CANDLE_HIGHLOW,  // Candle High/Low
   SL_EMA21,           // EMA 21 Level
   SL_ATR              // ATR Distance
};

enum ENUM_RISK_MODE
{
   RISK_FIXED_LOT,     // Fixed Lot Size
   RISK_PERCENTAGE     // Percentage Risk (% of Balance)
};

enum ENUM_TRAILING_MODE
{
   TRAILING_NONE,      // Disabled
   TRAILING_EMA21,     // Trailing via EMA 21
   TRAILING_ATR,       // Trailing via ATR
   TRAILING_POINTS     // Fixed Points Trailing
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
//--- 1. Trading Mode Settings
input group "=== Trading Mode Settings ==="
input ENUM_TRADING_MODE InpTradingMode        = AUTO_TRADE;     // Trading Mode

//--- 2. Symbol Scanner Settings
input group "=== Multi-Symbol Scanner Settings ==="
input bool              InpEnableMultiScanner  = true;           // Enable Multi-Pair Scanner
input string            InpSymbolsList         = "XAUUSD,XAGUSD,US500,US100,USOIL,EURUSD,GBPUSD,USDJPY,BTCUSD"; // Symbols (comma-separated)

//--- 3. Strategy Parameters
input group "=== Strategy Parameters ==="
input int               InpEMA9_Period         = 9;              // Execution Fast EMA (9)
input int               InpEMA21_Period        = 21;             // Execution Slow EMA (21)
input int               InpEMA200_Period       = 200;            // Higher TF Trend EMA (200)
input ENUM_TIMEFRAMES   InpExecutionTF         = PERIOD_M5;      // Execution Timeframe
input ENUM_TIMEFRAMES   InpHigherTF            = PERIOD_H1;      // Higher Timeframe
input bool              InpOneSignalPerCross   = true;           // Enable One Signal Per Cross
input int               InpSignalExpiryMinutes = 60;             // Signal Expiry (Minutes)

//--- 4. Session Filter Settings
input group "=== Trading Session Filter ==="
input bool              InpEnableSessionFilter = true;           // Enable Session Filter
input int               InpBrokerGMTOffset     = 0;              // Broker GMT Offset
input string            InpLondonStart         = "07:00";        // London Session Start
input string            InpLondonEnd           = "16:00";        // London Session End
input string            InpNYStart             = "13:00";        // New York Session Start
input string            InpNYEnd               = "22:00";        // New York Session End

//--- 5. Risk Management Settings
input group "=== Risk Management ==="
input ENUM_RISK_MODE    InpRiskMode            = RISK_PERCENTAGE;// Risk Mode
input double            InpRiskPercent         = 1.0;            // Risk Percentage per Trade (%)
input double            InpFixedLot            = 0.01;           // Fixed Lot Size

//--- 6. Stop Loss & Take Profit
input group "=== Stop Loss & Take Profit ==="
input ENUM_SL_METHOD    InpSLMethod            = SL_CANDLE_HIGHLOW; // Stop Loss Method
input int               InpCandleLookback      = 3;              // Candle Lookback for High/Low SL
input int               InpATRPeriod           = 14;             // ATR Period
input double            InpATRMultiplier       = 2.0;            // ATR Multiplier for SL
input bool              InpEnableTP            = true;           // Enable Take Profit
input double            InpTargetRR            = 3.0;            // Target Risk Reward Ratio (1:N)

//--- 7. Active Trade Management
input group "=== Active Trade Management ==="
input bool              InpEnableBreakEven     = true;           // Enable Break Even
input double            InpBERrTrigger         = 1.0;            // Break Even Trigger (R Multiplier)
input ENUM_TRAILING_MODE InpTrailingMode       = TRAILING_EMA21; // Trailing Stop Mode
input int               InpTrailingPoints      = 150;            // Fixed Points Trailing Distance
input bool              InpEnablePartialClose  = true;           // Enable Partial Close
input double            InpPartialCloseRR      = 2.0;            // Partial Close Target (RR)
input double            InpPartialClosePct     = 50.0;           // Partial Close Percentage (%)
input int               InpMaxTradeHours       = 24;             // Maximum Trade Duration (Hours)

//--- 8. Account Protection
input group "=== Account Protection ==="
input int               InpMaxOpenTrades       = 3;              // Maximum Total Open Trades
input int               InpMaxTradesPerDay     = 10;             // Maximum Trades Per Day
input double            InpMaxDailyLossPct     = 3.0;            // Daily Loss Limit (%)
input double            InpMaxDailyProfitPct   = 5.0;            // Daily Profit Target (%)

//--- 9. Market Filters
input group "=== Market Filters ==="
input double            InpMaxSpreadPoints     = 50.0;           // Maximum Allowed Spread (Points)
input double            InpMinATRValue         = 0.0001;         // Minimum ATR Volatility Filter
input double            InpMaxSlippagePoints   = 30.0;           // Maximum Slippage (Points)
input bool              InpEnableNewsFilter    = false;          // Enable News Filter

//--- 10. Order Execution Settings
input group "=== Order Execution ==="
input ulong             InpMagicNumber         = 9212026;        // EA Magic Number
input string            InpTradeComment        = "Auto Pilot EMA921"; // Trade Comment

//--- 11. Alert System
input group "=== Alert System ==="
input bool              InpEnablePushAlerts    = true;           // Send MT5 Push Notifications
input bool              InpTelegramEnabled     = false;          // Enable Telegram Alerts
input string   InpTelegramBotToken    = ""; // Telegram Bot Token (Configure in EA inputs)             // Telegram Bot Token
input string   InpTelegramChatID      = ""; // Telegram Chat / Channel ID (Configure in EA inputs)             // Telegram Chat ID

//--- 12. Dashboard Settings
input group "=== Visual Dashboard ==="
input bool              InpShowDashboard       = true;           // Show On-Chart Dashboard
input color             InpDashBgColor         = C'20,24,35';    // Dashboard Background Color
input color             InpDashTextColor       = C'240,240,240'; // Text Color
input color             InpDashAccentColor     = C'0,195,255';   // Accent Color

//+------------------------------------------------------------------+
//| STRUCTS                                                          |
//+------------------------------------------------------------------+
struct SymbolScannerState
{
   string   symbol;
   int      ema9_h_M5;
   int      ema21_h_M5;
   int      ema200_h_H1;
   int      atr_h_M5;
   datetime lastSignalTime;
   int      lastCrossDirection;  // 1 = Bullish, -1 = Bearish, 0 = None
   bool     signalFiredThisCross;
   int      currentSignal;       // 0 = None, 1 = Buy, -1 = Sell
   string   statusText;
   datetime lastBarTimeM5;
};

struct TradeRecord
{
   ulong    ticket;
   string   symbol;
   int      type;                // 0 = Buy, 1 = Sell
   double   openPrice;
   double   closePrice;
   double   sl;
   double   tp;
   double   profit;
   datetime openTime;
   datetime closeTime;
   string   reason;
};

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+
SymbolScannerState g_symbols[];
TradeRecord        g_journal[];
int                g_symbolCount          = 0;
datetime           g_currentDay           = 0;
double             g_dayStartBalance      = 0.0;
int                g_tradesTodayCount     = 0;
int                g_totalWinsToday       = 0;
int                g_totalLossesToday     = 0;

//+------------------------------------------------------------------+
//| EXPERT INITIALIZATION FUNCTION                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // 1. Initialize symbols list
   string symbolNames[];
   ushort u_sep = ::StringGetCharacter(",", 0);
   int splitCount = ::StringSplit(InpSymbolsList, u_sep, symbolNames);
   
   if(splitCount <= 0 || !InpEnableMultiScanner)
   {
      splitCount = 1;
      ::ArrayResize(symbolNames, 1);
      symbolNames[0] = _Symbol;
   }
   
   g_symbolCount = splitCount;
   ::ArrayResize(g_symbols, g_symbolCount);
   
   for(int i = 0; i < g_symbolCount; i++)
   {
      ::StringTrimLeft(symbolNames[i]);
      ::StringTrimRight(symbolNames[i]);
      
      g_symbols[i].symbol               = symbolNames[i];
      g_symbols[i].lastSignalTime       = 0;
      g_symbols[i].lastCrossDirection   = 0;
      g_symbols[i].signalFiredThisCross = false;
      g_symbols[i].currentSignal       = 0;
      g_symbols[i].statusText           = "WAIT";
      g_symbols[i].lastBarTimeM5        = 0;
      
      // Ensure symbol is selected in Market Watch
      ::SymbolSelect(g_symbols[i].symbol, true);
      
      // Create Indicator Handles
      g_symbols[i].ema9_h_M5   = ::iMA(g_symbols[i].symbol, InpExecutionTF, InpEMA9_Period, 0, MODE_EMA, PRICE_CLOSE);
      g_symbols[i].ema21_h_M5  = ::iMA(g_symbols[i].symbol, InpExecutionTF, InpEMA21_Period, 0, MODE_EMA, PRICE_CLOSE);
      g_symbols[i].ema200_h_H1 = ::iMA(g_symbols[i].symbol, InpHigherTF, InpEMA200_Period, 0, MODE_EMA, PRICE_CLOSE);
      g_symbols[i].atr_h_M5    = ::iATR(g_symbols[i].symbol, InpExecutionTF, InpATRPeriod);
      
      if(g_symbols[i].ema9_h_M5 == INVALID_HANDLE || 
         g_symbols[i].ema21_h_M5 == INVALID_HANDLE || 
         g_symbols[i].ema200_h_H1 == INVALID_HANDLE ||
         g_symbols[i].atr_h_M5 == INVALID_HANDLE)
      {
         ::Print("Error creating indicator handles for symbol: ", g_symbols[i].symbol);
      }
   }
   
   // 2. Initialize Day Tracker
   MqlDateTime dt;
   ::TimeToStruct(::TimeCurrent(), dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   g_currentDay      = ::StructToTime(dt);
   g_dayStartBalance = ::AccountInfoDouble(ACCOUNT_BALANCE);
   
   // 3. Set Chart Timer for Periodic Operations
   ::EventSetTimer(1);
   
   ::Print("Auto Pilot EMA 9-21 Pullback PRO Initialized Successfully. Total Symbols: ", g_symbolCount);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| EXPERT DEINITIALIZATION FUNCTION                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ::EventKillTimer();
   
   // Release Indicator Handles
   for(int i = 0; i < g_symbolCount; i++)
   {
      if(g_symbols[i].ema9_h_M5 != INVALID_HANDLE)   ::IndicatorRelease(g_symbols[i].ema9_h_M5);
      if(g_symbols[i].ema21_h_M5 != INVALID_HANDLE)  ::IndicatorRelease(g_symbols[i].ema21_h_M5);
      if(g_symbols[i].ema200_h_H1 != INVALID_HANDLE) ::IndicatorRelease(g_symbols[i].ema200_h_H1);
      if(g_symbols[i].atr_h_M5 != INVALID_HANDLE)    ::IndicatorRelease(g_symbols[i].atr_h_M5);
   }
   
   // Remove Dashboard Objects
   RemoveDashboard();
}

//+------------------------------------------------------------------+
//| EXPERT TICK FUNCTION                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check Daily Reset & Account Protection Limits
   CheckDailyReset();
   
   if(!IsAccountProtectionValid())
   {
      if(InpShowDashboard) RenderDashboard();
      return;
   }
   
   // Execute Multi-Symbol Engine
   for(int i = 0; i < g_symbolCount; i++)
   {
      ProcessSymbolStrategy(i);
      ManageActiveTrades(g_symbols[i].symbol);
   }
   
   // Render Dashboard
   if(InpShowDashboard) RenderDashboard();
}

//+------------------------------------------------------------------+
//| TIMER FUNCTION                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Periodic background maintenance
   CheckTradeDuration();
   if(InpShowDashboard) RenderDashboard();
}

//+------------------------------------------------------------------+
//| STRATEGY ENGINE & SIGNAL DETECTION                               |
//+------------------------------------------------------------------+
void ProcessSymbolStrategy(const int index)
{
   string sym = g_symbols[index].symbol;
   
   // Check M5 Bar Close to avoid intra-bar repainting
   datetime barTime[];
   if(::CopyTime(sym, InpExecutionTF, 0, 1, barTime) <= 0) return;
   
   bool isNewBar = (barTime[0] != g_symbols[index].lastBarTimeM5);
   if(isNewBar) g_symbols[index].lastBarTimeM5 = barTime[0];
   
   // 1. Fetch M5 EMA9 & EMA21
   double ema9_M5[], ema21_M5[];
   ::ArraySetAsSeries(ema9_M5, true);
   ::ArraySetAsSeries(ema21_M5, true);
   
   if(::CopyBuffer(g_symbols[index].ema9_h_M5, 0, 0, 4, ema9_M5) < 4) return;
   if(::CopyBuffer(g_symbols[index].ema21_h_M5, 0, 0, 4, ema21_M5) < 4) return;
   
   // 2. Track EMA Cross State on M5
   bool crossBullish = (ema9_M5[2] <= ema21_M5[2] && ema9_M5[1] > ema21_M5[1]);
   bool crossBearish = (ema9_M5[2] >= ema21_M5[2] && ema9_M5[1] < ema21_M5[1]);
   
   if(crossBullish)
   {
      g_symbols[index].lastCrossDirection   = 1;
      g_symbols[index].signalFiredThisCross = false;
   }
   else if(crossBearish)
   {
      g_symbols[index].lastCrossDirection   = -1;
      g_symbols[index].signalFiredThisCross = false;
   }
   
   // 3. Update Symbol Status
   if(g_symbols[index].lastCrossDirection == 1)      g_symbols[index].statusText = "BUY SETUP";
   else if(g_symbols[index].lastCrossDirection == -1) g_symbols[index].statusText = "SELL SETUP";
   else                                              g_symbols[index].statusText = "WAIT";
   
   if(!isNewBar) return; // Only process setup confirmation on bar close
   
   // 4. Verify Higher Timeframe Trend (H1 EMA 200 & H1 EMA 9 vs EMA 21)
   double ema200_H1[], h1Close[];
   double ema9_H1[], ema21_H1[];
   ::ArraySetAsSeries(ema200_H1, true);
   ::ArraySetAsSeries(h1Close, true);
   ::ArraySetAsSeries(ema9_H1, true);
   ::ArraySetAsSeries(ema21_H1, true);
   
   int h1_ema9_h = ::iMA(sym, InpHigherTF, InpEMA9_Period, 0, MODE_EMA, PRICE_CLOSE);
   int h1_ema21_h = ::iMA(sym, InpHigherTF, InpEMA21_Period, 0, MODE_EMA, PRICE_CLOSE);
   
   if(::CopyBuffer(g_symbols[index].ema200_h_H1, 0, 1, 1, ema200_H1) < 1 ||
      ::CopyClose(sym, InpHigherTF, 1, 1, h1Close) < 1 ||
      ::CopyBuffer(h1_ema9_h, 0, 1, 1, ema9_H1) < 1 ||
      ::CopyBuffer(h1_ema21_h, 0, 1, 1, ema21_H1) < 1)
   {
      if(h1_ema9_h != INVALID_HANDLE)  ::IndicatorRelease(h1_ema9_h);
      if(h1_ema21_h != INVALID_HANDLE) ::IndicatorRelease(h1_ema21_h);
      return;
   }
   
   bool h1Bullish = (h1Close[0] > ema200_H1[0] && ema9_H1[0] > ema21_H1[0]);
   bool h1Bearish = (h1Close[0] < ema200_H1[0] && ema9_H1[0] < ema21_H1[0]);
   
   if(h1_ema9_h != INVALID_HANDLE)  ::IndicatorRelease(h1_ema9_h);
   if(h1_ema21_h != INVALID_HANDLE) ::IndicatorRelease(h1_ema21_h);
   
   // 5. Fetch M5 Price Data for Pullback & Engulfing Confirmation
   MqlRates rates[];
   ::ArraySetAsSeries(rates, true);
   if(::CopyRates(sym, InpExecutionTF, 1, 3, rates) < 3) return;
   
   // Check One Signal Per Cross
   if(InpOneSignalPerCross && g_symbols[index].signalFiredThisCross) return;
   
   // Check Market Filters (Spread, ATR)
   if(!IsMarketFilterPassed(sym, index)) return;
   
   // Check Session Filter
   if(InpEnableSessionFilter && !IsSessionActive()) return;
   
   // BUY Setup Detection
   if(h1Bullish && g_symbols[index].lastCrossDirection == 1)
   {
      // Pullback into EMA Zone (rates[0] is Bar 1, rates[1] is Bar 2)
      double zoneHigh = MathMax(ema9_M5[1], ema21_M5[1]);
      double zoneLow  = MathMin(ema9_M5[1], ema21_M5[1]);
      
      bool pullbackInZone = (rates[0].low <= zoneHigh && rates[0].high >= zoneLow);
      
      // Bullish Engulfing Confirmation on Bar 1
      bool bullishEngulfing = (rates[0].close > rates[0].open && 
                               rates[1].close < rates[1].open && 
                               rates[0].close > rates[1].open && 
                               rates[0].open <= rates[1].close);
      
      if(pullbackInZone && bullishEngulfing)
      {
         g_symbols[index].statusText = "BUY READY";
         g_symbols[index].currentSignal = 1;
         TriggerSignal(sym, index, ORDER_TYPE_BUY, "H1 Bullish Trend + M5 Pullback & Engulfing");
      }
   }
   
   // SELL Setup Detection
   if(h1Bearish && g_symbols[index].lastCrossDirection == -1)
   {
      double zoneHigh = MathMax(ema9_M5[1], ema21_M5[1]);
      double zoneLow  = MathMin(ema9_M5[1], ema21_M5[1]);
      
      bool pullbackInZone = (rates[0].high >= zoneLow && rates[0].low <= zoneHigh);
      
      // Bearish Engulfing Confirmation on Bar 1
      bool bearishEngulfing = (rates[0].close < rates[0].open && 
                               rates[1].close > rates[1].open && 
                               rates[0].close < rates[1].open && 
                               rates[0].open >= rates[1].close);
      
      if(pullbackInZone && bearishEngulfing)
      {
         g_symbols[index].statusText = "SELL READY";
         g_symbols[index].currentSignal = -1;
         TriggerSignal(sym, index, ORDER_TYPE_SELL, "H1 Bearish Trend + M5 Pullback & Engulfing");
      }
   }
}

//+------------------------------------------------------------------+
//| SIGNAL TRIGGER & ORDER DISPATCH                                  |
//+------------------------------------------------------------------+
void TriggerSignal(const string sym, const int index, const ENUM_ORDER_TYPE orderType, const string reason)
{
   g_symbols[index].signalFiredThisCross = true;
   g_symbols[index].lastSignalTime       = ::TimeCurrent();
   
   double entryPrice = (orderType == ORDER_TYPE_BUY) ? ::SymbolInfoDouble(sym, SYMBOL_ASK) : ::SymbolInfoDouble(sym, SYMBOL_BID);
   double slPrice    = CalculateStopLoss(sym, index, orderType, entryPrice);
   double tpPrice    = CalculateTakeProfit(sym, orderType, entryPrice, slPrice);
   
   double lotSize = CalculateLotSize(sym, entryPrice, slPrice);
   
   // Send Notifications & Telegram
   SendAlertNotification(sym, orderType, entryPrice, slPrice, tpPrice, reason);
   
   // Handle Trading Mode
   if(InpTradingMode == ALERT_ONLY)
   {
      ::Print("Alert Only Mode: Signal generated for ", sym, " (No Trade Executed)");
      return;
   }
   
   if(InpTradingMode == CONFIRMATION_MODE)
   {
      ::Print("Confirmation Mode: Signal generated for ", sym, ". Awaiting user manual approval.");
      return;
   }
   
   if(InpTradingMode == AUTO_TRADE)
   {
      // Check existing position on symbol
      if(CountSymbolPositions(sym) > 0) return;
      
      ExecuteTradeNative(sym, orderType, lotSize, slPrice, tpPrice, reason);
   }
}

//+------------------------------------------------------------------+
//| NATIVE MQL5 ORDER EXECUTION                                      |
//+------------------------------------------------------------------+
bool ExecuteTradeNative(const string sym, const ENUM_ORDER_TYPE orderType, const double lot, const double sl, const double tp, const string comment)
{
   MqlTradeRequest request;
   MqlTradeResult  result;
   ::ZeroMemory(request);
   ::ZeroMemory(result);
   
   request.action       = TRADE_ACTION_DEAL;
   request.symbol       = sym;
   request.volume       = lot;
   request.type         = orderType;
   request.price        = (orderType == ORDER_TYPE_BUY) ? ::SymbolInfoDouble(sym, SYMBOL_ASK) : ::SymbolInfoDouble(sym, SYMBOL_BID);
   request.sl           = sl;
   request.tp           = tp;
   request.deviation    = (ulong)InpMaxSlippagePoints;
   request.magic        = InpMagicNumber;
   request.comment      = InpTradeComment + " (" + comment + ")";
   request.type_filling = GetSymbolFillingMode(sym);
   
   bool res = ::OrderSend(request, result);
   
   if(res && (result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED))
   {
      ::Print("Trade Executed Successfully on ", sym, " Ticket: ", result.order, " Lots: ", lot);
      g_tradesTodayCount++;
      RecordTradeJournal(result.order, sym, (orderType == ORDER_TYPE_BUY ? 0 : 1), request.price, sl, tp, comment);
      return true;
   }
   else
   {
      ::Print("OrderSend Failed on ", sym, " RetCode: ", result.retcode, " Comment: ", result.comment);
      return false;
   }
}

//+------------------------------------------------------------------+
//| RISK MANAGEMENT & LOT CALCULATOR                                 |
//+------------------------------------------------------------------+
double CalculateLotSize(const string sym, const double entryPrice, const double slPrice)
{
   if(InpRiskMode == RISK_FIXED_LOT) return NormalizeLot(sym, InpFixedLot);
   
   double balance = ::AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (InpRiskPercent / 100.0);
   
   double slDistancePoints = MathAbs(entryPrice - slPrice) / ::SymbolInfoDouble(sym, SYMBOL_POINT);
   if(slDistancePoints <= 0) return NormalizeLot(sym, InpFixedLot);
   
   double tickValue = ::SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = ::SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   double pointSize = ::SymbolInfoDouble(sym, SYMBOL_POINT);
   
   if(tickSize <= 0 || pointSize <= 0) return NormalizeLot(sym, InpFixedLot);
   
   double pointValue = tickValue * (pointSize / tickSize);
   double calculatedLot = riskAmount / (slDistancePoints * pointValue);
   
   return NormalizeLot(sym, calculatedLot);
}

double NormalizeLot(const string sym, const double lot)
{
   double step = ::SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
   double min  = ::SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   double max  = ::SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
   
   if(step <= 0) return min;
   
   double normLot = MathFloor(lot / step) * step;
   if(normLot < min) normLot = min;
   if(normLot > max) normLot = max;
   
   return ::NormalizeDouble(normLot, 2);
}

//+------------------------------------------------------------------+
//| STOP LOSS & TAKE PROFIT CALCULATIONS                             |
//+------------------------------------------------------------------+
double CalculateStopLoss(const string sym, const int index, const ENUM_ORDER_TYPE orderType, const double entryPrice)
{
   double point = ::SymbolInfoDouble(sym, SYMBOL_POINT);
   double slPrice = 0.0;
   
   if(InpSLMethod == SL_CANDLE_HIGHLOW)
   {
      MqlRates rates[];
      ::ArraySetAsSeries(rates, true);
      ::CopyRates(sym, InpExecutionTF, 1, InpCandleLookback, rates);
      
      if(orderType == ORDER_TYPE_BUY)
      {
         double lowest = rates[0].low;
         for(int i = 1; i < InpCandleLookback; i++) if(rates[i].low < lowest) lowest = rates[i].low;
         slPrice = lowest - (10 * point);
      }
      else
      {
         double highest = rates[0].high;
         for(int i = 1; i < InpCandleLookback; i++) if(rates[i].high > highest) highest = rates[i].high;
         slPrice = highest + (10 * point);
      }
   }
   else if(InpSLMethod == SL_EMA21)
   {
      double ema21[];
      ::ArraySetAsSeries(ema21, true);
      ::CopyBuffer(g_symbols[index].ema21_h_M5, 0, 1, 1, ema21);
      
      if(orderType == ORDER_TYPE_BUY) slPrice = ema21[0] - (10 * point);
      else                            slPrice = ema21[0] + (10 * point);
   }
   else if(InpSLMethod == SL_ATR)
   {
      double atr[];
      ::ArraySetAsSeries(atr, true);
      ::CopyBuffer(g_symbols[index].atr_h_M5, 0, 1, 1, atr);
      
      double atrDist = atr[0] * InpATRMultiplier;
      if(orderType == ORDER_TYPE_BUY) slPrice = entryPrice - atrDist;
      else                            slPrice = entryPrice + atrDist;
   }
   
   int digits = (int)::SymbolInfoInteger(sym, SYMBOL_DIGITS);
   return ::NormalizeDouble(slPrice, digits);
}

double CalculateTakeProfit(const string sym, const ENUM_ORDER_TYPE orderType, const double entryPrice, const double slPrice)
{
   if(!InpEnableTP) return 0.0;
   
   double slDistance = MathAbs(entryPrice - slPrice);
   double tpDistance = slDistance * InpTargetRR;
   
   double tpPrice = (orderType == ORDER_TYPE_BUY) ? (entryPrice + tpDistance) : (entryPrice - tpDistance);
   
   int digits = (int)::SymbolInfoInteger(sym, SYMBOL_DIGITS);
   return ::NormalizeDouble(tpPrice, digits);
}

//+------------------------------------------------------------------+
//| ACTIVE TRADE MANAGEMENT                                          |
//+------------------------------------------------------------------+
void ManageActiveTrades(const string sym)
{
   for(int i = ::PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = ::PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      if(::PositionGetString(POSITION_SYMBOL) != sym) continue;
      if(::PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)::PositionGetInteger(POSITION_TYPE);
      double openPrice  = ::PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL  = ::PositionGetDouble(POSITION_SL);
      double currentTP  = ::PositionGetDouble(POSITION_TP);
      double volume     = ::PositionGetDouble(POSITION_VOLUME);
      double currentPrice = (posType == POSITION_TYPE_BUY) ? ::SymbolInfoDouble(sym, SYMBOL_BID) : ::SymbolInfoDouble(sym, SYMBOL_ASK);
      double point      = ::SymbolInfoDouble(sym, SYMBOL_POINT);
      int digits        = (int)::SymbolInfoInteger(sym, SYMBOL_DIGITS);
      
      double slDist = MathAbs(openPrice - currentSL);
      
      // 1. Break Even
      if(InpEnableBreakEven && currentSL != 0.0)
      {
         bool triggerBE = false;
         if(posType == POSITION_TYPE_BUY && (currentPrice - openPrice) >= (slDist * InpBERrTrigger))
         {
            if(currentSL < openPrice) triggerBE = true;
         }
         else if(posType == POSITION_TYPE_SELL && (openPrice - currentPrice) >= (slDist * InpBERrTrigger))
         {
            if(currentSL > openPrice) triggerBE = true;
         }
         
         if(triggerBE)
         {
            double spread = ::SymbolInfoInteger(sym, SYMBOL_SPREAD) * point;
            double newSL  = (posType == POSITION_TYPE_BUY) ? (openPrice + spread) : (openPrice - spread);
            ModifyPositionSLTP(ticket, sym, ::NormalizeDouble(newSL, digits), currentTP);
            ::Print("Break Even Applied on Position #", ticket);
         }
      }
      
      // 2. Partial Close
      if(InpEnablePartialClose && slDist > 0.0)
      {
         bool triggerPC = false;
         if(posType == POSITION_TYPE_BUY && (currentPrice - openPrice) >= (slDist * InpPartialCloseRR)) triggerPC = true;
         if(posType == POSITION_TYPE_SELL && (openPrice - currentPrice) >= (slDist * InpPartialCloseRR)) triggerPC = true;
         
         if(triggerPC && volume > ::SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN))
         {
            double closeLots = NormalizeLot(sym, volume * (InpPartialClosePct / 100.0));
            if(closeLots > 0.0 && closeLots < volume)
            {
               ClosePartialPositionNative(ticket, sym, closeLots, posType);
               ::Print("Partial Close Executed on #", ticket, " Lots: ", closeLots);
            }
         }
      }
      
      // 3. Trailing Stop
      if(InpTrailingMode != TRAILING_NONE)
      {
         double newSL = 0.0;
         if(InpTrailingMode == TRAILING_POINTS)
         {
            if(posType == POSITION_TYPE_BUY && (currentPrice - openPrice) > (InpTrailingPoints * point))
            {
               double proposedSL = currentPrice - (InpTrailingPoints * point);
               if(proposedSL > currentSL) newSL = proposedSL;
            }
            else if(posType == POSITION_TYPE_SELL && (openPrice - currentPrice) > (InpTrailingPoints * point))
            {
               double proposedSL = currentPrice + (InpTrailingPoints * point);
               if(currentSL == 0.0 || proposedSL < currentSL) newSL = proposedSL;
            }
         }
         
         if(newSL > 0.0)
         {
            ModifyPositionSLTP(ticket, sym, ::NormalizeDouble(newSL, digits), currentTP);
         }
      }
   }
}

void CheckTradeDuration()
{
   if(InpMaxTradeHours <= 0) return;
   
   for(int i = ::PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = ::PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      if(::PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      
      datetime posTime = (datetime)::PositionGetInteger(POSITION_TIME);
      if((::TimeCurrent() - posTime) >= (InpMaxTradeHours * 3600))
      {
         string sym = ::PositionGetString(POSITION_SYMBOL);
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)::PositionGetInteger(POSITION_TYPE);
         double vol = ::PositionGetDouble(POSITION_VOLUME);
         
         ClosePartialPositionNative(ticket, sym, vol, posType);
         ::Print("Max Trade Duration Exceeded. Closed Position #", ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| POSITION MODIFICATION & CLOSING HELPERS                          |
//+------------------------------------------------------------------+
bool ModifyPositionSLTP(const ulong ticket, const string sym, const double sl, const double tp)
{
   MqlTradeRequest req;
   MqlTradeResult  res;
   ::ZeroMemory(req);
   ::ZeroMemory(res);
   
   req.action = TRADE_ACTION_SLTP;
   req.position = ticket;
   req.symbol   = sym;
   req.sl       = sl;
   req.tp       = tp;
   
   return ::OrderSend(req, res);
}

bool ClosePartialPositionNative(const ulong ticket, const string sym, const double lot, const ENUM_POSITION_TYPE posType)
{
   MqlTradeRequest req;
   MqlTradeResult  res;
   ::ZeroMemory(req);
   ::ZeroMemory(res);
   
   req.action   = TRADE_ACTION_DEAL;
   req.position = ticket;
   req.symbol   = sym;
   req.volume   = lot;
   req.type     = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   req.price    = (posType == POSITION_TYPE_BUY) ? ::SymbolInfoDouble(sym, SYMBOL_BID) : ::SymbolInfoDouble(sym, SYMBOL_ASK);
   req.magic    = InpMagicNumber;
   req.comment  = "Partial Close Auto Pilot";
   req.type_filling = GetSymbolFillingMode(sym);
   
   return ::OrderSend(req, res);
}

//+------------------------------------------------------------------+
//| ACCOUNT PROTECTION & LIMITS                                      |
//+------------------------------------------------------------------+
void CheckDailyReset()
{
   MqlDateTime dt;
   ::TimeToStruct(::TimeCurrent(), dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime todayStart = ::StructToTime(dt);
   
   if(todayStart != g_currentDay)
   {
      g_currentDay       = todayStart;
      g_dayStartBalance  = ::AccountInfoDouble(ACCOUNT_BALANCE);
      g_tradesTodayCount = 0;
      g_totalWinsToday   = 0;
      g_totalLossesToday = 0;
   }
}

bool IsAccountProtectionValid()
{
   // 1. Max Open Trades Filter
   if(CountTotalOpenPositions() >= InpMaxOpenTrades) return false;
   
   // 2. Max Trades Per Day Filter
   if(g_tradesTodayCount >= InpMaxTradesPerDay) return false;
   
   // 3. Daily Profit / Loss Target Filter
   double currentEquity = ::AccountInfoDouble(ACCOUNT_EQUITY);
   double pnlPct = ((currentEquity - g_dayStartBalance) / g_dayStartBalance) * 100.0;
   
   if(pnlPct <= -InpMaxDailyLossPct)
   {
      ::Print("Daily Loss Limit Reached (", pnlPct, "%). Trading Halted Today.");
      return false;
   }
   
   if(pnlPct >= InpMaxDailyProfitPct)
   {
      ::Print("Daily Profit Target Reached (", pnlPct, "%). Trading Halted Today.");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| MARKET & SESSION FILTERS                                         |
//+------------------------------------------------------------------+
bool IsMarketFilterPassed(const string sym, const int index)
{
   // Spread Filter
   double spread = (double)::SymbolInfoInteger(sym, SYMBOL_SPREAD);
   if(spread > InpMaxSpreadPoints) return false;
   
   // ATR Volatility Filter
   double atr[];
   ::ArraySetAsSeries(atr, true);
   if(::CopyBuffer(g_symbols[index].atr_h_M5, 0, 1, 1, atr) > 0)
   {
      if(atr[0] < InpMinATRValue) return false;
   }
   
   return true;
}

bool IsSessionActive()
{
   MqlDateTime dt;
   ::TimeToStruct(::TimeCurrent() + (InpBrokerGMTOffset * 3600), dt);
   int currentMin = dt.hour * 60 + dt.min;
   
   int lonStart = ParseTimeToMinutes(InpLondonStart);
   int lonEnd   = ParseTimeToMinutes(InpLondonEnd);
   int nyStart  = ParseTimeToMinutes(InpNYStart);
   int nyEnd    = ParseTimeToMinutes(InpNYEnd);
   
   bool inLondon = (currentMin >= lonStart && currentMin <= lonEnd);
   bool inNY     = (currentMin >= nyStart && currentMin <= nyEnd);
   
   return (inLondon || inNY);
}

int ParseTimeToMinutes(const string timeStr)
{
   string parts[];
   ushort u_sep = ::StringGetCharacter(":", 0);
   if(::StringSplit(timeStr, u_sep, parts) == 2)
   {
      return ((int)::StringToInteger(parts[0]) * 60 + (int)::StringToInteger(parts[1]));
   }
   return 0;
}

//+------------------------------------------------------------------+
//| ALERT & NOTIFICATION SYSTEM                                      |
//+------------------------------------------------------------------+
void SendAlertNotification(const string sym, const ENUM_ORDER_TYPE orderType, const double entry, const double sl, const double tp, const string reason)
{
   string dir = (orderType == ORDER_TYPE_BUY) ? "BUY" : "SELL";
   string msg = "--------------------------------\n" +
                "AUTO PILOT EMA 9-21 SIGNAL\n\n" +
                "Symbol: " + sym + "\n" +
                "Direction: " + dir + "\n" +
                "Entry: " + ::DoubleToString(entry, (int)::SymbolInfoInteger(sym, SYMBOL_DIGITS)) + "\n" +
                "Stop Loss: " + ::DoubleToString(sl, (int)::SymbolInfoInteger(sym, SYMBOL_DIGITS)) + "\n" +
                "Take Profit: " + ::DoubleToString(tp, (int)::SymbolInfoInteger(sym, SYMBOL_DIGITS)) + "\n" +
                "Risk: " + ::DoubleToString(InpRiskPercent, 1) + "%\n" +
                "RR: 1:" + ::DoubleToString(InpTargetRR, 1) + "\n" +
                "Reason: " + reason + "\n" +
                "--------------------------------";
                
   if(InpEnablePushAlerts)
   {
      ::Alert(msg);
      ::SendNotification(msg);
   }
   
   if(InpTelegramEnabled && ::StringLen(InpTelegramBotToken) > 0 && ::StringLen(InpTelegramChatID) > 0)
   {
      SendTelegramMessage(msg);
   }
}

void SendTelegramMessage(const string text)
{
   string url = "https://api.telegram.org/bot" + InpTelegramBotToken + "/sendMessage";
   string headers = "Content-Type: application/x-www-form-urlencoded\r\n";
   string postData = "chat_id=" + InpTelegramChatID + "&text=" + ::UrlEncode(text);
   
   char data[], result[];
   string resultHeaders;
   ::StringToCharArray(postData, data, 0, WHOLE_ARRAY, CP_UTF8);
   
   int res = ::WebRequest("POST", url, headers, 3000, data, result, resultHeaders);
   if(res != 200)
   {
      ::Print("Telegram Send Failed. HTTP Code: ", res);
   }
}

string UrlEncode(const string str)
{
   string encoded = "";
   int len = ::StringLen(str);
   for(int i = 0; i < len; i++)
   {
      ushort code = ::StringGetCharacter(str, i);
      if((code >= 'a' && code <= 'z') || (code >= 'A' && code <= 'Z') || (code >= '0' && code <= '9'))
         encoded += ::ShortToString(code);
      else if(code == ' ')
         encoded += "+";
      else
         encoded += ::StringFormat("%%%02X", code);
   }
   return encoded;
}

//+------------------------------------------------------------------+
//| VISUAL ON-CHART DASHBOARD                                        |
//+------------------------------------------------------------------+
void RenderDashboard()
{
   int x = 20, y = 30;
   int width = 320, height = 240 + (g_symbolCount * 20);
   
   // Background Label
   CreateOrUpdateRect("AP_BG", x, y, width, height, InpDashBgColor);
   
   // Title
   CreateOrUpdateText("AP_TITLE", "AUTO PILOT EMA 9-21 PRO", x + 15, y + 15, InpDashAccentColor, 11, true);
   
   // Account Info
   double balance = ::AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = ::AccountInfoDouble(ACCOUNT_EQUITY);
   double todayPnl = equity - g_dayStartBalance;
   
   string modeStr = (InpTradingMode == AUTO_TRADE) ? "AUTO TRADE" : (InpTradingMode == ALERT_ONLY ? "ALERT ONLY" : "CONFIRMATION");
   CreateOrUpdateText("AP_MODE", "Mode: " + modeStr, x + 15, y + 40, InpDashTextColor, 9);
   CreateOrUpdateText("AP_BAL",  "Balance: $" + ::DoubleToString(balance, 2), x + 15, y + 60, InpDashTextColor, 9);
   CreateOrUpdateText("AP_EQ",   "Equity:  $" + ::DoubleToString(equity, 2), x + 15, y + 80, InpDashTextColor, 9);
   
   color pnlColor = (todayPnl >= 0) ? C'0,225,120' : C'255,70,70';
   CreateOrUpdateText("AP_PNL",  "Today Profit: $" + ::DoubleToString(todayPnl, 2), x + 15, y + 100, pnlColor, 9, true);
   CreateOrUpdateText("AP_POS",  "Open Trades: " + ::IntegerToString(CountTotalOpenPositions()), x + 15, y + 120, InpDashTextColor, 9);
   
   // Table Divider
   CreateOrUpdateText("AP_DIV", "------------------------------------------", x + 15, y + 140, InpDashAccentColor, 9);
   CreateOrUpdateText("AP_HDR", "SYMBOL SCANNER STATUS", x + 15, y + 155, InpDashAccentColor, 9, true);
   
   // Render Symbol Statuses
   int rowY = y + 180;
   for(int i = 0; i < g_symbolCount; i++)
   {
      color statusCol = InpDashTextColor;
      if(g_symbols[i].statusText == "BUY READY" || g_symbols[i].statusText == "BUY SETUP") statusCol = C'0,225,120';
      else if(g_symbols[i].statusText == "SELL READY" || g_symbols[i].statusText == "SELL SETUP") statusCol = C'255,70,70';
      
      CreateOrUpdateText("AP_SYM_" + ::IntegerToString(i), g_symbols[i].symbol + ":", x + 15, rowY, InpDashTextColor, 9);
      CreateOrUpdateText("AP_STA_" + ::IntegerToString(i), g_symbols[i].statusText, x + 140, rowY, statusCol, 9, true);
      rowY += 20;
   }
   
   ::ChartRedraw(0);
}

void CreateOrUpdateRect(const string name, const int x, const int y, const int w, const int h, const color bgColor)
{
   if(::ObjectFind(0, name) < 0)
   {
      ::ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ::ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ::ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ::ObjectSetInteger(0, name, OBJPROP_BACK, false);
   }
   ::ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ::ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ::ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ::ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ::ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
   ::ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, InpDashAccentColor);
}

void CreateOrUpdateText(const string name, const string text, const int x, const int y, const color txtColor, const int fontSize = 9, const bool bold = false)
{
   if(::ObjectFind(0, name) < 0)
   {
      ::ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ::ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ::ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ::ObjectSetInteger(0, name, OBJPROP_BACK, false);
   }
   ::ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ::ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ::ObjectSetString(0, name, OBJPROP_TEXT, text);
   ::ObjectSetInteger(0, name, OBJPROP_COLOR, txtColor);
   ::ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ::ObjectSetString(0, name, OBJPROP_FONT, bold ? "Arial Bold" : "Arial");
}

void RemoveDashboard()
{
   ::ObjectsDeleteAll(0, "AP_");
}

//+------------------------------------------------------------------+
//| TRADE JOURNAL & UTILITY FUNCTIONS                                |
//+------------------------------------------------------------------+
void RecordTradeJournal(const ulong ticket, const string sym, const int type, const double price, const double sl, const double tp, const string reason)
{
   int size = ::ArraySize(g_journal);
   ::ArrayResize(g_journal, size + 1);
   
   g_journal[size].ticket    = ticket;
   g_journal[size].symbol    = sym;
   g_journal[size].type      = type;
   g_journal[size].openPrice = price;
   g_journal[size].sl        = sl;
   g_journal[size].tp        = tp;
   g_journal[size].openTime  = ::TimeCurrent();
   g_journal[size].reason    = reason;
   
   ::Print("Journal Record Added: Ticket #", ticket, " | Symbol: ", sym, " | Reason: ", reason);
}

int CountTotalOpenPositions()
{
   int count = 0;
   for(int i = ::PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = ::PositionGetTicket(i);
      if(ticket > 0 && ::PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) count++;
   }
   return count;
}

int CountSymbolPositions(const string sym)
{
   int count = 0;
   for(int i = ::PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = ::PositionGetTicket(i);
      if(ticket > 0 && ::PositionGetString(POSITION_SYMBOL) == sym && ::PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) count++;
   }
   return count;
}

ENUM_ORDER_TYPE_FILLING GetSymbolFillingMode(const string sym)
{
   uint filling = (uint)::SymbolInfoInteger(sym, SYMBOL_FILLING_MODE);
   if((filling & SYMBOL_FILLING_FOK) != 0) return ORDER_FILLING_FOK;
   if((filling & SYMBOL_FILLING_IOC) != 0) return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
}
//+------------------------------------------------------------------+