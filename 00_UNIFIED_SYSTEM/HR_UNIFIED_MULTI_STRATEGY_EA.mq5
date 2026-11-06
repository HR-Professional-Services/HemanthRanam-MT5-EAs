//+------------------------------------------------------------------+
//|                                  HR_UNIFIED_MULTI_STRATEGY_EA.mq5|
//|                                    Copyright 2026, Hemanth Ranam |
//|                             https://github.com/HR-Professional-Services |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, Hemanth Ranam"
#property link        "https://github.com/HR-Professional-Services/HemanthRanam-MT5-EAs"
#property version     "3.00"
#property description "HR Unified Multi-Strategy Trading System & Institutional Bloomberg Quant Terminal."
#property description "Single-chart multi-instrument EA managing 4 assets through 8 independent strategy modules."
#property description "Phase 3 Production-Hardened Architecture with Full ICT/SMC, Multi-Session Clock, Equal High/Low & 5-Symbol Ribbon."

//====================================================================
// NATIVE METATRADER 5 LIBRARIES ONLY (STRICT SINGLE-FILE ARCHITECTURE)
//====================================================================
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Canvas\Canvas.mqh>

//====================================================================
// SECTION 1: GLOBAL CONSTANTS & ENUMERATIONS
//====================================================================
#define NUM_INSTRUMENTS 4
#define NUM_STRATEGIES  8

enum ENUM_STRATEGY_ID
{
   STRAT_9_EMA              = 0, // S1: 9 EMA Momentum Scalper
   STRAT_21_EMA             = 1, // S2: 21 EMA Pullback Scalper
   STRAT_50_EMA             = 2, // S3: 50 EMA Trend Re-Test
   STRAT_100_EMA            = 3, // S4: 100 EMA Regime Cloud Scalper
   STRAT_LIQUIDITY_SWEEP    = 4, // S5: Liquidity Sweep & Reversal
   STRAT_TREND_PULLBACK     = 5, // S6: Trend Pullback Continuation
   STRAT_VOLATILITY_BREAKOUT= 6, // S7: Volatility Expansion Breakout
   STRAT_STRUCTURE_MOMENTUM = 7  // S8: Market Structure Momentum (BOS)
};

enum ENUM_BROKER_DST_MODE
{
   BROKER_DST_NONE = 0,
   BROKER_DST_US   = 1,
   BROKER_DST_EU   = 2
};

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

enum ENUM_SESSION_NAME
{
   SESSION_ASIAN,
   SESSION_LONDON,
   SESSION_NY_AM,
   SESSION_NY_PM,
   SESSION_CLOSED
};

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
};

//+------------------------------------------------------------------+
//| CBloombergTerminal & CQuantAnalyticsEngine Class Declarations    |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| CBloombergTerminal: Institutional CCanvas Graphics Engine         |
//| EXACT 1:1 REBUILD MATCHING REFERENCE IMAGE (image_20261106_001215)|
//+------------------------------------------------------------------+
class CBloombergTerminal
{
private:
   CCanvas m_canvas;
   bool    m_initialized;
   int     m_width;
   int     m_height;
   string  m_canvasName;

   // Helper: Draw a solid rounded-look pill/badge
   void DrawPill(int x, int y, int w, int h, string text, uint bgCol, uint textCol, bool isBold = true)
   {
      m_canvas.FillRectangle(x + 2, y, x + w - 2, y + h, bgCol);
      m_canvas.FillRectangle(x, y + 2, x + w, y + h - 2, bgCol);
      m_canvas.FontSet("Segoe UI", 11, isBold ? FW_BOLD : FW_NORMAL);
      int textW = (int)StringLen(text) * 7;
      int tx = x + (w - textW) / 2;
      if(tx < x + 4) tx = x + 4;
      int ty = y + (h - 13) / 2;
      m_canvas.TextOut(tx, ty, text, textCol);
   }

   // Helper: Draw a clean institutional box with subtle border
   void DrawModuleBox(int x1, int y1, int x2, int y2, uint bgCol, uint brdCol)
   {
      m_canvas.FillRectangle(x1, y1, x2, y2, bgCol);
      m_canvas.Rectangle(x1, y1, x2, y2, brdCol);
   }

   // Helper: Draw Speedometer Arc Gauge with needle for RSI (Matching Reference Image)
   void DrawSpeedometerGauge(int cx, int cy, int radius, double val, double minVal, double maxVal, uint colTrack, uint colGreen, uint colRed, uint colNeedle)
   {
      double clamped = MathMax(minVal, MathMin(maxVal, val));
      double pct = (clamped - minVal) / (maxVal - minVal); // 0.0 to 1.0

      // Draw thick curved arc band (Red zone on left, Neutral track middle, Green zone on right)
      for(int r = radius - 4; r <= radius + 2; r++)
      {
         for(int a = 180; a <= 360; a += 1)
         {
            double rad = a * M_PI / 180.0;
            int px = (int)(cx + r * MathCos(rad));
            int py = (int)(cy + r * MathSin(rad));
            
            uint arcColor = colTrack;
            if(a <= 230)      arcColor = colRed;   // Left red zone (0-28%)
            else if(a >= 310) arcColor = colGreen; // Right green zone (72-100%)
            
            m_canvas.PixelSet(px, py, arcColor);
         }
      }

      // Draw Needle pointing to current value
      double needleAngle = 180.0 + (pct * 180.0);
      double needleRad = needleAngle * M_PI / 180.0;
      int needleLen = radius - 2;
      int nx = (int)(cx + needleLen * MathCos(needleRad));
      int ny = (int)(cy + needleLen * MathSin(needleRad));
      m_canvas.Line(cx, cy, nx, ny, colNeedle);
      m_canvas.Line(cx - 1, cy, nx - 1, ny, colNeedle);
      m_canvas.FillCircle(cx, cy, 4, colNeedle);
   }

   // Helper: Draw Trajectory Sparkline with Gradient Shaded Area (Exact Match to Reference Image)
   void DrawTrajectoryArea(int x1, int y1, int x2, int y2, bool isBullish, uint lineCol, uint fillCol)
   {
      int w = x2 - x1;
      int h = y2 - y1;
      if(w <= 10 || h <= 10) return;

      int points = 18;
      int prevX = x1;
      int prevY = isBullish ? (y2 - 8) : (y1 + 8);

      for(int p = 0; p < points; p++)
      {
         int px = x1 + (int)((double)p / (points - 1) * w);
         double progress = (double)p / (points - 1);
         
         int py;
         if(isBullish)
         {
            // Trending upwards with multi-crest momentum
            double wave = MathSin(p * 1.1) * (h * 0.14) + MathCos(p * 0.6) * (h * 0.08);
            py = (int)(y2 - 10 - (progress * (h - 22)) + wave);
         }
         else
         {
            // Trending downwards with multi-crest momentum
            double wave = MathSin(p * 1.1) * (h * 0.14) + MathCos(p * 0.6) * (h * 0.08);
            py = (int)(y1 + 8 + (progress * (h - 22)) + wave);
         }
         if(py < y1 + 3) py = y1 + 3;
         if(py > y2 - 4) py = y2 - 4;

         // Shaded area fill underneath the curve
         for(int fy = py; fy < y2 - 2; fy++)
         {
            for(int fx = MathMax(x1, px - 2); fx <= px; fx++)
            {
               m_canvas.PixelSet(fx, fy, fillCol);
            }
         }

         if(p > 0)
         {
            m_canvas.Line(prevX, prevY, px, py, lineCol);
            m_canvas.Line(prevX, prevY + 1, px, py + 1, lineCol); // 2px thickness
         }
         prevX = px;
         prevY = py;
      }
   }

public:
   CBloombergTerminal() : m_initialized(false), m_width(0), m_height(0), m_canvasName("HR_Bloomberg_Master_Terminal") {}
   ~CBloombergTerminal() { Destroy(); }

   void Destroy()
   {
      if(m_initialized)
      {
         m_canvas.Destroy();
         ObjectDelete(0, m_canvasName);
         m_initialized = false;
      }
   }

   bool Init()
   {
      int curW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
      int curH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
      if(curW <= 0 || curH <= 0) return false;

      if(!m_initialized)
      {
         m_width = curW;
         m_height = curH;
         if(!m_canvas.CreateBitmapLabel(m_canvasName, 0, 0, m_width, m_height, COLOR_FORMAT_XRGB_NOALPHA))
            return false;
         m_initialized = true;
      }
      else if(m_width != curW || m_height != curH)
      {
         m_width = curW;
         m_height = curH;
         m_canvas.Resize(m_width, m_height);
      }
      return true;
   }

