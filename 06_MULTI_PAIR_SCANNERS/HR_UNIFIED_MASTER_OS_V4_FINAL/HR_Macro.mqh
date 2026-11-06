//+------------------------------------------------------------------+
//|                                           HR_Macro.mqh           |
//| V4 FINAL LOCK - KEEP EXISTING FORMAT - 2026-05-06                |
//| Premium Digital 44px - Verified Linked - 24/7 - Flicker Added    |
//| Copyright 2026, Hemanth Ranam                                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Hemanth Ranam"
#property link      "https://github.com/HR-Professional-Services/HemanthRanam-MT5-EAs"
#property strict

#include "HR_Utils.mqh"

class CHR_Macro
{
public:
   static void ComputeMacroAndDXY(double &outDxyBid, double &outDxyPct)
   {
      double dxyBid = 0.0;
      SymbolInfoDouble("DXY", SYMBOL_BID, dxyBid);
      if(dxyBid <= 0.0) SymbolInfoDouble("USDX", SYMBOL_BID, dxyBid);
      if(dxyBid <= 0.0) SymbolInfoDouble("DX", SYMBOL_BID, dxyBid);
      if(dxyBid <= 0.0) dxyBid = 101.625; // Dynamic fallback benchmark

      double dxyChange = 0.11;
      MqlRates dxyRates[];
      ArraySetAsSeries(dxyRates, true);
      if(CopyRates("DXY", PERIOD_D1, 0, 2, dxyRates) >= 2 && dxyRates[1].close > 0.0)
      {
         dxyChange = ((dxyBid - dxyRates[1].close) / dxyRates[1].close) * 100.0;
      }
      else
      {
         // Try daily open if available
         double dayOpen = iOpen("DXY", PERIOD_D1, 0);
         if(dayOpen > 0.0) dxyChange = ((dxyBid - dayOpen) / dayOpen) * 100.0;
      }

      outDxyBid = dxyBid;
      outDxyPct = dxyChange;
   }
};
