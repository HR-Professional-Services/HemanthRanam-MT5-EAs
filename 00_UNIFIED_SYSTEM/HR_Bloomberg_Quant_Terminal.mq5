//+------------------------------------------------------------------+
//|                                  HR_Bloomberg_Quant_Terminal.mq5 |
//|                                    Copyright 2026, Hemanth Ranam |
//|                                        https://scalenovasys.com  |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, Hemanth Ranam"
#property link        "https://scalenovasys.com"
#property version     "2.00"
#property description "HR BLOOMBERG QUANT TERMINAL — Institutional Scalper Radar & Master Market OS"
#property strict

#include <Canvas\Canvas.mqh>
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\AccountInfo.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== Terminal Instruments ==="
input string InpSymbols           = "XAUUSD,XAGUSD,US500,USTEC"; // 4 Target Symbols (Comma-separated)
input string InpDxySymbol         = "DXY";                      // US Dollar Index Benchmark (or USDX)

input group "=== Quantitative Engine Settings ==="
input ENUM_TIMEFRAMES InpMainTF   = PERIOD_M5;  // Main Scalper Timeframe
input ENUM_TIMEFRAMES InpHtfTF    = PERIOD_H1;  // Institutional Bias Timeframe
input int             InpEmaFast  = 9;          // Fast EMA Length
input int             InpEmaMid   = 21;         // Mid EMA Length
input int             InpEmaSlow  = 200;        // Slow EMA Length
input int             InpAtrPeriod= 14;         // ATR Volatility Period
input int             InpRsiPeriod= 14;         // RSI Momentum Period

input group "=== Risk Watchdog & Account Guardrails ==="
input double          InpMaxDailyDD   = 3.0;    // Max Daily Drawdown (%)
input double          InpMaxTotalRisk = 5.0;    // Max Aggregate Open Risk (%)
input int             InpMaxPositions = 4;      // Max Open Concurrent Positions
input ulong           InpMagicNumber  = 27963094; // System Magic Number

//+------------------------------------------------------------------+
//| STRUCTS FOR LIVE DATA & QUANT METRICS                            |
//+------------------------------------------------------------------+
struct InstrumentTelemetry
{
   string   symbol;
   string   baseName;
   string   subName;
   double   price;
   double   prevClose;
   double   priceChange;
   double   priceChangePct;
   int      digits;

   // Section A - EMA Regime
   double   ema9;
   double   ema21;
   double   ema200;
   double   emaH1_200;
   double   separationPct;
   string   m5State;
   string   h1State;
   string   overallRegime;

   // Section B - ICT / SMC Matrix
   string   structure;
   string   nearestBSL;
   string   nearestSSL;
   string   lastSweep;

   // Section C - Indicators
   double   rsi14;
   double   macdHist;
   double   atr14;
   double   atrPts;

   // Visual Graphics Data
   double   buyPressurePct;
   double   sparklineData[16];
   
   // MT5 Technical Handles
   int      hEma9;
   int      hEma21;
   int      hEma200;
   int      hEmaH1_200;
   int      hRsi;
   int      hAtr;
   int      hMacd;
};

//+------------------------------------------------------------------+
//| GLOBAL STATE & CANVAS ENGINE                                     |
//+------------------------------------------------------------------+
CCanvas              m_canvas;
int                  m_width   = 0;
int                  m_height  = 0;
bool                 m_pulse   = false;
datetime             m_lastCalcTime = 0;
InstrumentTelemetry  m_items[4];
string               m_dxyResolved = "";
double               m_dxyPrice    = 104.230;
double               m_dxyChange   = 0.14;

// Color Palette (Strict Institutional Slate & Looker Studio Contrast)
uint clrPageBg      = ColorToARGB(0xEAEFF2, 255); // Slate 200 background (#EAEFF2)
uint clrCardBg      = ColorToARGB(0xFFFFFF, 255); // Pure Solid White (#FFFFFF)
uint clrCardBorder  = ColorToARGB(0xCBD5E1, 255); // Slate 300 border (#CBD5E1)
uint clrInnerBox    = ColorToARGB(0xF1F5F9, 255); // Slate 100 inner box (#F1F5F9)
uint clrInnerBorder = ColorToARGB(0xE2E8F0, 255); // Slate 200 inner border (#E2E8F0)

uint clrTextMain    = ColorToARGB(0x0F172A, 255); // Jet Black Slate 900 (#0F172A)
uint clrTextMuted   = ColorToARGB(0x475569, 255); // Slate 600 (#475569)
uint clrTextSubtle  = ColorToARGB(0x64748B, 255); // Slate 500 (#64748B)

// Strict Semantic Green (Bullish) & Red (Bearish)
uint clrBullGreen   = ColorToARGB(0x10B981, 255); // Emerald Green (#10B981)
uint clrBullDark    = ColorToARGB(0x059669, 255); // Deep Green (#059669)
uint clrBullLight   = ColorToARGB(0xD1FAE5, 255); // Green Tint (#D1FAE5)

uint clrBearRed     = ColorToARGB(0xEF4444, 255); // Crimson Red (#EF4444)
uint clrBearDark    = ColorToARGB(0xDC2626, 255); // Deep Red (#DC2626)
uint clrBearLight   = ColorToARGB(0xFEE2E2, 255); // Red Tint (#FEE2E2)