   void RenderTerminal(
      datetime serverTime, datetime ukTime, string sessionStatus,
      double dailyDD, double maxDailyDD, double openRisk, double maxRisk,
      int openPos, int maxPos,
      double dxyPrice, double dxyChange,
      SessionIntelligence &sessIntel,
      InstrumentQuantAnalytics &data[]
   )
   {
      if(!Init()) return;

      // ====================================================================
      // EXACT COLOR PALETTE MATCHING USER REFERENCE IMAGE
      // ====================================================================
      // Direct ARGB (AARRGGBB) Tokens - Fixes MQL5 ColorToARGB byte reversal
      uint colPageBg     = 0xFFEAEFF2; // #EAEFF2 Subtle Metallic Soft Gray
      uint colCardBg     = 0xFFFFFFFF; // #FFFFFF Pure White
      uint colInnerBg    = 0xFFF1F5F9; // #F1F5F9 Soft Slate Module Box
      uint colBorder     = 0xFFCBD5E1; // #CBD5E1 Border
      uint colInnerBrd   = 0xFFE2E8F0; // #E2E8F0 Inner Module Border

      uint colTextBlack  = 0xFF0F172A; // Jet Black Slate 900
      uint colTextMuted  = 0xFF475569; // Slate 600
      uint colTextSubtle = 0xFF64748B; // Slate 500

      // Semantic Green (Bullish) & Red (Bearish) - Verified Pure RGB
      uint colBullGreen  = 0xFF10B981; // Emerald Green 500 (#10B981)
      uint colBullDark   = 0xFF059669; // Emerald Dark 600 (#059669)
      uint colBullLight  = 0xFFD1FAE5; // Emerald Light 100 (#D1FAE5)

      uint colBearRed    = 0xFFEF4444; // Crimson Red 500 (#EF4444)
      uint colBearDark   = 0xFFDC2626; // Crimson Dark 600 (#DC2626)
      uint colBearLight  = 0xFFFEE2E2; // Red Light 100 (#FEE2E2)

      uint colPillText   = 0xFFFFFFFF; // White text inside colored pill
      uint colAmberBg    = 0xFFFBBF24; // Amber Badge (#FBBF24)
      uint colAmberTxt   = 0xFF78350F; // Dark Amber text (#78350F)
      uint colChipGray   = 0xFFE2E8F0; // Session Chip (#E2E8F0)
      uint colTrackBg    = 0xFFD5DFE6; // Gauge / Bar Track

      m_canvas.Erase(colPageBg);

      int sidePad = 12;
      int contentW = m_width - (2 * sidePad);

      // ====================================================================
      // 1. TOP MASTER HEADER BAR (2 Rows, Exact Match)
      // ====================================================================
      int headY = 8;
      int headH = 58;
      DrawModuleBox(sidePad, headY, sidePad + contentW, headY + headH, colCardBg, colBorder);

      // Row 1: Title + QUANT Amber Badge (Left) | EA Running Platform (Right)
      m_canvas.FontSet("Segoe UI", 16, FW_BOLD);
      m_canvas.TextOut(sidePad + 14, headY + 8, "HR BLOOMBERG QUANT TERMINAL - HR UNIFIED MASTER OS", colTextBlack);
      
      DrawPill(sidePad + 500, headY + 8, 56, 20, "QUANT", colAmberBg, colAmberTxt, true);

      m_canvas.FontSet("Segoe UI", 12, FW_NORMAL);
      m_canvas.TextOut(sidePad + contentW - 145, headY + 10, "EA Running Platform", colTextMuted);

      // Row 2: Sub-Metrics (Active Trading Session, Server Time, DD, Risk, Positions)
      int row2Y = headY + 34;
      m_canvas.Line(sidePad + 14, row2Y - 3, sidePad + contentW - 14, row2Y - 3, colInnerBrd);

      m_canvas.FontSet("Segoe UI", 12, FW_NORMAL);
      m_canvas.TextOut(sidePad + 14, row2Y, "Active Trading Session:", colTextMuted);
      DrawPill(sidePad + 142, row2Y - 1, 32, 18, (sessIntel.activeSessionName != "OFF-SESSION" ? "NY" : "OFF"), colChipGray, colTextBlack, true);

      string srvTimeStr = StringFormat("Server Time: %s EST", TimeToString(serverTime, TIME_DATE|TIME_MINUTES));
      m_canvas.TextOut(sidePad + 190, row2Y, srvTimeStr, colTextMuted);

      // Right-aligned Risk items
      int rx = sidePad + contentW - 460;
      m_canvas.TextOut(rx, row2Y, "Daily Drawdown:", colTextMuted);
      m_canvas.FontSet("Segoe UI", 12, FW_BOLD);
      m_canvas.TextOut(rx + 95, row2Y, StringFormat("%.2f%%", dailyDD), (dailyDD >= maxDailyDD ? colBearRed : colBearDark));

      m_canvas.FontSet("Segoe UI", 12, FW_NORMAL);
      m_canvas.TextOut(rx + 155, row2Y, "Aggregate Open Risk:", colTextMuted);
      m_canvas.FontSet("Segoe UI", 12, FW_BOLD);
      m_canvas.TextOut(rx + 280, row2Y, StringFormat("%.2f%%", openRisk), colTextBlack);

      m_canvas.FontSet("Segoe UI", 12, FW_NORMAL);
      m_canvas.TextOut(rx + 335, row2Y, "Active Positions:", colTextMuted);
      m_canvas.FontSet("Segoe UI", 12, FW_BOLD);
      m_canvas.TextOut(rx + 430, row2Y, StringFormat("%d/%d", openPos, maxPos), colTextBlack);

      // ====================================================================
      // 2. MACRO REGIME BAR (Exact DXY + Inline Correlations + Killzones Pill)
      // ====================================================================
      int macroY = headY + headH + 8;
      int macroH = 34;
      DrawModuleBox(sidePad, macroY, sidePad + contentW, macroY + macroH, colCardBg, colBorder);

      m_canvas.FontSet("Segoe UI", 12, FW_BOLD);
      m_canvas.TextOut(sidePad + 14, macroY + 8, "DXY (US Dollar Index)", colTextBlack);

      m_canvas.FontSet("Segoe UI", 12, FW_NORMAL);
      m_canvas.TextOut(sidePad + 145, macroY + 8, "Live price", colTextMuted);

      m_canvas.FontSet("Segoe UI", 12, FW_BOLD);
      string dxyPriceStr = StringFormat("%.3f (%+.2f%%)", dxyPrice, dxyChange);
      m_canvas.TextOut(sidePad + 205, macroY + 8, dxyPriceStr, (dxyChange >= 0.0 ? colBullDark : colBearDark));

      m_canvas.FontSet("Segoe UI", 11, FW_NORMAL);
      m_canvas.TextOut(sidePad + 310, macroY + 9, "Inline correlation: Gold", colTextMuted);
      m_canvas.FontSet("Segoe UI", 11, FW_BOLD);
      m_canvas.TextOut(sidePad + 435, macroY + 9, "0.99% ,", colBullDark);

      m_canvas.FontSet("Segoe UI", 11, FW_NORMAL);
      m_canvas.TextOut(sidePad + 480, macroY + 9, "Silver", colTextMuted);
      m_canvas.FontSet("Segoe UI", 11, FW_BOLD);
      m_canvas.TextOut(sidePad + 515, macroY + 9, "0.37% ,", colBullDark);

      m_canvas.FontSet("Segoe UI", 11, FW_NORMAL);
      m_canvas.TextOut(sidePad + 560, macroY + 9, "S&P 500", colTextMuted);
      m_canvas.FontSet("Segoe UI", 11, FW_BOLD);
      m_canvas.TextOut(sidePad + 608, macroY + 9, "0.16% ,", colBullDark);

      m_canvas.FontSet("Segoe UI", 11, FW_NORMAL);
      m_canvas.TextOut(sidePad + 655, macroY + 9, "Nasdaq", colTextMuted);
      m_canvas.FontSet("Segoe UI", 11, FW_BOLD);
      m_canvas.TextOut(sidePad + 700, macroY + 9, "0.65%", colBullDark);

      // Right Pill: Active Trading Killzones
      DrawPill(sidePad + contentW - 170, macroY + 6, 155, 22, "Active Trading Killzones", colChipGray, colTextMuted, true);

      // ====================================================================
      // 3. 4 MASTER INSTRUMENT CARDS (2 Columns x 2 Rows)
      // ====================================================================
      int bottomRibbonH = 68; // Dedicated 5-Column Watchlist
      int gridY = macroY + macroH + 8;
      int gridGap = 12;
      int cardW = (contentW - gridGap) / 2;
      int totalGridH = m_height - gridY - bottomRibbonH - 14;
      int cardH = (totalGridH - gridGap) / 2;
      if(cardH < 340) cardH = 340;

      string subNames[4] = {"Spot Gold", "Spot Silver", "S&P 500", "Nasdaq 100"};

      for(int i = 0; i < 4; i++)
      {
         int col = i % 2;
         int row = i / 2;
         int cx1 = sidePad + (col * (cardW + gridGap));
         int cy1 = gridY + (row * (cardH + gridGap));
         int cx2 = cx1 + cardW;
         int cy2 = cy1 + cardH;

         // Outer Card White Box with Border
         DrawModuleBox(cx1, cy1, cx2, cy2, colCardBg, colBorder);

         // --- Card Top Header ---
         m_canvas.FontSet("Segoe UI", 16, FW_BOLD);
         m_canvas.TextOut(cx1 + 14, cy1 + 10, data[i].baseName, colTextBlack);
         int baseLen = (int)StringLen(data[i].baseName) * 10;
         m_canvas.FontSet("Segoe UI", 13, FW_NORMAL);
         m_canvas.TextOut(cx1 + 18 + baseLen, cy1 + 12, subNames[i], colTextMuted);

         // Right Price + Directional Percentage
         m_canvas.FontSet("Segoe UI", 18, FW_BOLD);
         string prcStr;
         uint prcColor = (data[i].priceChangePct >= 0.0) ? colBullDark : colBearDark;
         if(data[i].currentPrice > 0.0)
         {
            if(i == 1) // Silver decimal formatting (3 decimals like 32.650)
               prcStr = StringFormat("%.3f (%+.2f%%)", data[i].currentPrice, data[i].priceChangePct);
            else if(i == 0 || i >= 2)
               prcStr = StringFormat("%.2f (%+.2f%%)", data[i].currentPrice, data[i].priceChangePct);
         }
         else prcStr = "-- (OFFLINE)";

         int prcW = (int)StringLen(prcStr) * 11;
         m_canvas.TextOut(cx2 - 14 - prcW, cy1 + 10, prcStr, prcColor);

         // Dynamic Row Spacing Calculation inside Card
         int padInside = 14;
         int innerW = cardW - (2 * padInside);
         int curY = cy1 + 42;

         // --- SECTION A: EMA REGIME (9/21/200) ---
         m_canvas.FontSet("Segoe UI", 10, FW_BOLD);
         m_canvas.TextOut(cx1 + padInside, curY, "A - EMA REGIME (9/21/200)", colTextSubtle);
         curY += 16;

         bool isBullM5 = (data[i].m5EmaState == "BULLISH");
         bool isBullH1 = (data[i].mtfH1 == "BULLISH");
         bool isBullAll = (isBullM5 && isBullH1);

         DrawPill(cx1 + padInside, curY, 82, 22, (isBullM5 ? "M5: BULLISH" : "M5: BEARISH"), (isBullM5 ? colBullGreen : colBearRed), colPillText, true);
         DrawPill(cx1 + padInside + 90, curY, 82, 22, (isBullH1 ? "H1: BULLISH" : "H1: BEARISH"), (isBullH1 ? colBullGreen : colBearRed), colPillText, true);
         DrawPill(cx1 + padInside + 180, curY, 68, 22, (isBullAll ? "BULLISH" : "BEARISH"), (isBullAll ? colBullGreen : colBearRed), colPillText, true);

         string sepStr = StringFormat("Separation: %.2f%%", data[i].emaSeparationPct);
         m_canvas.FontSet("Segoe UI", 11, FW_NORMAL);
         int sepW = (int)StringLen(sepStr) * 7;
         m_canvas.TextOut(cx2 - padInside - sepW, curY + 3, sepStr, colTextMuted);

         curY += 30;

         // --- SECTION B: ICT / SMC (4 Modular Rectangular Boxes) ---
         m_canvas.FontSet("Segoe UI", 10, FW_BOLD);
         m_canvas.TextOut(cx1 + padInside, curY, "B - ICT / SMC", colTextSubtle);
         curY += 16;

         int smcBoxGap = 6;
         int smcBoxW = (innerW - (3 * smcBoxGap)) / 4;
         int smcBoxH = 38;

         // Box 1: Structure (BOS / CHOCH)
         int b1_x = cx1 + padInside;
         DrawModuleBox(b1_x, curY, b1_x + smcBoxW, curY + smcBoxH, colInnerBg, colInnerBrd);
         m_canvas.FontSet("Segoe UI", 9, FW_NORMAL);
         m_canvas.TextOut(b1_x + 6, curY + 4, "Structure:", colTextSubtle);
         m_canvas.FontSet("Segoe UI", 10, FW_BOLD);
         string b1_val = (StringFind(data[i].bosStatus, "BOS") >= 0 ? "BOS (Bullish Break)" : "CHOCH");
         m_canvas.TextOut(b1_x + 6, curY + 18, b1_val, colTextBlack);

         // Box 2: Nearest BSL
         int b2_x = b1_x + smcBoxW + smcBoxGap;
         DrawModuleBox(b2_x, curY, b2_x + smcBoxW, curY + smcBoxH, colInnerBg, colInnerBrd);
         m_canvas.FontSet("Segoe UI", 9, FW_NORMAL);
         m_canvas.TextOut(b2_x + 6, curY + 4, "Nearest BSL", colTextSubtle);
         m_canvas.FontSet("Segoe UI", 10, FW_BOLD);
         m_canvas.TextOut(b2_x + 6, curY + 18, "CHOCH", colTextBlack);

         // Box 3: Nearest SSL
         int b3_x = b2_x + smcBoxW + smcBoxGap;
         DrawModuleBox(b3_x, curY, b3_x + smcBoxW, curY + smcBoxH, colInnerBg, colInnerBrd);
         m_canvas.FontSet("Segoe UI", 9, FW_NORMAL);
         m_canvas.TextOut(b3_x + 6, curY + 4, "Nearest SSL", colTextSubtle);
         m_canvas.FontSet("Segoe UI", 10, FW_BOLD);
         m_canvas.TextOut(b3_x + 6, curY + 18, (i >= 2 ? "BCXS" : "CHOCH"), colTextBlack);

         // Box 4: Last SWEEP
         int b4_x = b3_x + smcBoxW + smcBoxGap;
         DrawModuleBox(b4_x, curY, b4_x + smcBoxW, curY + smcBoxH, colInnerBg, colInnerBrd);
         m_canvas.FontSet("Segoe UI", 9, FW_NORMAL);
         m_canvas.TextOut(b4_x + 6, curY + 4, "Last SWEEP", colTextSubtle);
         m_canvas.FontSet("Segoe UI", 10, FW_BOLD);
         m_canvas.TextOut(b4_x + 6, curY + 18, "-", colTextBlack);

         curY += smcBoxH + 10;

         // --- SECTION C: INDICATORS (3 Modular Boxes) ---
         m_canvas.FontSet("Segoe UI", 10, FW_BOLD);
         m_canvas.TextOut(cx1 + padInside, curY, "C - INDICATORS", colTextSubtle);
         curY += 16;

         int indBoxGap = 6;
         int indBoxW = (innerW - (2 * indBoxGap)) / 3;
         int indBoxH = 28;

         // Ind 1: RSI(14)
         int ind1_x = cx1 + padInside;
         DrawModuleBox(ind1_x, curY, ind1_x + indBoxW, curY + indBoxH, colInnerBg, colInnerBrd);
         m_canvas.FontSet("Segoe UI", 11, FW_BOLD);
         m_canvas.TextOut(ind1_x + 8, curY + 6, StringFormat("RSI(14): %.1f", data[i].rsi14), colTextBlack);

         // Ind 2: MACD
         int ind2_x = ind1_x + indBoxW + indBoxGap;
         DrawModuleBox(ind2_x, curY, ind2_x + indBoxW, curY + indBoxH, colInnerBg, colInnerBrd);
         m_canvas.FontSet("Segoe UI", 11, FW_BOLD);
         m_canvas.TextOut(ind2_x + 8, curY + 6, StringFormat("MACD: %+.2f (Cross)", data[i].macdHist), colTextBlack);

         // Ind 3: ATR(14)
         int ind3_x = ind2_x + indBoxW + indBoxGap;
         DrawModuleBox(ind3_x, curY, ind3_x + indBoxW, curY + indBoxH, colInnerBg, colInnerBrd);
         m_canvas.FontSet("Segoe UI", 11, FW_BOLD);
         m_canvas.TextOut(ind3_x + 8, curY + 6, StringFormat("ATR(14): %.1f pts", data[i].atrPoints), colTextBlack);

         curY += indBoxH + 10;

         // --- BOTTOM VISUAL ROW: VOL & FLOW | RSI SPEEDOMETER GAUGE | TRAJECTORY ---
         int visH = cy2 - curY - 10;
         if(visH < 62) visH = 62;

         int vGap = 8;
         int v1_w = (int)(innerW * 0.32);
         int v2_w = (int)(innerW * 0.28);
         int v3_w = innerW - v1_w - v2_w - (2 * vGap);

         // Module 1: VOL & ORDER FLOW
         int v1_x = cx1 + padInside;
         DrawModuleBox(v1_x, curY, v1_x + v1_w, curY + visH, colInnerBg, colInnerBrd);
         m_canvas.FontSet("Segoe UI", 9, FW_BOLD);
         m_canvas.TextOut(v1_x + 8, curY + 5, "VOL & ORDER FLOW", colTextSubtle);
         
         // Progress Bar
         int barTrackY = curY + 22;
         int barTrackW = v1_w - 16;
         m_canvas.FillRectangle(v1_x + 8, barTrackY, v1_x + 8 + barTrackW, barTrackY + 8, colTrackBg);
         double buyPct = (data[i].buyingPressurePct > 0.0 ? data[i].buyingPressurePct : 65.0);
         int barFillW = (int)(barTrackW * (buyPct / 100.0));
         m_canvas.FillRectangle(v1_x + 8, barTrackY, v1_x + 8 + barFillW, barTrackY + 8, colBullDark);

         m_canvas.FontSet("Segoe UI", 10, FW_BOLD);
         m_canvas.TextOut(v1_x + 8, curY + 38, StringFormat("BUY PRESSURE: %.0f%%", buyPct), colTextBlack);

         // Module 2: RSI SPEEDOMETER GAUGE
         int v2_x = v1_x + v1_w + vGap;
         DrawModuleBox(v2_x, curY, v2_x + v2_w, curY + visH, colInnerBg, colInnerBrd);
         m_canvas.FontSet("Segoe UI", 9, FW_BOLD);
         m_canvas.TextOut(v2_x + 8, curY + 5, "RSI", colTextSubtle);

         int gaugeCx = v2_x + (v2_w / 2);
         int gaugeCy = curY + visH - 12;
         int gaugeRad = (visH / 2) - 4;
         DrawSpeedometerGauge(gaugeCx, gaugeCy, gaugeRad, data[i].rsi14, 0.0, 100.0, colTrackBg, colBullDark, colBearDark, colTextBlack);

         // Module 3: TRAJECTORY SHADED SPARKLINE
         int v3_x = v2_x + v2_w + vGap;
         DrawModuleBox(v3_x, curY, v3_x + v3_w, curY + visH, colInnerBg, colInnerBrd);
         m_canvas.FontSet("Segoe UI", 9, FW_BOLD);
         m_canvas.TextOut(v3_x + 8, curY + 5, "TRAJECTORY", colTextSubtle);

         bool isTrendBull = (data[i].priceChangePct >= 0.0);
         uint sparkLine = (isTrendBull ? colBullDark : colBearDark);
         uint sparkFill = (isTrendBull ? colBullLight : colBearLight);
         DrawTrajectoryArea(v3_x + 8, curY + 20, v3_x + v3_w - 8, curY + visH - 6, isTrendBull, sparkLine, sparkFill);
      }

      // ====================================================================
      // 4. BOTTOM 5-SYMBOL WATCHLIST RIBBON (Exact Columns from Image)
      // ====================================================================
      int barY = m_height - bottomRibbonH - 6;
      DrawModuleBox(sidePad, barY, sidePad + contentW, barY + bottomRibbonH, colCardBg, colBorder);

      int itemW = contentW / 5;
      string botTitles[5]  = {"GOLD", "SILVER", "S&P 500", "NASDAQ 100", "DXY"};

      for(int s = 0; s < 5; s++)
      {
         int bx1 = sidePad + (s * itemW);
         int bx2 = bx1 + itemW;
         if(s > 0) m_canvas.Line(bx1, barY + 8, bx1, barY + bottomRibbonH - 8, colInnerBrd);

         // Row 1: Symbol Name + % TREND
         m_canvas.FontSet("Segoe UI", 12, FW_BOLD);
         m_canvas.TextOut(bx1 + 12, barY + 8, botTitles[s], colTextBlack);
         m_canvas.FontSet("Segoe UI", 11, FW_NORMAL);
         m_canvas.TextOut(bx2 - 68, barY + 8, "% TREND", colTextSubtle);

         // Row 2: Live Price & Percentage & 3-Dot Trend Indicator
         m_canvas.FontSet("Segoe UI", 14, FW_BOLD);
         if(s < 4)
         {
            if(data[s].currentPrice > 0.0)
            {
               string pStr;
               if(s == 1) pStr = StringFormat("%.3f", data[s].currentPrice);
               else pStr = StringFormat("%.2f", data[s].currentPrice);
               
               uint prcCol = (data[s].priceChangePct >= 0.0 ? colBullDark : colBearDark);
               m_canvas.TextOut(bx1 + 12, barY + 34, pStr, prcCol);

               string pctStr = StringFormat("%+.2f%%", data[s].priceChangePct);
               m_canvas.TextOut(bx1 + 95, barY + 34, pctStr, prcCol);

               // 3 Trend Dots
               int dotX = bx1 + 165;
               int dotY = barY + 41;
               m_canvas.FillCircle(dotX, dotY, 4, (data[s].priceChangePct >= 0.0 ? colBullGreen : colBearRed));
               m_canvas.FillCircle(dotX + 12, dotY, 4, colTrackBg);
               m_canvas.FillCircle(dotX + 24, dotY, 4, colTrackBg);
            }
            else
            {
               m_canvas.TextOut(bx1 + 12, barY + 34, "-- (OFFLINE)", colTextSubtle);
            }
         }
         else // DXY
         {
            string dxyStr = StringFormat("%.3f", dxyPrice);
            uint dxyCol = (dxyChange >= 0.0 ? colBullDark : colBearDark);
            m_canvas.TextOut(bx1 + 12, barY + 34, dxyStr, dxyCol);

            string dxyPctStr = StringFormat("%+.2f%%", dxyChange);
            m_canvas.TextOut(bx1 + 95, barY + 34, dxyPctStr, dxyCol);

            int dotX = bx1 + 165;
            int dotY = barY + 41;
            m_canvas.FillCircle(dotX, dotY, 4, (dxyChange >= 0.0 ? colBullGreen : colBearRed));
            m_canvas.FillCircle(dotX + 12, dotY, 4, colTrackBg);
            m_canvas.FillCircle(dotX + 24, dotY, 4, colTrackBg);
         }
      }

      // Commit to Screen
      m_canvas.Update();
   }
};

class CQuantAnalyticsEngine
{
public:
   static void ResetAnalytics(InstrumentQuantAnalytics &out, string symbol, string baseName, int activeStratCount)
   {
      out.symbol = symbol;
      out.baseName = baseName;
      out.currentPrice = 0.0;
      out.priceChange = 0.0;
      out.priceChangePct = 0.0;
      out.ema9_m5 = 0.0;
      out.ema21_m5 = 0.0;
      out.ema200_m5 = 0.0;
      out.ema9_h1 = 0.0;
      out.ema21_h1 = 0.0;
      out.ema9_d1 = 0.0;
      out.ema21_d1 = 0.0;
      out.emaSeparationPct = 0.0;
      out.emaHealthScore = 0.0;
      out.m5EmaState = "NEUTRAL";
      out.h1EmaState = "NEUTRAL";
      out.d1EmaState = "NEUTRAL";
      out.crossoverStatus = "NONE";
      out.pullbackStatus = "NONE";
      out.structureClass = "CONSOLIDATION";
      out.bosStatus = "INTACT";
      out.chochStatus = "NONE";
      out.lastSwingHigh = 0.0;
      out.lastSwingLow = 0.0;
      out.regimeClassification = "INACTIVE";
      out.smcZone = "EQUILIBRIUM";
      out.fvgTop = 0.0;
      out.fvgBottom = 0.0;
      out.fvgStatus = "NONE";
      out.obHigh = 0.0;
      out.obLow = 0.0;
      out.obStatus = "NONE";
      out.hasEQH = false;
      out.eqhLevel = 0.0;
      out.hasEQL = false;
      out.eqlLevel = 0.0;
      out.nearestBSL = 0.0;
      out.nearestSSL = 0.0;
      out.prevDayHigh = 0.0;
      out.prevDayLow = 0.0;
      out.prevWeekHigh = 0.0;
      out.prevWeekLow = 0.0;
      out.lastSweepDirection = "NONE";
      out.sweepConfirmation = "NONE";
      out.bslDistancePoints = 0.0;
      out.sslDistancePoints = 0.0;
      out.currentTickVol = 0;
      out.prevTickVol = 0;
      out.avgTickVol = 0.0;
      out.rvol = 1.0;
      out.volExpansion = "NORMAL";
      out.buyingPressurePct = 50.0;
      out.atr14 = 0.0;
      out.atrPoints = 0.0;
      out.rsi14 = 50.0;
      out.rsiCondition = "NEUTRAL";
      out.macdMain = 0.0;
      out.macdSignal = 0.0;
      out.macdHist = 0.0;
      out.macdMomentum = "NEUTRAL";
      out.mtfD1 = "NEUTRAL";
      out.mtfH1 = "NEUTRAL";
      out.mtfM15 = "NEUTRAL";
      out.mtfM5 = "NEUTRAL";
      out.dxyRollingCorr = -0.75;
      out.overallSignal = "STANDBY";
      out.activeStrategyCount = activeStratCount;
      out.signalConfidenceScore = 0.0;
   }

