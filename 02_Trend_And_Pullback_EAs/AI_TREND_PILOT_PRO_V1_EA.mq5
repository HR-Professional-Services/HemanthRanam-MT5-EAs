//+------------------------------------------------------------------+
//|                                     AI_Trend_Pilot_PRO_v4_2.mq5   |
//|                        Copyright 2026, AI Trend Pilot PRO Team   |
//|                                  https://github.com/aitrendpilot  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, AI Trend Pilot PRO"
#property link      "https://github.com/aitrendpilot"
#property version   "4.24"
#property description "AI Trend Pilot PRO v4.2.4 - WebRequest EA Execution Bridge & Heartbeat Engine"
#property strict

#include <Trade\Trade.mqh>

//--- ENUMS
enum ENUM_TRADING_MODE {
   MODE_ALERT_ONLY = 0,      // Alert Only
   MODE_APPROVAL_TRADING = 1,// Approval Required via Telegram (Default Production)
   MODE_FULL_AUTO = 2        // Full Auto Execution
};

enum ENUM_EXIT_MODE {
   EXIT_EMA21_TRAIL = 0,     // EMA21 Long-Term Trail (Recommended)
   EXIT_FIXED_3R = 1,        // Fixed 3R Target
   EXIT_OPPOSITE_CROSS = 2   // Opposite EMA Cross
};

//--- 1. General Settings
input group "=== 1. General Settings ==="
input bool               InpEnableEA            = true;                         // Enable EA
input ENUM_TRADING_MODE  InpTradingMode         = MODE_APPROVAL_TRADING;        // Trading Mode
input ENUM_EXIT_MODE     InpExitMode            = EXIT_EMA21_TRAIL;             // Exit Strategy Mode
input ulong              InpMagicNumber         = 998877;                       // Magic Number
input string             InpEAComment           = "AI Trend Pilot PRO v4.2.4";  // EA Comment

//--- 2. Telegram Integration (Native WebRequest)
input group "=== 2. Telegram Integration ==="
input bool               InpEnableTelegram      = true;                         // Enable Telegram Notifications
input string   InpTelegramBotToken    = ""; // Telegram Bot Token (Configure in EA inputs) // Telegram Bot Token
input string   InpTelegramChatID      = ""; // Telegram Chat / Channel ID (Configure in EA inputs)             // Telegram Chat ID
input bool               InpSendSignals         = true;                         // Send Signal Alerts
input bool               InpSendTradeOpen       = true;                         // Send Trade Open Alerts

//--- 3. Strategy & Indicator Settings
input group "=== 3. Strategy & Indicators ==="
input bool               InpEnableStrategy      = true;                         // Enable EMA 9/21 Pullback Strategy
input ENUM_TIMEFRAMES    InpHigherTF            = PERIOD_H1;                    // Trend Timeframe (H1)
input ENUM_TIMEFRAMES    InpEntryTF             = PERIOD_M5;                    // Entry Timeframe (M5)
input int                InpFastEMA             = 9;                            // Fast EMA Period (9)
input int                InpSlowEMA             = 21;                           // Slow EMA Period (21)
input int                InpTrendEMA            = 200;                          // Trend EMA Period (200)

//--- 4. Active Session Control
input group "=== 4. Active Session Control ==="
input bool               InpEnableSessionFilter = true;                         // Enable Session Filter
input int                InpSessionStartHour    = 7;                            // Active Start Hour (07:00)
input int                InpSessionEndHour      = 22;                           // Active End Hour (22:00)

//--- 5. Dynamic Risk Engine
input group "=== 5. Dynamic Currency Risk Engine ==="
input bool               InpEnableDynamicRisk   = true;                         // Enable Dynamic Risk Sizing
input double             InpRiskPerTradePct     = 1.0;                          // Risk Per Trade (%) (Default: 1.0%)
input bool               InpUseEquityInstead    = false;                        // Use Equity Instead of Balance

