//+------------------------------------------------------------------+
//|                                                    100_EMA_EA.mq5|
//|                                    Copyright 2026, Hemanth Ranam |
//|                             https://github.com/HR-Professional-Services |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, Hemanth Ranam"
#property link        "https://github.com/HR-Professional-Services/HemanthRanam-MT5-EAs"
#property version     "2.10"
#property description "Quantitative 100 EMA Macro Trend Continuation Engine."
#property description "Enforces H1 EMA directional bias, M5 closed-bar breakout retests, and strict equity risk controls."

//====================================================================
// STANDALONE ARCHITECTURE: STANDARD MT5 PLATFORM INCLUDES ONLY
//====================================================================
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>

//--- Asset Profiles
enum ENUM_ASSET_PROFILE
{
   PROFILE_AUTO_DETECT = 0, // Auto-Detect from Chart Symbol
   PROFILE_XAUUSD      = 1, // Gold (XAUUSD) Optimized Defaults
   PROFILE_XAGUSD      = 2, // Silver (XAGUSD) Optimized Defaults
   PROFILE_US500       = 3, // S&P 500 (US500) Optimized Defaults
   PROFILE_USTEC       = 4, // Nasdaq 100 (USTEC) Optimized Defaults
   PROFILE_CUSTOM      = 5  // Manual Custom Inputs Below
};

//--- Input Parameters
input group "=== Asset Profile & Auto-Calibration ==="
input ENUM_ASSET_PROFILE InpAssetProfile       = PROFILE_AUTO_DETECT; // Asset Volatility Profile

input group "=== Strategy Parameters ==="
input int             InpEMAPeriod         = 100;            // Local EMA Period (Default: 100)
input ENUM_TIMEFRAMES InpHTFTimeframe      = PERIOD_H1;      // Higher Timeframe Trend Filter
input int             InpTPRatio           = 3;              // Reward to Risk Ratio (1:N, Default: 1:3)
input int             InpMinSLPoints       = 100;            // Minimum SL Floor Distance (Points, Custom only)

input group "=== Structural Stop-Loss & ATR Protection (Stage 3) ==="
input bool            InpUseStructuralSL   = true;           // Enable Multi-Bar Swing Structure SL (Completed Bars)
input int             InpSwingLookback     = 5;              // Swing High/Low Lookback Window (Completed Bars)
input bool            InpUseATRBuffer      = true;           // Apply ATR Volatility Buffer Beyond Swing Structure
input int             InpATRPeriod         = 14;             // ATR Smoothing Period
input double          InpATRMultiplier     = 1.0;            // ATR Multiplier for Safety Buffer (e.g. 1.0x ATR)
input int             InpMaxSLPoints       = 1000;           // Maximum Defensible SL Guard in Points (0 = Disabled)

input group "=== Trend & Candle Quality Filters ==="
input bool            InpUseHTFSlopeFilter = false;          // Require HTF EMA Slope Agreement (Completed Bars)
input double          InpHTFMinSlopePoints = 0.0;            // Minimum HTF Slope in Points (0 = Flat/Positive Only)
input bool            InpUseBodyQuality    = false;          // Require Minimum Candle Body-to-Range Ratio
input double          InpMinBodyRatio      = 0.40;           // Minimum Body-to-Range Ratio (e.g. 0.40 = 40%)

input group "=== Volume Confirmation Filter ==="
input bool            InpUseVolumeFilter   = true;           // Require Volume Expansion Confirmation (Anti-Fakeout)
input int             InpVolumeLookback    = 20;             // Volume Rolling Average Lookback Period
input double          InpVolumeMultiplier  = 1.1;            // Minimum Volume Multiplier vs Average (Default: 1.1x)

input group "=== Risk Management ==="
input double          InpRiskPercent       = 1.0;            // Max Risk % per Trade (Account Equity, Max 1.0%)
input bool            InpUseEquityForRisk  = true;           // Calculate Risk on Equity (true) or Balance (false)
input int             InpMaxPositions      = 1;              // Max Concurrent Positions for this Symbol & Magic
input int             InpMaxSpreadPoints   = 50;             // Max Allowed Spread in Points (0 = Disabled, Custom only)
input ulong           InpDeviationPoints   = 20;             // Max Slippage Deviation (Points)

input group "=== Position Management & Trailing ==="
input bool            InpUseBE             = true;           // Enable Break-Even Protection
input int             InpBEPoints          = 100;            // Profit in Points to Trigger Break-Even (Custom only)
input int             InpBESafetyPoints    = 10;             // Profit Buffer Above/Below Entry for BE (Points, Custom only)
input bool            InpUseTrailing       = true;           // Enable Closed Candle Structure Trailing Stop
input int             InpTrailingStepPoints= 10;             // Minimum Improvement in Points to Modify SL (Custom only)

