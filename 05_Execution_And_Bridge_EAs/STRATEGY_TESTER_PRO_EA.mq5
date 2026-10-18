//+------------------------------------------------------------------+
//|                                         SmartMultiStrategyEA.mq5 |
//|                                  Copyright 2026, Antigravity AI |
//|                                       https://www.mql5.com       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity AI"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "Institutional-Grade Multi-Strategy Algorithmic Trading EA for MetaTrader 5."
#property description "Features: Trend Following, Mean Reversion, Confluence Mode, ATR Risk Management, Dynamic Trailing Stop & Daily Loss Circuit Breaker."

#include <Trade\Trade.mqh>

//====================================================================
// ENUMERATIONS
//====================================================================
enum ENUM_STRATEGY_MODE
  {
   STRATEGY_TREND_FOLLOWING = 0, // Strategy 1: EMA Crossover + RSI Momentum
   STRATEGY_MEAN_REVERSION  = 1, // Strategy 2: Bollinger Bands + RSI Extremes
   STRATEGY_CONFLUENCE       = 2  // Strategy 3: Confluence (Trend + Reversion Alignment)
  };

//====================================================================
// INPUT PARAMETERS
//====================================================================
//--- Risk & Account Protection
input group "=== Risk Management & Safety ==="
input double   InpRiskPercent       = 1.5;       // Risk per Trade (% of Equity)
input double   InpMaxDailyDrawdown  = 4.0;       // Max Daily Loss Circuit Breaker (%)
input double   InpMaxSpreadPips     = 3.0;       // Max Allowed Spread (in Pips)
input int      InpMagicNumber       = 888123;    // EA Unique Magic Number
input int      InpMaxOpenPositions  = 2;         // Max Concurrent Open Positions per Symbol

//--- Stop Loss & Take Profit Settings (ATR Dynamic)
input group "=== Dynamic ATR Stop Loss & Take Profit ==="
input int      InpATRPeriod         = 14;        // ATR Period for Volatility
input double   InpSL_ATR_Mult       = 1.5;       // Stop Loss ATR Multiplier
input double   InpTP_ATR_Mult       = 3.0;       // Take Profit ATR Multiplier (1:2 Risk/Reward)
input bool     InpUseTrailingStop   = true;      // Enable Trailing Stop
input double   InpTrailingATR_Mult  = 1.5;       // Trailing Stop ATR Multiplier
input bool     InpUseBreakEven      = true;      // Enable Break-Even Trigger
input double   InpBreakEvenR_Mult   = 1.0;       // Break-Even Trigger (R-Multiple of SL)

//--- Strategy Parameters
input group "=== Trading Strategy Setup ==="
input ENUM_STRATEGY_MODE InpStrategyMode = STRATEGY_TREND_FOLLOWING; // Strategy Selector Mode
input int      InpFastEMAPeriod     = 20;        // Fast EMA Period
input int      InpSlowEMAPeriod     = 50;        // Slow EMA Period
input int      InpRSI_Period        = 14;        // RSI Period
input double   InpRSI_Overbought    = 70.0;      // RSI Overbought Level (Sell Zone)
input double   InpRSI_Oversold      = 30.0;      // RSI Oversold Level (Buy Zone)
input int      InpBandsPeriod       = 20;        // Bollinger Bands Period
input double   InpBandsDeviations   = 2.0;       // Bollinger Bands Std Deviation

//====================================================================
// GLOBAL VARIABLES & HANDLES
//====================================================================
CTrade         m_trade;              // MQL5 Trade Execution Object
int            m_handle_fast_ema;    // Fast EMA Handle
int            m_handle_slow_ema;    // Slow EMA Handle
int            m_handle_rsi;         // RSI Handle
int            m_handle_atr;         // ATR Handle
int            m_handle_bands;       // Bollinger Bands Handle

datetime       m_last_bar_time;      // Track new bar generation
double         m_day_start_equity;   // Start of day equity for daily drawdown protection
datetime       m_last_day_check;     // Date tracker for resetting daily drawdown

