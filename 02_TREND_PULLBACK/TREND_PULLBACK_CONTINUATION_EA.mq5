//+------------------------------------------------------------------+
//|                                TREND_PULLBACK_CONTINUATION_EA.mq5|
//|                                    Copyright 2026, Hemanth Ranam |
//|                             https://github.com/HR-Professional-Services |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, Hemanth Ranam"
#property link        "https://github.com/HR-Professional-Services/HemanthRanam-MT5-EAs"
#property version     "2.00"
#property description "Trend Pullback and Continuation Quantitative System."
#property description "Enforces macro 200 EMA regime bias with tactical 9/21 EMA corridor pullbacks."

// Include Core Architectural Modules

//====================================================================
// STANDALONE ARCHITECTURE: CORE EMBEDDED MODULES
//====================================================================
#include <Trade/Trade.mqh>
#include <Trade/SymbolInfo.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/AccountInfo.mqh>

//+------------------------------------------------------------------+
//|                                                       Logger.mqh |
//|                                    Copyright 2026, Hemanth Ranam |
//|                             https://github.com/HR-Professional-Services |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Diagnostic Logging and Notification Handler                      |
//+------------------------------------------------------------------+
class CLogger
{
private:
   string            m_eaName;
   bool              m_enableTerminalLog;
   bool              m_enableAlertPopup;
   bool              m_enablePushNotify;

public:
                     CLogger();
                    ~CLogger() {}

   void              Init(const string eaName,
                          const bool terminalLog = true,
                          const bool alertPopup = false,
                          const bool pushNotify = false);

   void              Info(const string message);
   void              Warn(const string message);
   void              Error(const string message);
   void              Signal(const string symbol, const string action, const double price, const double sl, const double tp, const string rationale);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLogger::CLogger() :
   m_eaName("MT5_EA"),
   m_enableTerminalLog(true),
   m_enableAlertPopup(false),
   m_enablePushNotify(false)
{
}

//+------------------------------------------------------------------+
//| Initialize Logger Settings                                       |
//+------------------------------------------------------------------+
void CLogger::Init(const string eaName,
                   const bool terminalLog,
                   const bool alertPopup,
                   const bool pushNotify)
{
   m_eaName            = eaName;
   m_enableTerminalLog = terminalLog;
   m_enableAlertPopup  = alertPopup;
   m_enablePushNotify  = pushNotify;
}

//+------------------------------------------------------------------+
//| Log Informational Message                                        |
//+------------------------------------------------------------------+
void CLogger::Info(const string message)
{
   if(m_enableTerminalLog)
      PrintFormat("[%s][INFO][%s] %s", m_eaName, TimeToString(TimeCurrent(), TIME_SECONDS), message);
}

//+------------------------------------------------------------------+
//| Log Warning Message                                              |
//+------------------------------------------------------------------+
void CLogger::Warn(const string message)
{
   if(m_enableTerminalLog)
      PrintFormat("[%s][WARN][%s] %s", m_eaName, TimeToString(TimeCurrent(), TIME_SECONDS), message);
      
   if(m_enableAlertPopup)
      Alert(StringFormat("[%s][WARN] %s", m_eaName, message));
}

//+------------------------------------------------------------------+
//| Log Error Message                                                |
//+------------------------------------------------------------------+
void CLogger::Error(const string message)
{
   PrintFormat("[%s][ERROR][%s] %s", m_eaName, TimeToString(TimeCurrent(), TIME_SECONDS), message);
   
   if(m_enableAlertPopup)
      Alert(StringFormat("[%s][ERROR] %s", m_eaName, message));
}

//+------------------------------------------------------------------+
//| Dispatch Strategy Signal Event                                   |
//+------------------------------------------------------------------+
void CLogger::Signal(const string symbol, const string action, const double price, const double sl, const double tp, const string rationale)
{
   string formatted = StringFormat("[%s] SIGNAL on %s: %s @ %.5f | SL: %.5f | TP: %.5f | Rationale: %s",
                                   m_eaName, symbol, action, price, sl, tp, rationale);
                                   
   Print(formatted);
   
   if(m_enableAlertPopup)
      Alert(formatted);
      
   if(m_enablePushNotify)
      SendNotification(formatted);
}

//+------------------------------------------------------------------+
//|                                                  RiskManager.mqh |
//|                                    Copyright 2026, Hemanth Ranam |
//|                             https://github.com/HR-Professional-Services |
//+------------------------------------------------------------------+


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

//+------------------------------------------------------------------+
//|                                                SymbolScanner.mqh |
//|                                    Copyright 2026, Hemanth Ranam |
//|                             https://github.com/HR-Professional-Services |
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Symbol Context Structure                                         |
//+------------------------------------------------------------------+
struct SymbolContext
{
   string            configuredName;      // Base name requested (e.g. XAUUSD)
   string            resolvedName;        // Actual broker symbol name (e.g. XAUUSDm)
   bool              isValid;             // Whether symbol is verified & tradable
   int               digits;              // Price digits
   double            point;               // Point size
   double            tickSize;            // Minimum price change
   double            tickValue;           // Tick value in account currency
   int               spreadPoints;        // Current spread in points
   datetime          lastScanTime;        // Timestamp of last successful analysis
};

//+------------------------------------------------------------------+
//| Multi-Symbol Radar & Scanner Class                               |
//+------------------------------------------------------------------+
class CSymbolScanner
{
private:
   SymbolContext     m_symbols[];         // List of monitored instruments
   int               m_symbolCount;       // Number of valid instruments
   int               m_maxSpreadPoints;   // Maximum permitted spread points
   CSymbolInfo       m_symInfo;

