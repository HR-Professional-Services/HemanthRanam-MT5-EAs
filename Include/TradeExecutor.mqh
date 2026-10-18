//+------------------------------------------------------------------+
//|                                                TradeExecutor.mqh |
//|                                    Copyright 2026, Hemanth Ranam |
//|                             https://github.com/HR-Professional-Services |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Hemanth Ranam"
#property link      "https://github.com/HR-Professional-Services/HemanthRanam-MT5-EAs"
#property version   "2.00"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>

//+------------------------------------------------------------------+
//| Order Execution and Position Lifecycle Management                |
//+------------------------------------------------------------------+
class CTradeExecutor
{
private:
   CTrade            m_trade;             // Standard MQL5 Trade Class
   CPositionInfo     m_posInfo;           // Position selection & telemetry
   CSymbolInfo       m_symInfo;           // Symbol specifications
   ulong             m_magicNumber;       // Unique EA Magic Identifier
   ulong             m_slippageDeviation; // Maximum permitted slippage points
   bool              m_useBreakEven;      // Automatic break-even activation flag
   double            m_breakEvenTriggerR; // Reward in R to trigger break-even (Default 1.0R)
   double            m_breakEvenBufferPts;// Points beyond entry to cover spread/commission
   bool              m_useTrailingStop;   // Dynamic trailing stop flag
   double            m_trailingStopPts;   // Trailing distance in points
   double            m_trailingStepPts;   // Trailing increment step in points

   string            FormatRetcode(const uint retcode);

public:
                     CTradeExecutor();
                    ~CTradeExecutor() {}

   // Setup
   void              Init(const ulong magicNumber,
                          const ulong slippagePoints = 10,
                          const bool useBE = true,
                          const double beTriggerR = 1.0,
                          const double beBufferPts = 5.0,
                          const bool useTrailing = false,
                          const double trailPts = 50.0,
                          const double trailStepPts = 10.0);

   // Order Placement (Hedging & Netting Safe)
   ulong             ExecuteBuy(const string symbol,
                                const double volume,
                                const double stopLossPrice,
                                const double takeProfitPrice,
                                const string comment = "");
                                
   ulong             ExecuteSell(const string symbol,
                                 const double volume,
                                 const double stopLossPrice,
                                 const double takeProfitPrice,
                                 const string comment = "");

   // Position Modification
   bool              ModifyPosition(const ulong ticket, const double newSL, const double newTP);
   bool              ClosePositionTicket(const ulong ticket);
   bool              ClosePartial(const ulong ticket, const double volumeToClose);

   // Active Trade Management (Break-even & Trailing Stop)
   void              ManageOpenPositions(const string symbol);
   