input group "=== Session Filtering (Broker Time) ==="
input bool            InpFilterSessions    = true;           // Restrict Trading to Active Market Windows
input int             InpLondonStartHour   = 8;              // Session Start Hour (Broker Time)
input int             InpNYCloseHour       = 22;             // Session End Hour (Broker Time)
input bool            InpCloseFridayLate   = true;           // Restrict Late Friday Entries (Weekend Risk)
input int             InpFridayCloseHour   = 20;             // Friday Entry Cutoff Hour (Broker Time)

input group "=== Account-Level Risk Safeguards (Stage 4) ==="
input bool            InpUseDailyDrawdown  = true;           // Enforce Account Daily Drawdown Limit
input double          InpMaxDailyDrawdown  = 3.0;            // Max Daily Equity Drawdown Limit (%)
input bool            InpUsePortfolioRisk  = true;           // Enforce Aggregate Portfolio Open Risk Limit
input double          InpMaxPortfolioRisk  = 5.0;            // Max Portfolio Open Risk Limit (% Equity)
input int             InpMaxTotalPositions = 4;              // Max Aggregate Positions Across All EAs & Symbols

input group "=== Order Routing & Isolation ==="
input ulong           InpMagicNumber       = 100100;         // Unique Magic Number
input string          InpTradeComment      = "100 EMA PRO Trend"; // Execution Tag

//--- Global Engine Variables
int                   handleEMA_LTF        = INVALID_HANDLE;
int                   handleEMA_HTF        = INVALID_HANDLE;
int                   handleATR            = INVALID_HANDLE;
CTrade                trade;
CSymbolInfo           m_symbol;
datetime              lastBarTime          = 0;
//--- Stage 4 Account-Level Risk Tracking State
double                dailyStartEquity     = 0.0;
int                   lastResetDay         = -1;

//--- Active Calibrated Parameters (Set dynamically by Auto-Detection or Custom Input)
int                   activeMaxSpread      = 50;
int                   activeMinSL          = 100;
int                   activeBE             = 100;
int                   activeBESafety       = 10;
int                   activeTrailStep      = 10;
string                detectedProfileName  = "Custom";

//+------------------------------------------------------------------+
//| Apply Multi-Asset Institutional Volatility Calibration           |
//+------------------------------------------------------------------+
void ApplyAssetCalibration()
{
   ENUM_ASSET_PROFILE profile = InpAssetProfile;

   if(profile == PROFILE_AUTO_DETECT)
   {
      string sym = _Symbol;
      StringToUpper(sym);
      
      // Robust base symbol detection (handles broker prefixes/suffixes like XAUUSDm, rUS500)
      if(StringFind(sym, "XAUUSD") >= 0 || StringFind(sym, "GOLD") >= 0)
         profile = PROFILE_XAUUSD;
      else if(StringFind(sym, "XAGUSD") >= 0 || StringFind(sym, "SILVER") >= 0)
         profile = PROFILE_XAGUSD;
      else if(StringFind(sym, "US500") >= 0 || StringFind(sym, "SPX500") >= 0 || StringFind(sym, "SP500") >= 0)
         profile = PROFILE_US500;
      else if(StringFind(sym, "USTEC") >= 0 || StringFind(sym, "NAS100") >= 0 || StringFind(sym, "US100") >= 0 || StringFind(sym, "NDX") >= 0)
         profile = PROFILE_USTEC;
      else
         profile = PROFILE_CUSTOM;
   }

   switch(profile)
   {
      case PROFILE_XAUUSD:
         activeMaxSpread     = 50;
         activeMinSL         = 100;
         activeBE            = 100;
         activeBESafety      = 10;
         activeTrailStep     = 10;
         detectedProfileName = "XAUUSD (Gold Scalper)";
         break;

      case PROFILE_XAGUSD:
         activeMaxSpread     = 35;
         activeMinSL         = 80;
         activeBE            = 120;
         activeBESafety      = 15;
         activeTrailStep     = 15;
         detectedProfileName = "XAGUSD (Silver Momentum)";
         break;

      case PROFILE_US500:
         activeMaxSpread     = 120;
         activeMinSL         = 350;
         activeBE            = 500;
         activeBESafety      = 50;
         activeTrailStep     = 50;
         detectedProfileName = "US500 (S&P 500 Index)";
         break;

      case PROFILE_USTEC:
         activeMaxSpread     = 300;
         activeMinSL         = 2500;
         activeBE            = 3500;
         activeBESafety      = 300;
         activeTrailStep     = 300;
         detectedProfileName = "USTEC (Nasdaq 100 Index)";
         break;

      case PROFILE_CUSTOM:
      default:
         activeMaxSpread     = InpMaxSpreadPoints;
         activeMinSL         = InpMinSLPoints;
         activeBE            = InpBEPoints;
         activeBESafety      = InpBESafetyPoints;
         activeTrailStep     = InpTrailingStepPoints;
         detectedProfileName = "Custom Manual Parameters";
         break;
   }

   PrintFormat("[100_EMA_EA][CALIBRATION] Symbol: %s | Profile: %s | SpreadLimit: %d | MinSL: %d | BE: %d | BESafety: %d | TrailStep: %d",
               _Symbol, detectedProfileName, activeMaxSpread, activeMinSL, activeBE, activeBESafety, activeTrailStep);
}

