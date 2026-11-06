import os

mqh_code = """//+------------------------------------------------------------------+
//|                                           HR_Indicators.mqh      |
//| V4 FINAL LOCK - KEEP EXISTING FORMAT - 2026-05-06                |
//| Premium Digital 44px - Verified Linked - 24/7 - Flicker Added    |
//| Copyright 2026, Hemanth Ranam                                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Hemanth Ranam"
#property link      "https://github.com/HR-Professional-Services/HemanthRanam-MT5-EAs"
#property strict

#include "HR_Utils.mqh"

class CHR_Indicators
{
public:
   static void ComputeMomentum(string symbol, int h_atr_m5, int h_rsi_m5, InstrumentQuantAnalytics &out)
   {
      // ATR(14)
      double atrVal[];
      ArraySetAsSeries(atrVal, true);
      if(CopyBuffer(h_atr_m5, 0, 0, 1, atrVal) > 0)
      {
         out.atr14 = atrVal[0];
         double pt = SymbolInfoDouble(symbol, SYMBOL_POINT);
         out.atrPoints = (pt > 0) ? (atrVal[0] / pt) : 0;
      }

      // RSI(14)
      double rsiVal[];
      ArraySetAsSeries(rsiVal, true);
      if(CopyBuffer(h_rsi_m5, 0, 0, 1, rsiVal) > 0)
      {
         out.rsi14 = rsiVal[0];
         if(out.rsi14 >= 70.0) out.rsiCondition = "OVERBOUGHT";
         else if(out.rsi14 <= 30.0) out.rsiCondition = "OVERSOLD";
         else out.rsiCondition = "NEUTRAL";
      }

      // MACD Main & Signal on M5
      int h_macd = iMACD(symbol, PERIOD_M5, 12, 26, 9, PRICE_CLOSE);
      if(h_macd != INVALID_HANDLE)
      {
         double mMain[], mSig[];
         ArraySetAsSeries(mMain, true); ArraySetAsSeries(mSig, true);
         if(CopyBuffer(h_macd, 0, 0, 1, mMain) > 0 && CopyBuffer(h_macd, 1, 0, 1, mSig) > 0)
         {
            out.macdMain   = mMain[0];
            out.macdSignal = mSig[0];
            out.macdHist   = mMain[0] - mSig[0];
            out.macdMomentum = (mMain[0] > mSig[0]) ? "BULL CROSS" : "BEAR CROSS";
         }
         IndicatorRelease(h_macd);
      }
   }
};
"""

target_file = r"C:\Users\vaibh\.gemini\antigravity-ide\scratch\HemanthRanam-MT5-EAs\06_MULTI_PAIR_SCANNERS\HR_UNIFIED_MASTER_OS_V4_FINAL\HR_Indicators.mqh"
with open(target_file, "w", encoding="utf-8") as f:
    f.write(mqh_code)

print("Created HR_Indicators.mqh")