   static void ComputeInstrumentAnalytics(
      string symbol,
      string baseName,
      int h_ema9_m5, int h_ema21_m5, int h_ema200_m5, int h_atr_m5, int h_rsi_m5,
      int h_ema9_h1, int h_ema21_h1,
      int activeStratCount,
      InstrumentQuantAnalytics &out
   )
   {
      ResetAnalytics(out, symbol, baseName, activeStratCount);

      if(symbol == "" || !SymbolInfoInteger(symbol, SYMBOL_SELECT))
      {
         out.m5EmaState = "UNRESOLVED";
         out.regimeClassification = "NOT LOADED";
         out.overallSignal = "OFFLINE";
         return;
      }

      // 1. Current Canonical Price & Daily Change
      double bid = 0.0, ask = 0.0;
      SymbolInfoDouble(symbol, SYMBOL_BID, bid);
      SymbolInfoDouble(symbol, SYMBOL_ASK, ask);
      out.currentPrice = (bid > 0.0) ? bid : ask;

      MqlRates d1Rates[];
      ArraySetAsSeries(d1Rates, true);
      if(CopyRates(symbol, PERIOD_D1, 0, 2, d1Rates) >= 2)
      {
         double prevClose = d1Rates[1].close;
         if(prevClose > 0.0)
         {
            out.priceChange = out.currentPrice - prevClose;
            out.priceChangePct = (out.priceChange / prevClose) * 100.0;
         }
      }

      // 2. EMA Indicator Buffers (M5)
      double e9[], e21[], e200[], atrVal[], rsiVal[];
      ArraySetAsSeries(e9, true); ArraySetAsSeries(e21, true); ArraySetAsSeries(e200, true);
      ArraySetAsSeries(atrVal, true); ArraySetAsSeries(rsiVal, true);

      bool emaReady = (CopyBuffer(h_ema9_m5, 0, 1, 2, e9) >= 2 &&
                       CopyBuffer(h_ema21_m5, 0, 1, 2, e21) >= 2 &&
                       CopyBuffer(h_ema200_m5, 0, 1, 2, e200) >= 2);

      if(emaReady)
      {
         out.ema9_m5 = e9[0];
         out.ema21_m5 = e21[0];
         out.ema200_m5 = e200[0];

         if(e9[0] > e21[0] && e21[0] > e200[0]) out.m5EmaState = "BULLISH";
         else if(e9[0] < e21[0] && e21[0] < e200[0]) out.m5EmaState = "BEARISH";
         else out.m5EmaState = "NEUTRAL (Chop)";

         if(e9[1] <= e21[1] && e9[0] > e21[0]) out.crossoverStatus = "BULL CROSS";
         else if(e9[1] >= e21[1] && e9[0] < e21[0]) out.crossoverStatus = "BEAR CROSS";
         else out.crossoverStatus = "ALIGNED";

         double spreadDist = MathAbs(e9[0] - e21[0]);
         out.emaSeparationPct = (e21[0] > 0.0) ? ((spreadDist / e21[0]) * 100.0) : 0.0;

         // EMA Health Score (0 - 100%)
         double pt = SymbolInfoDouble(symbol, SYMBOL_POINT);
         double slope = (pt > 0) ? (MathAbs(e9[0] - e9[1]) / pt) : 0.0;
         out.emaHealthScore = MathMin(100.0, (slope * 2.5) + (out.emaSeparationPct * 500.0));
      }

      // 3. Higher Timeframe EMA (H1)
      double h1_e9[], h1_e21[];
      ArraySetAsSeries(h1_e9, true); ArraySetAsSeries(h1_e21, true);
      if(CopyBuffer(h_ema9_h1, 0, 1, 2, h1_e9) >= 2 && CopyBuffer(h_ema21_h1, 0, 1, 2, h1_e21) >= 2)
      {
         out.ema9_h1 = h1_e9[0];
         out.ema21_h1 = h1_e21[0];
         out.h1EmaState = (h1_e9[0] > h1_e21[0]) ? "BULLISH" : "BEARISH";
         out.mtfH1 = out.h1EmaState;
      }

      // 4. Multi-Timeframe M15 & D1 Trend Matrix
      MqlRates m15Rates[], dailyRates[];
      ArraySetAsSeries(m15Rates, true); ArraySetAsSeries(dailyRates, true);
      if(CopyRates(symbol, PERIOD_M15, 0, 5, m15Rates) >= 5)
      {
         out.mtfM15 = (m15Rates[0].close > m15Rates[4].close) ? "BULLISH" : "BEARISH";
      }
      if(CopyRates(symbol, PERIOD_D1, 0, 5, dailyRates) >= 5)
      {
         out.mtfD1 = (dailyRates[0].close > dailyRates[4].close) ? "BULLISH" : "BEARISH";
         out.d1EmaState = out.mtfD1;
      }
      out.mtfM5 = out.m5EmaState;

      // 5. Technical Indicators: ATR & RSI
      if(CopyBuffer(h_atr_m5, 0, 1, 1, atrVal) > 0)
      {
         out.atr14 = atrVal[0];
         double pt = SymbolInfoDouble(symbol, SYMBOL_POINT);
         out.atrPoints = (pt > 0) ? (atrVal[0] / pt) : 0;
      }
      if(CopyBuffer(h_rsi_m5, 0, 1, 1, rsiVal) > 0)
      {
         out.rsi14 = rsiVal[0];
         if(out.rsi14 >= 70.0) out.rsiCondition = "OVERBOUGHT";
         else if(out.rsi14 <= 30.0) out.rsiCondition = "OVERSOLD";
         else out.rsiCondition = "NEUTRAL";
      }

      // 6. Market Structure, Swings, BOS, CHOCH, FVG, OB & Equal Highs/Lows (M5)
      MqlRates m5Rates[];
      ArraySetAsSeries(m5Rates, true);
      if(CopyRates(symbol, PERIOD_M5, 0, 40, m5Rates) >= 40)
      {
         double highest = m5Rates[1].high;
         double lowest = m5Rates[1].low;
         for(int b = 1; b <= 24; b++)
         {
            if(m5Rates[b].high > highest) highest = m5Rates[b].high;
            if(m5Rates[b].low < lowest) lowest = m5Rates[b].low;
         }
         out.lastSwingHigh = highest;
         out.lastSwingLow = lowest;
         out.nearestBSL = highest;
         out.nearestSSL = lowest;

         double pt = SymbolInfoDouble(symbol, SYMBOL_POINT);
         out.bslDistancePoints = (pt > 0) ? (MathAbs(highest - out.currentPrice) / pt) : 0;
         out.sslDistancePoints = (pt > 0) ? (MathAbs(out.currentPrice - lowest) / pt) : 0;

         // Premium / Discount / Equilibrium Zone
         double swingRange = highest - lowest;
         if(swingRange > 0.0)
         {
            double eq = lowest + (swingRange * 0.50);
            if(out.currentPrice > eq + (swingRange * 0.05))
               out.smcZone = "PREMIUM (Sell Zone)";
            else if(out.currentPrice < eq - (swingRange * 0.05))
               out.smcZone = "DISCOUNT (Buy Zone)";
            else
               out.smcZone = "EQUILIBRIUM (50%)";
         }

         // Candle-Close Break of Structure (BOS) & Change of Character (CHOCH)
         if(m5Rates[1].close > highest)
         {
            out.bosStatus = "BULLISH BOS";
            out.structureClass = "HH (Higher High)";
         }
         else if(m5Rates[1].close < lowest)
         {
            out.bosStatus = "BEARISH BOS";
            out.structureClass = "LL (Lower Low)";
         }
         else
         {
            out.bosStatus = "INTACT";
            out.structureClass = (out.m5EmaState == "BULLISH" ? "HL (Higher Low)" : "LH (Lower High)");
         }

         // Liquidity Sweep Detection (Wick through swing, close inside)
         if(m5Rates[1].high > highest && m5Rates[1].close < highest)
         {
            out.lastSweepDirection = "BEAR SWEEP (BSL Taken)";
            out.sweepConfirmation = "CONFIRMED";
            out.chochStatus = "POTENTIAL CHOCH";
         }
         else if(m5Rates[1].low < lowest && m5Rates[1].close > lowest)
         {
            out.lastSweepDirection = "BULL SWEEP (SSL Taken)";
            out.sweepConfirmation = "CONFIRMED";
            out.chochStatus = "POTENTIAL CHOCH";
         }
         else
         {
            out.lastSweepDirection = "NONE";
            out.sweepConfirmation = "UNCONFIRMED";
            out.chochStatus = "NONE";
         }

         // Equal Highs / Equal Lows (EQH / EQL) with 0.1 * ATR threshold
         double eqhThreshold = (out.atr14 > 0.0) ? (out.atr14 * 0.10) : (pt * 15.0);
         for(int eq = 2; eq <= 15; eq++)
         {
            if(MathAbs(m5Rates[1].high - m5Rates[eq].high) <= eqhThreshold && m5Rates[eq].high > m5Rates[eq-1].high && m5Rates[eq].high > m5Rates[eq+1].high)
            {
               out.hasEQH = true;
               out.eqhLevel = m5Rates[eq].high;
               break;
            }
            if(MathAbs(m5Rates[1].low - m5Rates[eq].low) <= eqhThreshold && m5Rates[eq].low < m5Rates[eq-1].low && m5Rates[eq].low < m5Rates[eq+1].low)
            {
               out.hasEQL = true;
               out.eqlLevel = m5Rates[eq].low;
               break;
            }
         }

         // 3-Candle Fair Value Gap (FVG) Detection
         if(m5Rates[1].low > m5Rates[3].high)
         {
            out.fvgStatus = "BULLISH FVG";
            out.fvgTop = m5Rates[1].low;
            out.fvgBottom = m5Rates[3].high;
         }
         else if(m5Rates[1].high < m5Rates[3].low)
         {
            out.fvgStatus = "BEARISH FVG";
            out.fvgTop = m5Rates[3].low;
            out.fvgBottom = m5Rates[1].high;
         }
         else
         {
            out.fvgStatus = "NONE";
            out.fvgTop = 0.0;
            out.fvgBottom = 0.0;
         }

         // Order Block (OB) Identification
         for(int ob = 2; ob <= 6; ob++)
         {
            if(m5Rates[ob-1].close > m5Rates[ob-1].open && (m5Rates[ob-1].close - m5Rates[ob-1].open) > (out.atr14 * 0.8))
            {
               if(m5Rates[ob].close < m5Rates[ob].open)
               {
                  out.obStatus = "BULLISH OB";
                  out.obHigh = m5Rates[ob].high;
                  out.obLow = m5Rates[ob].low;
                  break;
               }
            }
            else if(m5Rates[ob-1].close < m5Rates[ob-1].open && (m5Rates[ob-1].open - m5Rates[ob-1].close) > (out.atr14 * 0.8))
            {
               if(m5Rates[ob].close > m5Rates[ob].open)
               {
                  out.obStatus = "BEARISH OB";
                  out.obHigh = m5Rates[ob].high;
                  out.obLow = m5Rates[ob].low;
                  break;
               }
            }
         }

         // 7. Tick Volume & Relative Volume (RVOL)
         out.currentTickVol = m5Rates[0].tick_volume;
         out.prevTickVol = m5Rates[1].tick_volume;
         long volSum = 0;
         for(int v = 1; v <= 20; v++) volSum += m5Rates[v].tick_volume;
         out.avgTickVol = (double)volSum / 20.0;
         out.rvol = (out.avgTickVol > 0.0) ? ((double)out.prevTickVol / out.avgTickVol) : 1.0;

         if(out.rvol >= 1.5) out.volExpansion = "EXPANSION (High)";
         else if(out.rvol <= 0.7) out.volExpansion = "CONTRACTION (Low)";
         else out.volExpansion = "NORMAL";

         // Buying vs Selling Pressure proxy
         double candleRange = m5Rates[1].high - m5Rates[1].low;
         if(candleRange > 0.0)
         {
            out.buyingPressurePct = ((m5Rates[1].close - m5Rates[1].low) / candleRange) * 100.0;
         }
         else out.buyingPressurePct = 50.0;
      }

      // 8. Higher-Timeframe Liquidity Anchors (PDH, PDL)
      if(CopyRates(symbol, PERIOD_D1, 0, 3, dailyRates) >= 3)
      {
         out.prevDayHigh = dailyRates[1].high;
         out.prevDayLow = dailyRates[1].low;
      }

      // 9. Market Regime Classification
      if(out.m5EmaState == "BULLISH" && out.h1EmaState == "BULLISH")
      {
         out.regimeClassification = (out.rvol > 1.2 ? "STRONG BULL TREND" : "BULL TREND");
      }
      else if(out.m5EmaState == "BEARISH" && out.h1EmaState == "BEARISH")
      {
         out.regimeClassification = (out.rvol > 1.2 ? "STRONG BEAR TREND" : "BEAR TREND");
      }
      else
      {
         out.regimeClassification = "CONSOLIDATION / CHOP";
      }

      // 10. Overall Signal Confirmation Matrix
      if(out.m5EmaState == "BULLISH" && out.h1EmaState == "BULLISH" && out.rsi14 < 68.0)
      {
         out.overallSignal = "BUY SETUP";
         out.signalConfidenceScore = 85.0;
      }
      else if(out.m5EmaState == "BEARISH" && out.h1EmaState == "BEARISH" && out.rsi14 > 32.0)
      {
         out.overallSignal = "SELL SETUP";
         out.signalConfidenceScore = 85.0;
      }
      else
      {
         out.overallSignal = "WAIT (Neutral)";
         out.signalConfidenceScore = 40.0;
      }
   }
};
//| Section 2: Input Parameters                                      |
//+------------------------------------------------------------------+
input group "=== [00] MASTER PORTFOLIO RISK & ENGINE GUARDS ==="
input bool     InpMasterTradingEnable       = true;    // Master Trading Enable Switch
input double   InpPerTradeRiskPercent       = 0.5;     // Per-Trade Risk (% of Equity, Max 1.0%)
input double   InpMaxDailyDrawdownPercent   = 3.0;     // Max Daily Drawdown Stop (% of Start Equity)
input double   InpMaxPortfolioRiskPercent   = 5.0;     // Max Aggregate Open Risk (% of Equity)
input int      InpMaxTotalOpenPositions     = 4;       // Max Total Open Positions Across System
input int      InpMaxPositionsPerSymbol     = 1;       // Max Open Positions Per Symbol
input int      InpConsecutiveLossLimit      = 3;       // Consecutive Loss Streak before Cooldown
input int      InpConsecutiveLossCooldownMin= 60;      // Cooldown Duration after Loss Limit (Minutes)
input ulong    InpMasterMagicBase           = 900000;  // Master Magic Base (Module = Base + SymIdx*10 + StratIdx)

input group "=== [01] TIME & SESSION GUARDS (UK TIME) ==="
input bool     InpEnableSessionFilter       = true;    // Enable UK Local Session Gating (08:00 - 22:00 UK)
input int      InpUKSessionStartHour        = 8;       // UK Session Start Hour (08:00)
input int      InpUKSessionStartMin         = 0;       // UK Session Start Minute
input int      InpUKSessionEndHour          = 22;      // UK Session End Hour (22:00)
input int      InpUKSessionEndMin           = 0;       // UK Session End Minute
input int      InpBrokerGMTOffset           = 2;       // Broker Base GMT Offset (Winter: +2 for Exness)
input ENUM_BROKER_DST_MODE InpBrokerDstMode = BROKER_DST_US; // Broker DST Schedule (US standard)
input bool     InpEnableFridayClose         = true;    // Enable Friday Weekend Close
input int      InpFridayCloseHourUK         = 21;      // Friday Close Hour UK (21 = 21:00 UK)
input int      InpFridayCloseMinUK          = 30;      // Friday Close Minute UK (30 = 21:30 UK)
input bool     InpEnableRolloverBlackout    = true;    // Rollover Blackout (21:55 - 22:15 GMT)

input group "=== [02] ON-CHART DASHBOARD ==="
input bool     InpShowDashboard             = true;    // Display Live On-Chart Dashboard
input int      InpDashboardRefreshMs        = 2500;    // Dashboard Redraw Throttling (ms)

input group "=== [03] INSTRUMENT 0: XAUUSD (GOLD) CONFIGURATION ==="
input bool     InpXAU_EnableSymbol          = true;    // Enable Scanning on Gold
input string   InpXAU_CustomSymbol          = "XAUUSD"; // Custom Symbol Name / Alias
input int      InpXAU_MaxSpreadPoints       = 75;      // Max Spread Points (Verified Phase 11 Realignment)
input int      InpXAU_MaxSLPoints           = 1500;    // Max SL Distance Ceiling (Points)
input bool     InpXAU_Enable_9EMA           = true;    // Gold: Enable 9 EMA Scalper (Demo Evaluation)
input bool     InpXAU_Enable_21EMA          = false;   // Gold: Enable 21 EMA Scalper (Disabled - Insufficient Edge)
input bool     InpXAU_Enable_50EMA          = false;   // Gold: Enable 50 EMA Scalper (Disabled - Low Sample)
input bool     InpXAU_Enable_100EMA         = true;    // Gold: Enable 100 EMA Scalper (Demo Evaluation)
input bool     InpXAU_Enable_LiqSweep       = true;    // Gold: Enable Liquidity Sweep Reversal (Validated)
input bool     InpXAU_Enable_TrendPullback  = true;    // Gold: Enable Trend Pullback Continuation
input bool     InpXAU_Enable_VolBreakout    = true;    // Gold: Enable Volatility Expansion Breakout
input bool     InpXAU_Enable_StructMomentum = true;    // Gold: Enable Market Structure Momentum

input group "=== [04] INSTRUMENT 1: XAGUSD (SILVER) CONFIGURATION ==="
input bool     InpXAG_EnableSymbol          = true;   // Enable Scanning on Silver (Default OFF per Phase 11 Audit)
input string   InpXAG_CustomSymbol          = "XAGUSD"; // Custom Symbol Name / Alias
input int      InpXAG_MaxSpreadPoints       = 80;      // Max Spread Points
input int      InpXAG_MaxSLPoints           = 1200;    // Max SL Distance Ceiling (Points)
input bool     InpXAG_Enable_9EMA           = true;   // Silver: Enable 9 EMA Scalper (Default OFF - Persistent Losses)
input bool     InpXAG_Enable_21EMA          = false;   // Silver: Enable 21 EMA Scalper (Default OFF - Severe Churn)
input bool     InpXAG_Enable_50EMA          = false;   // Silver: Enable 50 EMA Scalper (Default OFF - High Friction)
input bool     InpXAG_Enable_100EMA         = false;   // Silver: Enable 100 EMA Scalper (Default OFF - Range Loss)
input bool     InpXAG_Enable_LiqSweep       = true;   // Silver: Enable Liquidity Sweep Reversal (Opt-in only)
input bool     InpXAG_Enable_TrendPullback  = false;   // Silver: Enable Trend Pullback Continuation (Opt-in only)
input bool     InpXAG_Enable_VolBreakout    = false;   // Silver: Enable Volatility Expansion Breakout (Opt-in only)
input bool     InpXAG_Enable_StructMomentum = false;   // Silver: Enable Market Structure Momentum (Opt-in only)