//+------------------------------------------------------------------+
//| Helper: Count Active Positions for Specific Symbol & Magic       |
//+------------------------------------------------------------------+
int CountActivePositions(const string symbol, const ulong magic)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == symbol &&
            PositionGetInteger(POSITION_MAGIC) == (long)magic)
         {
            count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Normalize Price strictly to Symbol Tick Size                     |
//+------------------------------------------------------------------+
double NormalizePriceToTick(double price)
{
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0.0) return NormalizeDouble(price, _Digits);
   return NormalizeDouble(MathRound(price / tickSize) * tickSize, _Digits);
}

//+------------------------------------------------------------------+
//| Helper: Get Broker Stop Level & Spread Safe Minimum SL Distance  |
//+------------------------------------------------------------------+
double GetMinimumStopDistance()
{
   double stopLevel = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   double spread    = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   double floorDist = (double)activeMinSL * _Point;
   return MathMax(floorDist, stopLevel + spread + (5.0 * _Point));
}

//+------------------------------------------------------------------+
//| Verify Session Allowed Hours (Broker Clock Feed)                 |
//+------------------------------------------------------------------+
bool IsMarketInSession()
{
   if(!InpFilterSessions) return true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   // Skip weekends completely
   if(dt.day_of_week == 0 || dt.day_of_week == 6) return false;

   // Friday late close mitigation
   if(InpCloseFridayLate && dt.day_of_week == 5 && dt.hour >= InpFridayCloseHour) return false;

   // Normal session window
   if(dt.hour < InpLondonStartHour || dt.hour >= InpNYCloseHour) return false;

   return true;
}

//+------------------------------------------------------------------+
//| Calculate Lot Size strictly based on Account Equity & SL Distance|
//+------------------------------------------------------------------+
double CalculateLotSize(double slDistancePoints)
{
   if(slDistancePoints <= 0) slDistancePoints = (double)activeMinSL;

   double baseCapital = InpUseEquityForRisk ? AccountInfoDouble(ACCOUNT_EQUITY) : AccountInfoDouble(ACCOUNT_BALANCE);
   if(baseCapital <= 0) return 0.0;

   // Guardrail: Hard-cap risk per trade to 1.0%
   double riskPercent = MathMin(InpRiskPercent, 1.0);
   double riskAmount  = baseCapital * (riskPercent / 100.0);

   m_symbol.Refresh();
   m_symbol.RefreshRates();

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tickValue <= 0) tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double lotStep   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   if(tickSize <= 0 || tickValue <= 0 || lotStep <= 0)
   {
      PrintFormat("[100_EMA_EA][WARN] Incomplete symbol specifications for %s. Using minLot: %.2f", _Symbol, minLot);
      return minLot;
   }

   // Exact monetary weight conversion
   double slDistanceTicks = (slDistancePoints * _Point) / tickSize;
   if(slDistanceTicks <= 0) slDistanceTicks = 1.0;

   double lot = riskAmount / (slDistanceTicks * tickValue);

   // Volume step normalization (Strict downward floor to preserve risk cap)
   lot = MathFloor(lot / lotStep) * lotStep;
   lot = NormalizeDouble(lot, 2);

   // Free margin safety check
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double marginReq  = 0.0;
   if(OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, lot, SymbolInfoDouble(_Symbol, SYMBOL_ASK), marginReq))
   {
      if(marginReq > freeMargin * 0.85 && marginReq > 0)
      {
         lot = MathFloor((freeMargin * 0.75) / (marginReq / lot) / lotStep) * lotStep;
         lot = NormalizeDouble(lot, 2);
      }
   }

   return MathMin(maxLot, MathMax(minLot, lot));
}

