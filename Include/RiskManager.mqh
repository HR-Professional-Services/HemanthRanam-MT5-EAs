//+------------------------------------------------------------------+
//|                                                  RiskManager.mqh |
//|                                    Copyright 2026, Hemanth Ranam |
//|                             https://github.com/HR-Professional-Services |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Hemanth Ranam"
#property link      "https://github.com/HR-Professional-Services/HemanthRanam-MT5-EAs"
#property version   "2.00"

#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\PositionInfo.mqh>

//+------------------------------------------------------------------+
//| Risk Management Settings & Logic Class                           |
//+------------------------------------------------------------------+
class CRiskManager
{
private:
   double            m_riskPercent;              // Risk % per trade (Default 0.5%)
   double            m_maxDailyDrawdownPercent;  // Daily drawdown limit (Default 2.0%)
   double            m_maxPortfolioRiskPercent;  // Aggregate open risk limit (Default 1.5%)
   int               m_maxTotalPositions;        // Max concurrent positions portfolio-wide
   int               m_maxPositionsPerSymbol;    // Max concurrent positions per symbol
   int               m_consecutiveLossCooldown;  // Cooldown minutes after max consecutive losses
   int               m_maxConsecutiveLosses;     // Max allowable consecutive losses
   
   double            m_dailyStartEquity;         // Baseline equity at start of trading day
   datetime          m_lastResetDay;             // Date of last daily reset
   int               m_currentConsecutiveLosses; // Current streak of losing trades today
   datetime          m_cooldownUntil;            // Timestamp when cooldown expires
   bool              m_emergencyStop;            // Manual or automatic kill switch
   
   CSymbolInfo       m_symInfo;
   CAccountInfo      m_accInfo;
   CPositionInfo     m_posInfo;

public:
                     CRiskManager();
                    ~CRiskManager() {}

   // Initialization
   void              Init(const double riskPercent = 0.5,
                          const double maxDailyDD = 2.0,
                          const double maxPortfolioRisk = 1.5,
                          const int maxTotalPos = 5,
                          const int maxPosPerSym = 1,
                          const int maxConsecLoss = 3,
                          const int cooldownMin = 60);

   // Daily baseline maintenance
   void              CheckDailyReset();
   
   // Pre-Trade Validation Guards
   bool              CanOpenNewTrade(const string symbol, string &rejectReason);
   
   // Position Sizing
   double            CalculateLotSize(const string symbol, const double entryPrice, const double stopLossPrice);
   double            NormalizeVolume(const string symbol, const double rawLot);
   
   // Trade Result Feedback
   void              OnTradeClosed(const double netProfit);
   
   // Risk Telemetry
   double            GetDailyDrawdownPercent() const;
   double            GetPortfolioOpenRiskPercent();
   int               GetTotalOpenPositions();
   int               GetSymbolOpenPositions(const string symbol);
   bool              IsDailyLimitReached() const;
   bool              IsCooldownActive() const;
   
