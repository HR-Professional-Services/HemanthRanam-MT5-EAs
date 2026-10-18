//+------------------------------------------------------------------+
//|                                              HemanthRanamEA.mq5  |
//|                                  Copyright 2026, Hemanth Ranam.  |
//|                        https://app.hemanth-ranam.workers.dev/   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Hemanth Ranam"
#property link      "https://app.hemanth-ranam.workers.dev/"
#property version   "1.00"
#property description "Hemanth Ranam — Multi-Strategy Institutional Execution Bridge for MT5"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

CTrade         m_trade;
CPositionInfo  m_position;

//--- INPUT PARAMETERS ---
input group "=== Institutional Risk Management ==="
input double   InpMaxRiskPct       = 1.0;        // Max Risk per Trade (% Balance)
input double   InpMaxDailyLossPct  = 3.0;        // Max Daily Drawdown Limit (%)
input double   InpDefaultLotSize   = 0.01;       // Fixed Lot Fallback
input ulong    InpMagicNumber      = 20260827;   // Expert Advisor Magic Number

input group "=== Cloud Webhook & Bridge Gateway ==="
input string   InpBridgeApiUrl     = "https://api.chartora.in/api/v1/mt5"; // Bridge Endpoint
input string   InpApiKey              = ""; // API Authorization Key (Configure in EA inputs)                // API Authorization Key
input int      InpPollingInterval  = 2;                                    // Poll Interval (Seconds)

//--- GLOBAL STATE ---
datetime g_last_poll_time = 0;
double   g_daily_starting_balance = 0.0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   m_trade.SetExpertMagicNumber(InpMagicNumber);
   g_daily_starting_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   Print("[Hemanth Ranam MT5 Bridge] Initialized successfully. Magic: ", InpMagicNumber);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("[Hemanth Ranam MT5 Bridge] Deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   datetime now = TimeCurrent();
   if(now - g_last_poll_time < InpPollingInterval) return;
   g_last_poll_time = now;

   // Check Daily Risk Kill-Switch
   double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double max_allowed_loss = g_daily_starting_balance * (InpMaxDailyLossPct / 100.0);
   if(g_daily_starting_balance - current_equity > max_allowed_loss)
   {
      Print("[Hemanth Ranam MT5] Daily loss limit reached. Trading halted for safety.");
      return;
   }
}

//+------------------------------------------------------------------+
//| Lot Size Calculation (1% Risk Rule)                              |
//+------------------------------------------------------------------+
double CalculateLotSize(string symbol, double stop_loss_pts)
{
   if(stop_loss_pts <= 0) return InpDefaultLotSize;
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_currency = balance * (InpMaxRiskPct / 100.0);
   double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(tick_value <= 0 || tick_size <= 0) return InpDefaultLotSize;
   
   double lot = risk_currency / (stop_loss_pts * tick_value);
   double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   double min_lot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double max_lot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   
   lot = MathFloor(lot / lot_step) * lot_step;
   if(lot < min_lot) lot = min_lot;
   if(lot > max_lot) lot = max_lot;
   
   return lot;
}