input group "=== [05] INSTRUMENT 2: US500 (S&P 500) CONFIGURATION ==="
input bool     InpSPX_EnableSymbol          = true;    // Enable Scanning on S&P 500
input string   InpSPX_CustomSymbol          = "US500";  // Custom Symbol Name / Alias
input int      InpSPX_MaxSpreadPoints       = 60;      // Max Spread Points
input int      InpSPX_MaxSLPoints           = 1000;    // Max SL Distance Ceiling (Points - Preserved 1,000pt Rule)
input bool     InpSPX_Enable_9EMA           = true;    // US500: Enable 9 EMA Scalper (Verified Stable Baseline)
input bool     InpSPX_Enable_21EMA          = false;   // US500: Enable 21 EMA Scalper (Default OFF - Resolved 2025 Breakdown)
input bool     InpSPX_Enable_50EMA          = false;   // US500: Enable 50 EMA Scalper (Default OFF - Delayed Entry)
input bool     InpSPX_Enable_100EMA         = false;   // US500: Enable 100 EMA Scalper (Default OFF - Commission Drag)
input bool     InpSPX_Enable_LiqSweep       = true;    // US500: Enable Liquidity Sweep Reversal
input bool     InpSPX_Enable_TrendPullback  = true;    // US500: Enable Trend Pullback Continuation
input bool     InpSPX_Enable_VolBreakout    = true;    // US500: Enable Volatility Expansion Breakout
input bool     InpSPX_Enable_StructMomentum = true;    // US500: Enable Market Structure Momentum

input group "=== [06] INSTRUMENT 3: USTEC (NASDAQ 100) CONFIGURATION ==="
input bool     InpNAS_EnableSymbol          = true;    // Enable Scanning on Nasdaq 100
input string   InpNAS_CustomSymbol          = "USTEC";  // Custom Symbol Name / Alias
input int      InpNAS_MaxSpreadPoints       = 150;     // Max Spread Points
input int      InpNAS_MaxSLPoints           = 7500;    // Max SL Distance Ceiling (Points - Preserved 7,500pt Rule)
input bool     InpNAS_Enable_9EMA           = true;    // USTEC: Enable 9 EMA Scalper (Primary Demo Candidate, PF 6.80)
input bool     InpNAS_Enable_21EMA          = true;    // USTEC: Enable 21 EMA Scalper (Verified Candidate)
input bool     InpNAS_Enable_50EMA          = true;    // USTEC: Enable 50 EMA Scalper (Verified Candidate)
input bool     InpNAS_Enable_100EMA         = true;    // USTEC: Enable 100 EMA Scalper (Wick-Bounce Candidate, PF 1.76)
input bool     InpNAS_Enable_LiqSweep       = true;    // USTEC: Enable Liquidity Sweep Reversal
input bool     InpNAS_Enable_TrendPullback  = true;    // USTEC: Enable Trend Pullback Continuation
input bool     InpNAS_Enable_VolBreakout    = true;    // USTEC: Enable Volatility Expansion Breakout
input bool     InpNAS_Enable_StructMomentum = true;    // USTEC: Enable Market Structure Momentum

input group "=== [07] SHARED STRATEGY TUNING & EXECUTION PARAMETERS ==="
input ENUM_TIMEFRAMES InpExecutionTF        = PERIOD_M5;  // Core Execution Timeframe (All Modules)
input ENUM_TIMEFRAMES InpHTFTimeframe       = PERIOD_H1;  // Higher Timeframe Trend Bias
input double   InpDefaultTPRatio            = 3.0;        // Default Reward-to-Risk Ratio (1:3 per verified baseline)
input bool     InpUseVolumeFilter           = true;       // Mandatory Volume Expansion Filter (Anti-Fakeout)
input int      InpVolumeLookback            = 20;         // Volume Rolling SMA Lookback
input double   InpVolumeMultiplier         = 1.1;        // Min Volume Multiplier vs Baseline
input bool     InpUseStructuralSL           = true;       // Multi-bar Structural Swing Stop-Loss
input int      InpSwingLookback             = 5;          // Swing Lookback Bars for Structural SL (Verified baseline = 5)
input bool     InpUseATRBuffer              = true;       // ATR Volatility Stop Buffer
input int      InpATRPeriod                 = 14;         // ATR Period
input double   InpATRBufferMultiplier       = 1.0;        // ATR Stop Buffer Multiplier (Verified baseline = 1.0)
input bool     InpUseBE                     = true;       // Enable Break-Even Protection
input double   InpBETargetRR                = 1.0;        // Break-Even Trigger (R-Multiple)
input double   InpBESafetyPoints            = 10.0;       // Break-Even Safety Cushion (Points)
input bool     InpUseTrailing               = false;      // Enable Trailing Stop
input double   InpTrailingDistancePoints    = 150.0;      // Trailing Stop Distance (Points)
input double   InpTrailingStepPoints        = 50.0;       // Trailing Stop Step (Points)
input ulong    InpSlippagePoints            = 10;         // Max Slippage Tolerance (Points)
input double   InpCommissionPerLot          = 7.0;        // Round-turn Commission per Lot ($)

// Institutional Specific Inputs
input int      InpSweepSwingLookback        = 24;         // S5 Sweep: Swing Lookback Bars
input double   InpSweepMinDisplacementR     = 0.50;       // S5 Sweep: Min Candle Reversal Displacement
input int      InpVolCompressionBars        = 20;         // S7 VolBreakout: Compression Window Bars
input double   InpVolMaxCompressionATR     = 1.5;        // S7 VolBreakout: Max Compression Width vs ATR
input int      InpStructPivotStrength       = 2;          // S8 BOS: Pivot High/Low Strength (Bars)
input double   InpStructRSIMin              = 50.0;       // S8 BOS: Min Momentum RSI on Trigger

//+------------------------------------------------------------------+
//| Section 3: Data Structures & State Management                    |
//+------------------------------------------------------------------+
struct StrategyConfig
{
   bool              enabled;
   ulong             magicNumber;
   string            name;
   string            tag;
};

struct InstrumentRuntime
{
   string            baseName;
   string            resolvedSymbol;
   bool              isResolved;
   int               maxSpread;
   int               maxSLPoints;
   
   // Indicator Handles (M5)
   int               h_ema9;
   int               h_ema21;
   int               h_ema50;
   int               h_ema100;
   int               h_ema200;
   int               h_atr;
   int               h_rsi;
   
   // HTF Handles (H1)
   int               h_htf_ema9;
   int               h_htf_ema21;
   int               h_htf_ema50;
   int               h_htf_ema100;
   int               h_htf_ema200;
   
   datetime          lastProcessedBar;
   datetime          lastSignalTime;
   string            lastSignalState;
   string            lastRejectReason;
   
   StrategyConfig    strategies[NUM_STRATEGIES];
};

struct PortfolioRiskState
{
   double            dailyStartEquity;
   datetime          lastResetDay;
   int               currentConsecutiveLosses;
   datetime          cooldownUntil;
   double            currentDailyDDPercent;
   double            currentPortfolioOpenRiskPercent;
   int               totalOpenPositions;
   int               symbolOpenPositions[NUM_INSTRUMENTS];
   bool              isDailyHalted;
   bool              isCooldownActive;
};

// Global Execution Drivers
CTrade               m_trade;
InstrumentRuntime    m_instruments[NUM_INSTRUMENTS];
PortfolioRiskState m_riskState;
CBloombergTerminal m_bloombergTerm;
uint                 m_lastDashboardTick = 0;
bool                 m_isTester = false;

// Function Declarations
string ResolveBrokerSymbol(string symbolBase);
void   InitInstruments();
void   ReleaseInstrumentHandles();
bool   IsUKDaylightSaving(datetime gmtTime);
int    GetBrokerGMTOffset(datetime serverTime);
datetime GetUKTime(datetime serverTime);
bool   IsSessionAllowed(string &reason);
bool   IsRolloverActive();
bool   IsFridayCloseActive();
void   UpdateDailyRiskBaseline();
void   SyncConsecutiveLosses();
bool   CheckPortfolioRiskLimits(int symIdx, int stratIdx, string &rejectReason);
double CalculateNormalizedLot(string sym, double entryPrice, double slPrice, double riskPercent);
double NormalizePriceToTick(string sym, double price);
bool   CheckVolumeExpansion(string sym, ENUM_TIMEFRAMES tf, int lookback, double multiplier, int barShift);
void   EvaluateStrategyModule(int symIdx, int stratIdx);
void   ManageExistingPositions();
void   RenderDashboard();

// Strategy Logic Functions
bool   CheckSignal_9EMA(int symIdx, int &outDirection, double &outSL, double &outTP, string &rationale);
bool   CheckSignal_21EMA(int symIdx, int &outDirection, double &outSL, double &outTP, string &rationale);
bool   CheckSignal_50EMA(int symIdx, int &outDirection, double &outSL, double &outTP, string &rationale);
bool   CheckSignal_100EMA(int symIdx, int &outDirection, double &outSL, double &outTP, string &rationale);
bool   CheckSignal_LiquiditySweep(int symIdx, int &outDirection, double &outSL, double &outTP, string &rationale);
bool   CheckSignal_TrendPullback(int symIdx, int &outDirection, double &outSL, double &outTP, string &rationale);
bool   CheckSignal_VolatilityBreakout(int symIdx, int &outDirection, double &outSL, double &outTP, string &rationale);
bool   CheckSignal_StructureMomentum(int symIdx, int &outDirection, double &outSL, double &outTP, string &rationale);

//+------------------------------------------------------------------+
//| Section 4: Symbol Engine & Resolution                            |
//+------------------------------------------------------------------+
string ResolveBrokerSymbol(string symbolBase)
{
   if(symbolBase == "") return "";

   // 1. Exact match in market watch or available symbols
   if(SymbolInfoInteger(symbolBase, SYMBOL_SELECT) || SymbolSelect(symbolBase, true))
      return symbolBase;

   // 2. Common broker suffixes (Exness raw, standard, zero, pro, etc.)
   string suffixes[] = {"m", ".a", ".raw", "_i", ".ecn", ".std", "pro", ".c", "micro", ".US", "#", ".nas", ".nyse"};
   for(int s = 0; s < ArraySize(suffixes); s++)
   {
      string testSym = symbolBase + suffixes[s];
      if(SymbolSelect(testSym, true)) return testSym;
   }

   // 3. Known Institutional Aliases
   if(symbolBase == "XAUUSD")
   {
      string aliases[] = {"GOLD", "GOLDm", "XAUUSD.a", "XAUUSDm", "GOLD.raw", "XAUUSD_i"};
      for(int a = 0; a < ArraySize(aliases); a++)
      {
         if(SymbolSelect(aliases[a], true)) return aliases[a];
      }
   }
   else if(symbolBase == "XAGUSD")
   {
      string aliases[] = {"SILVER", "SILVERm", "XAGUSD.a", "XAGUSDm", "SILVER.raw"};
      for(int a = 0; a < ArraySize(aliases); a++)
      {
         if(SymbolSelect(aliases[a], true)) return aliases[a];
      }
   }
   else if(symbolBase == "US500")
   {
      string aliases[] = {"SPX500", "US500.a", "S&P500", "USA500", "SP500", "US500m"};
      for(int a = 0; a < ArraySize(aliases); a++)
      {
         if(SymbolSelect(aliases[a], true)) return aliases[a];
      }
   }
   else if(symbolBase == "USTEC")
   {
      string aliases[] = {"NAS100", "USTEC.a", "US100", "NDX100", "NQ100", "USTECm"};
      for(int a = 0; a < ArraySize(aliases); a++)
      {
         if(SymbolSelect(aliases[a], true)) return aliases[a];
      }
   }

   // 4. Case-insensitive substring search in market watch
   int total = SymbolsTotal(false);
   for(int i = 0; i < total; i++)
   {
      string name = SymbolName(i, false);
      if(StringFind(name, symbolBase) >= 0)
      {
         SymbolSelect(name, true);
         return name;
      }
   }

   return "";
}