   // Telemetry
   ulong             GetMagicNumber() const { return m_magicNumber; }
   int               GetPositionsCount(const string symbol);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTradeExecutor::CTradeExecutor() :
   m_magicNumber(1001),
   m_slippageDeviation(10),
   m_useBreakEven(true),
   m_breakEvenTriggerR(1.0),
   m_breakEvenBufferPts(5.0),
   m_useTrailingStop(false),
   m_trailingStopPts(50.0),
   m_trailingStepPts(10.0)
{
}

//+------------------------------------------------------------------+
//| Initialize Trade Execution Parameters                            |
//+------------------------------------------------------------------+
void CTradeExecutor::Init(const ulong magicNumber,
                          const ulong slippagePoints,
                          const bool useBE,
                          const double beTriggerR,
                          const double beBufferPts,
                          const bool useTrailing,
                          const double trailPts,
                          const double trailStepPts)
{
   m_magicNumber        = magicNumber;
   m_slippageDeviation  = slippagePoints;
   m_useBreakEven       = useBE;
   m_breakEvenTriggerR  = beTriggerR;
   m_breakEvenBufferPts = beBufferPts;
   m_useTrailingStop    = useTrailing;
   m_trailingStopPts    = trailPts;
   m_trailingStepPts    = trailStepPts;

   m_trade.SetExpertMagicNumber(m_magicNumber);
   m_trade.SetDeviationInPoints(m_slippageDeviation);
   m_trade.SetTypeFillingBySymbol(Symbol());
   m_trade.SetMarginMode();
}

//+------------------------------------------------------------------+
//| Execute BUY Order with Strict SL & TP                            |
//+------------------------------------------------------------------+
ulong CTradeExecutor::ExecuteBuy(const string symbol,
                                 const double volume,
                                 const double stopLossPrice,
                                 const double takeProfitPrice,
                                 const string comment)
{
   if(!m_symInfo.Name(symbol))
      return 0;
   m_symInfo.RefreshRates();
   
   double ask = m_symInfo.Ask();
   int digits = m_symInfo.Digits();
   
   double normalizedSL = NormalizeDouble(stopLossPrice, digits);
   double normalizedTP = NormalizeDouble(takeProfitPrice, digits);
   
   // Mandatory Stop Loss Verification
   if(normalizedSL <= 0.0 || normalizedSL >= ask)
   {
      PrintFormat("[TradeExecutor] Rejected BUY on %s: Invalid Stop Loss %.5f (Ask: %.5f)",
                  symbol, normalizedSL, ask);
      return 0;
   }
   
   m_trade.SetExpertMagicNumber(m_magicNumber);
   m_trade.SetTypeFillingBySymbol(symbol);
   
   if(m_trade.Buy(volume, symbol, ask, normalizedSL, normalizedTP, comment))
   {
      ulong orderTicket = m_trade.ResultOrder();
      PrintFormat("[TradeExecutor] BUY SUCCESS #%I64u on %s | Vol: %.2f | Ask: %.5f | SL: %.5f | TP: %.5f",
                  orderTicket, symbol, volume, ask, normalizedSL, normalizedTP);
      return orderTicket;
   }
   else
   {
      PrintFormat("[TradeExecutor] BUY FAILED on %s: Retcode %u (%s)",
                  symbol, m_trade.ResultRetcode(), FormatRetcode(m_trade.ResultRetcode()));
      return 0;
   }
}

//+------------------------------------------------------------------+
//| Execute SELL Order with Strict SL & TP                           |
//+------------------------------------------------------------------+
ulong CTradeExecutor::ExecuteSell(const string symbol,
                                  const double volume,
                                  const double stopLossPrice,
                                  const double takeProfitPrice,
                                  const string comment)
{
   if(!m_symInfo.Name(symbol))
      return 0;
   m_symInfo.RefreshRates();
   
   double bid = m_symInfo.Bid();
   int digits = m_symInfo.Digits();
   
   double normalizedSL = NormalizeDouble(stopLossPrice, digits);
   double normalizedTP = NormalizeDouble(takeProfitPrice, digits);
   
   // Mandatory Stop Loss Verification
   if(normalizedSL <= 0.0 || normalizedSL <= bid)
   {
      PrintFormat("[TradeExecutor] Rejected SELL on %s: Invalid Stop Loss %.5f (Bid: %.5f)",
                  symbol, normalizedSL, bid);
      return 0;
   }
   
   m_trade.SetExpertMagicNumber(m_magicNumber);
   m_trade.SetTypeFillingBySymbol(symbol);
   
   if(m_trade.Sell(volume, symbol, bid, normalizedSL, normalizedTP, comment))
   {
      ulong orderTicket = m_trade.ResultOrder();
      PrintFormat("[TradeExecutor] SELL SUCCESS #%I64u on %s | Vol: %.2f | Bid: %.5f | SL: %.5f | TP: %.5f",
                  orderTicket, symbol, volume, bid, normalizedSL, normalizedTP);
      return orderTicket;
   }
   else
   {
      PrintFormat("[TradeExecutor] SELL FAILED on %s: Retcode %u (%s)",
                  symbol, m_trade.ResultRetcode(), FormatRetcode(m_trade.ResultRetcode()));
      return 0;
   }
}

//+------------------------------------------------------------------+
//| Modify Existing Position SL & TP                                 |
//+------------------------------------------------------------------+
bool CTradeExecutor::ModifyPosition(const ulong ticket, const double newSL, const double newTP)
{
   if(!m_posInfo.SelectByTicket(ticket))
      return false;
      
   string sym = m_posInfo.Symbol();
   m_symInfo.Name(sym);
   int digits = m_symInfo.Digits();
   
   double normSL = NormalizeDouble(newSL, digits);
   double normTP = NormalizeDouble(newTP, digits);
   
   if(MathAbs(normSL - m_posInfo.StopLoss()) < m_symInfo.Point() &&
      MathAbs(normTP - m_posInfo.TakeProfit()) < m_symInfo.Point())
   {
      return true; // Already set
   }
   
   return m_trade.PositionModify(ticket, normSL, normTP);
}

//+------------------------------------------------------------------+
//| Close Position Completely                                        |
//+------------------------------------------------------------------+
bool CTradeExecutor::ClosePositionTicket(const ulong ticket)
{
   return m_trade.PositionClose(ticket);
}

//+------------------------------------------------------------------+
//| Close Partial Volume of Position                                 |
//+------------------------------------------------------------------+
bool CTradeExecutor::ClosePartial(const ulong ticket, const double volumeToClose)
{
   return m_trade.PositionClosePartial(ticket, volumeToClose);
}

//+------------------------------------------------------------------+
//| Active Trade Management: Break-even at +1R and Trailing Stop     |
//+------------------------------------------------------------------+
void CTradeExecutor::ManageOpenPositions(const string symbol)
{
   if(!m_useBreakEven && !m_useTrailingStop)
      return;
      
   if(!m_symInfo.Name(symbol))
      return;
   m_symInfo.RefreshRates();
   
   double point = m_symInfo.Point();
   int digits = m_symInfo.Digits();
   double bid = m_symInfo.Bid();
   double ask = m_symInfo.Ask();
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_posInfo.SelectByIndex(i))
      {
         if(m_posInfo.Magic() != m_magicNumber || m_posInfo.Symbol() != symbol)
            continue;
            
         ulong ticket = m_posInfo.Ticket();
         ENUM_POSITION_TYPE posType = m_posInfo.PositionType();
         double openPrice = m_posInfo.PriceOpen();
         double currentSL = m_posInfo.StopLoss();
         double currentTP = m_posInfo.TakeProfit();
         
         // 1. Break-Even at +1R
         if(m_useBreakEven && currentSL > 0.0)
         {
            double initialRiskDistance = MathAbs(openPrice - currentSL);
            if(initialRiskDistance > 0.0)
            {
               double targetTriggerDistance = initialRiskDistance * m_breakEvenTriggerR;
               
               if(posType == POSITION_TYPE_BUY)
               {
                  double buffer = m_breakEvenBufferPts * point;
                  double beLevel = openPrice + buffer;
                  if(bid >= openPrice + targetTriggerDistance && currentSL < openPrice)
                  {
                     PrintFormat("[TradeExecutor] Break-even triggered for BUY #%I64u on %s (Current SL: %.5f -> New SL: %.5f)",
                                 ticket, symbol, currentSL, beLevel);
                     ModifyPosition(ticket, beLevel, currentTP);
                     currentSL = beLevel;
                  }
               }
               else if(posType == POSITION_TYPE_SELL)
               {
                  double buffer = m_breakEvenBufferPts * point;
                  double beLevel = openPrice - buffer;
                  if(ask <= openPrice - targetTriggerDistance && (currentSL > openPrice || currentSL == 0.0))
                  {
                     PrintFormat("[TradeExecutor] Break-even triggered for SELL #%I64u on %s (Current SL: %.5f -> New SL: %.5f)",
                                 ticket, symbol, currentSL, beLevel);
                     ModifyPosition(ticket, beLevel, currentTP);
                     currentSL = beLevel;
                  }
               }
            }
         }
         
         // 2. Trailing Stop
         if(m_useTrailingStop)
         {
            double trailDist = m_trailingStopPts * point;
            double trailStep = m_trailingStepPts * point;
            
            if(posType == POSITION_TYPE_BUY)
            {
               if(bid - openPrice > trailDist)
               {
                  double newSL = bid - trailDist;
                  if(newSL - currentSL >= trailStep)
                  {
                     ModifyPosition(ticket, newSL, currentTP);
                  }
               }
            }
            else if(posType == POSITION_TYPE_SELL)
            {
               if(openPrice - ask > trailDist)
               {
                  double newSL = ask + trailDist;
                  if(currentSL == 0.0 || currentSL - newSL >= trailStep)
                  {
                     ModifyPosition(ticket, newSL, currentTP);
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Count Open Positions for Magic and Symbol                        |
//+------------------------------------------------------------------+
int CTradeExecutor::GetPositionsCount(const string symbol)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_posInfo.SelectByIndex(i))
      {
         if(m_posInfo.Magic() == m_magicNumber && m_posInfo.Symbol() == symbol)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Human Readable Retcode Translator                                |
//+------------------------------------------------------------------+
string CTradeExecutor::FormatRetcode(const uint retcode)
{
   switch(retcode)
   {
      case TRADE_RETCODE_DONE:           return "Request completed";
      case TRADE_RETCODE_REQUOTE:        return "Requote";
      case TRADE_RETCODE_REJECT:         return "Request rejected";
      case TRADE_RETCODE_CANCEL:         return "Request cancelled";
      case TRADE_RETCODE_PLACED:         return "Order placed";
      case TRADE_RETCODE_ERROR:          return "Common trade error";
      case TRADE_RETCODE_TIMEOUT:        return "Request timed out";
      case TRADE_RETCODE_INVALID_STOPS:  return "Invalid Stop Loss or Take Profit";
      case TRADE_RETCODE_INVALID_VOLUME: return "Invalid trade volume";
      case TRADE_RETCODE_INVALID_PRICE:  return "Invalid execution price";
      case TRADE_RETCODE_NO_MONEY:       return "Insufficient margin funds";
      case TRADE_RETCODE_MARKET_CLOSED:  return "Market is closed";
      case TRADE_RETCODE_TOO_MANY_REQUESTS: return "Too many requests";
      case TRADE_RETCODE_PRICE_CHANGED:  return "Price changed during execution";
      case TRADE_RETCODE_CONNECTION:     return "No connection to trade server";
      default:                           return "Unknown server retcode";
   }
}