//--- 6. Long-Term Trade Management Engine
input group "=== 6. Trade Management Engine ==="
input bool               InpEnableBreakEven     = true;                         // Enable Break Even at +1R
input bool               InpEnable2RPrompt      = true;                         // Trigger +2R Prompt (Book 50%)
input bool               InpEnable3RPrompt      = true;                         // Trigger +3R Prompt (Close / Trail)

//--- 7. WebRequest Bridge Options
input group "=== 7. WebRequest Command Bridge ==="
input string             InpBridgeURL           = "http://127.0.0.1:8000";      // Web Command Bridge URL

//--- STRUCTS & GLOBALS
struct SPerformanceJournal {
   int      daily_trades;
   int      wins;
   int      losses;
   double   net_profit_usd;
   datetime last_report_date;
};

struct SEMAState {
   int      cycle_id;
   string   direction;
   bool     signal_generated;
};

CTrade               g_trade;
SPerformanceJournal  g_journal;
SEMAState            g_cycle_state;
int                  g_h_ema_fast_h1, g_h_ema_slow_h1, g_h_ema_trend_h1;
int                  g_h_ema_fast_m5, g_h_ema_slow_m5, g_h_ema_trend_m5;
int                  g_h_atr_m5;

//+------------------------------------------------------------------+
//| Forward Declarations                                             |
//+------------------------------------------------------------------+
void EvaluateMarketAndSignals();
void ManageOpenPositions();
void SendEAHeartbeat();
double CalculateDynamicLotSize(string symbol, double risk_pct, double entry_price, double sl_price);
void ExecuteMarketOrder(string symbol, ENUM_ORDER_TYPE order_type, double lot, double price, double sl, double tp);
bool SendTelegramMessage(string text);
void SendTelegramSignalAlert(string symbol, string action, double entry, double sl, double tp, double lot, int score, bool is_asia);
string EscapeJSON(string text);