   // Auto-detect broker specific suffixes (e.g., Exness 'm', 'c', pro, raw)
   string            ResolveBrokerSymbol(const string baseSymbol);

public:
                     CSymbolScanner();
                    ~CSymbolScanner() {}

   // Setup and Symbol List Configuration
   bool              Init(const string symbolListCSV, const int maxSpreadPoints = 50);
   
   // Accessors
   int               GetSymbolCount() const { return m_symbolCount; }
   string            GetSymbol(const int index) const;
   bool              GetContext(const int index, SymbolContext &ctx) const;
   
   // Pre-Scan Filtering & Validation
   bool              RefreshSymbolData(const int index);
   bool              IsTradePermitted(const int index, string &rejectReason);
   
   // Quick Symbol Lookups
   double            GetBid(const string symbol);
   double            GetAsk(const string symbol);
   int               GetSpreadPoints(const string symbol);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSymbolScanner::CSymbolScanner() :
   m_symbolCount(0),
   m_maxSpreadPoints(50)
{
   ArrayResize(m_symbols, 0);
}

//+------------------------------------------------------------------+
//| Auto-Resolve Broker Suffixes (Exness Standard, Pro, Zero)        |
//+------------------------------------------------------------------+
string CSymbolScanner::ResolveBrokerSymbol(const string baseSymbol)
{
   // 1. Direct Match Check
   if(SymbolSelect(baseSymbol, true))
      return baseSymbol;
      
   // Common broker suffixes: Exness ('m', 'c', '_i', '.a'), Pro ('.pro', '.r')
   string commonSuffixes[] = {"m", "c", "_i", ".a", ".pro", ".raw", ".std", "#"};
   for(int i = 0; i < ArraySize(commonSuffixes); i++)
   {
      string candidate = baseSymbol + commonSuffixes[i];
      if(SymbolSelect(candidate, true))
      {
         PrintFormat("[SymbolScanner] Auto-resolved '%s' -> '%s'", baseSymbol, candidate);
         return candidate;
      }
   }
   
   // Alternative mappings (e.g. USOIL -> WTI, US500 -> SPX500)
   if(baseSymbol == "US500")
   {
      string spxCandidates[] = {"SPX500", "US500m", "SP500", "USA500"};
      for(int i = 0; i < ArraySize(spxCandidates); i++)
         if(SymbolSelect(spxCandidates[i], true)) return spxCandidates[i];
   }
   else if(baseSymbol == "US100")
   {
      string ndxCandidates[] = {"NAS100", "USTEC", "US100m", "NAS100m", "USTECm"};
      for(int i = 0; i < ArraySize(ndxCandidates); i++)
         if(SymbolSelect(ndxCandidates[i], true)) return ndxCandidates[i];
   }
   else if(baseSymbol == "USOIL" || baseSymbol == "Oil")
   {
      string oilCandidates[] = {"USOILm", "XTIUSD", "WTI", "Crude", "CL"};
      for(int i = 0; i < ArraySize(oilCandidates); i++)
         if(SymbolSelect(oilCandidates[i], true)) return oilCandidates[i];
   }
   
   return "";
}

//+------------------------------------------------------------------+
//| Initialize Watchlist from CSV String                             |
//+------------------------------------------------------------------+
bool CSymbolScanner::Init(const string symbolListCSV, const int maxSpreadPoints)
{
   m_maxSpreadPoints = maxSpreadPoints;
   m_symbolCount = 0;
   ArrayResize(m_symbols, 0);
   
   string rawSymbols[];
   ushort sep = StringGetCharacter(",", 0);
   int totalSplit = StringSplit(symbolListCSV, sep, rawSymbols);
   
   if(totalSplit <= 0)
   {
      Print("[SymbolScanner] No symbols configured in watchlist.");
      return false;
   }
   
   for(int i = 0; i < totalSplit; i++)
   {
      string trimmed = rawSymbols[i];
      StringTrimLeft(trimmed);
      StringTrimRight(trimmed);
      if(StringLen(trimmed) == 0)
         continue;
         
      string resolved = ResolveBrokerSymbol(trimmed);
      if(StringLen(resolved) > 0)
      {
         int newIdx = ArraySize(m_symbols);
         ArrayResize(m_symbols, newIdx + 1);
         
         m_symbols[newIdx].configuredName = trimmed;
         m_symbols[newIdx].resolvedName   = resolved;
         m_symbols[newIdx].isValid        = true;
         m_symbols[newIdx].lastScanTime   = 0;
         
         // Fetch initial specifications
         m_symInfo.Name(resolved);
         m_symInfo.Refresh();
         m_symbols[newIdx].digits       = m_symInfo.Digits();
         m_symbols[newIdx].point        = m_symInfo.Point();
         m_symbols[newIdx].tickSize     = m_symInfo.TickSize();
         m_symbols[newIdx].tickValue    = m_symInfo.TickValue();
         m_symbols[newIdx].spreadPoints = m_symInfo.Spread();
         
         m_symbolCount++;
         PrintFormat("[SymbolScanner] Registered [%d] %s (Broker: %s, Digits: %d, Spread: %d pts)",
                     m_symbolCount, trimmed, resolved, m_symbols[newIdx].digits, m_symbols[newIdx].spreadPoints);
      }
      else
      {
         PrintFormat("[SymbolScanner] Warning: Configured symbol '%s' not found on current broker account.", trimmed);
      }
   }
   
   PrintFormat("[SymbolScanner] Watchlist ready with %d tradable instruments.", m_symbolCount);
   return (m_symbolCount > 0);
}

//+------------------------------------------------------------------+
//| Get Symbol Resolved Name by Index                                |
//+------------------------------------------------------------------+
string CSymbolScanner::GetSymbol(const int index) const
{
   if(index < 0 || index >= m_symbolCount)
      return "";
   return m_symbols[index].resolvedName;
}

//+------------------------------------------------------------------+
//| Get Full Context by Index                                        |
//+------------------------------------------------------------------+
bool CSymbolScanner::GetContext(const int index, SymbolContext &ctx) const
{
   if(index < 0 || index >= m_symbolCount)
      return false;
   ctx = m_symbols[index];
   return true;
}

//+------------------------------------------------------------------+
//| Refresh Market Rates and Spreads for Symbol                      |
//+------------------------------------------------------------------+
bool CSymbolScanner::RefreshSymbolData(const int index)
{
   if(index < 0 || index >= m_symbolCount)
      return false;
      
   string sym = m_symbols[index].resolvedName;
   if(!m_symInfo.Name(sym))
      return false;
      
   if(!m_symInfo.RefreshRates())
      return false;
      
   m_symbols[index].spreadPoints = m_symInfo.Spread();
   m_symbols[index].lastScanTime = TimeCurrent();
   return true;
}

//+------------------------------------------------------------------+
//| Pre-Trade Spread and Execution Permissions Check                 |
//+------------------------------------------------------------------+
bool CSymbolScanner::IsTradePermitted(const int index, string &rejectReason)
{
   if(index < 0 || index >= m_symbolCount)
   {
      rejectReason = "Invalid Symbol Index";
      return false;
   }
   
   if(!RefreshSymbolData(index))
   {
      rejectReason = "Failed to Refresh Symbol Rates";
      return false;
   }
   
   string sym = m_symbols[index].resolvedName;
   
   // 1. Trade Mode Check
   ENUM_SYMBOL_TRADE_MODE tradeMode = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(sym, SYMBOL_TRADE_MODE);
   if(tradeMode != SYMBOL_TRADE_MODE_FULL)
   {
      rejectReason = StringFormat("Trading not fully permitted on %s (Mode: %d)", sym, tradeMode);
      return false;
   }
   
   // 2. Spread Guard Check
   int currentSpread = m_symbols[index].spreadPoints;
   if(currentSpread > m_maxSpreadPoints)
   {
      rejectReason = StringFormat("Excessive Spread on %s (%d pts > Max %d pts)",
                                  sym, currentSpread, m_maxSpreadPoints);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Quick Rates Accessors                                            |
//+------------------------------------------------------------------+
double CSymbolScanner::GetBid(const string symbol)
{
   return SymbolInfoDouble(symbol, SYMBOL_BID);
}

double CSymbolScanner::GetAsk(const string symbol)
{
   return SymbolInfoDouble(symbol, SYMBOL_ASK);
}

int CSymbolScanner::GetSpreadPoints(const string symbol)
{
   return (int)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
}

//+------------------------------------------------------------------+
//|                                                TradeExecutor.mqh |
//|                                    Copyright 2026, Hemanth Ranam |
//|                             https://github.com/HR-Professional-Services |
//+------------------------------------------------------------------+


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

//+------------------------------------------------------------------+
//|                                                MarketFilters.mqh |
//|                                    Copyright 2026, Hemanth Ranam |
//|                             https://github.com/HR-Professional-Services |
//+------------------------------------------------------------------+


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

//--- Input Groups
input group "=== Watchlist & Multi-Symbol Scanning ==="
input string            InpWatchlist            = "XAUUSD,XAGUSD,US500,US100,USOIL,EURUSD,GBPUSD,USDJPY"; // Multi-Symbol List (CSV)
input int               InpMaxSpreadPoints      = 40;                     // Maximum Permitted Spread (Points)
input int               InpScanTimerSeconds     = 5;                      // Scanner Polling Interval (Seconds)

input group "=== Trend & Pullback Strategy Parameters ==="
input ENUM_TIMEFRAMES   InpExecutionTF          = PERIOD_M15;             // Execution Timeframe
input int               InpFastEMA              = 9;                      // Fast Pullback EMA Period (9)
input int               InpSlowEMA              = 21;                     // Slow Pullback EMA Period (21)
input int               InpMacroEMA             = 200;                    // Macro Structural Baseline EMA (200)
input double            InpRewardToRiskRatio    = 2.2;                    // Minimum Target R:R Ratio (1:2.2)
input int               InpMinPullbackBars      = 2;                      // Minimum Retracement Bars into Corridor

input group "=== Risk Management ==="
input double            InpRiskPercent          = 0.5;                    // Risk Percentage per Trade (Default 0.5%)
input double            InpMaxDailyDrawdown     = 2.0;                    // Max Daily Equity Drawdown Limit (%)
input double            InpMaxPortfolioRisk     = 1.5;                    // Max Aggregate Open Portfolio Risk (%)
input int               InpMaxTotalPositions    = 5;                      // Max Concurrent Positions Total
input int               InpMaxPositionsPerSymbol= 1;                      // Max Concurrent Positions Per Symbol

input group "=== Trade Execution & Protection ==="
input ulong             InpMagicNumber          = 102002;                 // EA Magic Number
input ulong             InpSlippagePoints       = 10;                     // Max Slippage (Points)
input bool              InpEnableBreakEven      = true;                   // Enable Break-Even at +1R
input double            InpBreakEvenTriggerR    = 1.0;                    // Break-Even Trigger (R)
input double            InpBreakEvenBufferPts   = 5.0;                    // Break-Even Buffer (Points)
input bool              InpEnableTrailing       = false;                  // Enable Trailing Stop
input double            InpTrailingStopPts      = 50.0;                   // Trailing Distance (Points)

input group "=== Market Filters & Session Timing ==="
input bool              InpEnableSessionFilter  = true;                   // Enable Session Filter
input int               InpBrokerGMTOffset      = 0;                      // Broker GMT Offset
input bool              InpTradeLondon          = true;                   // Trade London Session
input bool              InpTradeNewYork         = true;                   // Trade New York Session
input bool              InpTradeAsian           = false;                  // Trade Asian Session
input bool              InpRolloverBlackout     = true;                   // Enable Rollover Blackout (21:55-22:15 GMT)

//--- Module Instances
CRiskManager      ExtRisk;
CSymbolScanner    ExtScanner;
CTradeExecutor    ExtTrade;
CMarketFilters    ExtFilter;
CLogger           ExtLog;

datetime          ExtLastBarTimes[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   ExtLog.Init("TREND_PULLBACK_EA", true, false, false);
   ExtLog.Info("Initializing Trend Pullback and Continuation EA...");
   
   if(!ExtScanner.Init(InpWatchlist, InpMaxSpreadPoints))
   {
      ExtLog.Error("Failed to initialize symbol watchlist.");
      return INIT_FAILED;
   }
   
   ExtRisk.Init(InpRiskPercent, InpMaxDailyDrawdown, InpMaxPortfolioRisk, 
                InpMaxTotalPositions, InpMaxPositionsPerSymbol, 3, 60);
                
   ExtTrade.Init(InpMagicNumber, InpSlippagePoints, InpEnableBreakEven, 
                 InpBreakEvenTriggerR, InpBreakEvenBufferPts, 
                 InpEnableTrailing, InpTrailingStopPts, 10.0);
                 
   ExtFilter.Init(InpEnableSessionFilter, InpBrokerGMTOffset, InpTradeAsian, 
                  InpTradeLondon, InpTradeNewYork, InpRolloverBlackout, 30);
                  
   ArrayResize(ExtLastBarTimes, ExtScanner.GetSymbolCount());
   ArrayInitialize(ExtLastBarTimes, 0);

   EventSetTimer(InpScanTimerSeconds);
   
   ExtLog.Info(StringFormat("Initialization complete. Multi-symbol trend scanner active across %d instruments.",
               ExtScanner.GetSymbolCount()));
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   ExtLog.Info(StringFormat("EA Deinitialized. Reason code: %d", reason));
}

//+------------------------------------------------------------------+
//| Periodic Timer Event                                             |
//+------------------------------------------------------------------+
void OnTimer()
{
   string sessionReject = "";
   if(!ExtFilter.IsSessionAllowed(sessionReject))
      return;
      
   ExtRisk.CheckDailyReset();
   
   int totalSymbols = ExtScanner.GetSymbolCount();
   for(int i = 0; i < totalSymbols; i++)
   {
      string sym = ExtScanner.GetSymbol(i);
      ExtTrade.ManageOpenPositions(sym);
      ProcessSymbolPullbackStrategy(i, sym);
   }
}

//+------------------------------------------------------------------+
//| Tick Event Handler                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   ExtTrade.ManageOpenPositions(Symbol());
}

//+------------------------------------------------------------------+
//| Strategy Logic: Trend Alignment & Pullback Confirmation          |
//+------------------------------------------------------------------+
void ProcessSymbolPullbackStrategy(const int symIndex, const string sym)
{
   datetime currentBarTime = (datetime)SeriesInfoInteger(sym, InpExecutionTF, SERIES_LASTBAR_DATE);
   if(currentBarTime == 0 || currentBarTime == ExtLastBarTimes[symIndex])
      return;
      
   string riskReject = "";
   if(!ExtRisk.CanOpenNewTrade(sym, riskReject))
      return;
      
   string spreadReject = "";
   if(!ExtScanner.IsTradePermitted(symIndex, spreadReject))
      return;

   // Indicator Handles
   int fastEmaH = iMA(sym, InpExecutionTF, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   int slowEmaH = iMA(sym, InpExecutionTF, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   int baseEmaH = iMA(sym, InpExecutionTF, InpMacroEMA, 0, MODE_EMA, PRICE_CLOSE);
   
   if(fastEmaH == INVALID_HANDLE || slowEmaH == INVALID_HANDLE || baseEmaH == INVALID_HANDLE)
   {
      if(fastEmaH != INVALID_HANDLE) IndicatorRelease(fastEmaH);
      if(slowEmaH != INVALID_HANDLE) IndicatorRelease(slowEmaH);
      if(baseEmaH != INVALID_HANDLE) IndicatorRelease(baseEmaH);
      return;
   }
   
   double fastBuf[3], slowBuf[3], baseBuf[3];
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   bool copiedOk = true;
   if(CopyBuffer(fastEmaH, 0, 1, 3, fastBuf) < 3) copiedOk = false;
   if(CopyBuffer(slowEmaH, 0, 1, 3, slowBuf) < 3) copiedOk = false;
   if(CopyBuffer(baseEmaH, 0, 1, 3, baseBuf) < 3) copiedOk = false;
   if(CopyRates(sym, InpExecutionTF, 1, 5, rates) < 5) copiedOk = false;
   
   IndicatorRelease(fastEmaH);
   IndicatorRelease(slowEmaH);
   IndicatorRelease(baseEmaH);
   
   if(!copiedOk)
      return;
      
   ExtLastBarTimes[symIndex] = currentBarTime;

   double fastEma = fastBuf[2]; // completed bar 1
   double slowEma = slowBuf[2];
   double baseEma = baseBuf[2];
   
   MqlRates triggerBar = rates[0]; // bar 1
   MqlRates prevBar    = rates[1]; // bar 2
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   if(point <= 0.0) return;

   // 1. BULLISH TREND PULLBACK
   // Macro Condition: Fast EMA > Slow EMA > 200 EMA and Price > 200 EMA
   bool isBullishMacro = (fastEma > slowEma && slowEma > baseEma && triggerBar.close > baseEma);
   if(isBullishMacro)
   {
      // Pullback condition: Previous bar low touched or penetrated the 9/21 EMA corridor
      bool touchedCorridor = (prevBar.low <= fastEma || triggerBar.low <= fastEma);
      
      // Resumption Trigger: Trigger bar closes bullish (green) and above Fast EMA
      bool resumptionCandle = (triggerBar.close > triggerBar.open && triggerBar.close > fastEma);
      
      if(touchedCorridor && resumptionCandle)
      {
         double entryPrice = SymbolInfoDouble(sym, SYMBOL_ASK);
         // Protective SL placed below the recent pullback low or below slow EMA
         double swingLow = MathMin(triggerBar.low, prevBar.low);
         double slPrice = MathMin(swingLow, slowEma) - (5.0 * point);
         double slDistance = entryPrice - slPrice;
         
         if(slDistance > 0.0)
         {
            double tpPrice = entryPrice + (slDistance * InpRewardToRiskRatio);
            double volume = ExtRisk.CalculateLotSize(sym, entryPrice, slPrice);
            
            if(volume > 0.0)
            {
               string comment = "TrendPullback_Buy";
               ulong ticket = ExtTrade.ExecuteBuy(sym, volume, slPrice, tpPrice, comment);
               if(ticket > 0)
               {
                  ExtLog.Signal(sym, "BUY", entryPrice, slPrice, tpPrice,
                                StringFormat("Bullish 9/21 corridor resumption above 200 EMA (SL: %.1f pts)", slDistance/point));
               }
            }
         }
      }
   }

   // 2. BEARISH TREND PULLBACK
   // Macro Condition: Fast EMA < Slow EMA < 200 EMA and Price < 200 EMA
   bool isBearishMacro = (fastEma < slowEma && slowEma < baseEma && triggerBar.close < baseEma);
   if(isBearishMacro)
   {
      // Pullback condition: Previous bar high touched or penetrated the 9/21 EMA corridor
      bool touchedCorridor = (prevBar.high >= fastEma || triggerBar.high >= fastEma);
      
      // Resumption Trigger: Trigger bar closes bearish (red) and below Fast EMA
      bool resumptionCandle = (triggerBar.close < triggerBar.open && triggerBar.close < fastEma);
      
      if(touchedCorridor && resumptionCandle)
      {
         double entryPrice = SymbolInfoDouble(sym, SYMBOL_BID);
         // Protective SL placed above the recent pullback high or above slow EMA
         double swingHigh = MathMax(triggerBar.high, prevBar.high);
         double slPrice = MathMax(swingHigh, slowEma) + (5.0 * point);
         double slDistance = slPrice - entryPrice;
         
         if(slDistance > 0.0)
         {
            double tpPrice = entryPrice - (slDistance * InpRewardToRiskRatio);
            double volume = ExtRisk.CalculateLotSize(sym, entryPrice, slPrice);
            
            if(volume > 0.0)
            {
               string comment = "TrendPullback_Sell";
               ulong ticket = ExtTrade.ExecuteSell(sym, volume, slPrice, tpPrice, comment);
               if(ticket > 0)
               {
                  ExtLog.Signal(sym, "SELL", entryPrice, slPrice, tpPrice,
                                StringFormat("Bearish 9/21 corridor resumption below 200 EMA (SL: %.1f pts)", slDistance/point));
               }
            }
         }
      }
   }
}