//+------------------------------------------------------------------+
//| Volume Confirmation: Check Volume Expansion on Trigger Candle    |
//| Note: Broker tick volume is local broker feed, not centralized.  |
//| Isolates completed trigger bar 1 from baseline bars [2..Lookback+1].|
//+------------------------------------------------------------------+
bool CheckVolumeExpansion(string sym, ENUM_TIMEFRAMES tf, int candleIndex = 1)
{
   if(!InpUseVolumeFilter) return true;
   if(InpVolumeLookback <= 0) return true;

   // 1. Fetch completed trigger candle volume (bar candleIndex)
   long triggerVol[];
   ArraySetAsSeries(triggerVol, true);
   bool triggerOk = (CopyRealVolume(sym, tf, candleIndex, 1, triggerVol) == 1 && triggerVol[0] > 0);
   bool usingTickVol = false;

   if(!triggerOk)
   {
      triggerOk = (CopyTickVolume(sym, tf, candleIndex, 1, triggerVol) == 1 && triggerVol[0] > 0);
      usingTickVol = true;
   }

   if(!triggerOk)
   {
      // Missing, zero or invalid trigger volume: reject safely (never confirm silently)
      return false;
   }

   // 2. Fetch baseline candles strictly preceding trigger candle [candleIndex + 1 .. candleIndex + InpVolumeLookback]
   long baselineVol[];
   ArraySetAsSeries(baselineVol, true);
   int copied = 0;

   if(!usingTickVol)
   {
      copied = CopyRealVolume(sym, tf, candleIndex + 1, InpVolumeLookback, baselineVol);
      if(copied < InpVolumeLookback)
      {
         copied = CopyTickVolume(sym, tf, candleIndex + 1, InpVolumeLookback, baselineVol);
         usingTickVol = true;
      }
   }
   else
   {
      copied = CopyTickVolume(sym, tf, candleIndex + 1, InpVolumeLookback, baselineVol);
   }

   if(copied < InpVolumeLookback)
   {
      // Insufficient baseline history: reject safely
      return false;
   }

   double sum = 0.0;
   int validCount = 0;
   for(int i = 0; i < copied; i++)
   {
      if(baselineVol[i] > 0)
      {
         sum += (double)baselineVol[i];
         validCount++;
      }
   }

   if(validCount < (InpVolumeLookback / 2) || sum <= 0.0)
   {
      // Unreliable or zero baseline volume: reject safely
      return false;
   }

   double avgVol = sum / (double)validCount;
   return ((double)triggerVol[0] >= avgVol * InpVolumeMultiplier);
}

//+------------------------------------------------------------------+
//| Stage 4: Check & Reset Daily Baseline Equity at Midnight        |
//+------------------------------------------------------------------+
void CheckDailyReset()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   if(dt.day != lastResetDay)
   {
      double currentEq = AccountInfoDouble(ACCOUNT_EQUITY);
      if(currentEq <= 0.0) currentEq = AccountInfoDouble(ACCOUNT_BALANCE);
      
      dailyStartEquity = currentEq;
      lastResetDay     = dt.day;
      
      PrintFormat("[100_EMA_EA][RISK_RESET] New trading day detected (Day %02d). Daily baseline equity reset to: %.2f",
                  dt.day, dailyStartEquity);
   }
}

//+------------------------------------------------------------------+
//| Stage 4: Get Current Daily Drawdown Percent                      |
//+------------------------------------------------------------------+
double GetDailyDrawdownPercent()
{
   CheckDailyReset();
   if(dailyStartEquity <= 0.0) return 0.0;
   
   double currentEq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(currentEq >= dailyStartEquity) return 0.0;
   
   return ((dailyStartEquity - currentEq) / dailyStartEquity) * 100.0;
}

//+------------------------------------------------------------------+
//| Stage 4: Calculate Total Open Risk Across Entire Portfolio       |
//+------------------------------------------------------------------+
double GetPortfolioOpenRiskPercent(bool &hasUnquantified, string &detail)
{
   hasUnquantified = false;
   detail = "";
   
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0.0)
   {
      hasUnquantified = true;
      detail = "Account equity is zero or negative.";
      return 100.0;
   }
   
   double totalOpenRiskCash = 0.0;
   int totalPositions = PositionsTotal();
   
   for(int i = 0; i < totalPositions; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      
      string posSym   = PositionGetString(POSITION_SYMBOL);
      long   posType  = PositionGetInteger(POSITION_TYPE);
      double posVol   = PositionGetDouble(POSITION_VOLUME);
      double openPx   = PositionGetDouble(POSITION_PRICE_OPEN);
      double curSL    = PositionGetDouble(POSITION_SL);
      
      if(curSL <= 0.0)
      {
         hasUnquantified = true;
         detail = StringFormat("Position #%I64u on %s has no Stop Loss!", ticket, posSym);
         double marginReq = 0.0;
         ENUM_ORDER_TYPE ordType = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
         if(OrderCalcMargin(ordType, posSym, posVol, openPx, marginReq) && marginReq > 0.0)
            totalOpenRiskCash += marginReq;
         else
            totalOpenRiskCash += (posVol * openPx);
         continue;
      }
      
      double slDist = 0.0;
      if(posType == POSITION_TYPE_BUY)
      {
         if(curSL >= openPx) continue;
         slDist = openPx - curSL;
      }
      else if(posType == POSITION_TYPE_SELL)
      {
         if(curSL <= openPx) continue;
         slDist = curSL - openPx;
      }
      
      double lossCash = 0.0;
      ENUM_ORDER_TYPE ordType = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      if(OrderCalcProfit(ordType, posSym, posVol, openPx, curSL, lossCash))
      {
         totalOpenRiskCash += MathAbs(lossCash);
      }
      else
      {
         double tickSz  = SymbolInfoDouble(posSym, SYMBOL_TRADE_TICK_SIZE);
         double tickVal = SymbolInfoDouble(posSym, SYMBOL_TRADE_TICK_VALUE);
         if(tickSz > 0.0 && tickVal > 0.0)
         {
            totalOpenRiskCash += (slDist / tickSz) * tickVal * posVol;
         }
         else
         {
            hasUnquantified = true;
            detail = StringFormat("Cannot determine tick value for %s.", posSym);
            totalOpenRiskCash += (posVol * openPx * 0.02);
         }
      }
   }
   
   return (totalOpenRiskCash / equity) * 100.0;
}

