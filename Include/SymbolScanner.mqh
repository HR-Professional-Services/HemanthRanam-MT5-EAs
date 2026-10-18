//+------------------------------------------------------------------+
//|                                                SymbolScanner.mqh |
//|                                    Copyright 2026, Hemanth Ranam |
//|                             https://github.com/HR-Professional-Services |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Hemanth Ranam"
#property link      "https://github.com/HR-Professional-Services/HemanthRanam-MT5-EAs"
#property version   "2.00"

#include <Trade\SymbolInfo.mqh>

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
