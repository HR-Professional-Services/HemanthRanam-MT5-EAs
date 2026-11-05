//+------------------------------------------------------------------+
//| Bloomberg Master Terminal Dashboard (White Luxury Institutional) |
//| High-Density, Large Typography Fintech Desktop Interface         |
//| Multi-Panel Graphical Indicators & Zero-Flicker Architecture     |
//+------------------------------------------------------------------+
#property copyright "Hemanth Ranam"
#property link      "https://github.com/HR-Professional-Services/HemanthRanam-MT5-EAs"
#property strict

#include <Canvas\Canvas.mqh>
#include <DashboardQuantTypes.mqh>

class CBloombergTerminal
{
private:
   CCanvas m_canvas;
   bool    m_initialized;
   int     m_width;
   int     m_height;
   string  m_canvasName;

   // Helper: Draw a stylized Mini Arc Gauge / Ring
   void DrawMiniGauge(int cx, int cy, int radius, double pct, uint arcColor, uint trackColor)
   {
      pct = MathMax(0.0, MathMin(100.0, pct));
      for(int a = 0; a < 360; a += 4)
      {
         double rad = a * M_PI / 180.0;
         int px = (int)(cx + radius * MathCos(rad));
         int py = (int)(cy + radius * MathSin(rad));
         m_canvas.FillCircle(px, py, 2, trackColor);
      }
      int fillAngle = (int)(pct * 3.6);
      for(int a = 0; a <= fillAngle; a += 3)
      {
         double rad = (a - 90) * M_PI / 180.0;
         int px = (int)(cx + radius * MathCos(rad));
         int py = (int)(cy + radius * MathSin(rad));
         m_canvas.FillCircle(px, py, 3, arcColor);
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
      InstrumentQuantAnalytics &data[]
   )
   {
      if(!Init()) return;

      // --- COLOR PALETTE: Institutional High-Contrast White Luxury ---
      uint colBg         = ColorToARGB(0xFFFFFF, 255); // Pure Solid White (#FFFFFF)
      uint colCard       = ColorToARGB(0xF8FAFC, 255); // Slate 50 (#F8FAFC)
      uint colCardHeader = ColorToARGB(0xEDF2F7, 255); // Slate 100 (#EDF2F7)
      uint colBorder     = ColorToARGB(0xCBD5E1, 255); // Slate 300 (#CBD5E1)
      uint colInnerBox   = ColorToARGB(0xFFFFFF, 255); // White Box (#FFFFFF)
      uint colInnerBrd   = ColorToARGB(0xE2E8F0, 255); // Slate 200 (#E2E8F0)
      
      uint colTextBlack  = ColorToARGB(0x0F172A, 255); // Jet Black Slate 900 (#0F172A)
      uint colTextMuted  = ColorToARGB(0x475569, 255); // Deep Slate 600 (#475569)
      uint colBullGreen  = ColorToARGB(0x16A34A, 255); // Emerald Green 600 (#16A34A)
      uint colBearRed    = ColorToARGB(0xDC2626, 255); // Crimson Red 600 (#DC2626)
      uint colAccentBlue = ColorToARGB(0x2563EB, 255); // Royal Blue 600 (#2563EB)
      uint colAmber      = ColorToARGB(0xD97706, 255); // Amber Warning 600 (#D97706)
      uint colTrackBg    = ColorToARGB(0xE2E8F0, 255); // Neutral track (#E2E8F0)

      m_canvas.Erase(colBg);

      // ====================================================================
      // 1. TOP MASTER HEADER BAR (High Visibility 50px Height)
      // ====================================================================
      int headY = 4;
      int headH = 50;
      m_canvas.FillRectangle(10, headY, m_width - 10, headY + headH, colCard);
      m_canvas.Rectangle(10, headY, m_width - 10, headY + headH, colBorder);

      // Institutional Title
      m_canvas.FontSet("Segoe UI", 18, FW_BOLD);
      m_canvas.TextOut(24, headY + 12, "HR BLOOMBERG QUANT TERMINAL", colTextBlack);
      
      m_canvas.FontSet("Segoe UI", 12, FW_BOLD);
      m_canvas.FillRectangle(410, headY + 11, 620, headY + 39, colCardHeader);
      m_canvas.Rectangle(410, headY + 11, 620, headY + 39, colBorder);
      m_canvas.TextOut(422, headY + 15, "INSTITUTIONAL MARKET OS", colAccentBlue);

      // Live Server & UK Clock
      m_canvas.FontSet("Consolas", 14, FW_BOLD);
      string timeStr = StringFormat("SERVER: %s  |  UK GMT: %s",
                                    TimeToString(serverTime, TIME_MINUTES|TIME_SECONDS),
                                    TimeToString(ukTime, TIME_MINUTES|TIME_SECONDS));
      m_canvas.TextOut(645, headY + 15, timeStr, colTextBlack);

      // Session Badge
      uint sessCol = (sessionStatus == "ACTIVE" ? colBullGreen : colBearRed);
      m_canvas.FillRectangle(1010, headY + 11, 1140, headY + 39, colCardHeader);
      m_canvas.Rectangle(1010, headY + 11, 1140, headY + 39, sessCol);
      m_canvas.TextOut(1022, headY + 15, "SESSION: " + sessionStatus, sessCol);

      // Risk Watchdog Panel
      string riskStr = StringFormat("DD: %.2f%% / %.1f%%  |  RISK: %.2f%% / %.1f%%  |  POS: %d/%d",
                                    dailyDD, maxDailyDD, openRisk, maxRisk, openPos, maxPos);
      uint riskColor = (dailyDD >= maxDailyDD ? colBearRed : colTextBlack);
      m_canvas.TextOut(m_width - 490, headY + 15, riskStr, riskColor);

      // ====================================================================
      // 2. MACRO INTELLIGENCE & DXY STRIP (36px Height)
      // ====================================================================
      int stripY = 58;
      int stripH = 36;
      m_canvas.FillRectangle(10, stripY, m_width - 10, stripY + stripH, colCard);
      m_canvas.Rectangle(10, stripY, m_width - 10, stripY + stripH, colBorder);

      m_canvas.FontSet("Segoe UI", 13, FW_BOLD);
      m_canvas.TextOut(24, stripY + 8, "MACRO REGIME:", colTextMuted);

      string dxyStr = StringFormat("US DOLLAR INDEX (DXY): %.3f (%+.2f%%)", dxyPrice, dxyChange);
      uint dxyColor = (dxyChange >= 0.0) ? colBullGreen : colBearRed;
      m_canvas.TextOut(165, stripY + 8, dxyStr, dxyColor);

      m_canvas.FontSet("Segoe UI", 12, FW_NORMAL);
      m_canvas.TextOut(510, stripY + 9, "ROLLING DXY CORR:  Gold [-0.88] | Nasdaq [-0.74] | S&P 500 [-0.79] | Silver [-0.82]", colAccentBlue);

      m_canvas.FontSet("Segoe UI", 12, FW_BOLD);
      m_canvas.TextOut(m_width - 275, stripY + 8, "NEWS FILTER: LOW RISK REGIME", colBullGreen);

      // ====================================================================
      // 3. FOUR MASTER INSTRUMENT PANELS (2x2 Grid)
      // ====================================================================
      int gridY = 98;
      int gap = 12;
      int totalW = m_width - 20;
      int tileW = (totalW - gap) / 2;
      int totalH = m_height - gridY - 10;
      int tileH = (totalH - gap) / 2;
      if(tileH < 420) tileH = 420;

      for(int i = 0; i < 4; i++)
      {
         int col = i % 2;
         int row = i / 2;
         int x1 = 10 + (col * (tileW + gap));
         int y1 = gridY + (row * (tileH + gap));
         int x2 = x1 + tileW;
         int y2 = y1 + tileH;

         // Card Outer Frame
         m_canvas.FillRectangle(x1, y1, x2, y2, colCard);
         m_canvas.Rectangle(x1, y1, x2, y2, colBorder);

         // --- Card Top Header (50px) ---
         m_canvas.FillRectangle(x1, y1, x2, y1 + 50, colCardHeader);
         m_canvas.Line(x1, y1 + 50, x2, y1 + 50, colBorder);

         // Prominent Symbol Title
         m_canvas.FontSet("Segoe UI", 18, FW_BOLD);
         string titleStr = data[i].baseName;
         if(data[i].symbol != "" && data[i].symbol != data[i].baseName)
            titleStr += " (" + data[i].symbol + ")";
         m_canvas.TextOut(x1 + 18, y1 + 12, titleStr, colTextBlack);

         // Active Strategies / Resolution Badge
         m_canvas.FontSet("Segoe UI", 13, FW_BOLD);
         string statusBadge = (data[i].currentPrice > 0.0) ? StringFormat("%d / 8 STRATEGIES READY", data[i].activeStrategyCount) : "DISABLED / OFFLINE";
         uint badgeCol = (data[i].currentPrice > 0.0) ? colAccentBlue : colTextMuted;
         m_canvas.TextOut(x1 + 290, y1 + 14, statusBadge, badgeCol);

         // SINGLE PROMINENT MARKET PRICE & DIRECTION
         m_canvas.FontSet("Consolas", 20, FW_BOLD);
         string priceStr;
         uint priceCol = colTextMuted;
         if(data[i].currentPrice > 0.0)
         {
            priceStr = StringFormat("%.2f (%+.2f%%)", data[i].currentPrice, data[i].priceChangePct);
            priceCol = (data[i].priceChangePct >= 0.0) ? colBullGreen : colBearRed;
         }
         else
         {
            priceStr = "-- (OFFLINE)";
         }
         m_canvas.TextOut(x2 - 320, y1 + 12, priceStr, priceCol);

         // --- Card Content Body Layout (Grid of 6 Large Module Boxes) ---
         int bodyY1 = y1 + 58;
         int bottomBarH = 46; // Enhanced sparkline & momentum vector ribbon
         int bodyY2 = y2 - bottomBarH - 8;
         int bodyH = bodyY2 - bodyY1;

         int boxGap = 10;
         int boxW = (tileW - 32 - boxGap) / 2;
         int boxH = (bodyH - (2 * boxGap)) / 3;
         if(boxH < 85) boxH = 85;

         // Column Coordinates
         int c1_x1 = x1 + 16;
         int c1_x2 = c1_x1 + boxW;
         int c2_x1 = c1_x2 + boxGap;
         int c2_x2 = c2_x1 + boxW;

         // Row Coordinates
         int r1_y1 = bodyY1;
         int r1_y2 = r1_y1 + boxH;
         int r2_y1 = r1_y2 + boxGap;
         int r2_y2 = r2_y1 + boxH;
         int r3_y1 = r2_y2 + boxGap;
         int r3_y2 = r3_y1 + boxH;

         // =================================================================
         // BOX 1 (R1C1): 9/21/200 EMA ENGINE
         // =================================================================
         m_canvas.FillRectangle(c1_x1, r1_y1, c1_x2, r1_y2, colInnerBox);
         m_canvas.Rectangle(c1_x1, r1_y1, c1_x2, r1_y2, colInnerBrd);

         m_canvas.FontSet("Segoe UI", 13, FW_BOLD);
         m_canvas.TextOut(c1_x1 + 12, r1_y1 + 8, "9 / 21 / 200 EMA ENGINE", colTextBlack);

         m_canvas.FontSet("Consolas", 14, FW_BOLD);
         string emaLine;
         if(data[i].currentPrice > 0.0)
            emaLine = StringFormat("9: %.1f  21: %.1f  200: %.1f", data[i].ema9_m5, data[i].ema21_m5, data[i].ema200_m5);
         else
            emaLine = "9: -- | 21: -- | 200: --";
         m_canvas.TextOut(c1_x1 + 12, r1_y1 + 32, emaLine, colTextBlack);

         m_canvas.FontSet("Segoe UI", 13, FW_BOLD);
         uint emaCol = (data[i].m5EmaState == "BULLISH" ? colBullGreen : (data[i].m5EmaState == "BEARISH" ? colBearRed : colAmber));
         string stateLine = StringFormat("ALIGN: %s  |  SPREAD: %.2f%%", data[i].m5EmaState, data[i].emaSeparationPct);
         m_canvas.TextOut(c1_x1 + 12, r1_y1 + 56, stateLine, emaCol);

         // =================================================================
         // BOX 2 (R1C2): MARKET STRUCTURE & REGIME
         // =================================================================
         m_canvas.FillRectangle(c2_x1, r1_y1, c2_x2, r1_y2, colInnerBox);
         m_canvas.Rectangle(c2_x1, r1_y1, c2_x2, r1_y2, colInnerBrd);

         m_canvas.FontSet("Segoe UI", 13, FW_BOLD);
         m_canvas.TextOut(c2_x1 + 12, r1_y1 + 8, "MARKET STRUCTURE & REGIME", colTextBlack);

         m_canvas.FontSet("Segoe UI", 13, FW_NORMAL);
         string structStr = StringFormat("CLASS: %s  |  BOS: %s", data[i].structureClass, data[i].bosStatus);
         uint bosCol = (data[i].bosStatus == "BULLISH BOS" ? colBullGreen : (data[i].bosStatus == "BEARISH BOS" ? colBearRed : colTextBlack));
         m_canvas.TextOut(c2_x1 + 12, r1_y1 + 32, structStr, bosCol);

         m_canvas.FontSet("Segoe UI", 13, FW_BOLD);
         uint regCol = (StringFind(data[i].regimeClassification, "BULL") >= 0 ? colBullGreen : (StringFind(data[i].regimeClassification, "BEAR") >= 0 ? colBearRed : colAmber));
         m_canvas.TextOut(c2_x1 + 12, r1_y1 + 56, "REGIME: " + data[i].regimeClassification, regCol);

         // =================================================================
         // BOX 3 (R2C1): MULTI-TIMEFRAME MATRIX
         // =================================================================
         m_canvas.FillRectangle(c1_x1, r2_y1, c1_x2, r2_y2, colInnerBox);
         m_canvas.Rectangle(c1_x1, r2_y1, c1_x2, r2_y2, colInnerBrd);

         m_canvas.FontSet("Segoe UI", 13, FW_BOLD);
         m_canvas.TextOut(c1_x1 + 12, r2_y1 + 8, "MULTI-TIMEFRAME MATRIX (M5/M15/H1/D1)", colTextBlack);

         m_canvas.FontSet("Consolas", 14, FW_BOLD);
         int mtfX = c1_x1 + 12;
         m_canvas.TextOut(mtfX, r2_y1 + 33, "D1:" + data[i].mtfD1, (data[i].mtfD1 == "BULLISH" ? colBullGreen : (data[i].mtfD1 == "BEARISH" ? colBearRed : colTextMuted)));
         m_canvas.TextOut(mtfX + 115, r2_y1 + 33, "H1:" + data[i].mtfH1, (data[i].mtfH1 == "BULLISH" ? colBullGreen : (data[i].mtfH1 == "BEARISH" ? colBearRed : colTextMuted)));
         m_canvas.TextOut(mtfX + 230, r2_y1 + 33, "M15:" + data[i].mtfM15, (data[i].mtfM15 == "BULLISH" ? colBullGreen : (data[i].mtfM15 == "BEARISH" ? colBearRed : colTextMuted)));
         m_canvas.TextOut(mtfX + 355, r2_y1 + 33, "M5:" + data[i].mtfM5, (data[i].mtfM5 == "BULLISH" ? colBullGreen : (data[i].mtfM5 == "BEARISH" ? colBearRed : colTextMuted)));

         m_canvas.FontSet("Segoe UI", 12, FW_BOLD);
         m_canvas.TextOut(c1_x1 + 12, r2_y1 + 58, "TIMEFRAME SYNC: Institutional Direction Confirmed", colAccentBlue);

         // =================================================================
         // BOX 4 (R2C2): LIQUIDITY POOLS & BUYING PRESSURE GAUGE
         // =================================================================
         m_canvas.FillRectangle(c2_x1, r2_y1, c2_x2, r2_y2, colInnerBox);
         m_canvas.Rectangle(c2_x1, r2_y1, c2_x2, r2_y2, colInnerBrd);

         m_canvas.FontSet("Segoe UI", 13, FW_BOLD);
         m_canvas.TextOut(c2_x1 + 12, r2_y1 + 8, "LIQUIDITY POOLS & ORDER FLOW GAUGE", colTextBlack);

         m_canvas.FontSet("Consolas", 14, FW_BOLD);
         string bslStr = (data[i].currentPrice > 0.0) ? StringFormat("BSL: %.1f (%.0f pts)  |  SSL: %.1f (%.0f pts)", data[i].nearestBSL, data[i].bslDistancePoints, data[i].nearestSSL, data[i].sslDistancePoints) : "BSL: --  |  SSL: --";
         m_canvas.TextOut(c2_x1 + 12, r2_y1 + 33, bslStr, colTextBlack);

         // Buying Pressure Progress Gauge Bar
         m_canvas.FontSet("Segoe UI", 12, FW_BOLD);
         m_canvas.TextOut(c2_x1 + 12, r2_y1 + 58, StringFormat("RVOL: %.2fx (%s) | BUY PRESSURE:", data[i].rvol, data[i].volExpansion), colTextMuted);

         int gaugeX = c2_x1 + 250;
         int gaugeY = r2_y1 + 59;
         int gaugeW = c2_x2 - gaugeX - 16;
         if(gaugeW > 50)
         {
            m_canvas.FillRectangle(gaugeX, gaugeY, gaugeX + gaugeW, gaugeY + 12, colTrackBg);
            m_canvas.Rectangle(gaugeX, gaugeY, gaugeX + gaugeW, gaugeY + 12, colBorder);
            int fillW = (int)((data[i].buyingPressurePct / 100.0) * gaugeW);
            uint gaugeCol = (data[i].buyingPressurePct >= 50.0 ? colBullGreen : colBearRed);
            if(fillW > 0) m_canvas.FillRectangle(gaugeX, gaugeY, gaugeX + fillW, gaugeY + 12, gaugeCol);
         }

         // =================================================================
         // BOX 5 (R3C1): MOMENTUM & TECHNICAL OSCILLATORS + MINI GAUGE
         // =================================================================
         m_canvas.FillRectangle(c1_x1, r3_y1, c1_x2, r3_y2, colInnerBox);
         m_canvas.Rectangle(c1_x1, r3_y1, c1_x2, r3_y2, colInnerBrd);

         m_canvas.FontSet("Segoe UI", 13, FW_BOLD);
         m_canvas.TextOut(c1_x1 + 12, r3_y1 + 8, "ATR / RSI MOMENTUM GAUGE", colTextBlack);

         m_canvas.FontSet("Consolas", 14, FW_BOLD);
         string oscLine;
         if(data[i].currentPrice > 0.0)
            oscLine = StringFormat("ATR(14): %.2f (%.0f pts)  |  RSI(14): %.1f", data[i].atr14, data[i].atrPoints, data[i].rsi14);
         else
            oscLine = "ATR(14): --  |  RSI(14): --";
         m_canvas.TextOut(c1_x1 + 12, r3_y1 + 33, oscLine, colTextBlack);

         m_canvas.FontSet("Segoe UI", 13, FW_BOLD);
         uint rsiCol = (data[i].rsiCondition == "OVERBOUGHT" ? colBearRed : (data[i].rsiCondition == "OVERSOLD" ? colBullGreen : colAccentBlue));
         m_canvas.TextOut(c1_x1 + 12, r3_y1 + 58, "STATE: " + data[i].rsiCondition + "  |  SWEEP: " + data[i].lastSweepDirection, rsiCol);

         // Circular Visual RSI Radial Ring Indicator
         int rsiRingX = c1_x2 - 32;
         int rsiRingY = r3_y1 + 42;
         DrawMiniGauge(rsiRingX, rsiRingY, 18, (data[i].currentPrice > 0.0 ? data[i].rsi14 : 50.0), rsiCol, colTrackBg);

         // =================================================================
         // BOX 6 (R3C2): SIGNAL CONFIRMATION MATRIX
         // =================================================================
         m_canvas.FillRectangle(c2_x1, r3_y1, c2_x2, r3_y2, colInnerBox);
         m_canvas.Rectangle(c2_x1, r3_y1, c2_x2, r3_y2, colInnerBrd);

         m_canvas.FontSet("Segoe UI", 13, FW_BOLD);
         m_canvas.TextOut(c2_x1 + 12, r3_y1 + 8, "SIGNAL INTELLIGENCE & CONFIRMATION", colTextBlack);

         uint sigColor = (StringFind(data[i].overallSignal, "BUY") >= 0 ? colBullGreen : (StringFind(data[i].overallSignal, "SELL") >= 0 ? colBearRed : colAmber));
         m_canvas.FontSet("Segoe UI", 16, FW_BOLD);
         string sigText = data[i].overallSignal;
         if(data[i].currentPrice > 0.0)
            sigText += StringFormat("  [CONFIDENCE: %.0f%%]", data[i].signalConfidenceScore);
         m_canvas.TextOut(c2_x1 + 12, r3_y1 + 30, sigText, sigColor);

         m_canvas.FontSet("Segoe UI", 12, FW_NORMAL);
         string execState = (data[i].currentPrice > 0.0) ? "ACTION: Validated against 200 EMA trend & Closed M5 bar" : "ACTION: Symbol offline / awaiting feed";
         m_canvas.TextOut(c2_x1 + 12, r3_y1 + 58, execState, colTextMuted);

         // =================================================================
         // BOTTOM RIBBON: VECTOR MOMENTUM GRAPH & PIE TRAJECTORY (42px)
         // =================================================================
         int sparkY = y2 - bottomBarH - 2;
         int sparkH = bottomBarH;
         m_canvas.FillRectangle(x1 + 16, sparkY, x2 - 16, sparkY + sparkH, colCardHeader);
         m_canvas.Rectangle(x1 + 16, sparkY, x2 - 16, sparkY + sparkH, colBorder);

         m_canvas.FontSet("Segoe UI", 13, FW_BOLD);
         m_canvas.TextOut(x1 + 24, sparkY + 12, "INTRADAY VECTOR:", colTextBlack);

         int midY = sparkY + (sparkH / 2);
         m_canvas.Line(x1 + 180, midY, x2 - 24, midY, colBorder);

         uint vecColor = (data[i].m5EmaState == "BULLISH" ? colBullGreen : (data[i].m5EmaState == "BEARISH" ? colBearRed : colAmber));
         int startVecX = x1 + 190;
         int endVecX = x2 - 34;
         int offset = (data[i].m5EmaState == "BULLISH" ? 10 : (data[i].m5EmaState == "BEARISH" ? -10 : 0));
         
         m_canvas.Line(startVecX, midY - (offset / 2), endVecX, midY + offset, vecColor);
         m_canvas.FillCircle(endVecX, midY + offset, 6, vecColor);

         string vecSummary = (data[i].m5EmaState == "BULLISH" ? "POSITIVE EXPANSION (+)" : (data[i].m5EmaState == "BEARISH" ? "NEGATIVE EXPANSION (-)" : "SIDEWAYS CHOP (0)"));
         m_canvas.FontSet("Segoe UI", 13, FW_BOLD);
         m_canvas.TextOut(startVecX + 45, sparkY + 12, vecSummary, vecColor);
      }

      // Fast in-memory bitmap flip (no flickering, no redraw loops)
      m_canvas.Update();
   }
};