//+------------------------------------------------------------------+
//| Stage 4: Master Account Risk Pre-Trade Check                     |
//+------------------------------------------------------------------+
bool CanOpenTradeRiskCheck(string &rejectReason)
{
   rejectReason = "";
   
   // 1. Max Total Aggregate Positions Check across all EAs/symbols
   int totalPos = PositionsTotal();
   if(InpMaxTotalPositions > 0 && totalPos >= InpMaxTotalPositions)
   {
      rejectReason = StringFormat("Total active positions (%d) reached aggregate limit (%d).",
                                  totalPos, InpMaxTotalPositions);
      return false;
   }
   
   // 2. Daily Drawdown Limit Check
   if(InpUseDailyDrawdown)
   {
      double currentDD = GetDailyDrawdownPercent();
      if(currentDD >= InpMaxDailyDrawdown)
      {
         rejectReason = StringFormat("Daily drawdown limit reached: %.2f%% >= %.2f%% (Baseline: %.2f).",
                                     currentDD, InpMaxDailyDrawdown, dailyStartEquity);
         return false;
      }
   }
   
   // 3. Aggregate Portfolio Open Risk Check
   if(InpUsePortfolioRisk)
   {
      bool hasUnquantified = false;
      string detail = "";
      double currentRiskPct = GetPortfolioOpenRiskPercent(hasUnquantified, detail);
      
      if(hasUnquantified)
      {
         PrintFormat("[100_EMA_EA][RISK_WARNING] Portfolio open risk check noted unquantified position: %s", detail);
      }
      
      double potentialTotalRisk = currentRiskPct + InpRiskPercent;
      if(potentialTotalRisk > InpMaxPortfolioRisk)
      {
         rejectReason = StringFormat("Total open risk (%.2f%% + %.2f%% new = %.2f%%) exceeds portfolio limit (%.2f%%).",
                                     currentRiskPct, InpRiskPercent, potentialTotalRisk, InpMaxPortfolioRisk);
         return false;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Execute Trade with Dynamic Risk Sizing & Execution Guards        |
//+------------------------------------------------------------------+
bool ExecuteTrade(ENUM_ORDER_TYPE type)
{
   // Stage 4: Account-Level Risk Safeguards (Drawdown, Portfolio Open Risk, Max Total Positions)
   string riskRejectReason = "";
   if(!CanOpenTradeRiskCheck(riskRejectReason))
   {
      PrintFormat("[100_EMA_EA][RISK_REJECT] Trade blocked by account safeguards: %s", riskRejectReason);
      return false;
   }

   // Spread filter check
   if(activeMaxSpread > 0)
   {
      int currentSpread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(currentSpread > activeMaxSpread)
      {
         PrintFormat("[100_EMA_EA][SPREAD_REJECT] Current spread (%d) exceeds limit (%d) on %s.",
                     currentSpread, activeMaxSpread, _Symbol);
         return false;
      }
   }

   m_symbol.RefreshRates();
   double price = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   price = NormalizePriceToTick(price);

   // Stage 3: Multi-Bar Structural Swing Stop-Loss with ATR Buffer
   double rawSwing = 0.0;
   int lookback = MathMax(1, InpSwingLookback);

   if(InpUseStructuralSL)
   {
      if(type == ORDER_TYPE_BUY)
      {
         int lowestBar = iLowest(_Symbol, _Period, MODE_LOW, lookback, 1);
         if(lowestBar < 0)
         {
            PrintFormat("[100_EMA_EA][ERROR] Failed to calculate swing low over %d bars. Trade rejected.", lookback);
            return false;
         }
         rawSwing = iLow(_Symbol, _Period, lowestBar);
      }
      else
      {
         int highestBar = iHighest(_Symbol, _Period, MODE_HIGH, lookback, 1);
         if(highestBar < 0)
         {
            PrintFormat("[100_EMA_EA][ERROR] Failed to calculate swing high over %d bars. Trade rejected.", lookback);
            return false;
         }
         rawSwing = iHigh(_Symbol, _Period, highestBar);
      }
   }
   else
   {
      rawSwing = (type == ORDER_TYPE_BUY) ? iLow(_Symbol, _Period, 1) : iHigh(_Symbol, _Period, 1);
   }

   if(rawSwing <= 0.0)
   {
      PrintFormat("[100_EMA_EA][ERROR] Invalid structural swing price (%.5f). Trade rejected.", rawSwing);
      return false;
   }

   // Fetch completed ATR buffer for volatility safety buffer
   double atrBuffer = 0.0;
   if(InpUseATRBuffer)
   {
      if(handleATR == INVALID_HANDLE)
      {
         PrintFormat("[100_EMA_EA][ERROR] ATR indicator handle invalid. Trade rejected.");
         return false;
      }
      double atrValues[];
      ArraySetAsSeries(atrValues, true);
      if(CopyBuffer(handleATR, 0, 1, 1, atrValues) < 1 || atrValues[0] <= 0.0)
      {
         PrintFormat("[100_EMA_EA][ERROR] Failed to fetch valid ATR value on bar 1. Trade rejected.");
         return false;
      }
      atrBuffer = atrValues[0] * MathMax(0.0, InpATRMultiplier);
   }

   // Construct initial Stop Loss beyond structural extreme
   double rawDist = 0.0;
   if(type == ORDER_TYPE_BUY)
   {
      double structuralSL = rawSwing - atrBuffer;
      rawDist = price - structuralSL;
   }
   else
   {
      double structuralSL = rawSwing + atrBuffer;
      rawDist = structuralSL - price;
   }

   // Enforce broker stop level & calibrated minimum floor
   double minSLDist = GetMinimumStopDistance();
   double slDist    = MathMax(rawDist, minSLDist);

   // Enforce maximum defensible SL distance guard (if configured)
   if(InpMaxSLPoints > 0)
   {
      double maxAllowedDist = (double)InpMaxSLPoints * _Point;
      if(slDist > maxAllowedDist)
      {
         PrintFormat("[100_EMA_EA][SL_REJECT] Calculated SL distance (%.1f pts) exceeds InpMaxSLPoints (%d pts). Trade rejected.",
                     slDist / _Point, InpMaxSLPoints);
         return false;
      }
   }

   double sl = (type == ORDER_TYPE_BUY) ? price - slDist : price + slDist;
   double tp = (type == ORDER_TYPE_BUY) ? price + (slDist * InpTPRatio) : price - (slDist * InpTPRatio);

   sl = NormalizePriceToTick(sl);
   tp = NormalizePriceToTick(tp);

   // Revalidate final normalized SL distance after tick-size rounding
   double finalSLDist = MathAbs(price - sl);
   if(finalSLDist < minSLDist)
   {
      PrintFormat("[100_EMA_EA][ERROR] Final normalized SL distance (%.5f) violates broker stop level (%.5f). Trade rejected.",
                  finalSLDist, minSLDist);
      return false;
   }

   double lots = CalculateLotSize(finalSLDist / _Point);
   if(lots <= 0.0)
   {
      PrintFormat("[100_EMA_EA][ERROR] Calculated lot size is 0.0 on %s. Trade aborted.", _Symbol);
      return false;
   }

   if(trade.PositionOpen(_Symbol, type, lots, price, sl, tp, InpTradeComment))
   {
      PrintFormat("[100_EMA_EA][ORDER_OPEN] %s %s | Lots: %.2f | Price: %.5f | SL: %.5f | TP: %.5f | Ticket: %I64u",
                  EnumToString(type), _Symbol, lots, price, sl, tp, trade.ResultOrder());
      return true;
   }
   else
   {
      PrintFormat("[100_EMA_EA][EXECUTION_FAILED] %s on %s failed! Retcode: %u (%s)",
                  EnumToString(type), _Symbol, trade.ResultRetcode(), trade.ResultRetcodeDescription());
      return false;
   }
}

//+------------------------------------------------------------------+
//| Robust Position Management: Break-Even & Trailing Stop Engine    |
//+------------------------------------------------------------------+
void ManagePositions()
{
   double point = _Point;
   double minStopDist = GetMinimumStopDistance();

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;

      // Strict symbol and magic number isolation
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber) continue;

      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);
      double curPrice  = PositionGetDouble(POSITION_PRICE_CURRENT);
      long   posType   = PositionGetInteger(POSITION_TYPE);

      bool beTriggered = false;

      // 1. Break-Even Protection Engine
      if(InpUseBE)
      {
         if(posType == POSITION_TYPE_BUY)
         {
            if((curPrice - openPrice) >= (activeBE * point))
            {
               double desiredBE = NormalizePriceToTick(openPrice + (activeBESafety * point));
               if(currentSL < desiredBE - (point * 0.5))
               {
                  if(trade.PositionModify(ticket, desiredBE, currentTP))
                  {
                     PrintFormat("[100_EMA_EA][BE_SECURED] BUY Ticket #%I64u locked to Break-Even @ %.5f", ticket, desiredBE);
                     currentSL = desiredBE;
                     beTriggered = true;
                  }
               }
               else
               {
                  beTriggered = true;
               }
            }
         }
         else if(posType == POSITION_TYPE_SELL)
         {
            if((openPrice - curPrice) >= (activeBE * point))
            {
               double desiredBE = NormalizePriceToTick(openPrice - (activeBESafety * point));
               if(currentSL > desiredBE + (point * 0.5) || currentSL == 0.0)
               {
                  if(trade.PositionModify(ticket, desiredBE, currentTP))
                  {
                     PrintFormat("[100_EMA_EA][BE_SECURED] SELL Ticket #%I64u locked to Break-Even @ %.5f", ticket, desiredBE);
                     currentSL = desiredBE;
                     beTriggered = true;
                  }
               }
               else
               {
                  beTriggered = true;
               }
            }
         }
      }

      // 2. Closed Candle Trailing Stop Engine
      if(InpUseTrailing)
      {
         if(posType == POSITION_TYPE_BUY)
         {
            double newSL = NormalizePriceToTick(iLow(_Symbol, _Period, 1));
            
            // Ensure trailing step is met and distance from current market price is valid
            if(newSL > currentSL + (activeTrailStep * point) && (curPrice - newSL) >= minStopDist)
            {
               // Never degrade an already secured Break-Even stop
               if(!beTriggered || newSL >= (openPrice + (activeBESafety * point)))
               {
                  if(trade.PositionModify(ticket, newSL, currentTP))
                  {
                     PrintFormat("[100_EMA_EA][TRAIL_UPDATE] BUY Ticket #%I64u trailed SL to %.5f", ticket, newSL);
                  }
               }
            }
         }
         else if(posType == POSITION_TYPE_SELL)
         {
            double newSL = NormalizePriceToTick(iHigh(_Symbol, _Period, 1));
            
            if((currentSL == 0.0 || newSL < currentSL - (activeTrailStep * point)) && (newSL - curPrice) >= minStopDist)
            {
               if(!beTriggered || newSL <= (openPrice - (activeBESafety * point)))
               {
                  if(trade.PositionModify(ticket, newSL, currentTP))
                  {
                     PrintFormat("[100_EMA_EA][TRAIL_UPDATE] SELL Ticket #%I64u trailed SL to %.5f", ticket, newSL);
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Expert Initialization Function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   m_symbol.Name(_Symbol);
   m_symbol.Refresh();
   m_symbol.RefreshRates();

   lastBarTime = 0;

   // Apply auto-detected or configured asset volatility profile
   ApplyAssetCalibration();

   // Enforce strict 1% risk limit
   if(InpRiskPercent > 1.0)
   {
      PrintFormat("[100_EMA_EA][NOTICE] InpRiskPercent (%.1f%%) exceeds institutional 1%% limit. Auto-clamping to 1.0%%.", InpRiskPercent);
   }

   // Initialize Order Routing Settings
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpDeviationPoints);

   // Configure execution filling mode based on symbol capabilities
   uint filling = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((filling & SYMBOL_FILLING_FOK) != 0)
      trade.SetTypeFilling(ORDER_FILLING_FOK);
   else if((filling & SYMBOL_FILLING_IOC) != 0)
      trade.SetTypeFilling(ORDER_FILLING_IOC);
   else
      trade.SetTypeFilling(ORDER_FILLING_RETURN);

   // Initialize Indicator Handles
   handleEMA_LTF = iMA(_Symbol, _Period, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   handleEMA_HTF = iMA(_Symbol, InpHTFTimeframe, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   handleATR     = iATR(_Symbol, _Period, MathMax(1, InpATRPeriod));

   if(handleEMA_LTF == INVALID_HANDLE || handleEMA_HTF == INVALID_HANDLE || (InpUseATRBuffer && handleATR == INVALID_HANDLE))
   {
      PrintFormat("[100_EMA_EA][FATAL] Failed to initialize indicator handles for %s.", _Symbol);
      return(INIT_FAILED);
   }

   PrintFormat("[100_EMA_EA][INITIALIZED] %s ready. Magic: %I64u | Risk: %.1f%% | HTF: %s | ATRPeriod: %d",
               _Symbol, InpMagicNumber, MathMin(InpRiskPercent, 1.0), EnumToString(InpHTFTimeframe), InpATRPeriod);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert Deinitialization Function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(handleEMA_LTF != INVALID_HANDLE) IndicatorRelease(handleEMA_LTF);
   if(handleEMA_HTF != INVALID_HANDLE) IndicatorRelease(handleEMA_HTF);
   if(handleATR != INVALID_HANDLE) IndicatorRelease(handleATR);
   PrintFormat("[100_EMA_EA][DEINIT] Clean shutdown completed. Reason code: %d", reason);
}

//+------------------------------------------------------------------+
//| Expert Tick Function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 1. Manage active positions strictly matching this symbol and magic number
   if(CountActivePositions(_Symbol, InpMagicNumber) > 0)
   {
      ManagePositions();
   }

   // 2. Position limit check: Cease scanning if max concurrent positions reached
   if(CountActivePositions(_Symbol, InpMagicNumber) >= InpMaxPositions)
   {
      return;
   }

   // 3. Strict Session Control (Trading Windows)
   if(!IsMarketInSession()) return;

   // 4. New Candle Filter (Evaluate exclusively on fresh closed bar transitions)
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime == lastBarTime) return;

   // 5. Retrieve indicator buffers safely with Series orientation
   double emaLTF[];
   double emaHTF[];
   ArraySetAsSeries(emaLTF, true);
   ArraySetAsSeries(emaHTF, true);

   if(CopyBuffer(handleEMA_LTF, 0, 0, 3, emaLTF) < 3 || CopyBuffer(handleEMA_HTF, 0, 0, 3, emaHTF) < 3)
   {
      return;
   }

   // Get completed price structures (1 = preceding completed bar, 2 = 2 bars ago)
   double closePrice1 = iClose(_Symbol, _Period, 1);
   double openPrice1  = iOpen(_Symbol, _Period, 1);
   double highPrice1  = iHigh(_Symbol, _Period, 1);
   double lowPrice1   = iLow(_Symbol, _Period, 1);
   double closePrice2 = iClose(_Symbol, _Period, 2);
   double htfClose1   = iClose(_Symbol, InpHTFTimeframe, 1);

   // 6. Multi-Timeframe Bias Confirmation (HTF Trend Validation on closed bar 1)
   bool isBullishBias = (htfClose1 > emaHTF[1]);
   bool isBearishBias = (htfClose1 < emaHTF[1]);

   // Stage 2: HTF EMA Slope Agreement (Completed Bars: bar 1 vs bar 2)
   if(InpUseHTFSlopeFilter)
   {
      double htfSlopePoints = (emaHTF[1] - emaHTF[2]) / _Point;
      if(isBullishBias && htfSlopePoints < InpHTFMinSlopePoints)
         isBullishBias = false;
      if(isBearishBias && (-htfSlopePoints) < InpHTFMinSlopePoints)
         isBearishBias = false;
   }

   // Stage 2: Trigger Candle Body-to-Range Quality Filter (Rejects dojis and weak candles)
   bool isBodyQualityOk = true;
   if(InpUseBodyQuality)
   {
      double candleRange = highPrice1 - lowPrice1;
      double candleBody  = MathAbs(closePrice1 - openPrice1);
      if(candleRange <= 0.0 || (candleBody / candleRange) < InpMinBodyRatio)
      {
         isBodyQualityOk = false;
      }
   }

   // 7. Volume Confirmation Filter (Mandatory anti-fakeout expansion on trigger bar)
   bool isVolumeConfirmed = CheckVolumeExpansion(_Symbol, _Period, 1);

   // 8. High-Quality Breakout Setup Filter (Closed bar validation with Volume & Quality)
   // - Bullish: Preceding candle (1) closed cleanly ABOVE the EMA (emaLTF[1]), while candle (2) was below or touched it (emaLTF[2]).
   bool isHighQualityBuy  = isBullishBias && isVolumeConfirmed && isBodyQualityOk && (closePrice1 > emaLTF[1] && closePrice2 <= emaLTF[2] && closePrice1 > openPrice1);
   bool isHighQualitySell = isBearishBias && isVolumeConfirmed && isBodyQualityOk && (closePrice1 < emaLTF[1] && closePrice2 >= emaLTF[2] && closePrice1 < openPrice1);

   // 9. Order Execution
   if(isHighQualityBuy)
   {
      if(ExecuteTrade(ORDER_TYPE_BUY))
      {
         lastBarTime = currentBarTime;
      }
   }
   else if(isHighQualitySell)
   {
      if(ExecuteTrade(ORDER_TYPE_SELL))
      {
         lastBarTime = currentBarTime;
      }
   }
}
