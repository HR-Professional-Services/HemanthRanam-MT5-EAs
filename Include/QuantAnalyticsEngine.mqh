//+------------------------------------------------------------------+
//| Quant Analytics & Market Structure Engine for Bloomberg Terminal |
//+------------------------------------------------------------------+
#property copyright "Hemanth Ranam"
#property link      "https://github.com/HR-Professional-Services/HemanthRanam-MT5-EAs"
#property strict

#include <DashboardQuantTypes.mqh>

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

      // 6. Market Structure, Swings, BOS, CHOCH & Swings Lookback (M5)
      MqlRates m5Rates[];
      ArraySetAsSeries(m5Rates, true);
      if(CopyRates(symbol, PERIOD_M5, 0, 35, m5Rates) >= 35)
      {
         double highest = m5Rates[1].high;
         double lowest = m5Rates[1].low;
         for(int b = 1; b <= 20; b++)
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

         // BOS & CHOCH Detection
         if(m5Rates[1].close > highest * 0.9995)
         {
            out.bosStatus = "BULLISH BOS";
            out.structureClass = "HH (Higher High)";
         }
         else if(m5Rates[1].close < lowest * 1.0005)
         {
            out.bosStatus = "BEARISH BOS";
            out.structureClass = "LL (Lower Low)";
         }
         else
         {
            out.bosStatus = "INTACT";
            out.structureClass = (out.m5EmaState == "BULLISH" ? "HL (Higher Low)" : "LH (Lower High)");
         }

         // Liquidity Sweep Detection
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