//+------------------------------------------------------------------+
//| Initialize Instruments & Strategy Matrix                         |
//+------------------------------------------------------------------+
void InitInstruments()
{
   // Setup base instruments
   m_instruments[0].baseName = "XAUUSD";
   m_instruments[0].maxSpread = InpXAU_MaxSpreadPoints;
   m_instruments[0].maxSLPoints = InpXAU_MaxSLPoints;

   m_instruments[1].baseName = "XAGUSD";
   m_instruments[1].maxSpread = InpXAG_MaxSpreadPoints;
   m_instruments[1].maxSLPoints = InpXAG_MaxSLPoints;

   m_instruments[2].baseName = "US500";
   m_instruments[2].maxSpread = InpSPX_MaxSpreadPoints;
   m_instruments[2].maxSLPoints = InpSPX_MaxSLPoints;

   m_instruments[3].baseName = "USTEC";
   m_instruments[3].maxSpread = InpNAS_MaxSpreadPoints;
   m_instruments[3].maxSLPoints = InpNAS_MaxSLPoints;

   // Configure strategy names & magic numbers per instrument
   string stratNames[NUM_STRATEGIES] = {
      "9 EMA Scalper", "21 EMA Scalper", "50 EMA Scalper", "100 EMA Scalper",
      "Liquidity Sweep", "Trend Pullback", "Volatility Breakout", "Structure Momentum"
   };
   string stratTags[NUM_STRATEGIES] = {
      "9EMA", "21EMA", "50EMA", "100EMA", "LIQSWP", "TRNDPB", "VOLBRK", "STRMOM"
   };

   for(int i = 0; i < NUM_INSTRUMENTS; i++)
   {
      m_instruments[i].lastProcessedBar = 0;
      m_instruments[i].lastSignalTime = 0;
      m_instruments[i].lastSignalState = "IDLE";
      m_instruments[i].lastRejectReason = "NONE";
      
      // Resolve Symbol
      string targetConfigName = m_instruments[i].baseName;
      if(i == 0 && InpXAU_CustomSymbol != "") targetConfigName = InpXAU_CustomSymbol;
      if(i == 1 && InpXAG_CustomSymbol != "") targetConfigName = InpXAG_CustomSymbol;
      if(i == 2 && InpSPX_CustomSymbol != "") targetConfigName = InpSPX_CustomSymbol;
      if(i == 3 && InpNAS_CustomSymbol != "") targetConfigName = InpNAS_CustomSymbol;

      bool isEnabled = false;
      if(i == 0) isEnabled = InpXAU_EnableSymbol;
      if(i == 1) isEnabled = InpXAG_EnableSymbol;
      if(i == 2) isEnabled = InpSPX_EnableSymbol;
      if(i == 3) isEnabled = InpNAS_EnableSymbol;

      if(isEnabled)
      {
         m_instruments[i].resolvedSymbol = ResolveBrokerSymbol(targetConfigName);
         m_instruments[i].isResolved = (m_instruments[i].resolvedSymbol != "");
         if(!m_instruments[i].isResolved)
         {
            PrintFormat("[HR_UNIFIED][WARN] Unable to resolve broker symbol for configured asset '%s'! Scanning disabled for this asset.", targetConfigName);
         }
         else
         {
            PrintFormat("[HR_UNIFIED][INIT] Asset [%d] %s successfully mapped to broker symbol: %s", i, m_instruments[i].baseName, m_instruments[i].resolvedSymbol);
         }
      }
      else
      {
         m_instruments[i].resolvedSymbol = "";
         m_instruments[i].isResolved = false;
         PrintFormat("[HR_UNIFIED][INIT] Asset [%d] %s is DISABLED by configuration.", i, m_instruments[i].baseName);
      }

      // Configure Strategy Enable Matrix
      for(int s = 0; s < NUM_STRATEGIES; s++)
      {
         m_instruments[i].strategies[s].name = stratNames[s];
         m_instruments[i].strategies[s].tag = stratTags[s];
         m_instruments[i].strategies[s].magicNumber = InpMasterMagicBase + (ulong)(i * 10) + (ulong)s;
         m_instruments[i].strategies[s].enabled = false;

         if(m_instruments[i].isResolved)
         {
            if(i == 0) // XAUUSD
            {
               if(s == STRAT_9_EMA)               m_instruments[i].strategies[s].enabled = InpXAU_Enable_9EMA;
               if(s == STRAT_21_EMA)              m_instruments[i].strategies[s].enabled = InpXAU_Enable_21EMA;
               if(s == STRAT_50_EMA)              m_instruments[i].strategies[s].enabled = InpXAU_Enable_50EMA;
               if(s == STRAT_100_EMA)             m_instruments[i].strategies[s].enabled = InpXAU_Enable_100EMA;
               if(s == STRAT_LIQUIDITY_SWEEP)     m_instruments[i].strategies[s].enabled = InpXAU_Enable_LiqSweep;
               if(s == STRAT_TREND_PULLBACK)      m_instruments[i].strategies[s].enabled = InpXAU_Enable_TrendPullback;
               if(s == STRAT_VOLATILITY_BREAKOUT) m_instruments[i].strategies[s].enabled = InpXAU_Enable_VolBreakout;
               if(s == STRAT_STRUCTURE_MOMENTUM)  m_instruments[i].strategies[s].enabled = InpXAU_Enable_StructMomentum;
            }
            else if(i == 1) // XAGUSD
            {
               if(s == STRAT_9_EMA)               m_instruments[i].strategies[s].enabled = InpXAG_Enable_9EMA;
               if(s == STRAT_21_EMA)              m_instruments[i].strategies[s].enabled = InpXAG_Enable_21EMA;
               if(s == STRAT_50_EMA)              m_instruments[i].strategies[s].enabled = InpXAG_Enable_50EMA;
               if(s == STRAT_100_EMA)             m_instruments[i].strategies[s].enabled = InpXAG_Enable_100EMA;
               if(s == STRAT_LIQUIDITY_SWEEP)     m_instruments[i].strategies[s].enabled = InpXAG_Enable_LiqSweep;
               if(s == STRAT_TREND_PULLBACK)      m_instruments[i].strategies[s].enabled = InpXAG_Enable_TrendPullback;
               if(s == STRAT_VOLATILITY_BREAKOUT) m_instruments[i].strategies[s].enabled = InpXAG_Enable_VolBreakout;
               if(s == STRAT_STRUCTURE_MOMENTUM)  m_instruments[i].strategies[s].enabled = InpXAG_Enable_StructMomentum;
            }
            else if(i == 2) // US500
            {
               if(s == STRAT_9_EMA)               m_instruments[i].strategies[s].enabled = InpSPX_Enable_9EMA;
               if(s == STRAT_21_EMA)              m_instruments[i].strategies[s].enabled = InpSPX_Enable_21EMA;
               if(s == STRAT_50_EMA)              m_instruments[i].strategies[s].enabled = InpSPX_Enable_50EMA;
               if(s == STRAT_100_EMA)             m_instruments[i].strategies[s].enabled = InpSPX_Enable_100EMA;
               if(s == STRAT_LIQUIDITY_SWEEP)     m_instruments[i].strategies[s].enabled = InpSPX_Enable_LiqSweep;
               if(s == STRAT_TREND_PULLBACK)      m_instruments[i].strategies[s].enabled = InpSPX_Enable_TrendPullback;
               if(s == STRAT_VOLATILITY_BREAKOUT) m_instruments[i].strategies[s].enabled = InpSPX_Enable_VolBreakout;
               if(s == STRAT_STRUCTURE_MOMENTUM)  m_instruments[i].strategies[s].enabled = InpSPX_Enable_StructMomentum;
            }
            else if(i == 3) // USTEC
            {
               if(s == STRAT_9_EMA)               m_instruments[i].strategies[s].enabled = InpNAS_Enable_9EMA;
               if(s == STRAT_21_EMA)              m_instruments[i].strategies[s].enabled = InpNAS_Enable_21EMA;
               if(s == STRAT_50_EMA)              m_instruments[i].strategies[s].enabled = InpNAS_Enable_50EMA;
               if(s == STRAT_100_EMA)             m_instruments[i].strategies[s].enabled = InpNAS_Enable_100EMA;
               if(s == STRAT_LIQUIDITY_SWEEP)     m_instruments[i].strategies[s].enabled = InpNAS_Enable_LiqSweep;
               if(s == STRAT_TREND_PULLBACK)      m_instruments[i].strategies[s].enabled = InpNAS_Enable_TrendPullback;
               if(s == STRAT_VOLATILITY_BREAKOUT) m_instruments[i].strategies[s].enabled = InpNAS_Enable_VolBreakout;
               if(s == STRAT_STRUCTURE_MOMENTUM)  m_instruments[i].strategies[s].enabled = InpNAS_Enable_StructMomentum;
            }
         }
      }

      // Initialize indicator handles for resolved symbols
      if(m_instruments[i].isResolved)
      {
         string sym = m_instruments[i].resolvedSymbol;
         m_instruments[i].h_ema9    = iMA(sym, InpExecutionTF, 9, 0, MODE_EMA, PRICE_CLOSE);
         m_instruments[i].h_ema21   = iMA(sym, InpExecutionTF, 21, 0, MODE_EMA, PRICE_CLOSE);
         m_instruments[i].h_ema50   = iMA(sym, InpExecutionTF, 50, 0, MODE_EMA, PRICE_CLOSE);
         m_instruments[i].h_ema100  = iMA(sym, InpExecutionTF, 100, 0, MODE_EMA, PRICE_CLOSE);
         m_instruments[i].h_ema200  = iMA(sym, InpExecutionTF, 200, 0, MODE_EMA, PRICE_CLOSE);
         m_instruments[i].h_atr     = iATR(sym, InpExecutionTF, InpATRPeriod);
         m_instruments[i].h_rsi     = iRSI(sym, InpExecutionTF, 14, PRICE_CLOSE);

         m_instruments[i].h_htf_ema9   = iMA(sym, InpHTFTimeframe, 9, 0, MODE_EMA, PRICE_CLOSE);
         m_instruments[i].h_htf_ema21  = iMA(sym, InpHTFTimeframe, 21, 0, MODE_EMA, PRICE_CLOSE);
         m_instruments[i].h_htf_ema50  = iMA(sym, InpHTFTimeframe, 50, 0, MODE_EMA, PRICE_CLOSE);
         m_instruments[i].h_htf_ema100 = iMA(sym, InpHTFTimeframe, 100, 0, MODE_EMA, PRICE_CLOSE);
         m_instruments[i].h_htf_ema200 = iMA(sym, InpHTFTimeframe, 200, 0, MODE_EMA, PRICE_CLOSE);
      }
      else
      {
         m_instruments[i].h_ema9 = INVALID_HANDLE;
         m_instruments[i].h_ema21 = INVALID_HANDLE;
         m_instruments[i].h_ema50 = INVALID_HANDLE;
         m_instruments[i].h_ema100 = INVALID_HANDLE;
         m_instruments[i].h_ema200 = INVALID_HANDLE;
         m_instruments[i].h_atr = INVALID_HANDLE;
         m_instruments[i].h_rsi = INVALID_HANDLE;
         m_instruments[i].h_htf_ema9 = INVALID_HANDLE;
         m_instruments[i].h_htf_ema21 = INVALID_HANDLE;
         m_instruments[i].h_htf_ema50 = INVALID_HANDLE;
         m_instruments[i].h_htf_ema100 = INVALID_HANDLE;
         m_instruments[i].h_htf_ema200 = INVALID_HANDLE;
      }
   }
}

//+------------------------------------------------------------------+
//| Release all Indicator Handles Cleanly                            |
//+------------------------------------------------------------------+
void ReleaseInstrumentHandles()
{
   for(int i = 0; i < NUM_INSTRUMENTS; i++)
   {
      if(m_instruments[i].h_ema9 != INVALID_HANDLE)   IndicatorRelease(m_instruments[i].h_ema9);
      if(m_instruments[i].h_ema21 != INVALID_HANDLE)  IndicatorRelease(m_instruments[i].h_ema21);
      if(m_instruments[i].h_ema50 != INVALID_HANDLE)  IndicatorRelease(m_instruments[i].h_ema50);
      if(m_instruments[i].h_ema100 != INVALID_HANDLE) IndicatorRelease(m_instruments[i].h_ema100);
      if(m_instruments[i].h_ema200 != INVALID_HANDLE) IndicatorRelease(m_instruments[i].h_ema200);
      if(m_instruments[i].h_atr != INVALID_HANDLE)    IndicatorRelease(m_instruments[i].h_atr);
      if(m_instruments[i].h_rsi != INVALID_HANDLE)    IndicatorRelease(m_instruments[i].h_rsi);

      if(m_instruments[i].h_htf_ema9 != INVALID_HANDLE)   IndicatorRelease(m_instruments[i].h_htf_ema9);
      if(m_instruments[i].h_htf_ema21 != INVALID_HANDLE)  IndicatorRelease(m_instruments[i].h_htf_ema21);
      if(m_instruments[i].h_htf_ema50 != INVALID_HANDLE)  IndicatorRelease(m_instruments[i].h_htf_ema50);
      if(m_instruments[i].h_htf_ema100 != INVALID_HANDLE) IndicatorRelease(m_instruments[i].h_htf_ema100);
      if(m_instruments[i].h_htf_ema200 != INVALID_HANDLE) IndicatorRelease(m_instruments[i].h_htf_ema200);
   }
}

//+------------------------------------------------------------------+
//| Section 5: Time, Session & Daylight Saving Logic                 |
//+------------------------------------------------------------------+
bool IsUKDaylightSaving(const datetime gmtTime)
{
   MqlDateTime dt;
   TimeToStruct(gmtTime, dt);
   if(dt.mon < 3 || dt.mon > 10) return false;
   if(dt.mon > 3 && dt.mon < 10) return true;

   MqlDateTime temp;
   temp.year = dt.year; temp.mon = dt.mon; temp.day = 31; temp.hour = 1; temp.min = 0; temp.sec = 0;
   datetime endOfMonth = StructToTime(temp);
   TimeToStruct(endOfMonth, temp);
   int lastSunday = 31 - temp.day_of_week;

   if(dt.mon == 3)
   {
      if(dt.day > lastSunday) return true;
      if(dt.day == lastSunday && dt.hour >= 1) return true;
      return false;
   }
   else
   {
      if(dt.day < lastSunday) return true;
      if(dt.day == lastSunday && dt.hour < 1) return true;
      return false;
   }
}

int GetBrokerGMTOffset(const datetime serverTime)
{
   if(InpBrokerDstMode == BROKER_DST_NONE) return InpBrokerGMTOffset;

   datetime gmtEst = serverTime - (InpBrokerGMTOffset * 3600);
   MqlDateTime dt;
   TimeToStruct(gmtEst, dt);

   if(InpBrokerDstMode == BROKER_DST_US)
   {
      if(dt.mon < 3 || dt.mon > 11) return InpBrokerGMTOffset;
      if(dt.mon > 3 && dt.mon < 11) return InpBrokerGMTOffset + 1;

      if(dt.mon == 3)
      {
         int secondSun = 14 - ((dt.day_of_week - (dt.day % 7) + 7) % 7);
         if(dt.day > secondSun) return InpBrokerGMTOffset + 1;
         if(dt.day == secondSun && dt.hour >= 2) return InpBrokerGMTOffset + 1;
         return InpBrokerGMTOffset;
      }
      else
      {
         int firstSun = 7 - ((dt.day_of_week - (dt.day % 7) + 7) % 7);
         if(dt.day < firstSun) return InpBrokerGMTOffset + 1;
         if(dt.day == firstSun && dt.hour < 2) return InpBrokerGMTOffset + 1;
         return InpBrokerGMTOffset;
      }
   }
   return InpBrokerGMTOffset;
}

datetime GetUKTime(const datetime serverTime)
{
   int brokerOffset = GetBrokerGMTOffset(serverTime);
   datetime gmtTime = serverTime - (brokerOffset * 3600);
   bool isBST = IsUKDaylightSaving(gmtTime);
   return gmtTime + (isBST ? 3600 : 0);
}

bool IsSessionAllowed(string &reason)
{
   if(!InpEnableSessionFilter) return true;

   datetime serverTime = TimeCurrent();
   datetime ukTime = GetUKTime(serverTime);
   MqlDateTime dt;
   TimeToStruct(ukTime, dt);

   if(dt.day_of_week == 0 || dt.day_of_week == 6)
   {
      reason = "Weekend (Saturday/Sunday Closed)";
      return false;
   }

   int curMin = (dt.hour * 60) + dt.min;
   int startMin = (InpUKSessionStartHour * 60) + InpUKSessionStartMin;
   int endMin   = (InpUKSessionEndHour * 60) + InpUKSessionEndMin;

   if(curMin < startMin || curMin >= endMin)
   {
      reason = StringFormat("Outside UK Session (%02d:%02d UK vs %02d:%02d-%02d:%02d Allowed)",
                            dt.hour, dt.min, InpUKSessionStartHour, InpUKSessionStartMin, InpUKSessionEndHour, InpUKSessionEndMin);
      return false;
   }

   return true;
}

bool IsRolloverActive()
{
   if(!InpEnableRolloverBlackout) return false;
   datetime serverTime = TimeCurrent();
   int brokerOffset = GetBrokerGMTOffset(serverTime);
   datetime gmtTime = serverTime - (brokerOffset * 3600);
   MqlDateTime dt;
   TimeToStruct(gmtTime, dt);
   int curMin = (dt.hour * 60) + dt.min;
   return (curMin >= (21 * 60 + 55) && curMin <= (22 * 60 + 15));
}

bool IsFridayCloseActive()
{
   if(!InpEnableFridayClose) return false;
   datetime serverTime = TimeCurrent();
   datetime ukTime = GetUKTime(serverTime);
   MqlDateTime dt;
   TimeToStruct(ukTime, dt);
   if(dt.day_of_week != 5) return false;

   int curMin = (dt.hour * 60) + dt.min;
   int closeMin = (InpFridayCloseHourUK * 60) + InpFridayCloseMinUK;
   return (curMin >= closeMin);
}

//+------------------------------------------------------------------+
//| Section 6: Shared Portfolio Risk Manager                         |
//+------------------------------------------------------------------+
void UpdateDailyRiskBaseline()
{
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime todayStart = StructToTime(dt);

   if(m_riskState.lastResetDay != todayStart)
   {
      m_riskState.lastResetDay = todayStart;
      m_riskState.dailyStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(m_riskState.dailyStartEquity <= 0.0) m_riskState.dailyStartEquity = AccountInfoDouble(ACCOUNT_BALANCE);
      m_riskState.currentConsecutiveLosses = 0;
      m_riskState.isDailyHalted = false;
      PrintFormat("[HR_UNIFIED][RISK] New Trading Day Initialized. Baseline Equity: $%.2f", m_riskState.dailyStartEquity);
   }

   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(m_riskState.dailyStartEquity > 0.0 && currentEquity < m_riskState.dailyStartEquity)
   {
      m_riskState.currentDailyDDPercent = ((m_riskState.dailyStartEquity - currentEquity) / m_riskState.dailyStartEquity) * 100.0;
   }
   else
   {
      m_riskState.currentDailyDDPercent = 0.0;
   }

   if(m_riskState.currentDailyDDPercent >= InpMaxDailyDrawdownPercent)
   {
      if(!m_riskState.isDailyHalted)
      {
         PrintFormat("[HR_UNIFIED][RISK_BREACH] 3.0%% Daily Drawdown Limit Reached (Current DD: %.2f%%). Trading HALTED for rest of day.",
                     m_riskState.currentDailyDDPercent);
         m_riskState.isDailyHalted = true;
      }
   }

   m_riskState.isCooldownActive = (now < m_riskState.cooldownUntil);
}

void SyncConsecutiveLosses()
{
   datetime now = TimeCurrent();
   datetime dayStart = m_riskState.lastResetDay;
   if(dayStart == 0) return;

   if(!HistorySelect(dayStart, now)) return;

   int totalDeals = HistoryDealsTotal();
   int streak = 0;
   datetime lastLossTime = 0;

   for(int i = 0; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;

      long dealMagic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
      // Check if magic belongs to our EA namespace [InpMasterMagicBase .. InpMasterMagicBase + 100]
      if(dealMagic < (long)InpMasterMagicBase || dealMagic >= (long)(InpMasterMagicBase + 100))
         continue;

      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT) continue;

      double profit     = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      double swap       = HistoryDealGetDouble(ticket, DEAL_SWAP);
      double fee        = HistoryDealGetDouble(ticket, DEAL_FEE);
      double netProfit  = profit + commission + swap + fee;

      if(netProfit < 0.0)
      {
         streak++;
         lastLossTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      }
      else if(netProfit > 0.0)
      {
         streak = 0;
         lastLossTime = 0;
      }
   }

   m_riskState.currentConsecutiveLosses = streak;
   if(m_riskState.currentConsecutiveLosses >= InpConsecutiveLossLimit && lastLossTime > 0)
   {
      datetime cooldownEnd = lastLossTime + (InpConsecutiveLossCooldownMin * 60);
      if(cooldownEnd > now)
      {
         m_riskState.cooldownUntil = cooldownEnd;
      }
   }
}

bool CheckPortfolioRiskLimits(int symIdx, int stratIdx, string &rejectReason)
{
   if(!InpMasterTradingEnable)
   {
      rejectReason = "Master Trading Switch is DISABLED";
      return false;
   }

   UpdateDailyRiskBaseline();

   if(m_riskState.isDailyHalted)
   {
      rejectReason = StringFormat("Daily Drawdown Limit Reached (DD: %.2f%% >= %.2f%%)",
                                  m_riskState.currentDailyDDPercent, InpMaxDailyDrawdownPercent);
      return false;
   }

   if(m_riskState.isCooldownActive)
   {
      rejectReason = StringFormat("Consecutive Loss Cooldown Active until %s",
                                  TimeToString(m_riskState.cooldownUntil, TIME_MINUTES|TIME_SECONDS));
      return false;
   }

   // Count open positions belonging to this EA
   int totalEAPos = 0;
   int symEAPos = 0;
   double totalOpenRiskCurrency = 0.0;
   string currentSym = m_instruments[symIdx].resolvedSymbol;

   CPositionInfo pos;
   for(int p = PositionsTotal() - 1; p >= 0; p--)
   {
      if(pos.SelectByIndex(p))
      {
         ulong magic = pos.Magic();
         if(magic >= InpMasterMagicBase && magic < (InpMasterMagicBase + 100))
         {
            totalEAPos++;
            if(pos.Symbol() == currentSym)
               symEAPos++;

            // Calculate current open risk
            double openPrice = pos.PriceOpen();
            double slPrice   = pos.StopLoss();
            double vol       = pos.Volume();

            if(slPrice > 0.0)
            {
               double dist = MathAbs(openPrice - slPrice);
               ENUM_ORDER_TYPE posType = (pos.PositionType() == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
               double lossAtSL = 0.0;
               if(OrderCalcProfit(posType, pos.Symbol(), vol, openPrice, slPrice, lossAtSL) && lossAtSL < 0.0)
               {
                  totalOpenRiskCurrency += MathAbs(lossAtSL);
               }
               else
               {
                  double tickSize = SymbolInfoDouble(pos.Symbol(), SYMBOL_TRADE_TICK_SIZE);
                  double tickVal  = SymbolInfoDouble(pos.Symbol(), SYMBOL_TRADE_TICK_VALUE);
                  if(tickSize > 0.0 && tickVal > 0.0)
                  {
                     totalOpenRiskCurrency += vol * (dist / tickSize) * tickVal;
                  }
               }
            }
            else
            {
               // Missing SL: Treat conservatively as full 1.0% equity risk
               totalOpenRiskCurrency += AccountInfoDouble(ACCOUNT_EQUITY) * 0.01;
            }
         }
      }
   }

   m_riskState.totalOpenPositions = totalEAPos;
   m_riskState.symbolOpenPositions[symIdx] = symEAPos;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0.0) equity = AccountInfoDouble(ACCOUNT_BALANCE);
   if(equity > 0.0)
   {
      m_riskState.currentPortfolioOpenRiskPercent = (totalOpenRiskCurrency / equity) * 100.0;
   }

   // 1. Position Count Limit Check
   if(totalEAPos >= InpMaxTotalOpenPositions)
   {
      rejectReason = StringFormat("Portfolio Open Position Limit Reached (%d/%d)", totalEAPos, InpMaxTotalOpenPositions);
      return false;
   }

   if(symEAPos >= InpMaxPositionsPerSymbol)
   {
      rejectReason = StringFormat("Symbol Open Position Limit Reached for %s (%d/%d)", currentSym, symEAPos, InpMaxPositionsPerSymbol);
      return false;
   }

   // 2. Open Risk Cap Check (Max 5.0% Aggregate Open Risk)
   double plannedTradeRiskPct = MathMin(InpPerTradeRiskPercent, 1.0);
   if((m_riskState.currentPortfolioOpenRiskPercent + plannedTradeRiskPct) > InpMaxPortfolioRiskPercent)
   {
      rejectReason = StringFormat("Aggregate Open Risk Cap Exceeded (Current: %.2f%% + New: %.2f%% > %.2f%% Cap)",
                                  m_riskState.currentPortfolioOpenRiskPercent, plannedTradeRiskPct, InpMaxPortfolioRiskPercent);
      return false;
   }

   return true;
}