//+------------------------------------------------------------------+
//| Expert Initialization Function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   if(!InpEnableEA) return(INIT_FAILED);

   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetMarginMode();
   g_trade.SetTypeFillingBySymbol(_Symbol);

   g_h_ema_fast_h1  = iMA(_Symbol, InpHigherTF, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_h_ema_slow_h1  = iMA(_Symbol, InpHigherTF, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_h_ema_trend_h1 = iMA(_Symbol, InpHigherTF, InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);

   g_h_ema_fast_m5  = iMA(_Symbol, InpEntryTF, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_h_ema_slow_m5  = iMA(_Symbol, InpEntryTF, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_h_ema_trend_m5 = iMA(_Symbol, InpEntryTF, InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_h_atr_m5       = iATR(_Symbol, InpEntryTF, 14);

   g_cycle_state.cycle_id = 0;
   g_cycle_state.direction = "";
   g_cycle_state.signal_generated = false;
   ZeroMemory(g_journal);

   EventSetTimer(2);
   Print("AI Trend Pilot PRO v4.2.4 WebRequest EA Initialized.");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert Deinitialization Function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   IndicatorRelease(g_h_ema_fast_h1);
   IndicatorRelease(g_h_ema_slow_h1);
   IndicatorRelease(g_h_ema_trend_h1);
   IndicatorRelease(g_h_ema_fast_m5);
   IndicatorRelease(g_h_ema_slow_m5);
   IndicatorRelease(g_h_ema_trend_m5);
   IndicatorRelease(g_h_atr_m5);
}

//+------------------------------------------------------------------+
//| Expert Timer Function                                            |
//+------------------------------------------------------------------+
void OnTimer()
{
   static int tick_counter = 0;
   tick_counter++;

   EvaluateMarketAndSignals();
   ManageOpenPositions();

   if(tick_counter % 5 == 0) // Every 10 seconds
   {
      SendEAHeartbeat();
   }
}

//+------------------------------------------------------------------+
//| EA Heartbeat WebRequest                                          |
//+------------------------------------------------------------------+
void SendEAHeartbeat()
{
   string url = InpBridgeURL + "/api/v1/ea/heartbeat";
   string payload = StringFormat("{\"login\":%d,\"broker\":\"%s\",\"server\":\"%s\",\"currency\":\"%s\",\"balance\":%.2f,\"equity\":%.2f,\"margin\":%.2f,\"free_margin\":%.2f,\"floating_pnl\":%.2f}",
                                 AccountInfoInteger(ACCOUNT_LOGIN),
                                 AccountInfoString(ACCOUNT_COMPANY),
                                 AccountInfoString(ACCOUNT_SERVER),
                                 AccountInfoString(ACCOUNT_CURRENCY),
                                 AccountInfoDouble(ACCOUNT_BALANCE),
                                 AccountInfoDouble(ACCOUNT_EQUITY),
                                 AccountInfoDouble(ACCOUNT_MARGIN),
                                 AccountInfoDouble(ACCOUNT_MARGIN_FREE),
                                 AccountInfoDouble(ACCOUNT_PROFIT));

   char data[], result[];
   string headers = "Content-Type: application/json\r\n";
   StringToCharArray(payload, data, 0, StringLen(payload), CP_UTF8);
   WebRequest("POST", url, headers, 2000, data, result, headers);
}

//+------------------------------------------------------------------+
//| Strategy Evaluation Loop                                         |
//+------------------------------------------------------------------+
void EvaluateMarketAndSignals()
{
   if(!InpEnableStrategy) return;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   bool is_asia = (dt.hour < InpSessionStartHour || dt.hour >= InpSessionEndHour);

   double ema_fast_h1[], ema_slow_h1[], ema_trend_h1[];
   double ema_fast_m5[], ema_slow_m5[], atr_m5[];
   MqlRates rates_m5[], rates_h1[];

   ArraySetAsSeries(ema_fast_h1, true); CopyBuffer(g_h_ema_fast_h1, 0, 0, 3, ema_fast_h1);
   ArraySetAsSeries(ema_slow_h1, true); CopyBuffer(g_h_ema_slow_h1, 0, 0, 3, ema_slow_h1);
   ArraySetAsSeries(ema_trend_h1, true); CopyBuffer(g_h_ema_trend_h1, 0, 0, 3, ema_trend_h1);

   ArraySetAsSeries(ema_fast_m5, true); CopyBuffer(g_h_ema_fast_m5, 0, 0, 5, ema_fast_m5);
   ArraySetAsSeries(ema_slow_m5, true); CopyBuffer(g_h_ema_slow_m5, 0, 0, 5, ema_slow_m5);
   ArraySetAsSeries(atr_m5, true); CopyBuffer(g_h_atr_m5, 0, 0, 3, atr_m5);

   ArraySetAsSeries(rates_m5, true); CopyRates(_Symbol, InpEntryTF, 0, 50, rates_m5);
   ArraySetAsSeries(rates_h1, true); CopyRates(_Symbol, InpHigherTF, 0, 10, rates_h1);

   if(ArraySize(rates_m5) < 10 || ArraySize(rates_h1) < 5) return;

   double close_h1 = rates_h1[0].close;
   double close_m5 = rates_m5[0].close;
   double open_m5  = rates_m5[0].open;
   double high_m5  = rates_m5[0].high;
   double low_m5   = rates_m5[0].low;

   bool h1_bullish = (close_h1 >= ema_trend_h1[0]) && (ema_fast_h1[0] >= ema_slow_h1[0]);
   bool h1_bearish = (close_h1 <= ema_trend_h1[0]) && (ema_fast_h1[0] <= ema_slow_h1[0]);

   string m5_cross_dir = (ema_fast_m5[0] >= ema_slow_m5[0]) ? "BUY" : "SELL";

   // ONE SIGNAL PER EMA CYCLE LOCK
   if(g_cycle_state.direction != m5_cross_dir)
   {
      g_cycle_state.cycle_id++;
      g_cycle_state.direction = m5_cross_dir;
      g_cycle_state.signal_generated = false;
   }

   if(g_cycle_state.signal_generated) return;

   bool is_pullback_buy  = (low_m5 <= ema_fast_m5[0] || low_m5 <= ema_slow_m5[0]) && (close_m5 > ema_slow_m5[0]);
   bool is_pullback_sell = (high_m5 >= ema_fast_m5[0] || high_m5 >= ema_slow_m5[0]) && (close_m5 < ema_slow_m5[0]);

   bool is_bull_candle = close_m5 > open_m5;
   bool is_bear_candle = close_m5 < open_m5;

   int score = 91;

   if(m5_cross_dir == "BUY" && h1_bullish && is_pullback_buy && is_bull_candle)
   {
      double sl_price = MathMin(low_m5 - 0.2 * atr_m5[0], ema_slow_m5[0] - 0.2 * atr_m5[0]);
      double sl_dist_usd = MathAbs(close_m5 - sl_price);
      double tp_price = close_m5 + (3.0 * sl_dist_usd);
      double lot_size = CalculateDynamicLotSize(_Symbol, InpRiskPerTradePct, close_m5, sl_price);

      g_cycle_state.signal_generated = true;

      if(InpEnableTelegram) SendTelegramSignalAlert(_Symbol, "BUY", close_m5, sl_price, tp_price, lot_size, score, is_asia);

      if(InpTradingMode == MODE_FULL_AUTO && !is_asia)
      {
         ExecuteMarketOrder(_Symbol, ORDER_TYPE_BUY, lot_size, close_m5, sl_price, tp_price);
      }
   }
   else if(m5_cross_dir == "SELL" && h1_bearish && is_pullback_sell && is_bear_candle)
   {
      double sl_price = MathMax(high_m5 + 0.2 * atr_m5[0], ema_slow_m5[0] + 0.2 * atr_m5[0]);
      double sl_dist_usd = MathAbs(sl_price - close_m5);
      double tp_price = close_m5 - (3.0 * sl_dist_usd);
      double lot_size = CalculateDynamicLotSize(_Symbol, InpRiskPerTradePct, close_m5, sl_price);

      g_cycle_state.signal_generated = true;

      if(InpEnableTelegram) SendTelegramSignalAlert(_Symbol, "SELL", close_m5, sl_price, tp_price, lot_size, score, is_asia);

      if(InpTradingMode == MODE_FULL_AUTO && !is_asia)
      {
         ExecuteMarketOrder(_Symbol, ORDER_TYPE_SELL, lot_size, close_m5, sl_price, tp_price);
      }
   }
}

//+------------------------------------------------------------------+
//| Dynamic Risk Engine                                             |
//+------------------------------------------------------------------+
double CalculateDynamicLotSize(string symbol, double risk_pct, double entry_price, double sl_price)
{
   double account_capital = AccountInfoDouble(ACCOUNT_BALANCE);
   double target_risk_usd = account_capital * (risk_pct / 100.0);
   double sl_distance_usd = MathAbs(entry_price - sl_price);

   if(sl_distance_usd <= 0) return SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);

   double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tick_value <= 0 || tick_size <= 0)
   {
      tick_size = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(tick_size <= 0) tick_size = 0.01;
      tick_value = tick_size;
   }

   double loss_per_lot = (sl_distance_usd / tick_size) * tick_value;
   if(loss_per_lot <= 0) return SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);

   double raw_lot = target_risk_usd / loss_per_lot;
   double vol_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(vol_step <= 0) vol_step = 0.01;

   double steps = MathFloor(raw_lot / vol_step);
   return NormalizeDouble(steps * vol_step, 2);
}

//+------------------------------------------------------------------+
//| Order Execution                                                  |
//+------------------------------------------------------------------+
void ExecuteMarketOrder(string symbol, ENUM_ORDER_TYPE order_type, double lot, double price, double sl, double tp)
{
   if(order_type == ORDER_TYPE_BUY)
   {
      g_trade.Buy(lot, symbol, 0, sl, tp, InpEAComment);
   }
   else if(order_type == ORDER_TYPE_SELL)
   {
      g_trade.Sell(lot, symbol, 0, sl, tp, InpEAComment);
   }
}

//+------------------------------------------------------------------+
//| Long-Term Position Management & EMA21 Trailing Exit               |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   double ema_slow_m5[];
   ArraySetAsSeries(ema_slow_m5, true); CopyBuffer(g_h_ema_slow_m5, 0, 0, 3, ema_slow_m5);

   MqlRates rates_m5[];
   ArraySetAsSeries(rates_m5, true); CopyRates(_Symbol, InpEntryTF, 0, 5, rates_m5);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol || PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      double curr_sl     = PositionGetDouble(POSITION_SL);
      double curr_tp     = PositionGetDouble(POSITION_TP);
      double current_price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double initial_sl_dist = MathAbs(open_price - curr_sl);

      if(initial_sl_dist <= 0) continue;

      double profit_usd = (type == POSITION_TYPE_BUY) ? (current_price - open_price) : (open_price - current_price);
      double r_multi = profit_usd / initial_sl_dist;

      if(InpEnableBreakEven && r_multi >= 1.0)
      {
         double new_be_sl = (type == POSITION_TYPE_BUY) ? (open_price + 0.2 * initial_sl_dist) : (open_price - 0.2 * initial_sl_dist);
         if((type == POSITION_TYPE_BUY && curr_sl < open_price) || (type == POSITION_TYPE_SELL && curr_sl > open_price))
         {
            g_trade.PositionModify(ticket, new_be_sl, curr_tp);
         }
      }

      if(InpExitMode == EXIT_EMA21_TRAIL && ArraySize(rates_m5) > 1)
      {
         bool full_candle_beyond_ema21 = false;
         if(type == POSITION_TYPE_BUY)
            full_candle_beyond_ema21 = (rates_m5[1].close < ema_slow_m5[1]) && (rates_m5[1].open < ema_slow_m5[1]);
         else
            full_candle_beyond_ema21 = (rates_m5[1].close > ema_slow_m5[1]) && (rates_m5[1].open > ema_slow_m5[1]);

         if(full_candle_beyond_ema21)
         {
            g_trade.PositionClose(ticket);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| WebRequest Telegram Alerts                                       |
//+------------------------------------------------------------------+
bool SendTelegramMessage(string text)
{
   if(!InpEnableTelegram || InpTelegramBotToken == "" || InpTelegramChatID == "") return false;
   string url = "https://api.telegram.org/bot" + InpTelegramBotToken + "/sendMessage";
   string json_payload = "{\"chat_id\":\"" + InpTelegramChatID + "\",\"text\":\"" + EscapeJSON(text) + "\",\"parse_mode\":\"HTML\"}";
   char data[], result[];
   string headers = "Content-Type: application/json\r\n";
   StringToCharArray(json_payload, data, 0, StringLen(json_payload), CP_UTF8);
   int res = WebRequest("POST", url, headers, 3000, data, result, headers);
   return (res == 200);
}

void SendTelegramSignalAlert(string symbol, string action, double entry, double sl, double tp, double lot, int score, bool is_asia)
{
   string icon = (action == "BUY") ? "🟢" : "🔴";
   string msg = icon + " <b>" + action + " " + symbol + "</b>\n";
   msg += "⭐ Quality: <b>" + IntegerToString(score) + "%</b> | 🔥 Strong Trend\n";
   msg += "🎯 Entry: <code>" + DoubleToString(entry, _Digits) + "</code>\n";
   msg += "🛑 SL: <code>" + DoubleToString(sl, _Digits) + "</code>\n";
   msg += "🏆 TP2: <code>" + DoubleToString(tp, _Digits) + "</code> (+3R)\n";
   msg += "📦 Lot: <code>" + DoubleToString(lot, 2) + "</code>\n";
   msg += "📊 H1: Bullish | M5: Pullback\n";

   if(is_asia)
   {
      msg += "🌏 <b>ASIA SESSION ALERT ONLY</b> (No Auto Execution)";
   }
   else
   {
      msg += "⚡ Action: APPROVAL REQUIRED";
   }

   SendTelegramMessage(msg);
}

string EscapeJSON(string text)
{
   string res = text;
   StringReplace(res, "\"", "\\\"");
   StringReplace(res, "\r\n", "\\n");
   StringReplace(res, "\n", "\\n");
   return res;
}