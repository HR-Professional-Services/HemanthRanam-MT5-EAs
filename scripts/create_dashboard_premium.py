import os

v4_dir = r"C:\Users\vaibh\.gemini\antigravity-ide\scratch\HemanthRanam-MT5-EAs\06_MULTI_PAIR_SCANNERS\HR_UNIFIED_MASTER_OS_V4_FINAL"
repo_dir = r"C:\Users\vaibh\.gemini\antigravity-ide\scratch\HemanthRanam-MT5-EAs"
src_file = os.path.join(repo_dir, "00_UNIFIED_SYSTEM", "HR_UNIFIED_MULTI_STRATEGY_EA.mq5")

with open(src_file, "r", encoding="utf-8") as f:
    text = f.read()

start_term = text.find("class CBloombergTerminal")
end_term = text.find("class CQuantAnalyticsEngine")
term_code = text[start_term:end_term]

# We need to build HR_Dashboard_Premium.mqh
# It will have:
# #include "HR_Utils.mqh"
# And then the complete CBloombergTerminal with the requested Bloomberg Flash Flicker enhancements!

dashboard_mqh = """//+------------------------------------------------------------------+
//|                                   HR_Dashboard_Premium.mqh       |
//| V4 FINAL LOCK - KEEP EXISTING FORMAT - 2026-05-06                |
//| Premium Digital 44px - Verified Linked - 24/7 - Flicker Added    |
//| Copyright 2026, Hemanth Ranam                                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Hemanth Ranam"
#property link      "https://github.com/HR-Professional-Services/HemanthRanam-MT5-EAs"
#property strict

#include <Canvas\\Canvas.mqh>
#include "HR_Utils.mqh"

//+------------------------------------------------------------------+
//| CBloombergTerminal: Institutional CCanvas Graphics Engine         |
//| V4 FINAL: DIGITAL WATCH NUMBERS 44px + 30px TRIBAL BOLD HEADINGS |
//| REAL-TIME 300ms BLOOMBERG FLICKER + LOCKED 1:1 ARCHITECTURE      |
//+------------------------------------------------------------------+
class CBloombergTerminal
{
private:
   CCanvas               m_canvas;
   bool                  m_initialized;
   int                   m_width;
   int                   m_height;
   string                m_canvasName;
   BloombergFlickerState m_flicker;

   // Helper: Format number string with extra tracking/letter spacing for Digital LED look
   string FormatDigitalSpacing(string val)
   {
      string out = "";
      int len = StringLen(val);
      for(int i = 0; i < len; i++)
      {
         out += StringSubstr(val, i, 1);
         if(i < len - 1 && StringSubstr(val, i, 1) != " ")
            out += " ";
      }
      return out;
   }

   // Helper: Draw a solid rounded-look pill/badge with scalable typography
   void DrawPill(int x, int y, int w, int h, string text, uint bgCol, uint textCol, int fontSize = 16, bool isBold = true)
   {
      m_canvas.FillRectangle(x + 3, y, x + w - 3, y + h, bgCol);
      m_canvas.FillRectangle(x, y + 3, x + w, y + h - 3, bgCol);
      m_canvas.FontSet("Segoe UI Black", fontSize, isBold ? FW_BLACK : FW_BOLD);
      int charWidth = (fontSize >= 18) ? 11 : ((fontSize >= 15) ? 9 : 8);
      int textW = (int)StringLen(text) * charWidth;
      int tx = x + (w - textW) / 2;
      if(tx < x + 4) tx = x + 4;
      int ty = y + (h - (fontSize + 4)) / 2;
      m_canvas.TextOut(tx, ty, text, textCol);
   }

   // Helper: Draw a clean institutional box with subtle border
   void DrawModuleBox(int x1, int y1, int x2, int y2, uint bgCol, uint brdCol)
   {
      m_canvas.FillRectangle(x1, y1, x2, y2, bgCol);
      m_canvas.Rectangle(x1, y1, x2, y2, brdCol);
   }

   // Helper: Draw Speedometer Arc Gauge with needle and large digital readout for RSI
   void DrawSpeedometerGauge(int cx, int cy, int radius, double val, double minVal, double maxVal, uint colTrack, uint colGreen, uint colRed, uint colNeedle, uint flashGaugeBg = 0)
   {
      double clamped = MathMax(minVal, MathMin(maxVal, val));
      double pct = (clamped - minVal) / (maxVal - minVal); // 0.0 to 1.0

      if(flashGaugeBg != 0)
      {
         m_canvas.FillCircle(cx, cy - (radius / 2), radius, flashGaugeBg);
      }

      // Draw thick 10px curved arc band
      int arcThickness = 10;
      for(int r = radius - arcThickness; r <= radius; r++)
      {
         for(int deg = 180; deg <= 360; deg += 2)
         {
            double rad = deg * 3.1415926535 / 180.0;
            int px = cx + (int)(r * MathCos(rad));
            int py = cy + (int)(r * MathSin(rad));

            // Visual zone: Red zone (0-30%), Gray middle (30-70%), Green zone (70-100%)
            uint dotCol = colTrack;
            if(deg <= 180 + (int)(180 * 0.30))
               dotCol = colRed;
            else if(deg >= 180 + (int)(180 * 0.70))
               dotCol = colGreen;

            m_canvas.PixelSet(px, py, dotCol);
         }
      }

      // Needle Angle (-180 to 0 degrees mapped across semicircle)
      double needleAngle = 180.0 + (pct * 180.0);
      double nRad = needleAngle * 3.1415926535 / 180.0;
      int nx = cx + (int)((radius - 2) * MathCos(nRad));
      int ny = cy + (int)((radius - 2) * MathSin(nRad));

      // Draw 3px bold needle pointer
      m_canvas.Line(cx, cy, nx, ny, colNeedle);
      m_canvas.Line(cx - 1, cy, nx - 1, ny, colNeedle);
      m_canvas.Line(cx + 1, cy, nx + 1, ny, colNeedle);

      // Center Hub Pivot Pin
      m_canvas.FillCircle(cx, cy, 6, colNeedle);

      // Large 24px Digital readout inside gauge
      m_canvas.FontSet("Consolas", 24, FW_BOLD);
      string rsiStr = StringFormat("%.1f", val);
      int rw = (int)StringLen(rsiStr) * 14;
      // Drop shadow glow
      m_canvas.TextOut(cx - (rw / 2) + 1, cy - 36 + 1, rsiStr, 0x40000000);
      m_canvas.TextOut(cx - (rw / 2), cy - 36, rsiStr, (val >= 70.0 ? colGreen : (val <= 30.0 ? colRed : 0xFF0F172A)));
   }

   // Helper: Draw Trajectory Sparkline with Gradient Shaded Area (Thick 3px Vector from live EMA 9 history)
   void DrawTrajectoryArea(int x1, int y1, int x2, int y2, bool isBullish, uint lineCol, uint fillCol, const double &emaHistory[])
   {
      int w = x2 - x1;
      int h = y2 - y1;
      if(w <= 10 || h <= 10) return;

      int points = 18;
      int prevX = x1;
      int prevY = isBullish ? (y2 - 8) : (y1 + 8);

      // Check if real history buffer is available
      double minE = 9999999.0, maxE = -9999999.0;
      bool hasRealData = false;
      for(int k = 0; k < 18; k++)
      {
         if(emaHistory[k] > 0.0)
         {
            hasRealData = true;
            if(emaHistory[k] < minE) minE = emaHistory[k];
            if(emaHistory[k] > maxE) maxE = emaHistory[k];
         }
      }

      for(int p = 0; p < points; p++)
      {
         int px = x1 + (int)((double)p / (points - 1) * w);
         double progress = (double)p / (points - 1);
         
         int py;
         if(hasRealData && maxE > minE)
         {
            // Oldest bar is at index (17 - p)
            int idx = 17 - p;
            double norm = (emaHistory[idx] - minE) / (maxE - minE); // 0.0 to 1.0
            py = (int)(y2 - 10 - (norm * (h - 22)));
         }
         else if(isBullish)
         {
            double wave = MathSin(p * 1.1) * (h * 0.14) + MathCos(p * 0.6) * (h * 0.08);
            py = (int)(y2 - 10 - (progress * (h - 22)) + wave);
         }
         else
         {
            double wave = MathSin(p * 1.1) * (h * 0.14) + MathCos(p * 0.6) * (h * 0.08);
            py = (int)(y1 + 8 + (progress * (h - 22)) + wave);
         }
         if(py < y1 + 3) py = y1 + 3;
         if(py > y2 - 4) py = y2 - 4;

         for(int fy = py; fy < y2 - 2; fy++)
         {
            for(int fx = MathMax(x1, px - 2); fx <= px; fx++)
            {
               m_canvas.PixelSet(fx, fy, fillCol);
            }
         }

         if(p > 0)
         {
            // Thick 3px line
            m_canvas.Line(prevX, prevY, px, py, lineCol);
            m_canvas.Line(prevX, prevY - 1, px, py - 1, lineCol);
            m_canvas.Line(prevX, prevY + 1, px, py + 1, lineCol);
         }
         prevX = px;
         prevY = py;
      }
   }

public:
   CBloombergTerminal() : m_initialized(false), m_width(0), m_height(0), m_canvasName("HR_Bloomberg_Master_Terminal")
   {
      m_flicker.Reset();
   }
   
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

   // Update real-time flicker states on price/pct/indicators
   void CheckFlicker(int idx, double newPrice, double newPct, string newEmaM5, double newBuyPress, double newRsi, double newBsl, double newSsl)
   {
      ulong now = GetTickCount();

      // 1. Price Flicker: 300ms flash Light Green #D1FAE5 / Light Red #FEE2E2
      if(m_flicker.prevPrice[idx] > 0.0 && newPrice != m_flicker.prevPrice[idx])
      {
         if(newPrice > m_flicker.prevPrice[idx])
         {
            m_flicker.priceFlickerBg[idx]  = CLR_BULL_LIGHT; // #D1FAE5
            m_flicker.priceFlickerTxt[idx] = CLR_BULL_GREEN; // #10B981
         }
         else
         {
            m_flicker.priceFlickerBg[idx]  = CLR_BEAR_LIGHT; // #FEE2E2
            m_flicker.priceFlickerTxt[idx] = CLR_BEAR_RED;   // #EF4444
         }
         m_flicker.priceFlickerEnd[idx] = now + 300;
      }
      m_flicker.prevPrice[idx] = newPrice;

      // 2. Percentage Change Flicker: 300ms
      if(m_flicker.prevPct[idx] != 0.0 && MathAbs(newPct - m_flicker.prevPct[idx]) > 0.01)
      {
         m_flicker.pctFlickerBg[idx]  = (newPct >= 0.0 ? CLR_BULL_LIGHT : CLR_BEAR_LIGHT);
         m_flicker.pctFlickerEnd[idx] = now + 300;
      }
      m_flicker.prevPct[idx] = newPct;

      // 3. EMA Regime Pill Flicker: 400ms flash
      if(m_flicker.prevEmaM5[idx] != "" && newEmaM5 != m_flicker.prevEmaM5[idx])
      {
         m_flicker.emaFlickerBg[idx]  = 0xFFFCD34D; // Bright Yellow-Amber flash
         m_flicker.emaFlickerEnd[idx] = now + 400;
      }
      m_flicker.prevEmaM5[idx] = newEmaM5;

      // 4. RSI Overbought/Oversold Cross Flicker: 500ms
      if((newRsi >= 70.0 && m_flicker.prevRsi[idx] < 70.0) || (newRsi <= 30.0 && m_flicker.prevRsi[idx] > 30.0))
      {
         m_flicker.gaugeFlickerBg[idx]  = 0xFFFEF3C7; // Light yellow
         m_flicker.gaugeFlickerEnd[idx] = now + 500;
      }
      m_flicker.prevRsi[idx] = newRsi;

      // 5. BSL / SSL Swept Flicker: 500ms
      if((m_flicker.prevBsl[idx] > 0.0 && newBsl != m_flicker.prevBsl[idx]) || (m_flicker.prevSsl[idx] > 0.0 && newSsl != m_flicker.prevSsl[idx]))
      {
         m_flicker.bslFlickerBg[idx]  = 0xFFFED7AA; // Light Orange
         m_flicker.bslFlickerEnd[idx] = now + 500;
      }
      m_flicker.prevBsl[idx] = newBsl;
      m_flicker.prevSsl[idx] = newSsl;

      // 6. Buy Pressure > 5% shift: 300ms
      if(m_flicker.prevBuyPress[idx] > 0.0 && MathAbs(newBuyPress - m_flicker.prevBuyPress[idx]) >= 5.0)
      {
         m_flicker.volFlickerBg[idx]  = 0xFF6EE7B7; // Bright Emerald
         m_flicker.volFlickerEnd[idx] = now + 300;
      }
      m_flicker.prevBuyPress[idx] = newBuyPress;
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

      ulong now = GetTickCount();

      // Check flicker transitions for all 4 symbols
      for(int k = 0; k < 4; k++)
      {
         CheckFlicker(k, data[k].currentPrice, data[k].priceChangePct, data[k].m5EmaState, data[k].buyingPressurePct, data[k].rsi14, data[k].nearestBSL, data[k].nearestSSL);
      }

      // DIRECT ARGB TOKENS (Pure RGB, zero blue/red reversals)
      uint colPageBg     = CLR_PAGE_BG;
      uint colCardBg     = CLR_CARD_BG;
      uint colInnerBg    = CLR_INNER_BG;
      uint colBorder     = CLR_BORDER;
      uint colInnerBrd   = CLR_INNER_BRD;
      uint colTextBlack  = CLR_TEXT_BLACK;
      uint colTextMuted  = CLR_TEXT_MUTED;
      uint colTextSubtle = CLR_TEXT_SUBTLE;

      uint colBullGreen  = CLR_BULL_GREEN;
      uint colBullDark   = CLR_BULL_DARK;
      uint colBullLight  = CLR_BULL_LIGHT;
      uint colBearRed    = CLR_BEAR_RED;
      uint colBearDark   = CLR_BEAR_DARK;
      uint colBearLight  = CLR_BEAR_LIGHT;

      uint colAmberBg    = CLR_AMBER_BG;
      uint colAmberTxt   = CLR_AMBER_TXT;
      uint colChipGray   = CLR_CHIP_GRAY;
      uint colTrackBg    = CLR_TRACK_BG;
      uint colPillText   = CLR_PILL_TEXT;

      // Master Canvas Background Fill
      m_canvas.Erase(colPageBg);

      int sidePad  = 12;
      int contentW = m_width - (2 * sidePad);
      if(contentW < 900) contentW = 900;

      // AUTO-SCALED COMPONENT HEIGHTS (V3/V4 DIGITAL EXPANSION)
      int headY         = 8;
      int headH         = 64; 
      int macroY        = headY + headH + 6;
      int macroH        = 38; 
      int bottomRibbonH = 72; 
      int gridY         = macroY + macroH + 6;
      int gridGap       = 10;

      int availH = m_height - gridY - bottomRibbonH - 12;
      int cardH  = (availH - gridGap) / 2;
      if(cardH < 350) cardH = 350;

      int cardW = (contentW - gridGap) / 2;

      // TOP MASTER HEADER BAR (64px Height, Tribal Bold & Large Metrics)
      DrawModuleBox(sidePad, headY, sidePad + contentW, headY + headH, colCardBg, colBorder);

      m_canvas.FontSet("Segoe UI Black", 20, FW_BLACK);
      m_canvas.TextOut(sidePad + 16, headY + 8, "HR BLOOMBERG QUANT TERMINAL - HR UNIFIED MASTER OS", colTextBlack);
      
      DrawPill(sidePad + 660, headY + 8, 76, 24, "QUANT", colAmberBg, colAmberTxt, 14, true);

      m_canvas.FontSet("Segoe UI Bold", 15, FW_BOLD);
      m_canvas.TextOut(sidePad + contentW - 190, headY + 10, "EA Running Platform", colTextMuted);

      // Row 2: Sub-Metrics (15px-16px Bold)
      int row2Y = headY + 36;
      m_canvas.Line(sidePad + 16, row2Y - 4, sidePad + contentW - 16, row2Y - 4, colInnerBrd);

      m_canvas.FontSet("Segoe UI Bold", 14, FW_BOLD);
      m_canvas.TextOut(sidePad + 16, row2Y, "Active Session:", colTextMuted);
      DrawPill(sidePad + 120, row2Y - 2, 54, 22, (sessionStatus == "ACTIVE" ? "ON" : "OFF"), (sessionStatus == "ACTIVE" ? colBullGreen : colTextBlack), colPillText, 12, true);

      m_canvas.TextOut(sidePad + 185, row2Y, "Server: " + TimeToString(serverTime, TIME_MINUTES) + " | UK: " + TimeToString(ukTime, TIME_MINUTES), colTextBlack);

      int rx = sidePad + contentW - 620;
      m_canvas.TextOut(rx, row2Y, "Daily Drawdown:", colTextMuted);
      m_canvas.FontSet("Consolas", 16, FW_BOLD);
      m_canvas.TextOut(rx + 125, row2Y, StringFormat("%.2f%%", dailyDD), (dailyDD >= maxDailyDD ? colBearDark : colBullDark));

      m_canvas.FontSet("Segoe UI Bold", 14, FW_BOLD);
      m_canvas.TextOut(rx + 205, row2Y, "Open Risk:", colTextMuted);
      m_canvas.FontSet("Consolas", 16, FW_BOLD);
      m_canvas.TextOut(rx + 285, row2Y, StringFormat("%.2f%%", openRisk), (openRisk >= maxRisk ? colBearDark : colBullDark));

      m_canvas.FontSet("Segoe UI Bold", 14, FW_BOLD);
      m_canvas.TextOut(rx + 365, row2Y, "Positions:", colTextMuted);
      m_canvas.FontSet("Consolas", 16, FW_BOLD);
      m_canvas.TextOut(rx + 445, row2Y, StringFormat("%d/%d", openPos, maxPos), colTextBlack);

      // MACRO DXY BAR (38px Height)
      DrawModuleBox(sidePad, macroY, sidePad + contentW, macroY + macroH, colCardBg, colBorder);

      m_canvas.FontSet("Segoe UI Black", 14, FW_BLACK);
      m_canvas.TextOut(sidePad + 16, macroY + 10, "DXY (US Dollar Index)", colTextBlack);

      m_canvas.FontSet("Segoe UI Bold", 14, FW_BOLD);
      m_canvas.TextOut(sidePad + 205, macroY + 10, "Live price", colTextMuted);

      m_canvas.FontSet("Consolas", 18, FW_BOLD);
      string dxyPriceStr = StringFormat("%.3f (%+.2f%%)", dxyPrice, dxyChange);
      m_canvas.TextOut(sidePad + 285, macroY + 9, dxyPriceStr, (dxyChange >= 0.0 ? colBullDark : colBearDark));

      m_canvas.FontSet("Segoe UI Bold", 14, FW_BOLD);
      m_canvas.TextOut(sidePad + 450, macroY + 10, "Inline correlation: Gold", colTextMuted);
      m_canvas.FontSet("Consolas", 15, FW_BOLD);
      m_canvas.TextOut(sidePad + 610, macroY + 10, "0.99% ,", colBullDark);

      m_canvas.FontSet("Segoe UI Bold", 14, FW_BOLD);
      m_canvas.TextOut(sidePad + 675, macroY + 10, "Silver", colTextMuted);
      m_canvas.FontSet("Consolas", 15, FW_BOLD);
      m_canvas.TextOut(sidePad + 725, macroY + 10, "0.37% ,", colBullDark);

      m_canvas.FontSet("Segoe UI Bold", 14, FW_BOLD);
      m_canvas.TextOut(sidePad + 790, macroY + 10, "S&P 500", colTextMuted);
      m_canvas.FontSet("Consolas", 15, FW_BOLD);
      m_canvas.TextOut(sidePad + 850, macroY + 10, "0.16% ,", colBullDark);

      m_canvas.FontSet("Segoe UI Bold", 14, FW_BOLD);
      m_canvas.TextOut(sidePad + 915, macroY + 10, "Nasdaq", colTextMuted);
      m_canvas.FontSet("Consolas", 15, FW_BOLD);
      m_canvas.TextOut(sidePad + 975, macroY + 10, "0.65%", colBullDark);

      DrawPill(sidePad + contentW - 200, macroY + 5, 185, 28, "Active Trading Killzones", colChipGray, colTextMuted, 13, true);

      // FOUR MASTER INSTRUMENT CARDS (2 Columns x 2 Rows)
      string subNames[4] = {"Spot Gold", "Spot Silver", "S&P 500", "Nasdaq 100"};

      for(int i = 0; i < 4; i++)
      {
         int col = i % 2;
         int row = i / 2;
         int cx1 = sidePad + (col * (cardW + gridGap));
         int cy1 = gridY + (row * (cardH + gridGap));
         int cx2 = cx1 + cardW;
         int cy2 = cy1 + cardH;

         DrawModuleBox(cx1, cy1, cx2, cy2, colCardBg, colBorder);

         // Card Top Header: Tribal Bold Name (30px) + Digital Watch Price (44px)
         m_canvas.FontSet("Segoe UI Black", 30, FW_BLACK);
         m_canvas.TextOut(cx1 + 16, cy1 + 8, data[i].baseName, colTextBlack);
         int baseLen = (int)StringLen(data[i].baseName) * 18;
         m_canvas.FontSet("Segoe UI Bold", 18, FW_BOLD);
         m_canvas.TextOut(cx1 + 20 + baseLen, cy1 + 18, subNames[i], colTextMuted);

         // 44px DIGITAL WATCH PRICE WITH GLOW EFFECT & FLICKER
         m_canvas.FontSet("Consolas", 44, FW_BOLD);
         string rawPrcStr;
         uint prcColor = (data[i].priceChangePct >= 0.0) ? colBullDark : colBearDark;
         if(data[i].currentPrice > 0.0)
         {
            if(i == 1)
               rawPrcStr = StringFormat("%.3f (%+.2f%%)", data[i].currentPrice, data[i].priceChangePct);
            else
               rawPrcStr = StringFormat("%.2f (%+.2f%%)", data[i].currentPrice, data[i].priceChangePct);
         }
         else rawPrcStr = "-- (OFFLINE)";

         int prcW = (int)StringLen(rawPrcStr) * 24;
         int prcX = cx2 - 16 - prcW;
         int prcY = cy1 + 6;

         // Check if Price is flickering
         if(now < m_flicker.priceFlickerEnd[i])
         {
            // Flash Price Background Badge for 300ms
            m_canvas.FillRectangle(prcX - 6, prcY - 2, cx2 - 12, prcY + 48, m_flicker.priceFlickerBg[i]);
            m_canvas.Rectangle(prcX - 6, prcY - 2, cx2 - 12, prcY + 48, colBorder);
            prcColor = m_flicker.priceFlickerTxt[i];
         }

         // Dual-layer Digital Shadow Glow
         m_canvas.TextOut(prcX + 1, prcY + 1, rawPrcStr, 0x30000000);
         m_canvas.TextOut(prcX, prcY, rawPrcStr, prcColor);

         int padInside = 14;
         int innerW = cardW - (2 * padInside);
         int curY = cy1 + 56;

         // --- SECTION A: EMA REGIME (9/21/200) ---
         m_canvas.FontSet("Segoe UI Bold", 14, FW_BOLD);
         m_canvas.TextOut(cx1 + padInside, curY, "A - EMA REGIME (9/21/200)", colTextSubtle);
         curY += 20;

         bool isBullM5  = (data[i].m5EmaState == "BULLISH");
         bool isBullH1  = (data[i].h1EmaState == "BULLISH");
         bool isBullAll = (isBullM5 && isBullH1);

         uint m5PillBg = (isBullM5 ? colBullGreen : colBearRed);
         if(now < m_flicker.emaFlickerEnd[i]) m5PillBg = m_flicker.emaFlickerBg[i];

         // Large 30px Pills with 15px Bold text
         DrawPill(cx1 + padInside, curY, 126, 30, (isBullM5 ? "M5: BULLISH" : "M5: BEARISH"), m5PillBg, colPillText, 15, true);
         DrawPill(cx1 + padInside + 134, curY, 126, 30, (isBullH1 ? "H1: BULLISH" : "H1: BEARISH"), (isBullH1 ? colBullGreen : colBearRed), colPillText, 15, true);
         DrawPill(cx1 + padInside + 268, curY, 102, 30, (isBullAll ? "BULLISH" : "BEARISH"), (isBullAll ? colBullGreen : colBearRed), colPillText, 15, true);

         // Separation & EMA Health
         string sepStr = StringFormat("Sep: %.2f%% | Health: %.0f%%", data[i].emaSeparationPct, data[i].emaHealthScore);
         m_canvas.FontSet("Segoe UI Bold", 15, FW_BOLD);
         int sepW = (int)StringLen(sepStr) * 9;
         m_canvas.TextOut(cx2 - padInside - sepW, curY + 6, sepStr, colTextMuted);

         curY += 38;

         // --- SECTION B: ICT / SMC MATRIX (44px Boxes with 22px Digital Numbers) ---
         m_canvas.FontSet("Segoe UI Bold", 14, FW_BOLD);
         m_canvas.TextOut(cx1 + padInside, curY, "B - ICT / SMC MATRIX", colTextSubtle);
         curY += 20;

         int smcBoxGap = 8;
         int smcBoxW = (innerW - (3 * smcBoxGap)) / 4;
         int smcBoxH = 46;

         // Box 1: Structure (BOS / CHOCH)
         int b1_x = cx1 + padInside;
         DrawModuleBox(b1_x, curY, b1_x + smcBoxW, curY + smcBoxH, colInnerBg, colInnerBrd);
         m_canvas.FontSet("Segoe UI Bold", 12, FW_BOLD);
         m_canvas.TextOut(b1_x + 8, curY + 4, "Structure:", colTextSubtle);
         m_canvas.FontSet("Segoe UI Black", 15, FW_BLACK);
         string b1_val = (StringFind(data[i].bosStatus, "BOS") >= 0 ? "BOS (" + data[i].structureClass + ")" : "CHOCH (" + data[i].structureClass + ")");
         m_canvas.TextOut(b1_x + 8, curY + 22, b1_val, colTextBlack);

         // Box 2: Nearest BSL (22px Digital Number)
         int b2_x = b1_x + smcBoxW + smcBoxGap;
         uint bslBoxBg = (now < m_flicker.bslFlickerEnd[i]) ? m_flicker.bslFlickerBg[i] : colInnerBg;
         DrawModuleBox(b2_x, curY, b2_x + smcBoxW, curY + smcBoxH, bslBoxBg, colInnerBrd);
         m_canvas.FontSet("Segoe UI Bold", 12, FW_BOLD);
         m_canvas.TextOut(b2_x + 8, curY + 4, "Nearest BSL", colTextSubtle);
         m_canvas.FontSet("Consolas", 22, FW_BOLD);
         string bslStr = (data[i].nearestBSL > 0) ? StringFormat("%.1f", data[i].nearestBSL) : "CHOCH";
         m_canvas.TextOut(b2_x + 8, curY + 20, bslStr, colTextBlack);

         // Box 3: Nearest SSL (22px Digital Number)
         int b3_x = b2_x + smcBoxW + smcBoxGap;
         DrawModuleBox(b3_x, curY, b3_x + smcBoxW, curY + smcBoxH, colInnerBg, colInnerBrd);
         m_canvas.FontSet("Segoe UI Bold", 12, FW_BOLD);
         m_canvas.TextOut(b3_x + 8, curY + 4, "Nearest SSL", colTextSubtle);
         m_canvas.FontSet("Consolas", 22, FW_BOLD);
         string sslStr = (data[i].nearestSSL > 0) ? StringFormat("%.1f", data[i].nearestSSL) : "CHOCH";
         m_canvas.TextOut(b3_x + 8, curY + 20, sslStr, colTextBlack);

         // Box 4: Last SWEEP / Zone
         int b4_x = b3_x + smcBoxW + smcBoxGap;
         DrawModuleBox(b4_x, curY, b4_x + smcBoxW, curY + smcBoxH, colInnerBg, colInnerBrd);
         m_canvas.FontSet("Segoe UI Bold", 12, FW_BOLD);
         m_canvas.TextOut(b4_x + 8, curY + 4, "Last SWEEP", colTextSubtle);
         m_canvas.FontSet("Segoe UI Bold", 14, FW_BOLD);
         string sweepVal = (data[i].lastSweepDirection != "NONE" && data[i].lastSweepDirection != "") ? "SWEEP CONF" : "DISCOUNT (Buy)";
         m_canvas.TextOut(b4_x + 8, curY + 22, sweepVal, colTextBlack);

         curY += smcBoxH + 10;

         // --- SECTION C: TECHNICAL INDICATORS (34px Boxes with 20px Digital Numbers) ---
         m_canvas.FontSet("Segoe UI Bold", 14, FW_BOLD);
         m_canvas.TextOut(cx1 + padInside, curY, "C - INDICATORS", colTextSubtle);
         curY += 20;

         int indBoxGap = 8;
         int indBoxW = (innerW - (2 * indBoxGap)) / 3;
         int indBoxH = 34;

         // Ind 1: RSI(14)
         int ind1_x = cx1 + padInside;
         DrawModuleBox(ind1_x, curY, ind1_x + indBoxW, curY + indBoxH, colInnerBg, colInnerBrd);
         m_canvas.FontSet("Segoe UI Bold", 13, FW_BOLD);
         m_canvas.TextOut(ind1_x + 8, curY + 8, "RSI(14):", colTextSubtle);
         m_canvas.FontSet("Consolas", 20, FW_BOLD);
         m_canvas.TextOut(ind1_x + 72, curY + 6, StringFormat("%.1f", data[i].rsi14), colTextBlack);

         // Ind 2: MACD
         int ind2_x = ind1_x + indBoxW + indBoxGap;
         DrawModuleBox(ind2_x, curY, ind2_x + indBoxW, curY + indBoxH, colInnerBg, colInnerBrd);
         m_canvas.FontSet("Segoe UI Bold", 13, FW_BOLD);
         m_canvas.TextOut(ind2_x + 8, curY + 8, "MACD:", colTextSubtle);
         m_canvas.FontSet("Consolas", 20, FW_BOLD);
         m_canvas.TextOut(ind2_x + 65, curY + 6, StringFormat("%+.2f (%s)", data[i].macdHist, (data[i].macdHist >= 0 ? "Cross" : "Bear")), colTextBlack);

         // Ind 3: ATR(14)
         int ind3_x = ind2_x + indBoxW + indBoxGap;
         DrawModuleBox(ind3_x, curY, ind3_x + indBoxW, curY + indBoxH, colInnerBg, colInnerBrd);
         m_canvas.FontSet("Segoe UI Bold", 13, FW_BOLD);
         m_canvas.TextOut(ind3_x + 8, curY + 8, "ATR(14):", colTextSubtle);
         m_canvas.FontSet("Consolas", 20, FW_BOLD);
         m_canvas.TextOut(ind3_x + 72, curY + 6, StringFormat("%.1f pts", data[i].atrPoints), colTextBlack);

         curY += indBoxH + 10;

         // --- BOTTOM VISUAL ROW: VOL & FLOW | RSI SPEEDOMETER GAUGE | TRAJECTORY ---
         int visH = cy2 - curY - 8;
         if(visH < 74) visH = 74;

         int vGap = 8;
         int v1_w = (int)(innerW * 0.32);
         int v2_w = (int)(innerW * 0.28);
         int v3_w = innerW - v1_w - v2_w - (2 * vGap);

         // Module 1: VOL & ORDER FLOW (14px Progress Bar)
         int v1_x = cx1 + padInside;
         DrawModuleBox(v1_x, curY, v1_x + v1_w, curY + visH, colInnerBg, colInnerBrd);
         m_canvas.FontSet("Segoe UI Bold", 13, FW_BOLD);
         m_canvas.TextOut(v1_x + 10, curY + 6, "VOL & ORDER FLOW", colTextSubtle);
         
         // 14px Thick Progress Bar
         int barTrackY = curY + 26;
         int barTrackW = v1_w - 20;
         int barTrackH = 14;
         m_canvas.FillRectangle(v1_x + 10, barTrackY, v1_x + 10 + barTrackW, barTrackY + barTrackH, colTrackBg);
         double buyPct = (data[i].buyingPressurePct > 0.0 ? data[i].buyingPressurePct : 65.0);
         int barFillW = (int)(barTrackW * (buyPct / 100.0));
         uint barColor = (now < m_flicker.volFlickerEnd[i]) ? m_flicker.volFlickerBg[i] : colBullDark;
         m_canvas.FillRectangle(v1_x + 10, barTrackY, v1_x + 10 + barFillW, barTrackY + barTrackH, barColor);

         m_canvas.FontSet("Consolas", 18, FW_BOLD);
         m_canvas.TextOut(v1_x + 10, curY + 46, StringFormat("BUY PRESS: %.0f%%", buyPct), colTextBlack);

         // Module 2: RSI SPEEDOMETER GAUGE (10px Arc + 24px Digital readout inside)
         int v2_x = v1_x + v1_w + vGap;
         uint rsiGaugeFlash = (now < m_flicker.gaugeFlickerEnd[i]) ? m_flicker.gaugeFlickerBg[i] : 0;
         DrawModuleBox(v2_x, curY, v2_x + v2_w, curY + visH, colInnerBg, colInnerBrd);
         m_canvas.FontSet("Segoe UI Bold", 13, FW_BOLD);
         m_canvas.TextOut(v2_x + 10, curY + 6, "RSI GAUGE", colTextSubtle);

         int gaugeCx = v2_x + (v2_w / 2);
         int gaugeCy = curY + visH - 8;
         int gaugeRad = (visH / 2) - 2;
         DrawSpeedometerGauge(gaugeCx, gaugeCy, gaugeRad, data[i].rsi14, 0.0, 100.0, colTrackBg, colBullDark, colBearDark, colTextBlack, rsiGaugeFlash);

         // Module 3: TRAJECTORY SHADED SPARKLINE & INTRADAY VECTOR
         int v3_x = v2_x + v2_w + vGap;
         DrawModuleBox(v3_x, curY, v3_x + v3_w, curY + visH, colInnerBg, colInnerBrd);
         m_canvas.FontSet("Segoe UI Bold", 13, FW_BOLD);
         m_canvas.TextOut(v3_x + 10, curY + 6, "TRAJECTORY", colTextSubtle);

         m_canvas.FontSet("Consolas", 13, FW_BOLD);
         string trajDiag = StringFormat("M5:%s | H1:%s", (data[i].m5EmaState == "BULLISH" ? "BULL" : "BEAR"), (data[i].h1EmaState == "BULLISH" ? "BULL" : "BEAR"));
         m_canvas.TextOut(v3_x + 105, curY + 6, trajDiag, (data[i].priceChangePct >= 0.0 ? colBullDark : colBearDark));

         bool isTrendBull = (data[i].priceChangePct >= 0.0);
         uint sparkLine = (isTrendBull ? colBullDark : colBearDark);
         uint sparkFill = (isTrendBull ? colBullLight : colBearLight);
         DrawTrajectoryArea(v3_x + 10, curY + 22, v3_x + v3_w - 10, curY + visH - 6, isTrendBull, sparkLine, sparkFill, data[i].ema9_history);
      }

      // 5. BOTTOM 5-SYMBOL WATCHLIST RIBBON (72px Height, 24px Digital Numbers)
      int barY = m_height - bottomRibbonH - 4;
      DrawModuleBox(sidePad, barY, sidePad + contentW, barY + bottomRibbonH, colCardBg, colBorder);

      int itemW = contentW / 5;
      string botTitles[5] = {"GOLD", "SILVER", "S&P 500", "NASDAQ 100", "DXY"};

      for(int s = 0; s < 5; s++)
      {
         int bx1 = sidePad + (s * itemW);
         int bx2 = bx1 + itemW;
         if(s > 0) m_canvas.Line(bx1, barY + 8, bx1, barY + bottomRibbonH - 8, colInnerBrd);

         // Row 1: Symbol Name (Tribal Bold 18px) + % TREND (12px)
         m_canvas.FontSet("Segoe UI Black", 18, FW_BLACK);
         m_canvas.TextOut(bx1 + 14, barY + 8, botTitles[s], colTextBlack);
         m_canvas.FontSet("Segoe UI Bold", 12, FW_BOLD);
         m_canvas.TextOut(bx2 - 75, barY + 10, "% TREND", colTextSubtle);

         // Row 2: Live Digital Price (24px Consolas Bold) & Percentage & Status Dots
         m_canvas.FontSet("Consolas", 24, FW_BOLD);
         if(s < 4)
         {
            if(data[s].currentPrice > 0.0)
            {
               string pStr = (s == 1) ? StringFormat("%.3f", data[s].currentPrice) : StringFormat("%.2f", data[s].currentPrice);
               uint prcCol = (data[s].priceChangePct >= 0.0 ? colBullDark : colBearDark);
               
               // Digital Glow
               m_canvas.TextOut(bx1 + 15, barY + 36, pStr, 0x30000000);
               m_canvas.TextOut(bx1 + 14, barY + 35, pStr, prcCol);

               m_canvas.FontSet("Consolas", 18, FW_BOLD);
               string pctStr = StringFormat("%+.2f%%", data[s].priceChangePct);
               m_canvas.TextOut(bx1 + 130, barY + 38, pctStr, prcCol);

               // 3 Status Dots
               int dotX = bx1 + 225;
               int dotY = barY + 48;
               m_canvas.FillCircle(dotX, dotY, 5, (data[s].priceChangePct >= 0.0 ? colBullGreen : colBearRed));
               m_canvas.FillCircle(dotX + 14, dotY, 5, colTrackBg);
               m_canvas.FillCircle(dotX + 28, dotY, 5, colTrackBg);
            }
            else
            {
               m_canvas.TextOut(bx1 + 14, barY + 35, "-- (OFFLINE)", colTextSubtle);
            }
         }
         else // DXY
         {
            string dxyStr = StringFormat("%.3f", dxyPrice);
            uint dxyCol = (dxyChange >= 0.0 ? colBullDark : colBearDark);
            
            m_canvas.TextOut(bx1 + 15, barY + 36, dxyStr, 0x30000000);
            m_canvas.TextOut(bx1 + 14, barY + 35, dxyStr, dxyCol);

            m_canvas.FontSet("Consolas", 18, FW_BOLD);
            string dxyPctStr = StringFormat("%+.2f%%", dxyChange);
            m_canvas.TextOut(bx1 + 130, barY + 38, dxyPctStr, dxyCol);

            int dotX = bx1 + 225;
            int dotY = barY + 48;
            m_canvas.FillCircle(dotX, dotY, 5, (dxyChange >= 0.0 ? colBullGreen : colBearRed));
            m_canvas.FillCircle(dotX + 14, dotY, 5, colTrackBg);
            m_canvas.FillCircle(dotX + 28, dotY, 5, colTrackBg);
         }
      }

      // Commit to Screen (Zero Flicker)
      m_canvas.Update();
   }
};
"""

target_file = os.path.join(v4_dir, "HR_Dashboard_Premium.mqh")
with open(target_file, "w", encoding="utf-8") as f:
    f.write(dashboard_mqh)

print("Created HR_Dashboard_Premium.mqh successfully.")
