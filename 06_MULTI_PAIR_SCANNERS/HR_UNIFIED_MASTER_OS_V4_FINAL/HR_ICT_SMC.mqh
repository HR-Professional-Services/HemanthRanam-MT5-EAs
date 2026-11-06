//+------------------------------------------------------------------+
//|                                           HR_ICT_SMC.mqh         |
//| V4 FINAL LOCK - KEEP EXISTING FORMAT - 2026-05-06                |
//| Premium Digital 44px - Verified Linked - 24/7 - Flicker Added    |
//| Copyright 2026, Hemanth Ranam                                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Hemanth Ranam"
#property link      "https://github.com/HR-Professional-Services/HemanthRanam-MT5-EAs"
#property strict

#include "HR_Utils.mqh"

class CHR_ICT_SMC
{
public:
   static void ComputeStructureAndLiquidity(string symbol, InstrumentQuantAnalytics &out)
   {
      MqlRates m5Rates[];
      ArraySetAsSeries(m5Rates, true);
      if(CopyRates(symbol, PERIOD_M5, 0, 50, m5Rates) >= 50)
      {
         // Highest high and lowest low of last 20 bars (Nearest BSL / SSL)
         double highest = m5Rates[1].high;
         double lowest  = m5Rates[1].low;
         for(int b = 1; b <= 20; b++)
         {
            if(m5Rates[b].high > highest) highest = m5Rates[b].high;
            if(m5Rates[b].low < lowest)   lowest  = m5Rates[b].low;
         }

         out.nearestBSL = highest;
         out.nearestSSL = lowest;
         out.lastSwingHigh = highest;
         out.lastSwingLow  = lowest;

         double pt = SymbolInfoDouble(symbol, SYMBOL_POINT);
         out.bslDistancePoints = (pt > 0) ? (MathAbs(highest - out.currentPrice) / pt) : 0;
         out.sslDistancePoints = (pt > 0) ? (MathAbs(out.currentPrice - lowest) / pt) : 0;

         // Premium / Discount Zone
         double swingRange = highest - lowest;
         if(swingRange > 0.0)
         {
            double eq = lowest + (swingRange * 0.50);
            if(out.currentPrice > eq + (swingRange * 0.15)) out.smcZone = "PREMIUM (Sell Zone)";
            else if(out.currentPrice < eq - (swingRange * 0.15)) out.smcZone = "DISCOUNT (Buy Zone)";
            else out.smcZone = "EQUILIBRIUM (Fair Value)";
         }

         // Structure & CHOCH / BOS Evaluation from last 50 bars
         double swing50H = m5Rates[1].high;
         double swing50L = m5Rates[1].low;
         for(int k = 1; k < 50; k++)
         {
            if(m5Rates[k].high > swing50H) swing50H = m5Rates[k].high;
            if(m5Rates[k].low < swing50L)  swing50L = m5Rates[k].low;
         }

         if(m5Rates[1].close > highest)
         {
            out.bosStatus = "BULLISH BOS";
            out.structureClass = "HH (Higher High)";
            out.chochStatus = "BULLISH CHOCH";
         }
         else if(m5Rates[1].close < lowest)
         {
            out.bosStatus = "BEARISH BOS";
            out.structureClass = "LL (Lower Low)";
            out.chochStatus = "BEARISH CHOCH";
         }
         else
         {
            out.bosStatus = "INTACT";
            out.structureClass = (out.currentPrice > lowest + (swingRange * 0.5)) ? "CHOCH (LH Lower High)" : "CHOCH (HL Higher Low)";
            out.chochStatus = "CHOCH (LH Lower High)";
         }

         // Check Liquidity Sweeps
         if(m5Rates[1].high > highest && m5Rates[1].close < highest)
         {
            out.lastSweepDirection = "SWEEP BUY";
            out.sweepConfirmation = "CONFIRMED";
         }
         else if(m5Rates[1].low < lowest && m5Rates[1].close > lowest)
         {
            out.lastSweepDirection = "SWEEP SELL";
            out.sweepConfirmation = "CONFIRMED";
         }
         else
         {
            out.lastSweepDirection = "NONE";
            out.sweepConfirmation = "NONE";
         }

         // Volume & Relative Volume
         out.currentTickVol = m5Rates[0].tick_volume;
         out.prevTickVol = m5Rates[1].tick_volume;
         long volSum = 0;
         for(int v = 1; v <= 20; v++) volSum += m5Rates[v].tick_volume;
         out.avgTickVol = (double)volSum / 20.0;
         out.rvol = (out.avgTickVol > 0.0) ? ((double)out.prevTickVol / out.avgTickVol) : 1.0;
         out.volExpansion = (out.rvol >= 1.5) ? "EXPANSION (High)" : ((out.rvol <= 0.7) ? "CONTRACTION (Low)" : "NORMAL");

         // Buy Pressure proxy: % of bullish bars in last 20 bars
         int bullCount = 0;
         for(int b = 1; b <= 20; b++)
         {
            if(m5Rates[b].close >= m5Rates[b].open) bullCount++;
         }
         out.buyingPressurePct = ((double)bullCount / 20.0) * 100.0;
      }
   }
};
