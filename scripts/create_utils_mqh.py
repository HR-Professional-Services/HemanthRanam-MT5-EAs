import os

mqh_code = """//+------------------------------------------------------------------+
//|                                           HR_Utils.mqh           |
//| V4 FINAL LOCK - KEEP EXISTING FORMAT - 2026-05-06                |
//| Premium Digital 44px - Verified Linked - 24/7 - Flicker Added    |
//| Copyright 2026, Hemanth Ranam                                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Hemanth Ranam"
#property link      "https://github.com/HR-Professional-Services/HemanthRanam-MT5-EAs"
#property strict

#include <Canvas\\Canvas.mqh>

//====================================================================
// GLOBAL CONSTANTS & PALETTE
//====================================================================
#define NUM_INSTRUMENTS 4
#define NUM_STRATEGIES  8

// Strict 32-bit ARGB Hex Color Tokens
#define CLR_PAGE_BG      0xFFEAEFF2 // Subtle Metallic Soft Gray
#define CLR_CARD_BG      0xFFFFFFFF // Pure White
#define CLR_INNER_BG     0xFFF1F5F9 // Soft Slate Module Box
#define CLR_BORDER       0xFFCBD5E1 // Border
#define CLR_INNER_BRD    0xFFE2E8F0 // Inner Module Border
#define CLR_TEXT_BLACK   0xFF0F172A // Jet Black Slate 900
#define CLR_TEXT_MUTED   0xFF475569 // Slate 600
#define CLR_TEXT_SUBTLE  0xFF64748B // Slate 500

#define CLR_BULL_GREEN   0xFF10B981 // Emerald Green 500
#define CLR_BULL_DARK    0xFF059669 // Emerald Dark 600
#define CLR_BULL_LIGHT   0xFFD1FAE5 // Emerald Light 100
#define CLR_BEAR_RED     0xFFEF4444 // Red 500
#define CLR_BEAR_DARK    0xFFDC2626 // Red 600
#define CLR_BEAR_LIGHT   0xFFFEE2E2 // Red Light 100

#define CLR_AMBER_BG     0xFFF59E0B // Amber 500
#define CLR_AMBER_TXT    0xFFFFFFFF
#define CLR_CHIP_GRAY    0xFFF1F5F9
#define CLR_TRACK_BG     0xFFE2E8F0
#define CLR_PILL_TEXT    0xFFFFFFFF

//+------------------------------------------------------------------+
//| Multi-Session Intel Structure (Asian, London, NY AM/PM)          |
//+------------------------------------------------------------------+
struct SessionIntelligence
{
   string   activeSessionName;
   string   activeKillzoneName;
   bool     inAsian;
   bool     inLondon;
   bool     inNewYork;
   bool     inOverlap;
   datetime ukTime;
   datetime nyTime;
   string   nextSessionCountdown;
};

//+------------------------------------------------------------------+
//| Comprehensive Instrument Quant & SMC Analytics Structure         |
//+------------------------------------------------------------------+
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
   
   // ICT / SMC Market Structure & Swings
   string            structureClass; // HH, HL, LH, LL
   string            bosStatus;      // Bullish BOS, Bearish BOS, Intact
   string            chochStatus;    // Bullish CHOCH, Bearish CHOCH, None
   double            lastSwingHigh;
   double            lastSwingLow;
   string            regimeClassification; // STRONG BULL, BEAR, CONSOLIDATION etc.
   string            smcZone;        // PREMIUM, DISCOUNT, EQUILIBRIUM
   double            fvgTop;         // Fair Value Gap top
   double            fvgBottom;      // Fair Value Gap bottom
   string            fvgStatus;      // BULLISH FVG, BEARISH FVG, NONE
   double            obHigh;         // Order Block High
   double            obLow;          // Order Block Low
   string            obStatus;       // BULLISH OB, BEARISH OB, NONE
   
   // Equal Highs / Equal Lows (EQH / EQL)
   bool              hasEQH;
   double            eqhLevel;
   bool              hasEQL;
   double            eqlLevel;
   
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

   // Live M5 EMA 9 Sparkline Buffer (Last 20 bars)
   double            ema9_history[20];
};

//+------------------------------------------------------------------+
//| Bloomberg Flicker Tracking Structure                             |
//+------------------------------------------------------------------+
struct BloombergFlickerState
{
   double prevPrice[4];
   double prevPct[4];
   string prevEmaM5[4];
   double prevBuyPress[4];
   double prevRsi[4];
   double prevBsl[4];
   double prevSsl[4];
   
   ulong  priceFlickerEnd[4];
   uint   priceFlickerBg[4];
   uint   priceFlickerTxt[4];
   
   ulong  pctFlickerEnd[4];
   uint   pctFlickerBg[4];
   
   ulong  emaFlickerEnd[4];
   uint   emaFlickerBg[4];
   
   ulong  gaugeFlickerEnd[4];
   uint   gaugeFlickerBg[4];
   
   ulong  bslFlickerEnd[4];
   uint   bslFlickerBg[4];
   
   ulong  volFlickerEnd[4];
   uint   volFlickerBg[4];

   void Reset()
   {
      for(int i = 0; i < 4; i++)
      {
         prevPrice[i]       = 0.0;
         prevPct[i]         = 0.0;
         prevEmaM5[i]       = "";
         prevBuyPress[i]    = 0.0;
         prevRsi[i]         = 0.0;
         prevBsl[i]         = 0.0;
         prevSsl[i]         = 0.0;
         
         priceFlickerEnd[i] = 0;
         priceFlickerBg[i]  = 0;
         priceFlickerTxt[i] = 0;
         
         pctFlickerEnd[i]   = 0;
         pctFlickerBg[i]    = 0;
         
         emaFlickerEnd[i]   = 0;
         emaFlickerBg[i]    = 0;
         
         gaugeFlickerEnd[i] = 0;
         gaugeFlickerBg[i]  = 0;
         
         bslFlickerEnd[i]   = 0;
         bslFlickerBg[i]    = 0;
         
         volFlickerEnd[i]   = 0;
         volFlickerBg[i]    = 0;
      }
   }
};
"""

target_file = r"C:\Users\vaibh\.gemini\antigravity-ide\scratch\HemanthRanam-MT5-EAs\06_MULTI_PAIR_SCANNERS\HR_UNIFIED_MASTER_OS_V4_FINAL\HR_Utils.mqh"
os.makedirs(os.path.dirname(target_file), exist_ok=True)
with open(target_file, "w", encoding="utf-8") as f:
    f.write(mqh_code)

print("Created HR_Utils.mqh")