//+------------------------------------------------------------------+
//| Expert Initialization Function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // 1. Validate Input Parameters
   if(InpRiskPercent <= 0 || InpRiskPercent > 10)
     {
      Print("Error: Risk percent must be between 0.1% and 10%");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpFastEMAPeriod >= InpSlowEMAPeriod)
     {
      Print("Error: Fast EMA period must be smaller than Slow EMA period");
      return(INIT_PARAMETERS_INCORRECT);
     }

   // 2. Configure Trade Execution Settings
   m_trade.SetExpertMagicNumber(InpMagicNumber);
   m_trade.SetMarginMode();
   m_trade.SetTypeFillingBySymbol(_Symbol);
   m_trade.SetDeviationInPoints(10);

   // 3. Initialize Indicator Handles
   m_handle_fast_ema = iMA(_Symbol, _Period, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   m_handle_slow_ema = iMA(_Symbol, _Period, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   m_handle_rsi      = iRSI(_Symbol, _Period, InpRSI_Period, PRICE_CLOSE);
   m_handle_atr      = iATR(_Symbol, _Period, InpATRPeriod);
   m_handle_bands    = iBands(_Symbol, _Period, InpBandsPeriod, 0, InpBandsDeviations, PRICE_CLOSE);

   if(m_handle_fast_ema == INVALID_HANDLE || m_handle_slow_ema == INVALID_HANDLE ||
      m_handle_rsi == INVALID_HANDLE || m_handle_atr == INVALID_HANDLE || m_handle_bands == INVALID_HANDLE)
     {
      Print("Error: Failed to initialize indicator handles.");
      return(INIT_FAILED);
     }

   // 4. Initialize State Trackers
   m_last_bar_time     = 0;
   m_day_start_equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   m_last_day_check    = TimeCurrent();

   Print("SmartMultiStrategyEA successfully initialized on ", _Symbol, " (", EnumToString(_Period), ")");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert Deinitialization Function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   // Release Indicator Handles to free memory
   IndicatorRelease(m_handle_fast_ema);
   IndicatorRelease(m_handle_slow_ema);
   IndicatorRelease(m_handle_rsi);
   IndicatorRelease(m_handle_atr);
   IndicatorRelease(m_handle_bands);

   // Clear Chart Dashboard
   Comment("");
   Print("SmartMultiStrategyEA deinitialized. Reason code: ", reason);
  }

//+------------------------------------------------------------------+
//| Expert Tick Function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // 1. Reset Daily Start Equity on New Trading Day
   MqlDateTime dt_curr, dt_last;
   TimeToStruct(TimeCurrent(), dt_curr);
   TimeToStruct(m_last_day_check, dt_last);

   if(dt_curr.day != dt_last.day)
     {
      m_day_start_equity = AccountInfoDouble(ACCOUNT_EQUITY);
      m_last_day_check   = TimeCurrent();
     }

   // 2. Check Daily Drawdown Circuit Breaker
   double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double daily_loss_pct = ((m_day_start_equity - current_equity) / m_day_start_equity) * 100.0;

   if(daily_loss_pct >= InpMaxDailyDrawdown)
     {
      UpdateDashboard("CIRCUIT BREAKER ACTIVE - Max Daily Drawdown Reached (" + DoubleToString(daily_loss_pct, 2) + "%)");
      ManagePositions(); // Still manage active positions (trailing stop)
      return;
     }

   // 3. Manage Existing Open Positions (Trailing Stop / Break-Even)
   ManagePositions();

   // 4. Update On-Chart Information Dashboard
   UpdateDashboard("Active");

   // 5. Ensure New Bar Evaluation to avoid over-trading on every tick
   datetime current_bar_time = iTime(_Symbol, _Period, 0);
   if(current_bar_time == m_last_bar_time) return;
   m_last_bar_time = current_bar_time;

   // 6. Check Spread Filter
   double spread_pips = GetCurrentSpreadPips();
   if(spread_pips > InpMaxSpreadPips)
     {
      Print("Spread too high: ", DoubleToString(spread_pips, 1), " pips. Skipping signal evaluation.");
      return;
     }

   // 7. Check Max Open Positions Limit
   if(CountOpenPositions() >= InpMaxOpenPositions) return;

   // 8. Fetch Indicator Data
   double fast_ema[2], slow_ema[2], rsi[2], atr[1], band_upper[2], band_lower[2];

   if(CopyBuffer(m_handle_fast_ema, 0, 1, 2, fast_ema) < 2 ||
      CopyBuffer(m_handle_slow_ema, 0, 1, 2, slow_ema) < 2 ||
      CopyBuffer(m_handle_rsi, 0, 1, 2, rsi) < 2 ||
      CopyBuffer(m_handle_atr, 0, 1, 1, atr) < 1 ||
      CopyBuffer(m_handle_bands, 1, 1, 2, band_upper) < 2 || // Buffer 1 = Upper Band
      CopyBuffer(m_handle_bands, 2, 1, 2, band_lower) < 2)   // Buffer 2 = Lower Band
     {
      Print("Error copying indicator buffers.");
      return;
     }

   double close_price = iClose(_Symbol, _Period, 1);

   // 9. Signal Evaluation
   bool buy_signal  = false;
   bool sell_signal = false;

   // Strategy 1: Trend Following (EMA Crossover + RSI Direction)
   bool trend_buy  = (fast_ema[0] > slow_ema[0]) && (rsi[0] > 50.0);
   bool trend_sell = (fast_ema[0] < slow_ema[0]) && (rsi[0] < 50.0);

   // Strategy 2: Mean Reversion (Bollinger Bands Rebound + RSI Extreme)
   bool mean_buy  = (close_price <= band_lower[0]) && (rsi[0] <= InpRSI_Oversold);
   bool mean_sell = (close_price >= band_upper[0]) && (rsi[0] >= InpRSI_Overbought);

   if(InpStrategyMode == STRATEGY_TREND_FOLLOWING)
     {
      // Trigger on EMA Crossover in trend direction
      buy_signal  = trend_buy && (fast_ema[1] <= slow_ema[1]);
      sell_signal = trend_sell && (fast_ema[1] >= slow_ema[1]);
     }
   else if(InpStrategyMode == STRATEGY_MEAN_REVERSION)
     {
      buy_signal  = mean_buy;
      sell_signal = mean_sell;
     }
   else if(InpStrategyMode == STRATEGY_CONFLUENCE)
     {
      // Confluence: Trend is bullish and price pulled back to lower band/oversold RSI
      buy_signal  = (fast_ema[0] > slow_ema[0]) && mean_buy;
      sell_signal = (fast_ema[0] < slow_ema[0]) && mean_sell;
     }

   // 10. Execute Orders
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   double atr_val = atr[0];
   if(atr_val <= 0) return;

   double sl_distance = atr_val * InpSL_ATR_Mult;
   double tp_distance = atr_val * InpTP_ATR_Mult;

   if(buy_signal)
     {
      double sl = ask - sl_distance;
      double tp = ask + tp_distance;
      double lot = CalculateLotSize(sl_distance / point);

      if(lot > 0)
        {
         m_trade.Buy(lot, _Symbol, ask, sl, tp, "SmartEA Buy");
         Print("BUY Order Executed: Lot=", lot, " SL=", sl, " TP=", tp);
        }
     }
   else if(sell_signal)
     {
      double sl = bid + sl_distance;
      double tp = bid - tp_distance;
      double lot = CalculateLotSize(sl_distance / point);

      if(lot > 0)
        {
         m_trade.Sell(lot, _Symbol, bid, sl, tp, "SmartEA Sell");
         Print("SELL Order Executed: Lot=", lot, " SL=", sl, " TP=", tp);
        }
     }
  }