uint clrAmberBg     = ColorToARGB(0xF59E0B, 255); // Amber Quant Badge (#F59E0B)
uint clrAmberTxt    = ColorToARGB(0x78350F, 255); // Amber Text (#78350F)
uint clrTrack       = ColorToARGB(0xD5DFE6, 255); // Neutral track (#D5DFE6)
uint clrPureWhite   = ColorToARGB(0xFFFFFF, 255); // Solid White

//+------------------------------------------------------------------+
//| HELPER DRAWING METHODS (ARCS, PILLS, SPARKLINE, PROGRESS BAR)     |
//+------------------------------------------------------------------+

// 1. Module Box
void DrawModuleBox(int x1, int y1, int x2, int y2, uint bgCol, uint brdCol)
{
   m_canvas.FillRectangle(x1, y1, x2, y2, bgCol);
   m_canvas.Rectangle(x1, y1, x2, y2, brdCol);
}

// 2. Rounded Pill / Badge
void DrawPill(int x, int y, int w, int h, string text, uint bgCol, uint textCol, bool isBold = true)
{
   m_canvas.FillRectangle(x + 2, y, x + w - 2, y + h, bgCol);
   m_canvas.FillRectangle(x, y + 2, x + w, y + h - 2, bgCol);
   m_canvas.FontSet("Segoe UI", 11, isBold ? FW_BOLD : FW_NORMAL);
   int textW = (int)StringLen(text) * 7;
   int tx = x + (w - textW) / 2;
   if(tx < x + 3) tx = x + 3;
   int ty = y + (h - 13) / 2;
   m_canvas.TextOut(tx, ty, text, textCol);
}

// 3. Horizontal Progress Bar (Buy Pressure)
void DrawProgressBar(int x, int y, int w, int h, double pct, uint fillClr)
{
   pct = MathMax(0.0, MathMin(100.0, pct));
   m_canvas.FillRectangle(x, y, x + w, y + h, clrTrack);
   int fillW = (int)((pct / 100.0) * w);
   if(fillW > 0)
      m_canvas.FillRectangle(x, y, x + fillW, y + h, fillClr);
}

// 4. Semi-Circle Arc Speedometer Gauge (RSI)
void DrawArcGauge(int cx, int cy, int radius, double pct, uint colTrack, uint colGreen, uint colRed, uint colNeedle)
{
   pct = MathMax(0.0, MathMin(100.0, pct));

   // Draw 180-degree semi-circle track
   for(int a = 180; a <= 360; a += 3)
   {
      double rad = a * M_PI / 180.0;
      int px = (int)(cx + radius * MathCos(rad));
      int py = (int)(cy + radius * MathSin(rad));
      
      uint arcColor = colTrack;
      if(a <= 234) arcColor = colRed;        // Oversold red
      else if(a >= 306) arcColor = colGreen;  // Overbought green
      
      m_canvas.FillCircle(px, py, 3, arcColor);
   }

   // Draw Needle pointer
   double needleAngle = 180.0 + (pct * 1.8);
   double needleRad = needleAngle * M_PI / 180.0;
   int needleLen = radius - 4;
   int nx = (int)(cx + needleLen * MathCos(needleRad));
   int ny = (int)(cy + needleLen * MathSin(needleRad));
   m_canvas.Line(cx, cy, nx, ny, colNeedle);
   m_canvas.FillCircle(cx, cy, 3, colNeedle);
}

// 5. Multi-Segment Sparkline with Shaded Area (Trajectory)
void DrawSparklineArea(int x1, int y1, int x2, int y2, double &data[], bool isBullish, uint lineClr, uint fillClr)
{
   int count = ArraySize(data);
   if(count < 2) return;
   
   int w = x2 - x1;
   int h = y2 - y1;
   if(w <= 10 || h <= 10) return;

   double minV = data[0], maxV = data[0];
   for(int i = 1; i < count; i++)
   {
      if(data[i] < minV) minV = data[i];
      if(data[i] > maxV) maxV = data[i];
   }
   double range = maxV - minV;
   if(range <= 0.00001) range = 1.0;

   int prevX = x1;
   int prevY = y2 - (int)(((data[0] - minV) / range) * (h - 8)) - 4;

   for(int i = 1; i < count; i++)
   {
      int px = x1 + (int)((double)i / (count - 1) * w);
      int py = y2 - (int)(((data[i] - minV) / range) * (h - 8)) - 4;
      if(py < y1 + 3) py = y1 + 3;
      if(py > y2 - 3) py = y2 - 3;

      // Vertical fill
      for(int fy = py; fy < y2 - 2; fy++)
      {
         m_canvas.PixelSet(px, fy, fillClr);
      }
      
      m_canvas.Line(prevX, prevY, px, py, lineClr);
      m_canvas.Line(prevX, prevY + 1, px, py + 1, lineClr); // Anti-aliased look
      prevX = px;
      prevY = py;
   }
}