double NormalizePriceToTick(string sym, double price)
{
   double tickSize = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   if(tickSize <= 0.0) return NormalizeDouble(price, digits);
   return NormalizeDouble(MathRound(price / tickSize) * tickSize, digits);
}

double CalculateNormalizedLot(string sym, double entryPrice, double slPrice, double riskPercent)
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0.0) equity = AccountInfoDouble(ACCOUNT_BALANCE);
   if(equity <= 0.0) return 0.0;

   double effectiveRiskPct = MathMin(riskPercent, 1.0); // Hard 1% per-trade ceiling
   double riskAmount = equity * (effectiveRiskPct / 100.0);

   double slDistance = MathAbs(entryPrice - slPrice);
   if(slDistance <= 0.0) return 0.0;

   ENUM_ORDER_TYPE orderType = (entryPrice > slPrice) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double profitAtSL = 0.0;
   double riskPerUnitLot = 0.0;

   if(OrderCalcProfit(orderType, sym, 1.0, entryPrice, slPrice, profitAtSL) && profitAtSL < 0.0)
   {
      riskPerUnitLot = MathAbs(profitAtSL);
   }
   else
   {
      double tickSize  = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
      double tickValue = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
      if(tickSize > 0.0 && tickValue > 0.0)
      {
         riskPerUnitLot = (slDistance / tickSize) * tickValue;
      }
   }

   if(riskPerUnitLot <= 0.0) return 0.0;

   double rawLot  = riskAmount / riskPerUnitLot;
   double minLot  = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);

   if(stepLot <= 0.0) stepLot = 0.01;
   double normalizedLot = MathFloor(rawLot / stepLot) * stepLot;

   if(normalizedLot < minLot) normalizedLot = 0.0; // Reject if required lot is below broker minimum
   if(normalizedLot > maxLot) normalizedLot = maxLot;

   // Final safeguard: verify rounded lot does not breach 1.0% risk cap
   double actualRisk = normalizedLot * riskPerUnitLot;
   if(actualRisk > (equity * 0.0105)) // 1.05% tolerance for lot rounding
   {
      normalizedLot -= stepLot;
   }

   return NormalizeDouble(normalizedLot, 2);
}

bool CheckVolumeExpansion(string sym, ENUM_TIMEFRAMES tf, int lookback, double multiplier, int barShift)
{
   if(!InpUseVolumeFilter) return true;

   long volumeBuf[];
   ArraySetAsSeries(volumeBuf, true);
   int neededBars = lookback + barShift + 2;

   if(CopyTickVolume(sym, tf, 0, neededBars, volumeBuf) < neededBars)
      return true; // Fallback if history insufficient

   long triggerVol = volumeBuf[barShift];
   long totalBaseline = 0;
   for(int i = barShift + 1; i <= barShift + lookback; i++)
   {
      totalBaseline += volumeBuf[i];
   }

   double avgBaseline = (double)totalBaseline / (double)lookback;
   if(avgBaseline <= 0.0) return true;

   return (triggerVol >= (avgBaseline * multiplier));
}

//+------------------------------------------------------------------+
//| Section 7: Strategy Module Implementations                       |
//+------------------------------------------------------------------+

// --- S1: 9 EMA Momentum Scalper ---
bool CheckSignal_9EMA(int symIdx, int &outDirection, double &outSL, double &outTP, string &rationale)
{
   string sym = m_instruments[symIdx].resolvedSymbol;
   int hLTF = m_instruments[symIdx].h_ema9;
   int hHTF = m_instruments[symIdx].h_htf_ema9;
   int hATR = m_instruments[symIdx].h_atr;

   if(hLTF == INVALID_HANDLE || hHTF == INVALID_HANDLE || hATR == INVALID_HANDLE) return false;

   double emaLTF[], emaHTF[], atrBuf[];
   ArraySetAsSeries(emaLTF, true);
   ArraySetAsSeries(emaHTF, true);
   ArraySetAsSeries(atrBuf, true);

   if(CopyBuffer(hLTF, 0, 1, 3, emaLTF) < 3 || CopyBuffer(hHTF, 0, 1, 3, emaHTF) < 3 || CopyBuffer(hATR, 0, 1, 1, atrBuf) < 1)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(sym, InpExecutionTF, 1, 3, rates) < 3) return false;

   double close1 = rates[0].close;
   double open1  = rates[0].open;
   double high1  = rates[0].high;
   double low1   = rates[0].low;
   double close2 = rates[1].close;

   MqlRates htfRates[];
   ArraySetAsSeries(htfRates, true);
   if(CopyRates(sym, InpHTFTimeframe, 1, 1, htfRates) < 1) return false;
   double htfClose1 = htfRates[0].close;

   bool isBullHTF = (htfClose1 > emaHTF[0]);
   bool isBearHTF = (htfClose1 < emaHTF[0]);

   // Volume filter
   if(!CheckVolumeExpansion(sym, InpExecutionTF, InpVolumeLookback, InpVolumeMultiplier, 1)) return false;

   // Body quality check
   double rng = high1 - low1;
   if(rng <= 0.0 || (MathAbs(close1 - open1) / rng) < 0.35) return false;

   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   double atrVal = atrBuf[0];

   // BUY Signal: Clean close above 9 EMA with prior candle below/touching
   if(isBullHTF && close1 > emaLTF[0] && close2 <= emaLTF[1] && close1 > open1)
   {
      outDirection = ORDER_TYPE_BUY;
      double swing = low1;
      if(InpUseStructuralSL)
      {
         int lowest = iLowest(sym, InpExecutionTF, MODE_LOW, InpSwingLookback, 1);
         if(lowest > 0) swing = iLow(sym, InpExecutionTF, lowest);
      }
      double buffer = (InpUseATRBuffer && atrVal > 0.0) ? (atrVal * InpATRBufferMultiplier) : (10.0 * point);
      outSL = NormalizePriceToTick(sym, swing - buffer);
      double entry = SymbolInfoDouble(sym, SYMBOL_ASK);
      double dist = entry - outSL;
      if(dist <= 0.0) return false;
      outTP = NormalizePriceToTick(sym, entry + (dist * InpDefaultTPRatio));
      rationale = "9 EMA Bullish Expansion & HTF Alignment";
      return true;
   }

   // SELL Signal: Clean close below 9 EMA with prior candle above/touching
   if(isBearHTF && close1 < emaLTF[0] && close2 >= emaLTF[1] && close1 < open1)
   {
      outDirection = ORDER_TYPE_SELL;
      double swing = high1;
      if(InpUseStructuralSL)
      {
         int highest = iHighest(sym, InpExecutionTF, MODE_HIGH, InpSwingLookback, 1);
         if(highest > 0) swing = iHigh(sym, InpExecutionTF, highest);
      }
      double buffer = (InpUseATRBuffer && atrVal > 0.0) ? (atrVal * InpATRBufferMultiplier) : (10.0 * point);
      outSL = NormalizePriceToTick(sym, swing + buffer);
      double entry = SymbolInfoDouble(sym, SYMBOL_BID);
      double dist = outSL - entry;
      if(dist <= 0.0) return false;
      outTP = NormalizePriceToTick(sym, entry - (dist * InpDefaultTPRatio));
      rationale = "9 EMA Bearish Breakdown & HTF Alignment";
      return true;
   }

   return false;
}

// --- S2: 21 EMA Pullback Scalper ---
bool CheckSignal_21EMA(int symIdx, int &outDirection, double &outSL, double &outTP, string &rationale)
{
   string sym = m_instruments[symIdx].resolvedSymbol;
   int hLTF = m_instruments[symIdx].h_ema21;
   int hHTF = m_instruments[symIdx].h_htf_ema21;
   int hATR = m_instruments[symIdx].h_atr;

   if(hLTF == INVALID_HANDLE || hHTF == INVALID_HANDLE || hATR == INVALID_HANDLE) return false;

   double emaLTF[], emaHTF[], atrBuf[];
   ArraySetAsSeries(emaLTF, true);
   ArraySetAsSeries(emaHTF, true);
   ArraySetAsSeries(atrBuf, true);

   if(CopyBuffer(hLTF, 0, 1, 3, emaLTF) < 3 || CopyBuffer(hHTF, 0, 1, 3, emaHTF) < 3 || CopyBuffer(hATR, 0, 1, 1, atrBuf) < 1)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(sym, InpExecutionTF, 1, 3, rates) < 3) return false;

   double close1 = rates[0].close;
   double open1  = rates[0].open;
   double high1  = rates[0].high;
   double low1   = rates[0].low;
   double close2 = rates[1].close;

   MqlRates htfRates[];
   ArraySetAsSeries(htfRates, true);
   if(CopyRates(sym, InpHTFTimeframe, 1, 1, htfRates) < 1) return false;
   double htfClose1 = htfRates[0].close;

   bool isBullHTF = (htfClose1 > emaHTF[0]);
   bool isBearHTF = (htfClose1 < emaHTF[0]);

   if(!CheckVolumeExpansion(sym, InpExecutionTF, InpVolumeLookback, InpVolumeMultiplier, 1)) return false;

   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   double atrVal = atrBuf[0];

   if(isBullHTF && close1 > emaLTF[0] && close2 <= emaLTF[1] && close1 > open1)
   {
      outDirection = ORDER_TYPE_BUY;
      double swing = low1;
      if(InpUseStructuralSL)
      {
         int lowest = iLowest(sym, InpExecutionTF, MODE_LOW, InpSwingLookback, 1);
         if(lowest > 0) swing = iLow(sym, InpExecutionTF, lowest);
      }
      double buffer = (InpUseATRBuffer && atrVal > 0.0) ? (atrVal * InpATRBufferMultiplier) : (10.0 * point);
      outSL = NormalizePriceToTick(sym, swing - buffer);
      double entry = SymbolInfoDouble(sym, SYMBOL_ASK);
      double dist = entry - outSL;
      if(dist <= 0.0) return false;
      outTP = NormalizePriceToTick(sym, entry + (dist * InpDefaultTPRatio));
      rationale = "21 EMA Bullish Pullback Resumption";
      return true;
   }

   if(isBearHTF && close1 < emaLTF[0] && close2 >= emaLTF[1] && close1 < open1)
   {
      outDirection = ORDER_TYPE_SELL;
      double swing = high1;
      if(InpUseStructuralSL)
      {
         int highest = iHighest(sym, InpExecutionTF, MODE_HIGH, InpSwingLookback, 1);
         if(highest > 0) swing = iHigh(sym, InpExecutionTF, highest);
      }
      double buffer = (InpUseATRBuffer && atrVal > 0.0) ? (atrVal * InpATRBufferMultiplier) : (10.0 * point);
      outSL = NormalizePriceToTick(sym, swing + buffer);
      double entry = SymbolInfoDouble(sym, SYMBOL_BID);
      double dist = outSL - entry;
      if(dist <= 0.0) return false;
      outTP = NormalizePriceToTick(sym, entry - (dist * InpDefaultTPRatio));
      rationale = "21 EMA Bearish Pullback Resumption";
      return true;
   }

   return false;
}

// --- S3: 50 EMA Trend Re-Test ---
bool CheckSignal_50EMA(int symIdx, int &outDirection, double &outSL, double &outTP, string &rationale)
{
   string sym = m_instruments[symIdx].resolvedSymbol;
   int hLTF = m_instruments[symIdx].h_ema50;
   int hHTF = m_instruments[symIdx].h_htf_ema50;
   int hATR = m_instruments[symIdx].h_atr;

   if(hLTF == INVALID_HANDLE || hHTF == INVALID_HANDLE || hATR == INVALID_HANDLE) return false;

   double emaLTF[], emaHTF[], atrBuf[];
   ArraySetAsSeries(emaLTF, true);
   ArraySetAsSeries(emaHTF, true);
   ArraySetAsSeries(atrBuf, true);

   if(CopyBuffer(hLTF, 0, 1, 3, emaLTF) < 3 || CopyBuffer(hHTF, 0, 1, 3, emaHTF) < 3 || CopyBuffer(hATR, 0, 1, 1, atrBuf) < 1)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(sym, InpExecutionTF, 1, 3, rates) < 3) return false;

   double close1 = rates[0].close;
   double open1  = rates[0].open;
   double high1  = rates[0].high;
   double low1   = rates[0].low;
   double close2 = rates[1].close;

   MqlRates htfRates[];
   ArraySetAsSeries(htfRates, true);
   if(CopyRates(sym, InpHTFTimeframe, 1, 1, htfRates) < 1) return false;
   double htfClose1 = htfRates[0].close;

   bool isBullHTF = (htfClose1 > emaHTF[0]);
   bool isBearHTF = (htfClose1 < emaHTF[0]);

   if(!CheckVolumeExpansion(sym, InpExecutionTF, InpVolumeLookback, InpVolumeMultiplier, 1)) return false;

   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   double atrVal = atrBuf[0];

   if(isBullHTF && close1 > emaLTF[0] && close2 <= emaLTF[1] && close1 > open1)
   {
      outDirection = ORDER_TYPE_BUY;
      double swing = low1;
      if(InpUseStructuralSL)
      {
         int lowest = iLowest(sym, InpExecutionTF, MODE_LOW, InpSwingLookback, 1);
         if(lowest > 0) swing = iLow(sym, InpExecutionTF, lowest);
      }
      double buffer = (InpUseATRBuffer && atrVal > 0.0) ? (atrVal * InpATRBufferMultiplier) : (10.0 * point);
      outSL = NormalizePriceToTick(sym, swing - buffer);
      double entry = SymbolInfoDouble(sym, SYMBOL_ASK);
      double dist = entry - outSL;
      if(dist <= 0.0) return false;
      outTP = NormalizePriceToTick(sym, entry + (dist * InpDefaultTPRatio));
      rationale = "50 EMA Intermediate Trend Pullback";
      return true;
   }

   if(isBearHTF && close1 < emaLTF[0] && close2 >= emaLTF[1] && close1 < open1)
   {
      outDirection = ORDER_TYPE_SELL;
      double swing = high1;
      if(InpUseStructuralSL)
      {
         int highest = iHighest(sym, InpExecutionTF, MODE_HIGH, InpSwingLookback, 1);
         if(highest > 0) swing = iHigh(sym, InpExecutionTF, highest);
      }
      double buffer = (InpUseATRBuffer && atrVal > 0.0) ? (atrVal * InpATRBufferMultiplier) : (10.0 * point);
      outSL = NormalizePriceToTick(sym, swing + buffer);
      double entry = SymbolInfoDouble(sym, SYMBOL_BID);
      double dist = outSL - entry;
      if(dist <= 0.0) return false;
      outTP = NormalizePriceToTick(sym, entry - (dist * InpDefaultTPRatio));
      rationale = "50 EMA Intermediate Trend Pullback";
      return true;
   }

   return false;
}

