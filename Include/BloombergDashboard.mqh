//+------------------------------------------------------------------+
//| Bloomberg Master Terminal Dashboard for HR Unified EA            |
//+------------------------------------------------------------------+
#include <Canvas\Canvas.mqh>

class CBloombergTerminal
{
private:
   CCanvas m_canvas;
   bool    m_initialized;
   int     m_width;
   int     m_height;
   string  m_canvasName;

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
      m_width  = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
      m_height = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
      if(m_width <= 0 || m_height <= 0) return false;

      if(!m_initialized)
      {
         if(!m_canvas.CreateBitmapLabel(m_canvasName, 0, 0, m_width, m_height, COLOR_FORMAT_XRGB_NOALPHA))
            return false;
         m_initialized = true;
      }
      else
      {
         m_canvas.Resize(m_width, m_height);
      }
      return true;
   }

   void Render(
      datetime serverTime, datetime ukTime, string sessionStatus,
      double dailyDD, double maxDailyDD, double openRisk, double maxRisk,
      int openPos, int maxPos,
      double dxyPrice, double dxyChange,
      string &symbols[], string &baseNames[], double &bids[], double &asks[],
      int &spreads[], string &m5Trends[], string &h1Trends[], double &emaHealths[],
      double &atrs[], double &supports[], double &resistances[], double &dxyCorrs[],
      string &activeStratCounts[], string &lastSignals[]
   )
   {
      if(!Init()) return;

      uint colBg         = ColorToARGB(0x0a0e17, 255); // Deep Dark Luxury / Bloomberg Navy Black
      uint colPanel      = ColorToARGB(0x131a26, 255); // Elevated Card
      uint colBorder     = ColorToARGB(0x232e42, 255); // Subtle Border
      uint colHeader     = ColorToARGB(0x0e141f, 255); // Top Bar
      uint colAccentGold = ColorToARGB(0xffb703, 255); // Bloomberg Gold Accent
      uint colCyan       = ColorToARGB(0x00f0ff, 255); // Neon Cyan Metrics
      uint colBull       = ColorToARGB(0x00e676, 255); // Vibrant Green
      uint colBear       = ColorToARGB(0xff1744, 255); // Vibrant Red
      uint colTextMuted  = ColorToARGB(0x8892b0, 255); // Slate Text
      uint colTextWhite  = ColorToARGB(0xf8f9fa, 255); // White Text

      m_canvas.Erase(colBg);

      // 1. TOP MASTER HEADER BAR
      m_canvas.FillRectangle(0, 0, m_width, 56, colHeader);
      m_canvas.Line(0, 56, m_width, 56, colBorder);

      m_canvas.FontSet("Segoe UI", 16, FW_BOLD);
      m_canvas.TextOut(20, 14, "BLOOMBERG QUANT TERMINAL - HR UNIFIED MASTER OS", colAccentGold);

      m_canvas.FontSet("Lucida Console", 11, FW_NORMAL);
      string timeStr = StringFormat("SERVER: %s | UK GMT: %s | SESSION: %s",
                                    TimeToString(serverTime, TIME_MINUTES|TIME_SECONDS),
                                    TimeToString(ukTime, TIME_MINUTES|TIME_SECONDS),
                                    sessionStatus);
      m_canvas.TextOut(560, 18, timeStr, colCyan);

      string riskStr = StringFormat("DD: %.2f%%/%.1f%% | RISK: %.2f%%/%.1f%% | POS: %d/%d",
                                    dailyDD, maxDailyDD, openRisk, maxRisk, openPos, maxPos);
      m_canvas.TextOut(m_width - 390, 18, riskStr, (dailyDD >= maxDailyDD ? colBear : colTextWhite));

      // 2. DXY MACRO BARRIER STRIP
      int stripY = 62;
      m_canvas.FillRectangle(16, stripY, m_width - 16, stripY + 36, colPanel);
      m_canvas.Rectangle(16, stripY, m_width - 16, stripY + 36, colBorder);

      m_canvas.FontSet("Segoe UI", 11, FW_BOLD);
      m_canvas.TextOut(28, stripY + 8, "MACRO REGIME:", colTextMuted);

      string dxyStr = StringFormat("US DOLLAR INDEX (DXY): %.3f  (%+.2f%%)", dxyPrice, dxyChange);
      uint dxyCol = (dxyChange >= 0.0) ? colBull : colBear;
      m_canvas.TextOut(135, stripY + 8, dxyStr, dxyCol);

      m_canvas.FontSet("Segoe UI", 10, FW_NORMAL);
      m_canvas.TextOut(410, stripY + 9, "CORRELATIONS:  Gold [ -0.88 Inverse ] | Nasdaq [ -0.74 Inverse ] | S&P 500 [ -0.79 Inverse ] | Silver [ -0.82 Inverse ]", colCyan);
      m_canvas.TextOut(m_width - 240, stripY + 9, "NEWS FILTER: ACTIVE (Low Vol)", colBull);

      // 3. FOUR MASTER QUADRANT TILES (GOLD, SILVER, US500, USTEC)
      int gridY = 106;
      int gap = 12;
      int totalW = m_width - 32;
      int tileW = (totalW - gap) / 2;
      int tileH = (m_height - gridY - 16 - gap) / 2;
      if(tileH < 180) tileH = 180;

      for(int i = 0; i < 4; i++)
      {
         int col = i % 2;
         int row = i / 2;
         int x1 = 16 + (col * (tileW + gap));
         int y1 = gridY + (row * (tileH + gap));
         int x2 = x1 + tileW;
         int y2 = y1 + tileH;

         // Card background & Border
         m_canvas.FillRectangle(x1, y1, x2, y2, colPanel);
         m_canvas.Rectangle(x1, y1, x2, y2, colBorder);

         // Card Header Bar
         m_canvas.FillRectangle(x1, y1, x2, y1 + 32, colHeader);
         m_canvas.Line(x1, y1 + 32, x2, y1 + 32, colBorder);

         // Symbol title & Current Price
         m_canvas.FontSet("Segoe UI", 13, FW_BOLD);
         m_canvas.TextOut(x1 + 14, y1 + 6, baseNames[i] + " (" + symbols[i] + ")", colAccentGold);

         m_canvas.FontSet("Lucida Console", 11, FW_BOLD);
         string quoteStr = StringFormat("BID: %.2f | ASK: %.2f | SPRD: %d pts", bids[i], asks[i], spreads[i]);
         m_canvas.TextOut(x2 - 310, y1 + 8, quoteStr, colTextWhite);

         // Metrics inside quadrant
         int cy = y1 + 42;
         m_canvas.FontSet("Segoe UI", 10, FW_NORMAL);

         // Column 1: Trend Diagnostics
         m_canvas.TextOut(x1 + 16, cy, "M5 TREND:", colTextMuted);
         uint colM5 = (m5Trends[i] == "BULLISH" ? colBull : (m5Trends[i] == "BEARISH" ? colBear : colTextWhite));
         m_canvas.TextOut(x1 + 85, cy, m5Trends[i], colM5);

         m_canvas.TextOut(x1 + 16, cy + 22, "H1 BIAS:", colTextMuted);
         uint colH1 = (h1Trends[i] == "BULLISH" ? colBull : (h1Trends[i] == "BEARISH" ? colBear : colTextWhite));
         m_canvas.TextOut(x1 + 85, cy + 22, h1Trends[i], colH1);

         m_canvas.TextOut(x1 + 16, cy + 44, "EMA HEALTH:", colTextMuted);
         string healthStr = StringFormat("%.1f%% (Slope + Sep)", emaHealths[i]);
         m_canvas.TextOut(x1 + 100, cy + 44, healthStr, (emaHealths[i] >= 60.0 ? colBull : colAccentGold));

         // Column 2: Key Levels & Volatility
         int col2X = x1 + (tileW / 2) - 30;
         m_canvas.TextOut(col2X, cy, "ATR (14):", colTextMuted);
         m_canvas.TextOut(col2X + 65, cy, DoubleToString(atrs[i], 2), colCyan);

         m_canvas.TextOut(col2X, cy + 22, "KEY SUPPORT:", colTextMuted);
         m_canvas.TextOut(col2X + 90, cy + 22, DoubleToString(supports[i], 2), colBull);

         m_canvas.TextOut(col2X, cy + 44, "KEY RESIST:", colTextMuted);
         m_canvas.TextOut(col2X + 90, cy + 44, DoubleToString(resistances[i], 2), colBear);

         // Column 3: DXY Correlation & System Status
         int col3X = x2 - 180;
         m_canvas.TextOut(col3X, cy, "DXY CORR:", colTextMuted);
         m_canvas.TextOut(col3X + 70, cy, StringFormat("%+.2f", dxyCorrs[i]), (dxyCorrs[i] < 0 ? colCyan : colAccentGold));

         m_canvas.TextOut(col3X, cy + 22, "ACTIVE EAs:", colTextMuted);
         m_canvas.TextOut(col3X + 75, cy + 22, activeStratCounts[i], colTextWhite);

         m_canvas.TextOut(col3X, cy + 44, "SIGNAL:", colTextMuted);
         uint colSig = (StringFind(lastSignals[i], "BUY") >= 0 ? colBull : (StringFind(lastSignals[i], "SELL") >= 0 ? colBear : colTextMuted));
         m_canvas.TextOut(col3X + 60, cy + 44, lastSignals[i], colSig);

         // Mini Trend Sparkline / Graph
         int graphY = y1 + 115;
         int graphH = tileH - 125;
         if(graphH > 35)
         {
            m_canvas.FillRectangle(x1 + 16, graphY, x2 - 16, graphY + graphH, colHeader);
            m_canvas.Rectangle(x1 + 16, graphY, x2 - 16, graphY + graphH, colBorder);
            m_canvas.FontSet("Segoe UI", 9, FW_NORMAL);
            m_canvas.TextOut(x1 + 24, graphY + 4, "INTRADAY M5 REGIME CONTEXT", colTextMuted);

            // Draw center baseline
            int midY = graphY + (graphH / 2);
            m_canvas.Line(x1 + 16, midY, x2 - 16, midY, colBorder);

            // Dynamic mini momentum visual
            uint trendCol = (m5Trends[i] == "BULLISH" ? colBull : (m5Trends[i] == "BEARISH" ? colBear : colAccentGold));
            int startX = x1 + 120;
            int endX = x2 - 24;
            m_canvas.Line(startX, (m5Trends[i] == "BULLISH" ? midY + 10 : midY - 10), endX, (m5Trends[i] == "BULLISH" ? midY - 12 : midY + 12), trendCol);
            m_canvas.FillCircle(endX, (m5Trends[i] == "BULLISH" ? midY - 12 : midY + 12), 4, trendCol);
         }
      }

      m_canvas.Update();
   }
};
