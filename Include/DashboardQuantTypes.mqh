//+------------------------------------------------------------------+
//| Market Structure & Liquidity Types for Bloomberg Quant Terminal   |
//+------------------------------------------------------------------+
#property copyright "Hemanth Ranam"
#property link      "https://github.com/HR-Professional-Services/HemanthRanam-MT5-EAs"
#property strict

enum ENUM_REGIME_STATE
{
   REGIME_STRONG_BULL,
   REGIME_BULL,
   REGIME_WEAK_BULL,
   REGIME_STRONG_BEAR,
   REGIME_BEAR,
   REGIME_WEAK_BEAR,
   REGIME_RANGING,
   REGIME_CONSOLIDATION,
   REGIME_EXPANSION
};

enum ENUM_STRUCT_SIGNAL
{
   STRUCT_SIG_NONE,
   STRUCT_SIG_BOS_BULL,
   STRUCT_SIG_BOS_BEAR,
   STRUCT_SIG_CHOCH_BULL,
   STRUCT_SIG_CHOCH_BEAR,
   STRUCT_SIG_SWEEP_BUY,
   STRUCT_SIG_SWEEP_SELL
};

struct InstrumentQuantAnalytics
{
   string            symbol;
   string            baseName;
   double            currentPrice;
   double            priceChange;
   double            priceChangePct;
   
   // 9/21/200 EMA Engine
   double            ema9_m5;
   double            ema21_m5;
   double            ema200_m5;
   double            ema9_h1;
   double            ema21_h1;
   double            ema9_d1;
   double            ema21_d1;
   double            emaSeparationPct;
   double            emaHealthScore;
   string            m5EmaState;
   string            h1EmaState;
   string            d1EmaState;
   string            crossoverStatus;
   string            pullbackStatus;
   
   // Market Structure & Swings
   string            structureClass; // HH, HL, LH, LL
   string            bosStatus;      // Bullish BOS, Bearish BOS, None
   string            chochStatus;    // Bullish CHOCH, Bearish CHOCH, None
   double            lastSwingHigh;
   double            lastSwingLow;
   string            regimeClassification; // STRONG BULL, BEAR, CONSOLIDATION etc.
   
   // Liquidity Engine
   double            nearestBSL;     // Buy-Side Liquidity
   double            nearestSSL;     // Sell-Side Liquidity
   double            prevDayHigh;
   double            prevDayLow;
   double            prevWeekHigh;
   double            prevWeekLow;
   string            lastSweepDirection;
   string            sweepConfirmation;
   double            bslDistancePoints;
   double            sslDistancePoints;
   
   // Volume & Order-Flow Proxy
   long              currentTickVol;
   long              prevTickVol;
   double            avgTickVol;
   double            rvol;           // Relative Volume
   string            volExpansion;   // EXPANSION, NORMAL, CONTRACTION
   double            buyingPressurePct; // Proxy from Close relative to (High-Low)
   
   // Technical Momentum & Volatility
   double            atr14;
   double            atrPoints;
   double            rsi14;
   string            rsiCondition;   // OVERBOUGHT, OVERSOLD, NEUTRAL
   double            macdMain;
   double            macdSignal;
   double            macdHist;
   string            macdMomentum;   // BULLISH EXPANDING, BEARISH, etc.
   
   // Multi-Timeframe Directional Alignment
   string            mtfD1;
   string            mtfH1;
   string            mtfM15;
   string            mtfM5;
   
   // Macro DXY Correlation
   double            dxyRollingCorr;
   
   // Strategy Matrix & Signal Confirmation
   string            overallSignal;  // BUY SETUP, SELL SETUP, WAIT, RANGING
   int               activeStrategyCount;
   double            signalConfidenceScore; // 0 to 100%
};
