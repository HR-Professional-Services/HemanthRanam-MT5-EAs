//+------------------------------------------------------------------+
//|                                           HR_EMA_Engine.mqh      |
//| V4 FINAL LOCK - KEEP EXISTING FORMAT - 2026-05-06                |
//| Premium Digital 44px - Verified Linked - 24/7 - Flicker Added    |
//| Copyright 2026, Hemanth Ranam                                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Hemanth Ranam"
#property link      "https://github.com/HR-Professional-Services/HemanthRanam-MT5-EAs"
#property strict

#include "HR_Utils.mqh"

class CHR_EMA_Engine
{
public:
   static void ComputeEMAs(string symbol, int h_e9_m5, int h_e21_m5, int h_e200_m5, int h_e9_h1, int h_e21_h1, InstrumentQuantAnalytics &out)
   {
      double e9[], e21[], e200[];
      ArraySetAsSeries(e9, true); ArraySetAsSeries(e21, true); ArraySetAsSeries(e200, true);

      // Copy last 20 bars of EMA 9 for live Trajectory Area rendering
      double e9_hist[];
      ArraySetAsSeries(e9_hist, true);
      if(CopyBuffer(h_e9_m5, 0, 0, 20, e9_hist) >= 20)
      {
         for(int b = 0; b < 20; b++) out.ema9_history[b] = e9_hist[b];
      }

      bool emaReady = (CopyBuffer(h_e9_m5, 0, 0, 2, e9) >= 2 &&
                       CopyBuffer(h_e21_m5, 0, 0, 2, e21) >= 2 &&
                       CopyBuffer(h_e200_m5, 0, 0, 2, e200) >= 2);

      if(emaReady)
      {
         out.ema9_m5   = e9[0];
         out.ema21_m5  = e21[0];
         out.ema200_m5 = e200[0];

         if(e9[0] > e21[0] && e21[0] > e200[0]) out.m5EmaState = "BULLISH";
         else if(e9[0] < e21[0] && e21[0] < e200[0]) out.m5EmaState = "BEARISH";
         else out.m5EmaState = (e9[0] > e21[0] ? "BULLISH" : "BEARISH");

         if(e9[1] <= e21[1] && e9[0] > e21[0]) out.crossoverStatus = "BULL CROSS";
         else if(e9[1] >= e21[1] && e9[0] < e21[0]) out.crossoverStatus = "BEAR CROSS";
         else out.crossoverStatus = "ALIGNED";

         double spreadDist = MathAbs(e9[0] - e21[0]);
         out.emaSeparationPct = (e21[0] > 0.0) ? ((spreadDist / e21[0]) * 100.0) : 0.0;

         double pt = SymbolInfoDouble(symbol, SYMBOL_POINT);
         double slope = (pt > 0) ? (MathAbs(e9[0] - e9[1]) / pt) : 0.0;
         out.emaHealthScore = MathMin(100.0, (slope * 2.5) + (out.emaSeparationPct * 500.0));
      }

      // H1 EMA
      double h1_e9[], h1_e21[];
      ArraySetAsSeries(h1_e9, true); ArraySetAsSeries(h1_e21, true);
      if(CopyBuffer(h_e9_h1, 0, 0, 2, h1_e9) >= 2 && CopyBuffer(h_e21_h1, 0, 0, 2, h1_e21) >= 2)
      {
         out.ema9_h1  = h1_e9[0];
         out.ema21_h1 = h1_e21[0];
         out.h1EmaState = (h1_e9[0] > h1_e21[0]) ? "BULLISH" : "BEARISH";
         out.mtfH1 = out.h1EmaState;
      }
   }
};