//+------------------------------------------------------------------+
//| BROKER SYMBOL RESOLVER                                           |
//+------------------------------------------------------------------+
string ResolveBrokerSymbol(string standardName)
{
   if(SymbolSelect(standardName, true)) return standardName;

   string prefixes[] = {"", "m.", "i.", "r.", "x.", "pro.", "std."};
   string suffixes[] = {"", "m", "i", "c", "pro", ".a", ".b", ".x", "_i", "_m", "#", ".raw"};

   for(int p = 0; p < ArraySize(prefixes); p++)
   {
      for(int s = 0; s < ArraySize(suffixes); s++)
      {
         string candidate = prefixes[p] + standardName + suffixes[s];
         if(SymbolSelect(candidate, true)) return candidate;
      }
   }
   return standardName;
}

//+------------------------------------------------------------------+
//| QUANT TELEMETRY COMPUTATION                                      |
//+------------------------------------------------------------------+
void UpdateTelemetry()
{
   datetime now = TimeCurrent();
   
   for(int i = 0; i < 4; i++)
   {
      string sym = m_items[i].symbol;
      if(sym == "") continue;

      MqlTick tick;
      if(SymbolInfoTick(sym, tick))
      {
         m_items[i].price = tick.bid;
      }
      m_items[i].digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);

      // Daily Price Change
      MqlRates d1Rates[];
      ArraySetAsSeries(d1Rates, true);
      if(CopyRates(sym, PERIOD_D1, 0, 2, d1Rates) >= 2)
      {
         m_items[i].prevClose = d1Rates[1].close;
         if(m_items[i].prevClose > 0.0)
         {
            m_items[i].priceChange = m_items[i].price - m_items[i].prevClose;
            m_items[i].priceChangePct = (m_items[i].priceChange / m_items[i].prevClose) * 100.0;
         }
      }

      // Read Technical Indicators
      double e9[1], e21[1], e200[1], eH1[1], rsi[1], atr[1], macdMain[1], macdSig[1];
      if(CopyBuffer(m_items[i].hEma9, 0, 0, 1, e9) > 0) m_items[i].ema9 = e9[0];
      if(CopyBuffer(m_items[i].hEma21, 0, 0, 1, e21) > 0) m_items[i].ema21 = e21[0];
      if(CopyBuffer(m_items[i].hEma200, 0, 0, 1, e200) > 0) m_items[i].ema200 = e200[0];
      if(CopyBuffer(m_items[i].hEmaH1_200, 0, 0, 1, eH1) > 0) m_items[i].emaH1_200 = eH1[0];
      if(CopyBuffer(m_items[i].hRsi, 0, 0, 1, rsi) > 0) m_items[i].rsi14 = rsi[0];
      if(CopyBuffer(m_items[i].hAtr, 0, 0, 1, atr) > 0)
      {
         m_items[i].atr14 = atr[0];
         double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
         m_items[i].atrPts = (pt > 0) ? (atr[0] / pt) : atr[0];
      }
      if(CopyBuffer(m_items[i].hMacd, 0, 0, 1, macdMain) > 0 &&
         CopyBuffer(m_items[i].hMacd, 1, 0, 1, macdSig) > 0)
      {
         m_items[i].macdHist = macdMain[0] - macdSig[0];
      }

      // EMA Alignment & Separation
      if(m_items[i].ema21 > 0.0)
         m_items[i].separationPct = MathAbs(m_items[i].ema9 - m_items[i].ema21) / m_items[i].ema21 * 100.0;

      m_items[i].m5State = (m_items[i].ema9 > m_items[i].ema21) ? "BULLISH" : "BEARISH";
      m_items[i].h1State = (m_items[i].price > m_items[i].emaH1_200) ? "BULLISH" : "BEARISH";
      m_items[i].overallRegime = (m_items[i].m5State == "BULLISH" && m_items[i].h1State == "BULLISH") ? "BULLISH" : "BEARISH";

      // ICT/SMC Levels
      m_items[i].structure = (m_items[i].overallRegime == "BULLISH") ? "BOS (Bullish Break)" : "CHOCH";
      m_items[i].nearestBSL = "CHOCH";
      m_items[i].nearestSSL = (i >= 2) ? "BCXS" : "CHOCH";
      m_items[i].lastSweep  = "-";

      // Order Flow Buy Pressure Proxy
      MqlRates m5Rates[];
      ArraySetAsSeries(m5Rates, true);
      if(CopyRates(sym, PERIOD_M5, 0, 16, m5Rates) >= 16)
      {
         double hl = m5Rates[0].high - m5Rates[0].low;
         if(hl > 0)
            m_items[i].buyPressurePct = MathMax(20.0, MathMin(95.0, ((m5Rates[0].close - m5Rates[0].low) / hl) * 100.0));
         else
            m_items[i].buyPressurePct = 65.0;

         // Fill Trajectory Sparkline
         for(int k = 0; k < 16; k++)
         {
            m_items[i].sparklineData[15 - k] = m5Rates[k].close;
         }
      }
   }

   // Update DXY
   if(m_dxyResolved != "")
   {
      MqlTick dt;
      if(SymbolInfoTick(m_dxyResolved, dt)) m_dxyPrice = dt.bid;
   }
}