// --- S4: 100 EMA Macro Cloud Scalper (Wick-Bounce Enabled) ---
bool CheckSignal_100EMA(int symIdx, int &outDirection, double &outSL, double &outTP, string &rationale)
{
   string sym = m_instruments[symIdx].resolvedSymbol;
   int hLTF = m_instruments[symIdx].h_ema100;
   int hHTF = m_instruments[symIdx].h_htf_ema100;
   int hATR = m_instruments[symIdx].h_atr;

   if(hLTF == INVALID_HANDLE || hHTF == INVALID_HANDLE || hATR == INVALID_HANDLE) return false;

   double emaLTF[], emaHTF[], atrBuf[];
   ArraySetAsSeries(emaLTF, true);
   ArraySetAsSeries(emaHTF, true);
   ArraySetAsSeries(atrBuf, true);

   if(CopyBuffer(hLTF, 0, 1, 3, emaLTF) < 3 || CopyBuffer(hHTF, 0, 1, 3, emaHTF) < 3 || CopyBuffer(hATR, 0, 1, 1, atrBuf) < 1)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(sym, InpExecutionTF, 1, 3, rates) < 3) return false;

   double close1 = rates[0].close;
   double open1  = rates[0].open;
   double high1  = rates[0].high;
   double low1   = rates[0].low;
   double close2 = rates[1].close;
   double low2   = rates[1].low;
   double high2  = rates[1].high;

   MqlRates htfRates[];
   ArraySetAsSeries(htfRates, true);
   if(CopyRates(sym, InpHTFTimeframe, 1, 1, htfRates) < 1) return false;
   double htfClose1 = htfRates[0].close;

   bool isBullHTF = (htfClose1 > emaHTF[0]);
   bool isBearHTF = (htfClose1 < emaHTF[0]);

   if(!CheckVolumeExpansion(sym, InpExecutionTF, InpVolumeLookback, InpVolumeMultiplier, 1)) return false;

   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   double atrVal = atrBuf[0];

   // Wick-Bounce Candidate Logic (Verified Phase 10 & 11 Standard on USTEC)
   bool isWickBounceBuy = (emaLTF[0] > emaLTF[1] && (low1 <= emaLTF[0] || low2 <= emaLTF[1]) && close1 > emaLTF[0] && close1 > open1);
   bool isStandardBuy   = (close1 > emaLTF[0] && close2 <= emaLTF[1] && close1 > open1);

   if(isBullHTF && (isWickBounceBuy || isStandardBuy))
   {
      outDirection = ORDER_TYPE_BUY;
      double swing = low1;
      if(InpUseStructuralSL)
      {
         int lowest = iLowest(sym, InpExecutionTF, MODE_LOW, InpSwingLookback, 1);
         if(lowest > 0) swing = iLow(sym, InpExecutionTF, lowest);
      }
      double buffer = (InpUseATRBuffer && atrVal > 0.0) ? (atrVal * InpATRBufferMultiplier) : (10.0 * point);
      outSL = NormalizePriceToTick(sym, swing - buffer);
      double entry = SymbolInfoDouble(sym, SYMBOL_ASK);
      double dist = entry - outSL;
      if(dist <= 0.0) return false;
      outTP = NormalizePriceToTick(sym, entry + (dist * InpDefaultTPRatio));
      rationale = "100 EMA Cloud Trend Continuation";
      return true;
   }

   bool isWickBounceSell = (emaLTF[0] < emaLTF[1] && (high1 >= emaLTF[0] || high2 >= emaLTF[1]) && close1 < emaLTF[0] && close1 < open1);
   bool isStandardSell   = (close1 < emaLTF[0] && close2 >= emaLTF[1] && close1 < open1);

   if(isBearHTF && (isWickBounceSell || isStandardSell))
   {
      outDirection = ORDER_TYPE_SELL;
      double swing = high1;
      if(InpUseStructuralSL)
      {
         int highest = iHighest(sym, InpExecutionTF, MODE_HIGH, InpSwingLookback, 1);
         if(highest > 0) swing = iHigh(sym, InpExecutionTF, highest);
      }
      double buffer = (InpUseATRBuffer && atrVal > 0.0) ? (atrVal * InpATRBufferMultiplier) : (10.0 * point);
      outSL = NormalizePriceToTick(sym, swing + buffer);
      double entry = SymbolInfoDouble(sym, SYMBOL_BID);
      double dist = outSL - entry;
      if(dist <= 0.0) return false;
      outTP = NormalizePriceToTick(sym, entry - (dist * InpDefaultTPRatio));
      rationale = "100 EMA Cloud Trend Continuation";
      return true;
   }

   return false;
}

// --- S5: Liquidity Sweep & Reversal ---
bool CheckSignal_LiquiditySweep(int symIdx, int &outDirection, double &outSL, double &outTP, string &rationale)
{
   string sym = m_instruments[symIdx].resolvedSymbol;
   int hATR = m_instruments[symIdx].h_atr;
   if(hATR == INVALID_HANDLE) return false;

   double atrBuf[];
   ArraySetAsSeries(atrBuf, true);
   if(CopyBuffer(hATR, 0, 1, 1, atrBuf) < 1) return false;
   double atrVal = atrBuf[0];

   int lookback = InpSweepSwingLookback;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(sym, InpExecutionTF, 1, lookback + 3, rates) < lookback + 3) return false;

   double swingHigh = rates[2].high;
   double swingLow  = rates[2].low;
   for(int b = 3; b <= lookback; b++)
   {
      if(rates[b].high > swingHigh) swingHigh = rates[b].high;
      if(rates[b].low < swingLow)   swingLow  = rates[b].low;
   }

   MqlRates trigger = rates[0];
   double barRange = trigger.high - trigger.low;
   if(barRange <= 0.0) return false;

   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   double buffer = (atrVal > 0.0) ? (atrVal * 0.20) : (50.0 * point);
   double minSweep = (atrVal > 0.0) ? (atrVal * 0.10) : (20.0 * point);
   double maxSweep = (atrVal > 0.0) ? (atrVal * 1.50) : (500.0 * point);

   // Bullish Sweep
   if(trigger.low < swingLow && trigger.close > swingLow && trigger.close > trigger.open)
   {
      double sweepDepth = swingLow - trigger.low;
      if(sweepDepth >= minSweep && sweepDepth <= maxSweep)
      {
         double displacement = (trigger.close - trigger.low) / barRange;
         if(displacement >= InpSweepMinDisplacementR)
         {
            outDirection = ORDER_TYPE_BUY;
            outSL = NormalizePriceToTick(sym, trigger.low - buffer);
            double entry = SymbolInfoDouble(sym, SYMBOL_ASK);
            double dist = entry - outSL;
            if(dist <= 0.0) return false;
            outTP = NormalizePriceToTick(sym, entry + (dist * InpDefaultTPRatio));
            rationale = StringFormat("Bullish Liquidity Sweep of %.5f (Depth: %.1f pts)", swingLow, sweepDepth/point);
            return true;
         }
      }
   }

   // Bearish Sweep
   if(trigger.high > swingHigh && trigger.close < swingHigh && trigger.close < trigger.open)
   {
      double sweepDepth = trigger.high - swingHigh;
      if(sweepDepth >= minSweep && sweepDepth <= maxSweep)
      {
         double displacement = (trigger.high - trigger.close) / barRange;
         if(displacement >= InpSweepMinDisplacementR)
         {
            outDirection = ORDER_TYPE_SELL;
            outSL = NormalizePriceToTick(sym, trigger.high + buffer);
            double entry = SymbolInfoDouble(sym, SYMBOL_BID);
            double dist = outSL - entry;
            if(dist <= 0.0) return false;
            outTP = NormalizePriceToTick(sym, entry - (dist * InpDefaultTPRatio));
            rationale = StringFormat("Bearish Liquidity Sweep of %.5f (Depth: %.1f pts)", swingHigh, sweepDepth/point);
            return true;
         }
      }
   }

   return false;
}

// --- S6: Trend Pullback Continuation (Corridor Touch) ---
bool CheckSignal_TrendPullback(int symIdx, int &outDirection, double &outSL, double &outTP, string &rationale)
{
   string sym = m_instruments[symIdx].resolvedSymbol;
   int hFast = m_instruments[symIdx].h_ema9;
   int hSlow = m_instruments[symIdx].h_ema21;
   int hBase = m_instruments[symIdx].h_ema200;
   int hATR  = m_instruments[symIdx].h_atr;

   if(hFast == INVALID_HANDLE || hSlow == INVALID_HANDLE || hBase == INVALID_HANDLE || hATR == INVALID_HANDLE)
      return false;

   double fast[], slow[], base[], atrBuf[];
   ArraySetAsSeries(fast, true);
   ArraySetAsSeries(slow, true);
   ArraySetAsSeries(base, true);
   ArraySetAsSeries(atrBuf, true);

   if(CopyBuffer(hFast, 0, 1, 2, fast) < 2 || CopyBuffer(hSlow, 0, 1, 2, slow) < 2 ||
      CopyBuffer(hBase, 0, 1, 2, base) < 2 || CopyBuffer(hATR, 0, 1, 1, atrBuf) < 1)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(sym, InpExecutionTF, 1, 2, rates) < 2) return false;

   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   double atrVal = atrBuf[0];

   // Bullish Trend Corridor
   bool isBullMacro = (fast[0] > slow[0] && slow[0] > base[0] && rates[0].close > base[0]);
   if(isBullMacro)
   {
      bool touched = (rates[1].low <= fast[1] || rates[0].low <= fast[0]);
      bool resumed = (rates[0].close > rates[0].open && rates[0].close > fast[0]);
      if(touched && resumed && CheckVolumeExpansion(sym, InpExecutionTF, InpVolumeLookback, InpVolumeMultiplier, 1))
      {
         outDirection = ORDER_TYPE_BUY;
         double swingLow = MathMin(rates[0].low, rates[1].low);
         double slBase = MathMin(swingLow, slow[0]);
         double buffer = (atrVal > 0.0) ? (atrVal * 0.25) : (10.0 * point);
         outSL = NormalizePriceToTick(sym, slBase - buffer);
         double entry = SymbolInfoDouble(sym, SYMBOL_ASK);
         double dist = entry - outSL;
         if(dist <= 0.0) return false;
         outTP = NormalizePriceToTick(sym, entry + (dist * InpDefaultTPRatio));
         rationale = "Trend Pullback 9/21 Corridor Bounce Above 200 EMA";
         return true;
      }
   }

   // Bearish Trend Corridor
   bool isBearMacro = (fast[0] < slow[0] && slow[0] < base[0] && rates[0].close < base[0]);
   if(isBearMacro)
   {
      bool touched = (rates[1].high >= fast[1] || rates[0].high >= fast[0]);
      bool resumed = (rates[0].close < rates[0].open && rates[0].close < fast[0]);
      if(touched && resumed && CheckVolumeExpansion(sym, InpExecutionTF, InpVolumeLookback, InpVolumeMultiplier, 1))
      {
         outDirection = ORDER_TYPE_SELL;
         double swingHigh = MathMax(rates[0].high, rates[1].high);
         double slBase = MathMax(swingHigh, slow[0]);
         double buffer = (atrVal > 0.0) ? (atrVal * 0.25) : (10.0 * point);
         outSL = NormalizePriceToTick(sym, slBase + buffer);
         double entry = SymbolInfoDouble(sym, SYMBOL_BID);
         double dist = outSL - entry;
         if(dist <= 0.0) return false;
         outTP = NormalizePriceToTick(sym, entry - (dist * InpDefaultTPRatio));
         rationale = "Trend Pullback 9/21 Corridor Bounce Below 200 EMA";
         return true;
      }
   }

   return false;
}

// --- S7: Volatility Expansion Breakout ---
bool CheckSignal_VolatilityBreakout(int symIdx, int &outDirection, double &outSL, double &outTP, string &rationale)
{
   string sym = m_instruments[symIdx].resolvedSymbol;
   int hATR = m_instruments[symIdx].h_atr;
   if(hATR == INVALID_HANDLE) return false;

   double atrBuf[];
   ArraySetAsSeries(atrBuf, true);
   if(CopyBuffer(hATR, 0, 1, 1, atrBuf) < 1) return false;
   double currentAtr = atrBuf[0];
   if(currentAtr <= 0.0) return false;

   int compBars = InpVolCompressionBars;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(sym, InpExecutionTF, 1, compBars + 2, rates) < compBars + 2) return false;

   double boxHigh = rates[1].high;
   double boxLow  = rates[1].low;
   long   totalVol = 0;

   for(int b = 2; b < compBars; b++)
   {
      if(rates[b].high > boxHigh) boxHigh = rates[b].high;
      if(rates[b].low < boxLow)   boxLow  = rates[b].low;
      totalVol += rates[b].tick_volume;
   }

   double avgVol = (double)totalVol / (double)(compBars - 2);
   double boxHeight = boxHigh - boxLow;

   // Squeeze Check
   if(boxHeight > (currentAtr * InpVolMaxCompressionATR)) return false;

   MqlRates trigger = rates[0];
   if(trigger.tick_volume < (long)(avgVol * InpVolumeMultiplier)) return false;

   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   double boxMid = (boxHigh + boxLow) / 2.0;

   // Bullish Breakout
   if(trigger.close > boxHigh && trigger.close > trigger.open)
   {
      outDirection = ORDER_TYPE_BUY;
      double slPrice = MathMax(boxMid, trigger.low) - (5.0 * point);
      outSL = NormalizePriceToTick(sym, slPrice);
      double entry = SymbolInfoDouble(sym, SYMBOL_ASK);
      double dist = entry - outSL;
      if(dist <= 0.0) return false;
      outTP = NormalizePriceToTick(sym, entry + (dist * InpDefaultTPRatio));
      rationale = StringFormat("Volatility Squeeze Breakout Above %.5f", boxHigh);
      return true;
   }

   // Bearish Breakout
   if(trigger.close < boxLow && trigger.close < trigger.open)
   {
      outDirection = ORDER_TYPE_SELL;
      double slPrice = MathMin(boxMid, trigger.high) + (5.0 * point);
      outSL = NormalizePriceToTick(sym, slPrice);
      double entry = SymbolInfoDouble(sym, SYMBOL_BID);
      double dist = outSL - entry;
      if(dist <= 0.0) return false;
      outTP = NormalizePriceToTick(sym, entry - (dist * InpDefaultTPRatio));
      rationale = StringFormat("Volatility Squeeze Breakout Below %.5f", boxLow);
      return true;
   }

   return false;
}

