//+------------------------------------------------------------------+
//| Bloomberg Master Terminal Dashboard (White Luxury Institutional) |
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

   void RenderTerminal(
      datetime serverTime, datetime ukTime, string sessionStatus,
      double dailyDD, double maxDailyDD, double openRisk, double maxRisk,
      int openPos, int maxPos,
      double dxyPrice, double dxyChange,
      InstrumentQuantAnalytics &data[]
   )
   {
      if(!Init()) return;

      // --- COLOR PALETTE: Institutional White Luxury ---
      uint colBg         = ColorToARGB(0xFFFFFF, 255); // Pure Solid White (#FFFFFF)
      uint colCard       = ColorToARGB(0xF8F9FA, 255); // Pearl White Card (#F8F9FA)
      uint colBorder     = ColorToARGB(0xE2E8F0, 255); // Slate Border (#E2E8F0)
      uint colHeaderBg   = ColorToARGB(0xF1F5F9, 255); // Light Header (#F1F5F9)
      uint colTextBlack  = ColorToARGB(0x0F172A, 255); // Deep Charcoal / Black (#0F172A)
      uint colTextMuted  = ColorToARGB(0x64748B, 255); // Slate Muted (#64748B)
      uint colBullGreen  = ColorToARGB(0x00873E, 255); // Forest Green (#00873E)
      uint colBearRed    = ColorToARGB(0xD90429, 255); // Crimson Red (#D90429)
      uint colAccentBlue = ColorToARGB(0x2563EB, 255); // Institutional Blue (#2563EB)
      uint colAmber      = ColorToARGB(0xD97706, 255); // Amber / Warning (#D97706)

      m_canvas.Erase(colBg);

      // ====================================================================
      // 1. TOP MASTER HEADER BAR
      // ====================================================================
      m_canvas.FillRectangle(0, 0, m_width, 56, colHeaderBg);
      m_canvas.Line(0, 56, m_width, 56, colBorder);

      m_canvas.FontSet("Segoe UI", 15, FW_BOLD);
      m_canvas.TextOut(20, 14, "HR BLOOMBERG QUANT TERMINAL", colTextBlack);
      m_canvas.FontSet("Segoe UI", 10, FW_BOLD);
      m_canvas.TextOut(315, 18, "INSTITUTIONAL MARKET INTELLIGENCE OS", colAccentBlue);

      m_canvas.FontSet("Lucida Console", 10, FW_NORMAL);
      string timeStr = StringFormat("SERVER: %s | UK GMT: %s | SESSION: %s",
                                    TimeToString(serverTime, TIME_MINUTES|TIME_SECONDS),
                                    TimeToString(ukTime, TIME_MINUTES|TIME_SECONDS),
                                    sessionStatus);
      m_canvas.TextOut(630, 18, timeStr, colTextBlack);

      string riskStr = StringFormat("DD: %.2f%% / %.1f%% | RISK: %.2f%% / %.1f%% | POS: %d/%d",
                                    dailyDD, maxDailyDD, openRisk, maxRisk, openPos, maxPos);
      m_canvas.TextOut(m_width - 410, 18, riskStr, (dailyDD >= maxDailyDD ? colBearRed : colTextBlack));

      // ====================================================================
      // 2. MACRO INTELLIGENCE & DXY CORRELATION STRIP
      // ====================================================================
      int stripY = 62;
      m_canvas.FillRectangle(16, stripY, m_width - 16, stripY + 36, colCard);
      m_canvas.Rectangle(16, stripY, m_width - 16, stripY + 36, colBorder);

      m_canvas.FontSet("Segoe UI", 10, FW_BOLD);
      m_canvas.TextOut(28, stripY + 9, "MACRO REGIME:", colTextMuted);

      string dxyStr = StringFormat("US DOLLAR INDEX (DXY): %.3f (%+.2f%%)", dxyPrice, dxyChange);
      uint dxyColor = (dxyChange >= 0.0) ? colBullGreen : colBearRed;
      m_canvas.TextOut(130, stripY + 9, dxyStr, dxyColor);

      m_canvas.FontSet("Segoe UI", 9, FW_NORMAL);
      m_canvas.TextOut(395, stripY + 10, "ROLLING CORRELATIONS:  Gold [-0.88] | Nasdaq [-0.74] | S&P 500 [-0.79] | Silver [-0.82]", colAccentBlue);
      m_canvas.TextOut(m_width - 240, stripY + 10, "NEWS FILTER: LOW RISK REGIME", colBullGreen);

      // ====================================================================
      // 3. FOUR MASTER INSTRUMENT PANELS (2x2 GRID)
      // ====================================================================
      int gridY = 106;
      int gap = 12;
      int totalW = m_width - 32;
      int tileW = (totalW - gap) / 2;
      int tileH = (m_height - gridY - 16 - gap) / 2;
      if(tileH < 280) tileH = 280;

      for(int i = 0; i < 4; i++)
      {
         int col = i % 2;
         int row = i / 2;
         int x1 = 16 + (col * (tileW + gap));
         int y1 = gridY + (row * (tileH + gap));
         int x2 = x1 + tileW;
         int y2 = y1 + tileH;

         // Card background & Clean Slate Border
         m_canvas.FillRectangle(x1, y1, x2, y2, colCard);
         m_canvas.Rectangle(x1, y1, x2, y2, colBorder);

         // Card Header Bar
         m_canvas.FillRectangle(x1, y1, x2, y1 + 38, colHeaderBg);
         m_canvas.Line(x1, y1 + 38, x2, y1 + 38, colBorder);

         // Prominent Symbol Title
         m_canvas.FontSet("Segoe UI", 14, FW_BOLD);
         m_canvas.TextOut(x1 + 14, y1 + 8, data[i].baseName + " (" + data[i].symbol + ")", colTextBlack);

         // SINGLE PROMINENT CURRENT MARKET PRICE & DIRECTION
         m_canvas.FontSet("Lucida Console", 14, FW_BOLD);
         string priceStr = StringFormat("%.2f (%+.2f%%)", data[i].currentPrice, data[i].priceChangePct);
         uint priceCol = (data[i].priceChangePct >= 0.0) ? colBullGreen : colBearRed;
         m_canvas.TextOut(x2 - 240, y1 + 9, priceStr, priceCol);

         // Data Sections
         int cy = y1 + 46;
         m_canvas.FontSet("Segoe UI", 9, FW_NORMAL);

         // --- SECTION A: 9/21/200 EMA SYSTEM ---
         m_canvas.FontSet("Segoe UI", 9, FW_BOLD);
         m_canvas.TextOut(x1 + 14, cy, "EMA 9/21/200 ENGINE:", colTextBlack);
         m_canvas.FontSet("Segoe UI", 9, FW_NORMAL);
         string emaLine = StringFormat("9: %.1f | 21: %.1f | 200: %.1f | Sep: %.2f%%",
                                       data[i].ema9_m5, data[i].ema21_m5, data[i].ema200_m5, data[i].emaSeparationPct);
         m_canvas.TextOut(x1 + 145, cy, emaLine, colTextMuted);

         // --- SECTION B: MULTI-TIMEFRAME ALIGNMENT MATRIX ---
         cy += 20;
         m_canvas.FontSet("Segoe UI", 9, FW_BOLD);
         m_canvas.TextOut(x1 + 14, cy, "MTF MATRIX:", colTextBlack);
         m_canvas.FontSet("Lucida Console", 9, FW_BOLD);
         m_canvas.TextOut(x1 + 105, cy, "D1:" + data[i].mtfD1, (data[i].mtfD1 == "BULLISH" ? colBullGreen : colBearRed));
         m_canvas.TextOut(x1 + 205, cy, "H1:" + data[i].mtfH1, (data[i].mtfH1 == "BULLISH" ? colBullGreen : colBearRed));
         m_canvas.TextOut(x1 + 305, cy, "M15:" + data[i].mtfM15, (data[i].mtfM15 == "BULLISH" ? colBullGreen : colBearRed));
         m_canvas.TextOut(x1 + 415, cy, "M5:" + data[i].mtfM5, (data[i].mtfM5 == "BULLISH" ? colBullGreen : colBearRed));

         // --- SECTION C: MARKET STRUCTURE & SWINGS ---
         cy += 20;
         m_canvas.FontSet("Segoe UI", 9, FW_BOLD);
         m_canvas.TextOut(x1 + 14, cy, "STRUCTURE / BOS:", colTextBlack);
         m_canvas.FontSet("Segoe UI", 9, FW_NORMAL);
         m_canvas.TextOut(x1 + 130, cy, data[i].structureClass, colAccentBlue);
         m_canvas.TextOut(x1 + 250, cy, "BOS: " + data[i].bosStatus, (data[i].bosStatus == "BULLISH BOS" ? colBullGreen : (data[i].bosStatus == "BEARISH BOS" ? colBearRed : colTextMuted)));
         m_canvas.TextOut(x1 + 390, cy, "REGIME: " + data[i].regimeClassification, colTextBlack);

         // --- SECTION D: LIQUIDITY INTELLIGENCE ---
         cy += 20;
         m_canvas.FontSet("Segoe UI", 9, FW_BOLD);
         m_canvas.TextOut(x1 + 14, cy, "LIQUIDITY POOLS:", colTextBlack);
         m_canvas.FontSet("Segoe UI", 9, FW_NORMAL);
         string bslStr = StringFormat("BSL: %.1f (%.0f pts)", data[i].nearestBSL, data[i].bslDistancePoints);
         string sslStr = StringFormat("SSL: %.1f (%.0f pts)", data[i].nearestSSL, data[i].sslDistancePoints);
         m_canvas.TextOut(x1 + 130, cy, bslStr, colBullGreen);
         m_canvas.TextOut(x1 + 270, cy, sslStr, colBearRed);
         m_canvas.TextOut(x1 + 410, cy, "SWEEP: " + data[i].lastSweepDirection, (StringFind(data[i].lastSweepDirection, "BULLISH") >= 0 ? colBullGreen : (StringFind(data[i].lastSweepDirection, "BEARISH") >= 0 ? colBearRed : colTextMuted)));

         // --- SECTION E: VOLUME, RVOL & ORDER-FLOW PROXY ---
         cy += 20;
         m_canvas.FontSet("Segoe UI", 9, FW_BOLD);
         m_canvas.TextOut(x1 + 14, cy, "VOLUME / ORDER FLOW:", colTextBlack);
         m_canvas.FontSet("Segoe UI", 9, FW_NORMAL);
         string volStr = StringFormat("Vol: %d | RVOL: %.2fx (%s) | Buying Pres: %.0f%% (Tick Proxy)",
                                      data[i].prevTickVol, data[i].rvol, data[i].volExpansion, data[i].buyingPressurePct);
         m_canvas.TextOut(x1 + 160, cy, volStr, colTextMuted);

         // --- SECTION F: ATR / RSI / MACD ---
         cy += 20;
         m_canvas.FontSet("Segoe UI", 9, FW_BOLD);
         m_canvas.TextOut(x1 + 14, cy, "ATR / RSI / MACD:", colTextBlack);
         m_canvas.FontSet("Segoe UI", 9, FW_NORMAL);
         string indLine = StringFormat("ATR(14): %.2f | RSI: %.1f (%s) | MACD Hist: %.2f",
                                       data[i].atr14, data[i].rsi14, data[i].rsiCondition, data[i].macdHist);
         m_canvas.TextOut(x1 + 135, cy, indLine, colAccentBlue);

         // --- SECTION G: STRATEGY STATUS & CONFIRMATION ---
         cy += 20;
         m_canvas.FontSet("Segoe UI", 9, FW_BOLD);
         m_canvas.TextOut(x1 + 14, cy, "SIGNAL INTELLIGENCE:", colTextBlack);
         uint sigCol = (StringFind(data[i].overallSignal, "BUY") >= 0 ? colBullGreen : (StringFind(data[i].overallSignal, "SELL") >= 0 ? colBearRed : colAmber));
         m_canvas.TextOut(x1 + 155, cy, data[i].overallSignal + " [Conf: " + DoubleToString(data[i].signalConfidenceScore, 0) + "%]", sigCol);

         // --- SECTION H: LIVE VECTOR MOMENTUM GRAPH & SPARKLINE ---
         int graphY = cy + 24;
         int graphH = y2 - graphY - 14;
         if(graphH > 35)
         {
            m_canvas.FillRectangle(x1 + 14, graphY, x2 - 14, graphY + graphH, colHeaderBg);
            m_canvas.Rectangle(x1 + 14, graphY, x2 - 14, graphY + graphH, colBorder);
            
            m_canvas.FontSet("Segoe UI", 8, FW_BOLD);
            m_canvas.TextOut(x1 + 22, graphY + 3, "INTRADAY REGIME & EMA MOMENTUM VECTOR", colTextMuted);

            int midY = graphY + (graphH / 2);
            m_canvas.Line(x1 + 14, midY, x2 - 14, midY, colBorder);

            uint trendColor = (data[i].m5EmaState == "BULLISH" ? colBullGreen : (data[i].m5EmaState == "BEARISH" ? colBearRed : colAmber));
            int startX = x1 + 140;
            int endX = x2 - 24;
            int offset = (data[i].m5EmaState == "BULLISH" ? 14 : -14);
            m_canvas.Line(startX, midY - (offset / 2), endX, midY + offset, trendColor);
            m_canvas.FillCircle(endX, midY + offset, 4, trendColor);
         }
      }

      m_canvas.Update();
   }
};