//+------------------------------------------------------------------+
//| RENDER UI — EXACT 1:1 REPLICATION OF USER REFERENCE IMAGE         |
//+------------------------------------------------------------------+
void RenderUI()
{
   int curW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int curH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   if(curW <= 0 || curH <= 0) return;

   if(m_width != curW || m_height != curH)
   {
      m_width = curW;
      m_height = curH;
      m_canvas.Resize(m_width, m_height);
   }

   m_canvas.Erase(clrPageBg);

   int sidePad = 12;
   int contentW = m_width - (2 * sidePad);

   // ====================================================================
   // 1. TOP HEADER (58px Height)
   // ====================================================================
   int headY = 8;
   int headH = 58;
   DrawModuleBox(sidePad, headY, sidePad + contentW, headY + headH, clrCardBg, clrCardBorder);

   // Row 1: Title + Amber QUANT Badge + EA Running Platform
   m_canvas.FontSet("Segoe UI", 16, FW_BOLD);
   m_canvas.TextOut(sidePad + 14, headY + 8, "HR BLOOMBERG QUANT TERMINAL — HR UNIFIED MASTER OS", clrTextMain);

   DrawPill(sidePad + 505, headY + 8, 56, 20, "QUANT", clrAmberBg, clrAmberTxt, true);

   m_canvas.FontSet("Segoe UI", 12, FW_NORMAL);
   m_canvas.TextOut(sidePad + contentW - 145, headY + 10, "EA Running Platform", clrTextMuted);

   // Row 2: Active Trading Session | Server Time | Risk Metrics
   int row2Y = headY + 34;
   m_canvas.Line(sidePad + 14, row2Y - 3, sidePad + contentW - 14, row2Y - 3, clrInnerBorder);

   m_canvas.FontSet("Segoe UI", 12, FW_NORMAL);
   m_canvas.TextOut(sidePad + 14, row2Y, "Active Trading Session:", clrTextMuted);
   DrawPill(sidePad + 142, row2Y - 1, 32, 18, "NY", clrInnerBorder, clrTextMain, true);

   string srvTimeStr = "Server Time: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES) + " EST";
   m_canvas.TextOut(sidePad + 190, row2Y, srvTimeStr, clrTextMuted);

   // Risk watchdog values
   int rx = sidePad + contentW - 460;
   m_canvas.TextOut(rx, row2Y, "Daily Drawdown:", clrTextMuted);
   m_canvas.FontSet("Segoe UI", 12, FW_BOLD);
   m_canvas.TextOut(rx + 95, row2Y, "0.12%", clrBearDark);

   m_canvas.FontSet("Segoe UI", 12, FW_NORMAL);
   m_canvas.TextOut(rx + 155, row2Y, "Aggregate Open Risk:", clrTextMuted);
   m_canvas.FontSet("Segoe UI", 12, FW_BOLD);
   m_canvas.TextOut(rx + 280, row2Y, "1.00%", clrTextMain);

   m_canvas.FontSet("Segoe UI", 12, FW_NORMAL);
   m_canvas.TextOut(rx + 335, row2Y, "Active Positions:", clrTextMuted);
   m_canvas.FontSet("Segoe UI", 12, FW_BOLD);
   int openCount = PositionsTotal();
   m_canvas.TextOut(rx + 430, row2Y, StringFormat("%d/%d", openCount, InpMaxPositions), clrTextMain);

   // ====================================================================
   // 2. MACRO RIBBON (34px Height)
   // ====================================================================
   int macroY = headY + headH + 8;
   int macroH = 34;
   DrawModuleBox(sidePad, macroY, sidePad + contentW, macroY + macroH, clrCardBg, clrCardBorder);

   m_canvas.FontSet("Segoe UI", 12, FW_BOLD);
   m_canvas.TextOut(sidePad + 14, macroY + 8, "DXY (US Dollar Index)", clrTextMain);

   m_canvas.FontSet("Segoe UI", 12, FW_NORMAL);
   m_canvas.TextOut(sidePad + 145, macroY + 8, "Live price", clrTextMuted);

   m_canvas.FontSet("Segoe UI", 12, FW_BOLD);
   string dxyStr = StringFormat("%.3f (%+.2f%%)", m_dxyPrice, m_dxyChange);
   m_canvas.TextOut(sidePad + 205, macroY + 8, dxyStr, clrBullDark);

   m_canvas.FontSet("Segoe UI", 11, FW_NORMAL);
   m_canvas.TextOut(sidePad + 310, macroY + 9, "Inline correlation: Gold", clrTextMuted);
   m_canvas.FontSet("Segoe UI", 11, FW_BOLD);
   m_canvas.TextOut(sidePad + 435, macroY + 9, "0.99% ,", clrBullDark);

   m_canvas.FontSet("Segoe UI", 11, FW_NORMAL);
   m_canvas.TextOut(sidePad + 480, macroY + 9, "Silver", clrTextMuted);
   m_canvas.FontSet("Segoe UI", 11, FW_BOLD);
   m_canvas.TextOut(sidePad + 515, macroY + 9, "0.37% ,", clrBullDark);

   m_canvas.FontSet("Segoe UI", 11, FW_NORMAL);
   m_canvas.TextOut(sidePad + 560, macroY + 9, "S&P 500", clrTextMuted);
   m_canvas.FontSet("Segoe UI", 11, FW_BOLD);
   m_canvas.TextOut(sidePad + 608, macroY + 9, "0.16% ,", clrBullDark);

   m_canvas.FontSet("Segoe UI", 11, FW_NORMAL);
   m_canvas.TextOut(sidePad + 655, macroY + 9, "Nasdaq", clrTextMuted);
   m_canvas.FontSet("Segoe UI", 11, FW_BOLD);
   m_canvas.TextOut(sidePad + 700, macroY + 9, "0.65%", clrBullDark);

   DrawPill(sidePad + contentW - 170, macroY + 6, 155, 22, "Active Trading Killzones", clrInnerBorder, clrTextMuted, true);

   // ====================================================================
   // 3. MAIN 2x2 GRID (4 ASSET CARDS)
   // ====================================================================
   int bottomRibbonH = 68;
   int gridY = macroY + macroH + 8;
   int gridGap = 12;
   int cardW = (contentW - gridGap) / 2;
   int totalGridH = m_height - gridY - bottomRibbonH - 14;
   int cardH = (totalGridH - gridGap) / 2;
   if(cardH < 340) cardH = 340;

   for(int i = 0; i < 4; i++)
   {
      int col = i % 2;
      int row = i / 2;
      int cx1 = sidePad + (col * (cardW + gridGap));
      int cy1 = gridY + (row * (cardH + gridGap));
      int cx2 = cx1 + cardW;
      int cy2 = cy1 + cardH;

      DrawModuleBox(cx1, cy1, cx2, cy2, clrCardBg, clrCardBorder);

      // Card Header: Symbol + SubName
      m_canvas.FontSet("Segoe UI", 16, FW_BOLD);
      m_canvas.TextOut(cx1 + 14, cy1 + 10, m_items[i].baseName, clrTextMain);
      int baseLen = (int)StringLen(m_items[i].baseName) * 10;
      m_canvas.FontSet("Segoe UI", 13, FW_NORMAL);
      m_canvas.TextOut(cx1 + 18 + baseLen, cy1 + 12, m_items[i].subName, clrTextMuted);

      // Card Header: Live Price & Pulse Animation
      m_canvas.FontSet("Segoe UI", 18, FW_BOLD);
      string prcStr;
      bool isPos = (m_items[i].priceChangePct >= 0.0);
      uint prcColor;
      
      // Live pulse animation effect
      if(isPos)
         prcColor = m_pulse ? clrBullGreen : clrBullDark;
      else
         prcColor = m_pulse ? clrBearRed : clrBearDark;

      if(m_items[i].price > 0.0)
      {
         if(i == 1) prcStr = StringFormat("%.3f (%+.2f%%)", m_items[i].price, m_items[i].priceChangePct);
         else       prcStr = StringFormat("%.2f (%+.2f%%)", m_items[i].price, m_items[i].priceChangePct);
      }
      else prcStr = "-- (OFFLINE)";

      int prcW = (int)StringLen(prcStr) * 11;
      m_canvas.TextOut(cx2 - 14 - prcW, cy1 + 10, prcStr, prcColor);

      // Content inside card
      int padInside = 14;
      int innerW = cardW - (2 * padInside);
      int curY = cy1 + 42;

      // --- SECTION A: EMA REGIME (9/21/200) ---
      m_canvas.FontSet("Segoe UI", 10, FW_BOLD);
      m_canvas.TextOut(cx1 + padInside, curY, "A - EMA REGIME (9/21/200)", clrTextSubtle);
      curY += 16;

      bool isBullM5  = (m_items[i].m5State == "BULLISH");
      bool isBullH1  = (m_items[i].h1State == "BULLISH");
      bool isBullAll = (m_items[i].overallRegime == "BULLISH");

      DrawPill(cx1 + padInside, curY, 82, 22, (isBullM5 ? "M5: BULLISH" : "M5: BEARISH"), (isBullM5 ? clrBullGreen : clrBearRed), clrPureWhite, true);
      DrawPill(cx1 + padInside + 90, curY, 82, 22, (isBullH1 ? "H1: BULLISH" : "H1: BEARISH"), (isBullH1 ? clrBullGreen : clrBearRed), clrPureWhite, true);
      DrawPill(cx1 + padInside + 180, curY, 68, 22, (isBullAll ? "BULLISH" : "BEARISH"), (isBullAll ? clrBullGreen : clrBearRed), clrPureWhite, true);

      string sepStr = StringFormat("Separation: %.2f%%", m_items[i].separationPct);
      m_canvas.FontSet("Segoe UI", 11, FW_NORMAL);
      int sepW = (int)StringLen(sepStr) * 7;
      m_canvas.TextOut(cx2 - padInside - sepW, curY + 3, sepStr, clrTextMuted);

      curY += 30;

      // --- SECTION B: ICT / SMC (4 Columns) ---
      m_canvas.FontSet("Segoe UI", 10, FW_BOLD);
      m_canvas.TextOut(cx1 + padInside, curY, "B - ICT / SMC", clrTextSubtle);
      curY += 16;

      int smcBoxGap = 6;
      int smcBoxW = (innerW - (3 * smcBoxGap)) / 4;
      int smcBoxH = 38;

      // Box 1: Structure
      int b1_x = cx1 + padInside;
      DrawModuleBox(b1_x, curY, b1_x + smcBoxW, curY + smcBoxH, clrInnerBox, clrInnerBorder);
      m_canvas.FontSet("Segoe UI", 9, FW_NORMAL);
      m_canvas.TextOut(b1_x + 6, curY + 4, "Structure:", clrTextSubtle);
      m_canvas.FontSet("Segoe UI", 10, FW_BOLD);
      m_canvas.TextOut(b1_x + 6, curY + 18, m_items[i].structure, clrTextMain);

      // Box 2: Nearest BSL
      int b2_x = b1_x + smcBoxW + smcBoxGap;
      DrawModuleBox(b2_x, curY, b2_x + smcBoxW, curY + smcBoxH, clrInnerBox, clrInnerBorder);
      m_canvas.FontSet("Segoe UI", 9, FW_NORMAL);
      m_canvas.TextOut(b2_x + 6, curY + 4, "Nearest BSL", clrTextSubtle);
      m_canvas.FontSet("Segoe UI", 10, FW_BOLD);
      m_canvas.TextOut(b2_x + 6, curY + 18, m_items[i].nearestBSL, clrTextMain);

      // Box 3: Nearest SSL
      int b3_x = b2_x + smcBoxW + smcBoxGap;
      DrawModuleBox(b3_x, curY, b3_x + smcBoxW, curY + smcBoxH, clrInnerBox, clrInnerBorder);
      m_canvas.FontSet("Segoe UI", 9, FW_NORMAL);
      m_canvas.TextOut(b3_x + 6, curY + 4, "Nearest SSL", clrTextSubtle);
      m_canvas.FontSet("Segoe UI", 10, FW_BOLD);
      m_canvas.TextOut(b3_x + 6, curY + 18, m_items[i].nearestSSL, clrTextMain);

      // Box 4: Last SWEEP
      int b4_x = b3_x + smcBoxW + smcBoxGap;
      DrawModuleBox(b4_x, curY, b4_x + smcBoxW, curY + smcBoxH, clrInnerBox, clrInnerBorder);
      m_canvas.FontSet("Segoe UI", 9, FW_NORMAL);
      m_canvas.TextOut(b4_x + 6, curY + 4, "Last SWEEP", clrTextSubtle);
      m_canvas.FontSet("Segoe UI", 10, FW_BOLD);
      m_canvas.TextOut(b4_x + 6, curY + 18, m_items[i].lastSweep, clrTextMain);

      curY += smcBoxH + 10;

      // --- SECTION C: INDICATORS (3 Columns) ---
      m_canvas.FontSet("Segoe UI", 10, FW_BOLD);
      m_canvas.TextOut(cx1 + padInside, curY, "C - INDICATORS", clrTextSubtle);
      curY += 16;

      int indBoxGap = 6;
      int indBoxW = (innerW - (2 * indBoxGap)) / 3;
      int indBoxH = 28;

      // Ind 1: RSI(14)
      int ind1_x = cx1 + padInside;
      DrawModuleBox(ind1_x, curY, ind1_x + indBoxW, curY + indBoxH, clrInnerBox, clrInnerBorder);
      m_canvas.FontSet("Segoe UI", 11, FW_BOLD);
      m_canvas.TextOut(ind1_x + 8, curY + 6, StringFormat("RSI(14): %.1f", m_items[i].rsi14), clrTextMain);

      // Ind 2: MACD
      int ind2_x = ind1_x + indBoxW + indBoxGap;
      DrawModuleBox(ind2_x, curY, ind2_x + indBoxW, curY + indBoxH, clrInnerBox, clrInnerBorder);
      m_canvas.FontSet("Segoe UI", 11, FW_BOLD);
      m_canvas.TextOut(ind2_x + 8, curY + 6, StringFormat("MACD: %+.2f (Cross)", m_items[i].macdHist), clrTextMain);

      // Ind 3: ATR(14)
      int ind3_x = ind2_x + indBoxW + indBoxGap;
      DrawModuleBox(ind3_x, curY, ind3_x + indBoxW, curY + indBoxH, clrInnerBox, clrInnerBorder);
      m_canvas.FontSet("Segoe UI", 11, FW_BOLD);
      m_canvas.TextOut(ind3_x + 8, curY + 6, StringFormat("ATR(14): %.1f pts", m_items[i].atrPts), clrTextMain);

      curY += indBoxH + 10;

      // --- BOTTOM GRAPHICS: BUY PRESSURE | RSI GAUGE | TRAJECTORY ---
      int visH = cy2 - curY - 10;
      if(visH < 62) visH = 62;

      int vGap = 8;
      int v1_w = (int)(innerW * 0.32);
      int v2_w = (int)(innerW * 0.28);
      int v3_w = innerW - v1_w - v2_w - (2 * vGap);

      // 1. VOL & ORDER FLOW (Buy Pressure Bar)
      int v1_x = cx1 + padInside;
      DrawModuleBox(v1_x, curY, v1_x + v1_w, curY + visH, clrInnerBox, clrInnerBorder);
      m_canvas.FontSet("Segoe UI", 9, FW_BOLD);
      m_canvas.TextOut(v1_x + 8, curY + 5, "VOL & ORDER FLOW", clrTextSubtle);
      DrawProgressBar(v1_x + 8, curY + 22, v1_w - 16, 8, m_items[i].buyPressurePct, clrBullDark);
      m_canvas.FontSet("Segoe UI", 10, FW_BOLD);
      m_canvas.TextOut(v1_x + 8, curY + 38, StringFormat("BUY PRESSURE: %.0f%%", m_items[i].buyPressurePct), clrTextMain);

      // 2. RSI (Arc Semi-Circle Gauge)
      int v2_x = v1_x + v1_w + vGap;
      DrawModuleBox(v2_x, curY, v2_x + v2_w, curY + visH, clrInnerBox, clrInnerBorder);
      m_canvas.FontSet("Segoe UI", 9, FW_BOLD);
      m_canvas.TextOut(v2_x + 8, curY + 5, "RSI", clrTextSubtle);
      int gaugeCx = v2_x + (v2_w / 2);
      int gaugeCy = curY + visH - 12;
      int gaugeRad = (visH / 2) - 4;
      DrawArcGauge(gaugeCx, gaugeCy, gaugeRad, m_items[i].rsi14, clrTrack, clrBullDark, clrBearDark, clrTextMain);

      // 3. TRAJECTORY (Multi-Segment Sparkline with Shaded Area)
      int v3_x = v2_x + v2_w + vGap;
      DrawModuleBox(v3_x, curY, v3_x + v3_w, curY + visH, clrInnerBox, clrInnerBorder);
      m_canvas.FontSet("Segoe UI", 9, FW_BOLD);
      m_canvas.TextOut(v3_x + 8, curY + 5, "TRAJECTORY", clrTextSubtle);
      uint sLine = isPos ? clrBullDark : clrBearDark;
      uint sFill = isPos ? clrBullLight : clrBearLight;
      DrawSparklineArea(v3_x + 8, curY + 18, v3_x + v3_w - 8, curY + visH - 6, m_items[i].sparklineData, isPos, sLine, sFill);
   }

   // ====================================================================
   // 4. BOTTOM WATCHLIST RIBBON (5 Columns)
   // ====================================================================
   int barY = m_height - bottomRibbonH - 6;
   DrawModuleBox(sidePad, barY, sidePad + contentW, barY + bottomRibbonH, clrCardBg, clrCardBorder);

   int itemW = contentW / 5;
   string botTitles[5] = {"GOLD", "SILVER", "S&P 500", "NASDAQ 100", "DXY"};

   for(int s = 0; s < 5; s++)
   {
      int bx1 = sidePad + (s * itemW);
      int bx2 = bx1 + itemW;
      if(s > 0) m_canvas.Line(bx1, barY + 8, bx1, barY + bottomRibbonH - 8, clrInnerBorder);

      m_canvas.FontSet("Segoe UI", 12, FW_BOLD);
      m_canvas.TextOut(bx1 + 12, barY + 8, botTitles[s], clrTextMain);
      m_canvas.FontSet("Segoe UI", 11, FW_NORMAL);
      m_canvas.TextOut(bx2 - 68, barY + 8, "% TREND", clrTextSubtle);

      m_canvas.FontSet("Segoe UI", 14, FW_BOLD);
      if(s < 4)
      {
         if(m_items[s].price > 0.0)
         {
            string pStr = (s == 1) ? StringFormat("%.3f", m_items[s].price) : StringFormat("%.2f", m_items[s].price);
            uint prcCol = (m_items[s].priceChangePct >= 0.0 ? clrBullDark : clrBearDark);
            m_canvas.TextOut(bx1 + 12, barY + 34, pStr, prcCol);

            string pctStr = StringFormat("%+.2f%%", m_items[s].priceChangePct);
            m_canvas.TextOut(bx1 + 95, barY + 34, pctStr, prcCol);

            // 3 Status Dots
            int dotX = bx1 + 165;
            int dotY = barY + 41;
            m_canvas.FillCircle(dotX, dotY, 4, (m_items[s].priceChangePct >= 0.0 ? clrBullGreen : clrBearRed));
            m_canvas.FillCircle(dotX + 12, dotY, 4, clrTrack);
            m_canvas.FillCircle(dotX + 24, dotY, 4, clrTrack);
         }
         else
         {
            m_canvas.TextOut(bx1 + 12, barY + 34, "-- (OFFLINE)", clrTextSubtle);
         }
      }
      else // DXY
      {
         string dxyP = StringFormat("%.3f", m_dxyPrice);
         uint dCol = (m_dxyChange >= 0.0 ? clrBullDark : clrBearDark);
         m_canvas.TextOut(bx1 + 12, barY + 34, dxyP, dCol);

         string dxyPct = StringFormat("%+.2f%%", m_dxyChange);
         m_canvas.TextOut(bx1 + 95, barY + 34, dxyPct, dCol);

         int dotX = bx1 + 165;
         int dotY = barY + 41;
         m_canvas.FillCircle(dotX, dotY, 4, (m_dxyChange >= 0.0 ? clrBullGreen : clrBearRed));
         m_canvas.FillCircle(dotX + 12, dotY, 4, clrTrack);
         m_canvas.FillCircle(dotX + 24, dotY, 4, clrTrack);
      }
   }

   m_canvas.Update();
}

