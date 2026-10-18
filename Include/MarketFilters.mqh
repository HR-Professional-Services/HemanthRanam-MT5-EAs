//+------------------------------------------------------------------+
//|                                                MarketFilters.mqh |
//|                                    Copyright 2026, Hemanth Ranam |
//|                             https://github.com/HR-Professional-Services |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Hemanth Ranam"
#property link      "https://github.com/HR-Professional-Services/HemanthRanam-MT5-EAs"
#property version   "2.00"

#include <Trade\SymbolInfo.mqh>

//+------------------------------------------------------------------+
//| Session & Market Quality Filter Class                            |
//+------------------------------------------------------------------+
class CMarketFilters
{
private:
   bool              m_enableSessionFilter;
   int               m_brokerGMTOffset;        // Broker GMT offset (e.g. +2 or +3)
   bool              m_tradeAsian;
   bool              m_tradeLondon;
   bool              m_tradeNewYork;
   bool              m_enableRolloverBlackout; // Avoid high-spread broker rollover (21:55 - 22:15 GMT)
   int               m_minSignalIntervalMinutes;
   
   CSymbolInfo       m_symInfo;

   int               TimeToMinutes(const int hour, const int min) const { return (hour * 60) + min; }

public:
                     CMarketFilters();
                    ~CMarketFilters() {}

   // Setup
   void              Init(const bool enableSessionFilter = true,
                          const int brokerGMTOffset = 0,
                          const bool tradeAsian = false,
                          const bool tradeLondon = true,
                          const bool tradeNewYork = true,
                          const bool enableRolloverBlackout = true,
                          const int minSignalInterval = 30);

   // Filter Checks
   bool              IsSessionAllowed(string &reason);
   bool              IsRolloverActive() const;
   bool              IsVolatilitySufficient(const string symbol, const ENUM_TIMEFRAMES tf, const double minATRPoints);
   bool              IsCooldownSatisfied(const datetime lastTradeTime) const;
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMarketFilters::CMarketFilters() :
   m_enableSessionFilter(true),
   m_brokerGMTOffset(0),
   m_tradeAsian(false),
   m_tradeLondon(true),
   m_tradeNewYork(true),
   m_enableRolloverBlackout(true),
   m_minSignalIntervalMinutes(30)
{
}

//+------------------------------------------------------------------+
//| Initialize Filter Settings                                       |
//+------------------------------------------------------------------+
void CMarketFilters::Init(const bool enableSessionFilter,
                          const int brokerGMTOffset,
                          const bool tradeAsian,
                          const bool tradeLondon,
                          const bool tradeNewYork,
                          const bool enableRolloverBlackout,
                          const int minSignalInterval)
{
   m_enableSessionFilter      = enableSessionFilter;
   m_brokerGMTOffset          = brokerGMTOffset;
   m_tradeAsian               = tradeAsian;
   m_tradeLondon              = tradeLondon;
   m_tradeNewYork             = tradeNewYork;
   m_enableRolloverBlackout   = enableRolloverBlackout;
   m_minSignalIntervalMinutes = minSignalInterval;
}

//+------------------------------------------------------------------+
//| Check if Current Time Falls Within Allowed Trading Sessions      |
//+------------------------------------------------------------------+
bool CMarketFilters::IsSessionAllowed(string &reason)
{
   if(!m_enableSessionFilter)
      return true;

   datetime serverTime = TimeCurrent();
   datetime gmtTime    = serverTime - (m_brokerGMTOffset * 3600);
   
   MqlDateTime dt;
   TimeToStruct(gmtTime, dt);
   
   // Weekend Check
   if(dt.day_of_week == 0 || (dt.day_of_week == 5 && dt.hour >= 21) || dt.day_of_week == 6)
   {
      reason = "Weekend Market Closure";
      return false;
   }
   
   // Rollover Blackout Check (21:55 - 22:15 GMT)
   if(m_enableRolloverBlackout)
   {
      int currentMin = TimeToMinutes(dt.hour, dt.min);
      int rolloverStart = TimeToMinutes(21, 55);
      int rolloverEnd   = TimeToMinutes(22, 15);
      if(currentMin >= rolloverStart && currentMin <= rolloverEnd)
      {
         reason = "Rollover Spread Expansion Blackout (21:55 - 22:15 GMT)";
         return false;
      }
   }
   
   // Session Hour Ranges in GMT
   // Asian:    00:00 - 08:00 GMT
   // London:   07:00 - 16:00 GMT
   // New York: 13:00 - 21:30 GMT
   bool inAsian    = (dt.hour >= 0 && dt.hour < 8);
   bool inLondon   = (dt.hour >= 7 && dt.hour < 16);
   bool inNewYork  = (dt.hour >= 13 && dt.hour < 21) || (dt.hour == 21 && dt.min <= 30);
   
   bool sessionValid = false;
   if(m_tradeAsian && inAsian)     sessionValid = true;
   if(m_tradeLondon && inLondon)   sessionValid = true;
   if(m_tradeNewYork && inNewYork) sessionValid = true;
   
   if(!sessionValid)
   {
      reason = StringFormat("Current GMT Time %02d:%02d outside enabled sessions (Asian:%d, London:%d, NY:%d)",
                            dt.hour, dt.min, m_tradeAsian, m_tradeLondon, m_tradeNewYork);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check Rollover Status                                            |
//+------------------------------------------------------------------+
bool CMarketFilters::IsRolloverActive() const
{
   datetime gmtTime = TimeCurrent() - (m_brokerGMTOffset * 3600);
   MqlDateTime dt;
   TimeToStruct(gmtTime, dt);
   int currentMin = (dt.hour * 60) + dt.min;
   return (currentMin >= (21 * 60 + 55) && currentMin <= (22 * 60 + 15));
}

//+------------------------------------------------------------------+
//| Check Volatility Sufficiency Using ATR                           |
//+------------------------------------------------------------------+
bool CMarketFilters::IsVolatilitySufficient(const string symbol, const ENUM_TIMEFRAMES tf, const double minATRPoints)
{
   if(minATRPoints <= 0.0)
      return true;
      
   int atrHandle = iATR(symbol, tf, 14);
   if(atrHandle == INVALID_HANDLE)
      return true;
      
   double atrBuffer[1];
   if(CopyBuffer(atrHandle, 0, 1, 1, atrBuffer) <= 0)
   {
      IndicatorRelease(atrHandle);
      return true;
   }
   
   IndicatorRelease(atrHandle);
   
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return true;
      
   double atrPoints = atrBuffer[0] / point;
   return (atrPoints >= minATRPoints);
}

//+------------------------------------------------------------------+
//| Prevent Rapid Consecutive Triggers in Same Move                  |
//+------------------------------------------------------------------+
bool CMarketFilters::IsCooldownSatisfied(const datetime lastTradeTime) const
{
   if(lastTradeTime == 0)
      return true;
   datetime elapsed = TimeCurrent() - lastTradeTime;
   return (elapsed >= (m_minSignalIntervalMinutes * 60));
}