   // Emergency Controls
   void              SetEmergencyStop(const bool stopState) { m_emergencyStop = stopState; }
   bool              GetEmergencyStop() const { return m_emergencyStop; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CRiskManager::CRiskManager() :
   m_riskPercent(0.5),
   m_maxDailyDrawdownPercent(2.0),
   m_maxPortfolioRiskPercent(1.5),
   m_maxTotalPositions(5),
   m_maxPositionsPerSymbol(1),
   m_consecutiveLossCooldown(60),
   m_maxConsecutiveLosses(3),
   m_dailyStartEquity(0.0),
   m_lastResetDay(0),
   m_currentConsecutiveLosses(0),
   m_cooldownUntil(0),
   m_emergencyStop(false)
{
}

//+------------------------------------------------------------------+
//| Initialize Risk Parameters                                       |
//+------------------------------------------------------------------+
void CRiskManager::Init(const double riskPercent,
                        const double maxDailyDD,
                        const double maxPortfolioRisk,
                        const int maxTotalPos,
                        const int maxPosPerSym,
                        const int maxConsecLoss,
                        const int cooldownMin)
{
   m_riskPercent = (riskPercent > 0.0) ? riskPercent : 0.5;
   m_maxDailyDrawdownPercent = (maxDailyDD > 0.0) ? maxDailyDD : 2.0;
   m_maxPortfolioRiskPercent = (maxPortfolioRisk > 0.0) ? maxPortfolioRisk : 1.5;
   m_maxTotalPositions = (maxTotalPos > 0) ? maxTotalPos : 5;
   m_maxPositionsPerSymbol = (maxPosPerSym > 0) ? maxPosPerSym : 1;
   m_maxConsecutiveLosses = (maxConsecLoss > 0) ? maxConsecLoss : 3;
   m_consecutiveLossCooldown = (cooldownMin > 0) ? cooldownMin : 60;
   
   CheckDailyReset();
}

//+------------------------------------------------------------------+
//| Reset Daily Baseline at 00:00 Server Time                        |
//+------------------------------------------------------------------+
void CRiskManager::CheckDailyReset()
{
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   datetime currentDayStart = StructToTime(dt);
   
   if(currentDayStart > m_lastResetDay)
   {
      m_lastResetDay = currentDayStart;
      m_dailyStartEquity = m_accInfo.Equity();
      m_currentConsecutiveLosses = 0;
      m_cooldownUntil = 0;
      PrintFormat("[RiskManager] Daily baseline reset. Starting Equity: %.2f %s", 
                  m_dailyStartEquity, m_accInfo.Currency());
   }
}

//+------------------------------------------------------------------+
//| Check if New Trade is Permitted by Risk Framework               |
//+------------------------------------------------------------------+
bool CRiskManager::CanOpenNewTrade(const string symbol, string &rejectReason)
{
   CheckDailyReset();
   
   // 1. Emergency Kill Switch
   if(m_emergencyStop)
   {
      rejectReason = "Emergency Stop Active";
      return false;
   }
   
   // 2. Cooldown Status
   if(IsCooldownActive())
   {
      rejectReason = StringFormat("Consecutive Loss Cooldown Active until %s", 
                                  TimeToString(m_cooldownUntil, TIME_DATE|TIME_MINUTES));
      return false;
   }
   
   // 3. Daily Drawdown Limit Guard
   if(IsDailyLimitReached())
   {
      rejectReason = StringFormat("Daily Equity Drawdown Limit Breached (Current DD: %.2f%%, Max: %.2f%%)", 
                                  GetDailyDrawdownPercent(), m_maxDailyDrawdownPercent);
      return false;
   }
   
   // 4. Maximum Total Concurrent Positions
   if(GetTotalOpenPositions() >= m_maxTotalPositions)
   {
      rejectReason = StringFormat("Max Portfolio Positions Reached (%d/%d)", 
                                  GetTotalOpenPositions(), m_maxTotalPositions);
      return false;
   }
   
   // 5. Maximum Positions Per Symbol
   if(GetSymbolOpenPositions(symbol) >= m_maxPositionsPerSymbol)
   {
      rejectReason = StringFormat("Max Positions for Symbol '%s' Reached (%d/%d)", 
                                  symbol, GetSymbolOpenPositions(symbol), m_maxPositionsPerSymbol);
      return false;
   }
   
   // 6. Portfolio Open Risk Check
   double currentOpenRisk = GetPortfolioOpenRiskPercent();
   if(currentOpenRisk + m_riskPercent > m_maxPortfolioRiskPercent)
   {
      rejectReason = StringFormat("Portfolio Open Risk Limit Exceeded (Current: %.2f%%, New: %.2f%%, Max: %.2f%%)",
                                  currentOpenRisk, m_riskPercent, m_maxPortfolioRiskPercent);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Calculate Precise Position Sizing from SL Distance & Tick Value  |
//+------------------------------------------------------------------+
double CRiskManager::CalculateLotSize(const string symbol, const double entryPrice, const double stopLossPrice)
{
   if(!m_symInfo.Name(symbol))
      return 0.0;
   m_symInfo.Refresh();
   
   double slDistance = MathAbs(entryPrice - stopLossPrice);
   if(slDistance <= 0.0)
      return 0.0;
      
   double equity = m_accInfo.Equity();
   double riskAmount = equity * (m_riskPercent / 100.0);
   
   double tickSize  = m_symInfo.TickSize();
   double tickValue = m_symInfo.TickValue();
   double point     = m_symInfo.Point();
   
   if(tickSize <= 0.0 || tickValue <= 0.0 || point <= 0.0)
   {
      PrintFormat("[RiskManager] Error reading symbol specifications for '%s'", symbol);
      return 0.0;
   }
   
   // Calculation: riskAmount / (ticksToSL * tickValue)
   double slTicks = slDistance / tickSize;
   double riskPerUnitLot = slTicks * tickValue;
   
   if(riskPerUnitLot <= 0.0)
      return 0.0;
      
   double calculatedLot = riskAmount / riskPerUnitLot;
   double normalizedLot = NormalizeVolume(symbol, calculatedLot);
   
   // Verify maximum allowable risk is not breached by lot rounding up
   double actualRisk = normalizedLot * riskPerUnitLot;
   if(actualRisk > riskAmount * 1.5)
   {
      PrintFormat("[RiskManager] Rejected: Minimum tradable volume %.2f would exceed allowed risk %.2f %s",
                  normalizedLot, riskAmount, m_accInfo.Currency());
      return 0.0;
   }
   
   return normalizedLot;
}

//+------------------------------------------------------------------+
//| Normalize Lot to Broker Steps and Bounds                         |
//+------------------------------------------------------------------+
double CRiskManager::NormalizeVolume(const string symbol, const double rawLot)
{
   if(!m_symInfo.Name(symbol))
      return 0.0;
   m_symInfo.Refresh();
   
   double minLot  = m_symInfo.LotsMin();
   double maxLot  = m_symInfo.LotsMax();
   double lotStep = m_symInfo.LotsStep();
   
   if(lotStep <= 0.0)
      return minLot;
      
   double normalized = MathFloor(rawLot / lotStep) * lotStep;
   
   if(normalized < minLot)
      normalized = minLot;
   if(normalized > maxLot)
      normalized = maxLot;
      
   int digits = 2;
   if(lotStep == 0.1) digits = 1;
   else if(lotStep == 0.01) digits = 2;
   else if(lotStep == 0.001) digits = 3;
   
   return NormalizeDouble(normalized, digits);
}

//+------------------------------------------------------------------+
//| Feedback Handler when Position Closes                            |
//+------------------------------------------------------------------+
void CRiskManager::OnTradeClosed(const double netProfit)
{
   if(netProfit < 0.0)
   {
      m_currentConsecutiveLosses++;
      if(m_currentConsecutiveLosses >= m_maxConsecutiveLosses)
      {
         m_cooldownUntil = TimeCurrent() + (m_consecutiveLossCooldown * 60);
         PrintFormat("[RiskManager] %d consecutive losses hit. Cooling down until %s.",
                     m_currentConsecutiveLosses, TimeToString(m_cooldownUntil, TIME_DATE|TIME_MINUTES));
      }
   }
   else if(netProfit > 0.0)
   {
      m_currentConsecutiveLosses = 0;
   }
}

//+------------------------------------------------------------------+
//| Get Current Daily Equity Drawdown %                              |
//+------------------------------------------------------------------+
double CRiskManager::GetDailyDrawdownPercent() const
{
   if(m_dailyStartEquity <= 0.0)
      return 0.0;
      
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(currentEquity >= m_dailyStartEquity)
      return 0.0;
      
   return ((m_dailyStartEquity - currentEquity) / m_dailyStartEquity) * 100.0;
}

//+------------------------------------------------------------------+
//| Check if Daily Drawdown Limit Breached                           |
//+------------------------------------------------------------------+
bool CRiskManager::IsDailyLimitReached() const
{
   return (GetDailyDrawdownPercent() >= m_maxDailyDrawdownPercent);
}

//+------------------------------------------------------------------+
//| Check if Cooldown is Active                                      |
//+------------------------------------------------------------------+
bool CRiskManager::IsCooldownActive() const
{
   return (TimeCurrent() < m_cooldownUntil);
}

//+------------------------------------------------------------------+
//| Count Total Open Positions Across All Symbols                    |
//+------------------------------------------------------------------+
int CRiskManager::GetTotalOpenPositions()
{
   return PositionsTotal();
}

//+------------------------------------------------------------------+
//| Count Open Positions for a Specific Symbol                       |
//+------------------------------------------------------------------+
int CRiskManager::GetSymbolOpenPositions(const string symbol)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_posInfo.SelectByIndex(i))
      {
         if(m_posInfo.Symbol() == symbol)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Calculate Aggregate Open Risk % Across All Positions             |
//+------------------------------------------------------------------+
double CRiskManager::GetPortfolioOpenRiskPercent()
{
   double totalRiskCurrency = 0.0;
   double equity = m_accInfo.Equity();
   if(equity <= 0.0)
      return 0.0;
      
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_posInfo.SelectByIndex(i))
      {
         string sym = m_posInfo.Symbol();
         double sl = m_posInfo.StopLoss();
         double openPrice = m_posInfo.PriceOpen();
         double volume = m_posInfo.Volume();
         
         if(sl > 0.0 && m_symInfo.Name(sym))
         {
            m_symInfo.Refresh();
            double slDistance = MathAbs(openPrice - sl);
            double tickSize = m_symInfo.TickSize();
            double tickValue = m_symInfo.TickValue();
            if(tickSize > 0.0 && tickValue > 0.0)
            {
               double posRisk = (slDistance / tickSize) * tickValue * volume;
               totalRiskCurrency += posRisk;
            }
         }
      }
   }
   
   return (totalRiskCurrency / equity) * 100.0;
}