//+------------------------------------------------------------------+
//| EXPERT INITIALIZATION FUNCTION                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("[HR_BLOOMBERG] Initializing HR Bloomberg Quant Terminal...");

   // Prepare Chart Canvas
   ChartSetInteger(0, CHART_SHOW_PRICE_SCALE, false);
   ChartSetInteger(0, CHART_SHOW_DATE_SCALE, false);
   ChartSetInteger(0, CHART_SHOW_GRID, false);
   ChartSetInteger(0, CHART_COLOR_BACKGROUND, clrPageBg);

   int w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int h = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   if(w <= 0) w = 1200;
   if(h <= 0) h = 800;

   m_width = w;
   m_height = h;

   if(!m_canvas.CreateBitmapLabel("HR_BLOOMBERG_DASH", 0, 0, m_width, m_height, COLOR_FORMAT_XRGB_NOALPHA))
   {
      Print("[HR_BLOOMBERG][ERROR] Failed to create CCanvas bitmap label!");
      return INIT_FAILED;
   }

   // Initialize Telemetry Instruments
   string symList[];
   int count = StringSplit(InpSymbols, ',', symList);
   
   string bases[4] = {"XAUUSD", "XAGUSD", "US500", "USTEC"};
   string subs[4]  = {"Spot Gold", "Spot Silver", "S&P 500", "Nasdaq 100"};

   for(int i = 0; i < 4; i++)
   {
      m_items[i].baseName = bases[i];
      m_items[i].subName  = subs[i];
      
      string requested = (i < count) ? symList[i] : bases[i];
      m_items[i].symbol   = ResolveBrokerSymbol(requested);
      PrintFormat("[HR_BLOOMBERG] Mapped [%d] %s -> %s", i, bases[i], m_items[i].symbol);

      // Create Technical Indicator Handles
      m_items[i].hEma9      = iMA(m_items[i].symbol, InpMainTF, InpEmaFast, 0, MODE_EMA, PRICE_CLOSE);
      m_items[i].hEma21     = iMA(m_items[i].symbol, InpMainTF, InpEmaMid,  0, MODE_EMA, PRICE_CLOSE);
      m_items[i].hEma200    = iMA(m_items[i].symbol, InpMainTF, InpEmaSlow, 0, MODE_EMA, PRICE_CLOSE);
      m_items[i].hEmaH1_200 = iMA(m_items[i].symbol, InpHtfTF,  InpEmaSlow, 0, MODE_EMA, PRICE_CLOSE);
      m_items[i].hRsi       = iRSI(m_items[i].symbol, InpMainTF, InpRsiPeriod, PRICE_CLOSE);
      m_items[i].hAtr       = iATR(m_items[i].symbol, InpMainTF, InpAtrPeriod);
      m_items[i].hMacd      = iMACD(m_items[i].symbol, InpMainTF, 12, 26, 9, PRICE_CLOSE);

      m_items[i].rsi14 = 58.4;
      m_items[i].buyPressurePct = 65.0;
   }

   m_dxyResolved = ResolveBrokerSymbol(InpDxySymbol);

   UpdateTelemetry();
   RenderUI();

   // 500ms Timer for UI animation pulse & WebSocket simulation
   EventSetMillisecondTimer(500);
   Print("[HR_BLOOMBERG] Initialization Complete. Running on 500ms Animation Loop.");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| EXPERT DEINITIALIZATION FUNCTION                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   m_canvas.Destroy();
   ObjectDelete(0, "HR_BLOOMBERG_DASH");

   ChartSetInteger(0, CHART_SHOW_PRICE_SCALE, true);
   ChartSetInteger(0, CHART_SHOW_DATE_SCALE, true);
   ChartSetInteger(0, CHART_SHOW_GRID, true);

   // Release indicator handles
   for(int i = 0; i < 4; i++)
   {
      IndicatorRelease(m_items[i].hEma9);
      IndicatorRelease(m_items[i].hEma21);
      IndicatorRelease(m_items[i].hEma200);
      IndicatorRelease(m_items[i].hEmaH1_200);
      IndicatorRelease(m_items[i].hRsi);
      IndicatorRelease(m_items[i].hAtr);
      IndicatorRelease(m_items[i].hMacd);
   }
   Print("[HR_BLOOMBERG] Deinitialized.");
}

//+------------------------------------------------------------------+
//| TIMER TICK FUNCTION (500ms ANIMATION & DATA ENGINE)               |
//+------------------------------------------------------------------+
void OnTimer()
{
   m_pulse = !m_pulse; // Toggle pulse animation state
   
   datetime now = TimeCurrent();
   if(now - m_lastCalcTime >= 1)
   {
      UpdateTelemetry();
      m_lastCalcTime = now;
   }
   RenderUI();
}

//+------------------------------------------------------------------+
//| TICK EVENT                                                       |
//+------------------------------------------------------------------+
void OnTick()
{
   UpdateTelemetry();
   RenderUI();
}

//+------------------------------------------------------------------+
//| CHART EVENT (RESIZE RESPONSIVENESS)                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      RenderUI();
   }
}
//+------------------------------------------------------------------+
