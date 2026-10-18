//+------------------------------------------------------------------+
//|                                             RegimeClassifier.mqh |
//|                                    Copyright 2026, Hemanth Ranam |
//|                             https://github.com/HR-Professional-Services |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Hemanth Ranam"
#property link      "https://github.com/HR-Professional-Services/HemanthRanam-MT5-EAs"
#property version   "2.00"

//+------------------------------------------------------------------+
//| Market Regime Enumeration                                        |
//+------------------------------------------------------------------+
enum ENUM_MARKET_REGIME
{
   REGIME_UNKNOWN,
   REGIME_TREND_BULL,           // Strong Bullish Trend (ADX > 25, EMAs aligned upward)
   REGIME_TREND_BEAR,           // Strong Bearish Trend (ADX > 25, EMAs aligned downward)
   REGIME_RANGING,              // Range-Bound / Consolidation (ADX < 20, flat slope)
   REGIME_VOLATILITY_COMPRESS,  // Range Compression / Pre-Breakout Squeeze
   REGIME_VOLATILITY_EXPAND,    // Active Volatility Expansion
   REGIME_UNSTABLE_HIGH_RISK    // Erratic Whipsaw or Illiquid
};

//+------------------------------------------------------------------+
//| Objective Market Regime Classification Class                     |
//+------------------------------------------------------------------+
class CRegimeClassifier
{
private:
   int               m_adxPeriod;
   double            m_trendAdxThreshold;
   int               m_fastEmaPeriod;
   int               m_slowEmaPeriod;
   int               m_baselineEmaPeriod;

public:
                     CRegimeClassifier();
                    ~CRegimeClassifier() {}

   void              Init(const int adxPeriod = 14,
                          const double trendAdxThreshold = 25.0,
                          const int fastEma = 9,
                          const int slowEma = 21,
                          const int baselineEma = 200);

   // Core Classification
   ENUM_MARKET_REGIME DetectRegime(const string symbol, const ENUM_TIMEFRAMES tf);
   
   // Formatted Regime Name
   string            GetRegimeName(const ENUM_MARKET_REGIME regime) const;
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CRegimeClassifier::CRegimeClassifier() :
   m_adxPeriod(14),
   m_trendAdxThreshold(25.0),
   m_fastEmaPeriod(9),
   m_slowEmaPeriod(21),
   m_baselineEmaPeriod(200)
{
}

//+------------------------------------------------------------------+
//| Initialize Regime Thresholds                                     |
//+------------------------------------------------------------------+
void CRegimeClassifier::Init(const int adxPeriod,
                             const double trendAdxThreshold,
                             const int fastEma,
                             const int slowEma,
                             const int baselineEma)
{
   m_adxPeriod          = adxPeriod;
   m_trendAdxThreshold  = trendAdxThreshold;
   m_fastEmaPeriod      = fastEma;
   m_slowEmaPeriod      = slowEma;
   m_baselineEmaPeriod  = baselineEma;
}

//+------------------------------------------------------------------+
//| Detect Objective Market Regime from Indicators                   |
//+------------------------------------------------------------------+
ENUM_MARKET_REGIME CRegimeClassifier::DetectRegime(const string symbol, const ENUM_TIMEFRAMES tf)
{
   int adxHandle = iADX(symbol, tf, m_adxPeriod);
   int fastHandle = iMA(symbol, tf, m_fastEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   int slowHandle = iMA(symbol, tf, m_slowEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   int baseHandle = iMA(symbol, tf, m_baselineEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   int atrHandle  = iATR(symbol, tf, 14);

   if(adxHandle == INVALID_HANDLE || fastHandle == INVALID_HANDLE ||
      slowHandle == INVALID_HANDLE || baseHandle == INVALID_HANDLE ||
      atrHandle == INVALID_HANDLE)
   {
      if(adxHandle != INVALID_HANDLE) IndicatorRelease(adxHandle);
      if(fastHandle != INVALID_HANDLE) IndicatorRelease(fastHandle);
      if(slowHandle != INVALID_HANDLE) IndicatorRelease(slowHandle);
      if(baseHandle != INVALID_HANDLE) IndicatorRelease(baseHandle);
      if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
      return REGIME_UNKNOWN;
   }

   double adxBuf[2];
   double fastBuf[2];
   double slowBuf[2];
   double baseBuf[2];
   double atrBuf[10];

   bool ok = true;
   if(CopyBuffer(adxHandle, 0, 1, 2, adxBuf) < 2) ok = false;
   if(CopyBuffer(fastHandle, 0, 1, 2, fastBuf) < 2) ok = false;
   if(CopyBuffer(slowHandle, 0, 1, 2, slowBuf) < 2) ok = false;
   if(CopyBuffer(baseHandle, 0, 1, 2, baseBuf) < 2) ok = false;
   if(CopyBuffer(atrHandle, 0, 1, 10, atrBuf) < 10) ok = false;

   IndicatorRelease(adxHandle);
   IndicatorRelease(fastHandle);
   IndicatorRelease(slowHandle);
   IndicatorRelease(baseHandle);
   IndicatorRelease(atrHandle);

   if(!ok)
      return REGIME_UNKNOWN;

   double currentAdx = adxBuf[1];
   double fastEma    = fastBuf[1];
   double slowEma    = slowBuf[1];
   double baseEma    = baseBuf[1];

   // ATR moving average over 10 bars
   double avgAtr = 0.0;
   for(int i = 0; i < 10; i++)
      avgAtr += atrBuf[i];
   avgAtr /= 10.0;
   double currentAtr = atrBuf[9];

   // 1. Extreme Volatility / Unstable
   if(currentAtr > avgAtr * 2.5)
      return REGIME_UNSTABLE_HIGH_RISK;

   // 2. Volatility Compression (Squeeze)
   if(currentAtr < avgAtr * 0.65)
      return REGIME_VOLATILITY_COMPRESS;

   // 3. Strong Directional Trend (Bull / Bear)
   if(currentAdx >= m_trendAdxThreshold)
   {
      if(fastEma > slowEma && slowEma > baseEma)
         return REGIME_TREND_BULL;
      if(fastEma < slowEma && slowEma < baseEma)
         return REGIME_TREND_BEAR;
   }

   // 4. Volatility Expansion Breakout
   if(currentAtr > avgAtr * 1.35 && currentAdx > 18.0)
      return REGIME_VOLATILITY_EXPAND;

   // 5. Default Ranging Consolidation
   if(currentAdx < 20.0)
      return REGIME_RANGING;

   return REGIME_RANGING;
}

//+------------------------------------------------------------------+
//| Get Formatted Regime String                                      |
//+------------------------------------------------------------------+
string CRegimeClassifier::GetRegimeName(const ENUM_MARKET_REGIME regime) const
{
   switch(regime)
   {
      case REGIME_TREND_BULL:          return "Strong Bullish Trend";
      case REGIME_TREND_BEAR:          return "Strong Bearish Trend";
      case REGIME_RANGING:             return "Ranging Consolidation";
      case REGIME_VOLATILITY_COMPRESS: return "Volatility Compression";
      case REGIME_VOLATILITY_EXPAND:   return "Volatility Expansion";
      case REGIME_UNSTABLE_HIGH_RISK:  return "High-Risk Unstable";
      default:                         return "Unknown Regime";
   }
}