//+------------------------------------------------------------------+
//| Calculate Dynamic Lot Size based on Account Equity & Risk %      |
//+------------------------------------------------------------------+
double CalculateLotSize(double sl_distance_points)
  {
   if(sl_distance_points <= 0) return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   double equity     = AccountInfoDouble(ACCOUNT_EQUITY);
   double risk_amount = equity * (InpRiskPercent / 100.0);

   double tick_size  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double point      = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(tick_size <= 0 || tick_value <= 0 || point <= 0) return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   double point_value = (tick_value / tick_size) * point;
   if(point_value <= 0) return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   double raw_lot = risk_amount / (sl_distance_points * point_value);

   double min_lot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   double lot = MathFloor(raw_lot / step_lot) * step_lot;

   if(lot < min_lot) lot = min_lot;
   if(lot > max_lot) lot = max_lot;

   return NormalizeDouble(lot, 2);
  }

//+------------------------------------------------------------------+
//| Trailing Stop & Break-Even Position Management                   |
//+------------------------------------------------------------------+
void ManagePositions()
  {
   double atr[1];
   if(CopyBuffer(m_handle_atr, 0, 0, 1, atr) < 1) return;
   double atr_val = atr[0];
   double point   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

      ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      double current_sl = PositionGetDouble(POSITION_SL);
      double current_tp = PositionGetDouble(POSITION_TP);
      double ask        = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid        = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      double sl_distance_points = MathAbs(open_price - current_sl) / point;

      // 1. Break-Even Logic
      if(InpUseBreakEven && current_sl != open_price)
        {
         double be_trigger_distance = sl_distance_points * InpBreakEvenR_Mult * point;

         if(pos_type == POSITION_TYPE_BUY)
           {
            if(bid - open_price >= be_trigger_distance && current_sl < open_price)
              {
               m_trade.PositionModify(ticket, open_price + (2 * point), current_tp);
               Print("Position #", ticket, " Moved to Break-Even");
               continue;
              }
           }
         else if(pos_type == POSITION_TYPE_SELL)
           {
            if(open_price - ask >= be_trigger_distance && (current_sl > open_price || current_sl == 0))
              {
               m_trade.PositionModify(ticket, open_price - (2 * point), current_tp);
               Print("Position #", ticket, " Moved to Break-Even");
               continue;
              }
           }
        }

      // 2. Dynamic Trailing Stop Logic
      if(InpUseTrailingStop)
        {
         double trailing_distance = atr_val * InpTrailingATR_Mult;

         if(pos_type == POSITION_TYPE_BUY)
           {
            double new_sl = NormalizeDouble(bid - trailing_distance, _Digits);
            if(new_sl > current_sl + (point * 5))
              {
               m_trade.PositionModify(ticket, new_sl, current_tp);
              }
           }
         else if(pos_type == POSITION_TYPE_SELL)
           {
            double new_sl = NormalizeDouble(ask + trailing_distance, _Digits);
            if(current_sl == 0 || new_sl < current_sl - (point * 5))
              {
               m_trade.PositionModify(ticket, new_sl, current_tp);
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Count Current Symbol & Magic Number Open Positions              |
//+------------------------------------------------------------------+
int CountOpenPositions()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         count++;
     }
   return count;
  }

//+------------------------------------------------------------------+
//| Get Current Symbol Spread in Pips                                |
//+------------------------------------------------------------------+
double GetCurrentSpreadPips()
  {
   double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits   = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   double pip_factor = (digits == 3 || digits == 5) ? 10.0 : 1.0;
   return ((ask - bid) / point) / pip_factor;
  }

//+------------------------------------------------------------------+
//| Render Real-Time On-Chart Dashboard                              |
//+------------------------------------------------------------------+
void UpdateDashboard(string status_msg)
  {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double profit  = AccountInfoDouble(ACCOUNT_PROFIT);
   double spread  = GetCurrentSpreadPips();

   string text = "===========================================\n";
   text += "      SMART MULTI-STRATEGY MT5 EA           \n";
   text += "===========================================\n";
   text += " Status            : " + status_msg + "\n";
   text += " Strategy Mode     : " + EnumToString(InpStrategyMode) + "\n";
   text += " Symbol / TF       : " + _Symbol + " / " + EnumToString(_Period) + "\n";
   text += " Account Balance   : $" + DoubleToString(balance, 2) + "\n";
   text += " Account Equity    : $" + DoubleToString(equity, 2) + "\n";
   text += " Open Floating P/L : $" + DoubleToString(profit, 2) + "\n";
   text += " Current Spread    : " + DoubleToString(spread, 1) + " pips\n";
   text += " Risk Per Trade    : " + DoubleToString(InpRiskPercent, 1) + "%\n";
   text += " Active Positions  : " + IntegerToString(CountOpenPositions()) + " / " + IntegerToString(InpMaxOpenPositions) + "\n";
   text += "===========================================";

   Comment(text);
  }
//+------------------------------------------------------------------+