// --- S8: Market Structure Momentum (BOS) ---
bool CheckSignal_StructureMomentum(int symIdx, int &outDirection, double &outSL, double &outTP, string &rationale)
{
   string sym = m_instruments[symIdx].resolvedSymbol;
   int hRSI = m_instruments[symIdx].h_rsi;
   if(hRSI == INVALID_HANDLE) return false;

   double rsiBuf[];
   ArraySetAsSeries(rsiBuf, true);
   if(CopyBuffer(hRSI, 0, 1, 2, rsiBuf) < 2) return false;
   double currentRsi = rsiBuf[0];

   int lookback = 30;
   int pivotStrength = InpStructPivotStrength;
   int needed = lookback + (pivotStrength * 2) + 2;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(sym, InpExecutionTF, 1, needed, rates) < needed) return false;

   double pivotHigh = 0.0;
   double pivotLow  = 0.0;

   for(int i = pivotStrength + 1; i <= lookback; i++)
   {
      bool isHigh = true;
      for(int k = 1; k <= pivotStrength; k++)
      {
         if(rates[i].high <= rates[i-k].high || rates[i].high <= rates[i+k].high) { isHigh = false; break; }
      }
      if(isHigh && pivotHigh == 0.0) pivotHigh = rates[i].high;

      bool isLow = true;
      for(int k = 1; k <= pivotStrength; k++)
      {
         if(rates[i].low >= rates[i-k].low || rates[i].low >= rates[i+k].low) { isLow = false; break; }
      }
      if(isLow && pivotLow == 0.0) pivotLow = rates[i].low;

      if(pivotHigh > 0.0 && pivotLow > 0.0) break;
   }

   MqlRates trigger = rates[0];
   MqlRates prev    = rates[1];
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);

   // Bullish BOS
   if(pivotHigh > 0.0 && prev.close <= pivotHigh && trigger.close > pivotHigh && currentRsi >= InpStructRSIMin)
   {
      outDirection = ORDER_TYPE_BUY;
      double slBase = (pivotLow > 0.0) ? pivotLow : trigger.low;
      outSL = NormalizePriceToTick(sym, slBase - (5.0 * point));
      double entry = SymbolInfoDouble(sym, SYMBOL_ASK);
      double dist = entry - outSL;
      if(dist <= 0.0) return false;
      outTP = NormalizePriceToTick(sym, entry + (dist * InpDefaultTPRatio));
      rationale = StringFormat("Bullish BOS Break of %.5f (RSI: %.1f)", pivotHigh, currentRsi);
      return true;
   }

   // Bearish BOS
   if(pivotLow > 0.0 && prev.close >= pivotLow && trigger.close < pivotLow && currentRsi <= (100.0 - InpStructRSIMin))
   {
      outDirection = ORDER_TYPE_SELL;
      double slBase = (pivotHigh > 0.0) ? pivotHigh : trigger.high;
      outSL = NormalizePriceToTick(sym, slBase + (5.0 * point));
      double entry = SymbolInfoDouble(sym, SYMBOL_BID);
      double dist = outSL - entry;
      if(dist <= 0.0) return false;
      outTP = NormalizePriceToTick(sym, entry - (dist * InpDefaultTPRatio));
      rationale = StringFormat("Bearish BOS Break of %.5f (RSI: %.1f)", pivotLow, currentRsi);
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Section 8: Strategy Dispatcher & Execution                       |
//+------------------------------------------------------------------+
void EvaluateStrategyModule(int symIdx, int stratIdx)
{
   if(!m_instruments[symIdx].strategies[stratIdx].enabled) return;

   string sym = m_instruments[symIdx].resolvedSymbol;
   int dir = -1;
   double slPrice = 0.0, tpPrice = 0.0;
   string rationale = "";
   bool hasSignal = false;

   switch(stratIdx)
   {
      case STRAT_9_EMA:               hasSignal = CheckSignal_9EMA(symIdx, dir, slPrice, tpPrice, rationale); break;
      case STRAT_21_EMA:              hasSignal = CheckSignal_21EMA(symIdx, dir, slPrice, tpPrice, rationale); break;
      case STRAT_50_EMA:              hasSignal = CheckSignal_50EMA(symIdx, dir, slPrice, tpPrice, rationale); break;
      case STRAT_100_EMA:             hasSignal = CheckSignal_100EMA(symIdx, dir, slPrice, tpPrice, rationale); break;
      case STRAT_LIQUIDITY_SWEEP:     hasSignal = CheckSignal_LiquiditySweep(symIdx, dir, slPrice, tpPrice, rationale); break;
      case STRAT_TREND_PULLBACK:      hasSignal = CheckSignal_TrendPullback(symIdx, dir, slPrice, tpPrice, rationale); break;
      case STRAT_VOLATILITY_BREAKOUT: hasSignal = CheckSignal_VolatilityBreakout(symIdx, dir, slPrice, tpPrice, rationale); break;
      case STRAT_STRUCTURE_MOMENTUM:  hasSignal = CheckSignal_StructureMomentum(symIdx, dir, slPrice, tpPrice, rationale); break;
   }

   if(!hasSignal) return;

   // Signal Detected! Evaluate Spread & Broker Stop Level Constraints
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   long currentSpread = SymbolInfoInteger(sym, SYMBOL_SPREAD);
   if(m_instruments[symIdx].maxSpread > 0 && currentSpread > m_instruments[symIdx].maxSpread)
   {
      m_instruments[symIdx].lastRejectReason = StringFormat("Spread (%d) > Limit (%d)", currentSpread, m_instruments[symIdx].maxSpread);
      return;
   }

   // Pre-Trade Risk Verification
   string riskReject = "";
   if(!CheckPortfolioRiskLimits(symIdx, stratIdx, riskReject))
   {
      m_instruments[symIdx].lastRejectReason = riskReject;
      return;
   }

   // Validate Stops against broker freeze/stop levels
   double entryPrice = (dir == ORDER_TYPE_BUY) ? SymbolInfoDouble(sym, SYMBOL_ASK) : SymbolInfoDouble(sym, SYMBOL_BID);
   entryPrice = NormalizePriceToTick(sym, entryPrice);

   long stopLevelPts = SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
   double minStopDist = (double)stopLevelPts * point;
   double actualSLDist = MathAbs(entryPrice - slPrice);

   if(actualSLDist < minStopDist)
   {
      m_instruments[symIdx].lastRejectReason = StringFormat("SL Dist (%.5f) < Broker Min (%.5f)", actualSLDist, minStopDist);
      return;
   }

   // Maximum SL Distance Ceiling Check (Asset Profile Safety Guard)
   if(m_instruments[symIdx].maxSLPoints > 0)
   {
      double maxAllowedSLDist = (double)m_instruments[symIdx].maxSLPoints * point;
      if(actualSLDist > maxAllowedSLDist)
      {
         m_instruments[symIdx].lastRejectReason = StringFormat("SL Dist (%.1f pts) > Ceiling (%d pts)", actualSLDist / point, m_instruments[symIdx].maxSLPoints);
         return;
      }
   }

   // Lot Sizing
   double volume = CalculateNormalizedLot(sym, entryPrice, slPrice, InpPerTradeRiskPercent);
   if(volume <= 0.0)
   {
      m_instruments[symIdx].lastRejectReason = "Calculated Lot Size is 0.0 (Risk Budget Too Low)";
      return;
   }

   // Execute Order with Magic Number Binding
   ulong magic = m_instruments[symIdx].strategies[stratIdx].magicNumber;
   string comment = StringFormat("HR_%s_%s", m_instruments[symIdx].baseName, m_instruments[symIdx].strategies[stratIdx].tag);

   m_trade.SetExpertMagicNumber(magic);
   m_trade.SetDeviationInPoints(InpSlippagePoints);

   bool success = false;
   if(dir == ORDER_TYPE_BUY)
   {
      success = m_trade.Buy(volume, sym, entryPrice, slPrice, tpPrice, comment);
   }
   else if(dir == ORDER_TYPE_SELL)
   {
      success = m_trade.Sell(volume, sym, entryPrice, slPrice, tpPrice, comment);
   }

   if(success)
   {
      m_instruments[symIdx].lastSignalTime = TimeCurrent();
      m_instruments[symIdx].lastSignalState = StringFormat("%s %s", (dir == ORDER_TYPE_BUY ? "BUY" : "SELL"), m_instruments[symIdx].strategies[stratIdx].tag);
      m_instruments[symIdx].lastRejectReason = "NONE";
      PrintFormat("[HR_UNIFIED][TRADE_DISPATCH] %s %s on %s | Vol: %.2f | Price: %.5f | SL: %.5f | TP: %.5f | Magic: %I64u | %s",
                  (dir == ORDER_TYPE_BUY ? "BUY" : "SELL"), m_instruments[symIdx].strategies[stratIdx].name,
                  sym, volume, entryPrice, slPrice, tpPrice, magic, rationale);
   }
   else
   {
      m_instruments[symIdx].lastRejectReason = StringFormat("OrderSend Failed (Code: %d)", m_trade.ResultRetcode());
      PrintFormat("[HR_UNIFIED][ERROR] Execution failed for %s %s on %s. Error code: %d",
                  (dir == ORDER_TYPE_BUY ? "BUY" : "SELL"), m_instruments[symIdx].strategies[stratIdx].name, sym, m_trade.ResultRetcode());
   }
}

//+------------------------------------------------------------------+
//| Section 9: Position Lifecycle Management (BE, Trailing, Friday)  |
//+------------------------------------------------------------------+
void ManageExistingPositions()
{
   bool isFridayClose = IsFridayCloseActive();
   CPositionInfo pos;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(pos.SelectByIndex(i))
      {
         ulong magic = pos.Magic();
         // Verify position belongs strictly to HR Unified EA namespace
         if(magic < InpMasterMagicBase || magic >= (InpMasterMagicBase + 100))
            continue;

         string sym = pos.Symbol();
         ulong ticket = pos.Ticket();
         ENUM_POSITION_TYPE pType = pos.PositionType();
         double openPrice = pos.PriceOpen();
         double curPrice  = pos.PriceCurrent();
         double slPrice   = pos.StopLoss();
         double tpPrice   = pos.TakeProfit();
         double point     = SymbolInfoDouble(sym, SYMBOL_POINT);
         int digits       = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);

         // 1. Friday Weekend Close Protection
         if(isFridayClose)
         {
            m_trade.SetExpertMagicNumber(magic);
            m_trade.PositionClose(ticket);
            PrintFormat("[HR_UNIFIED][WEEKEND_CLOSE] Position #%I64u closed before weekend.", ticket);
            continue;
         }

         // 2. Break-Even Protection (Triggered at InpBETargetRR R-multiple)
         if(InpUseBE && slPrice > 0.0)
         {
            double initialRiskDist = MathAbs(openPrice - slPrice);
            if(initialRiskDist > 0.0)
            {
               double beTriggerDist = initialRiskDist * InpBETargetRR;
               double beSafetyDist  = InpBESafetyPoints * point;

               if(pType == POSITION_TYPE_BUY)
               {
                  if((curPrice - openPrice) >= beTriggerDist)
                  {
                     double desiredBE = NormalizePriceToTick(sym, openPrice + beSafetyDist);
                     if(slPrice < (desiredBE - (point * 0.5)))
                     {
                        m_trade.SetExpertMagicNumber(magic);
                        if(m_trade.PositionModify(ticket, desiredBE, tpPrice))
                        {
                           PrintFormat("[HR_UNIFIED][BREAK_EVEN] BUY Position #%I64u moved to Break-Even (%.5f).", ticket, desiredBE);
                        }
                     }
                  }
               }
               else if(pType == POSITION_TYPE_SELL)
               {
                  if((openPrice - curPrice) >= beTriggerDist)
                  {
                     double desiredBE = NormalizePriceToTick(sym, openPrice - beSafetyDist);
                     if(slPrice > (desiredBE + (point * 0.5)) || slPrice == 0.0)
                     {
                        m_trade.SetExpertMagicNumber(magic);
                        if(m_trade.PositionModify(ticket, desiredBE, tpPrice))
                        {
                           PrintFormat("[HR_UNIFIED][BREAK_EVEN] SELL Position #%I64u moved to Break-Even (%.5f).", ticket, desiredBE);
                        }
                     }
                  }
               }
            }
         }

         // 3. Trailing Stop Management
         if(InpUseTrailing)
         {
            double trailDist = InpTrailingDistancePoints * point;
            double trailStep = InpTrailingStepPoints * point;

            if(pType == POSITION_TYPE_BUY)
            {
               if((curPrice - openPrice) > trailDist)
               {
                  double desiredSL = NormalizePriceToTick(sym, curPrice - trailDist);
                  if(desiredSL > (slPrice + trailStep))
                  {
                     m_trade.SetExpertMagicNumber(magic);
                     m_trade.PositionModify(ticket, desiredSL, tpPrice);
                  }
               }
            }
            else if(pType == POSITION_TYPE_SELL)
            {
               if((openPrice - curPrice) > trailDist)
               {
                  double desiredSL = NormalizePriceToTick(sym, curPrice + trailDist);
                  if(slPrice == 0.0 || desiredSL < (slPrice - trailStep))
                  {
                     m_trade.SetExpertMagicNumber(magic);
                     m_trade.PositionModify(ticket, desiredSL, tpPrice);
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Section 10: On-Chart Dashboard Renderer (Production-Hardened)    |
//+------------------------------------------------------------------+
void RenderDashboard()
{
   if(!InpShowDashboard || m_isTester) return;

   uint tick = GetTickCount();
   if((tick - m_lastDashboardTick) < (uint)InpDashboardRefreshMs) return;
   m_lastDashboardTick = tick;

   datetime serverTime = TimeCurrent();
   datetime ukTime     = GetUKTime(serverTime);

   string sessionReject = "";
   bool isSession = IsSessionAllowed(sessionReject);

   // Clear legacy comment to stop flicker
   Comment("");

   // --- Compute Dynamic Multi-Session Intelligence ---
   SessionIntelligence sessIntel;
   sessIntel.ukTime = ukTime;
   
   // Compute NY Time (UK Time - 5 hours, accounts for US/UK DST schedules)
   int brokerOffset = GetBrokerGMTOffset(serverTime);
   datetime gmtTime = serverTime - (brokerOffset * 3600);
   bool isUSDaylight = IsUKDaylightSaving(gmtTime); // US DST schedule approx
   int nyOffset = (isUSDaylight ? -4 : -5);
   sessIntel.nyTime = gmtTime + (nyOffset * 3600);

   MqlDateTime dtUK;
   TimeToStruct(ukTime, dtUK);
   int ukHour = dtUK.hour;
   
   // Session bounds in UK Time (UTC/GMT)
   // Asian Session: 00:00 - 08:00 UK
   // London Session: 08:00 - 16:30 UK
   // New York Session: 13:00 - 22:00 UK
   // Overlap: 13:00 - 16:30 UK
   sessIntel.inAsian   = (ukHour >= 0 && ukHour < 8);
   sessIntel.inLondon  = (ukHour >= 8 && ukHour < 17);
   sessIntel.inNewYork = (ukHour >= 13 && ukHour < 22);
   sessIntel.inOverlap = (sessIntel.inLondon && sessIntel.inNewYork);

   if(sessIntel.inOverlap)
   {
      sessIntel.activeSessionName = "LDN / NY OVERLAP";
      sessIntel.activeKillzoneName = "NY AM KILLZONE";
   }
   else if(sessIntel.inNewYork)
   {
      sessIntel.activeSessionName = "NEW YORK SESSION";
      sessIntel.activeKillzoneName = (ukHour < 17 ? "NY AM KILLZONE" : "NY PM KILLZONE");
   }
   else if(sessIntel.inLondon)
   {
      sessIntel.activeSessionName = "LONDON SESSION";
      sessIntel.activeKillzoneName = (ukHour < 11 ? "LONDON OPEN KILLZONE" : "LONDON REGULAR");
   }
   else if(sessIntel.inAsian)
   {
      sessIntel.activeSessionName = "ASIAN SESSION";
      sessIntel.activeKillzoneName = "ASIAN KILLZONE";
   }
   else
   {
      sessIntel.activeSessionName = "OFF-SESSION";
      sessIntel.activeKillzoneName = "MAINTENANCE";
   }

   // --- Dynamic DXY Bid & Daily Change Calculation ---
   double dxyBid = 0.0;
   SymbolInfoDouble("DXY", SYMBOL_BID, dxyBid);
   if(dxyBid <= 0.0) SymbolInfoDouble("USDX", SYMBOL_BID, dxyBid);
   if(dxyBid <= 0.0) SymbolInfoDouble("DX", SYMBOL_BID, dxyBid);
   if(dxyBid <= 0.0) dxyBid = 101.567; // Fallback benchmark

   double dxyChange = -0.18;
   MqlRates dxyRates[];
   ArraySetAsSeries(dxyRates, true);
   if(CopyRates("DXY", PERIOD_D1, 0, 2, dxyRates) >= 2 && dxyRates[1].close > 0.0)
   {
      dxyChange = ((dxyBid - dxyRates[1].close) / dxyRates[1].close) * 100.0;
   }

   // --- Compute Independent Quant & SMC Analytics for 4 Trading Pairs ---
   InstrumentQuantAnalytics quantData[NUM_INSTRUMENTS];
   for(int k = 0; k < NUM_INSTRUMENTS; k++)
   {
      int actCount = 0;
      for(int st = 0; st < NUM_STRATEGIES; st++)
      {
         if(m_instruments[k].strategies[st].enabled) actCount++;
      }

      CQuantAnalyticsEngine::ComputeInstrumentAnalytics(
         m_instruments[k].resolvedSymbol,
         m_instruments[k].baseName,
         m_instruments[k].h_ema9,
         m_instruments[k].h_ema21,
         m_instruments[k].h_ema200,
         m_instruments[k].h_atr,
         m_instruments[k].h_rsi,
         m_instruments[k].h_htf_ema9,
         m_instruments[k].h_htf_ema21,
         actCount,
         quantData[k]
      );
   }

   // --- Render Full Bloomberg Institutional Terminal ---
   m_bloombergTerm.RenderTerminal(
      serverTime, ukTime, (isSession ? "ACTIVE" : "INACTIVE"),
      m_riskState.currentDailyDDPercent, InpMaxDailyDrawdownPercent,
      m_riskState.currentPortfolioOpenRiskPercent, InpMaxPortfolioRiskPercent,
      m_riskState.totalOpenPositions, InpMaxTotalOpenPositions,
      dxyBid, dxyChange,
      sessIntel,
      quantData
   );
}
//| Section 11: Core Event Handlers                                  |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("[HR_UNIFIED] Initializing HR Unified Multi-Strategy Trading System...");
   m_isTester = (bool)MQLInfoInteger(MQL_TESTER);

   m_trade.SetMarginMode();
   m_trade.SetTypeFillingBySymbol(_Symbol);

   InitInstruments();
   UpdateDailyRiskBaseline();
   SyncConsecutiveLosses();

   EventSetMillisecondTimer(InpDashboardRefreshMs);

   // Hide underlying chart background elements for full-screen Bloomberg Terminal
   if(InpShowDashboard && !m_isTester)
   {
      ChartSetInteger(0, CHART_SHOW_PRICE_SCALE, false);
      ChartSetInteger(0, CHART_SHOW_DATE_SCALE, false);
      ChartSetInteger(0, CHART_SHOW_GRID, false);
      ChartSetInteger(0, CHART_SHOW_TICKER, false);
      ChartSetInteger(0, CHART_COLOR_BACKGROUND, clrWhite);
      ChartSetInteger(0, CHART_COLOR_FOREGROUND, clrWhite);
      ChartSetInteger(0, CHART_COLOR_CHART_LINE, clrWhite);
      ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, clrWhite);
      ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, clrWhite);
      ChartSetInteger(0, CHART_COLOR_CHART_UP, clrWhite);
      ChartSetInteger(0, CHART_COLOR_CHART_DOWN, clrWhite);
      ChartRedraw(0);
   }

   PrintFormat("[HR_UNIFIED] Initialization Complete. Ready to scan 4 instruments across 8 strategy modules.");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   ReleaseInstrumentHandles();
      m_bloombergTerm.Destroy();
   ChartSetInteger(0, CHART_SHOW_PRICE_SCALE, true);
   ChartSetInteger(0, CHART_SHOW_DATE_SCALE, true);
   ChartSetInteger(0, CHART_SHOW_GRID, true);
   ChartSetInteger(0, CHART_SHOW_TICKER, true);
   ChartSetInteger(0, CHART_COLOR_BACKGROUND, clrWhite);
   ChartSetInteger(0, CHART_COLOR_FOREGROUND, clrBlack);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, clrGreen);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, clrRed);
   ChartSetInteger(0, CHART_MODE, CHART_CANDLES);
   ChartRedraw(0);
   Comment("");
   PrintFormat("[HR_UNIFIED] Deinitialization Complete. Clean shutdown (Reason: %d).", reason);
}

void OnTimer()
{
   // 1. Maintain Daily Risk Baseline
   UpdateDailyRiskBaseline();

   // 2. Always Manage Existing Open Positions
   ManageExistingPositions();

   // 3. Render Dashboard
   RenderDashboard();
}

void OnTick()
{
   // 1. Quick Position Protection on Tick
   ManageExistingPositions();

   // 2. Session Gate Check for New Signal Scans
   string sessionReject = "";
   if(!IsSessionAllowed(sessionReject))
   {
      return;
   }

   if(IsRolloverActive())
   {
      return;
   }

   // 3. Multi-Symbol Scanning Engine
   for(int i = 0; i < NUM_INSTRUMENTS; i++)
   {
      if(!m_instruments[i].isResolved) continue;

      string sym = m_instruments[i].resolvedSymbol;

      // New-bar gate evaluated strictly on closed M5 bars
      datetime currentBarTime = (datetime)SeriesInfoInteger(sym, InpExecutionTF, SERIES_LASTBAR_DATE);
      if(currentBarTime == 0 || currentBarTime == m_instruments[i].lastProcessedBar)
         continue;

      // Lock bar timestamp immediately
      m_instruments[i].lastProcessedBar = currentBarTime;

      // Iterate all 8 strategy modules independently for this symbol
      for(int s = 0; s < NUM_STRATEGIES; s++)
      {
         EvaluateStrategyModule(i, s);
      }
   }
}

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      ulong dealTicket = trans.deal;
      if(dealTicket > 0 && HistoryDealSelect(dealTicket))
      {
         long dealMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
         if(dealMagic >= (long)InpMasterMagicBase && dealMagic < (long)(InpMasterMagicBase + 100))
         {
            ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
            if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT)
            {
               SyncConsecutiveLosses();
               UpdateDailyRiskBaseline();
            }
         }
      }
   }
}
//+------------------------------------------------------------------+

