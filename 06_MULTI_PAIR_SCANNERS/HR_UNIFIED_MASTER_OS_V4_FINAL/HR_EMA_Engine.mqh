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



   // ------------------------------------------------------------------

   // V4.1 A+ 9-21-200 Scalper Engine Evaluation

   // ------------------------------------------------------------------

      static void ComputeAPlusSetup(string symbol, int h_e200_h1, InstrumentQuantAnalytics &out)
   {
      // 1. Check 1H 200 bias: Close > H1 EMA200 -> LONG ONLY; Close < H1 EMA200 -> SHORT ONLY
      double h1_200_val[];
      ArraySetAsSeries(h1_200_val, true);
      bool longOnly  = false;
      bool shortOnly = false;
      out.h1_ema200_val = 0.0;
      if(CopyBuffer(h_e200_h1, 0, 0, 1, h1_200_val) > 0 && h1_200_val[0] > 0)
      {
         out.h1_ema200_val = h1_200_val[0];
      }
      else if(out.ema200_m5 > 0.0)
      {
         out.h1_ema200_val = out.ema200_m5;
      }

      // Strict mathematical check against live price
      if(out.h1_ema200_val > 0.0)
      {
         if(out.currentPrice < out.h1_ema200_val)
         {
            shortOnly = true;
            longOnly  = false;
            out.h1_filter_badge = "H: BELOW 200 = SHORT ONLY";
         }
         else
         {
            longOnly  = true;
            shortOnly = false;
            out.h1_filter_badge = "H: ABOVE 200 = LONG ONLY";
         }
      }
      else
      {
         longOnly  = (out.h1EmaState == "BULLISH");
         shortOnly = (out.h1EmaState == "BEARISH");
         out.h1_filter_badge = shortOnly ? "H: BELOW 200 = SHORT ONLY" : "H: ABOVE 200 = LONG ONLY";
      }

      // 2. Check M5 alignment: ema9 < ema21 < ema200 = Bearish, ema9 > ema21 > ema200 = Bullish
      bool m5BearAligned = (out.ema9_m5 < out.ema21_m5 && out.ema21_m5 < out.ema200_m5);
      bool m5BullAligned = (out.ema9_m5 > out.ema21_m5 && out.ema21_m5 > out.ema200_m5);

      // 3. Check 3-bar slope of EMA 9 & set slope arrows
      bool slopeDown = false;
      bool slopeUp   = false;
      if(ArraySize(out.ema9_history) >= 3)
      {
         slopeDown = (out.ema9_history[0] < out.ema9_history[1] && out.ema9_history[1] < out.ema9_history[2]);
         slopeUp   = (out.ema9_history[0] > out.ema9_history[1] && out.ema9_history[1] > out.ema9_history[2]);
      }

      if(slopeDown)
         out.m5_slope_arrows = "\x2193\x2193\x2193"; // vvv
      else if(slopeUp)
         out.m5_slope_arrows = "\x2191\x2191\x2191"; // ^^^
      else
         out.m5_slope_arrows = "\x2194\x2194\x2194"; // <->

      // 4. Check Pullback TOUCH in last 5 bars: low <= ema21 <= high
      MqlRates rates5[];
      ArraySetAsSeries(rates5, true);
      bool hasTouch  = false;
      bool hasRetest = false;
      bool hasClose  = false;
      bool atrGapSkip = false;

      double pt = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(pt <= 0.0) pt = 0.01;
      double atr = (out.atr14 > 0 ? out.atr14 : 10.0 * pt);

      if(CopyRates(symbol, PERIOD_M5, 0, 6, rates5) >= 5)
      {
         for(int k = 1; k <= 5; k++)
         {
            if(rates5[k].low <= out.ema21_m5 && rates5[k].high >= out.ema21_m5)
            {
               hasTouch = true;
               break;
            }
         }
         // Retest condition: rejection wick or test within EMA 9-21 corridor
         double corridorTop = MathMax(out.ema9_m5, out.ema21_m5);
         double corridorBot = MathMin(out.ema9_m5, out.ema21_m5);
         hasRetest = (rates5[0].high >= corridorBot && rates5[0].low <= corridorTop);

         // Directional engulfing close confirmation beyond retest
         if(shortOnly && rates5[0].close < rates5[0].open && rates5[0].close < rates5[1].low) hasClose = true;
         else if(shortOnly && rates5[0].close < rates5[0].open) hasClose = true;

         if(longOnly  && rates5[0].close > rates5[0].open && rates5[0].close > rates5[1].high) hasClose = true;
         else if(longOnly  && rates5[0].close > rates5[0].open) hasClose = true;

         // ATR Gap Filter: If current 5M candle range > ATR(14) -> GAP SKIP
         double candleRange = MathAbs(rates5[0].high - rates5[0].low);
         if(candleRange > (1.2 * atr))
            atrGapSkip = true;
      }
      else
      {
         hasTouch  = true;
         hasRetest = true;
         hasClose  = false;
      }

      out.stepTouch    = hasTouch;
      out.stepRetest   = hasRetest;
      out.stepClose    = hasClose;
      out.atr_gap_skip = atrGapSkip;

      // Evaluate A+ Readiness: 1H filter + M5 alignment + slope + touch
      bool sellReady = (shortOnly && m5BearAligned && slopeDown && hasTouch && !atrGapSkip);
      bool buyReady  = (longOnly  && m5BullAligned && slopeUp   && hasTouch && !atrGapSkip);

      out.isAPlusReady = (sellReady || buyReady);

      if(sellReady)
      {
         out.signalText   = "SELL READY 85%";
         out.signalPillBg = 0xFFEF4444; // Red
         out.signalConfidenceScore = 85.0;
      }
      else if(buyReady)
      {
         out.signalText   = "BUY READY 85%";
         out.signalPillBg = 0xFF10B981; // Green
         out.signalConfidenceScore = 85.0;
      }
      else
      {
         // Dynamic WAIT confidence: Base 30% + Health/4 + Separation + Slope + 1H alignment
         double conf = 30.0;
         conf += (out.emaHealthScore * 0.15); // up to +15%
         if(out.emaSeparationPct >= 0.08) conf += 10.0;
         else if(out.emaSeparationPct >= 0.04) conf += 5.0;

         // Check slope alignment
         if((shortOnly && slopeDown) || (longOnly && slopeUp)) conf += 10.0;

         // Check 1H filter alignment
         if((shortOnly && out.m5EmaState == "BEARISH") || (longOnly && out.m5EmaState == "BULLISH")) conf += 10.0;

         // Clamp between 30% and 55% during WAIT mode
         if(conf < 30.0) conf = 30.0;
         if(conf > 55.0) conf = 55.0;

         out.signalConfidenceScore = conf;
         out.signalText   = StringFormat("WAIT %.0f%%", conf);
         out.signalPillBg = 0xFFF59E0B; // Amber
      }

      // Calculate Entry, Stop, TP, and Lot Size
      out.calcEntry = out.currentPrice;

      if(sellReady)
      {
         double swingHigh = (out.lastSwingHigh > out.currentPrice ? out.lastSwingHigh : out.currentPrice + atr);
         out.calcStop = swingHigh + (0.2 * atr);
         double stopDist = MathAbs(out.calcStop - out.calcEntry);
         if(stopDist <= pt) stopDist = atr;
         out.calcTP = out.calcEntry - (1.5 * stopDist);
      }
      else if(buyReady)
      {
         double swingLow = (out.lastSwingLow > 0 && out.lastSwingLow < out.currentPrice ? out.lastSwingLow : out.currentPrice - atr);
         out.calcStop = swingLow - (0.2 * atr);
         double stopDist = MathAbs(out.calcEntry - out.calcStop);
         if(stopDist <= pt) stopDist = atr;
         out.calcTP = out.calcEntry + (1.5 * stopDist);
      }
      else
      {
         // Wait mode benchmark levels based on 1:1.5 RR (Stop = 0.2 ATR beyond local level)
         double stopDist = (atr > 0 ? (0.8 * atr) : 20.0 * pt);
         out.calcStop = out.calcEntry + (shortOnly ? stopDist : -stopDist);
         out.calcTP   = out.calcEntry + (shortOnly ? -1.5 * stopDist : 1.5 * stopDist);
      }

      // Lot Calculation (Strict 1% Equity/Balance Risk)
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      if(balance <= 0) balance = 10000.0;
      double riskUSD = balance * 0.01; // 1% risk
      out.riskAmountUSD = riskUSD;
      out.rewardRiskRatio = 1.5;

      double stopDistance = MathAbs(out.calcEntry - out.calcStop);
      double stopPts = (pt > 0.0) ? (stopDistance / pt) : (stopDistance * 100.0);
      double tickVal = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);

      double lotCalc = 0.24;
      // If tick value is in points or currency, check lossPerLot
      double lossPerLot = 0.0;
      if(contractSize > 0.0 && stopDistance > 0.0)
      {
         lossPerLot = stopDistance * contractSize;
      }
      else if(stopPts > 0.0 && tickVal > 0.0)
      {
         lossPerLot = stopPts * tickVal;
      }

      if(lossPerLot > 0.0)
      {
         lotCalc = riskUSD / lossPerLot;
      }
      else if(stopDistance > 0.0)
      {
         lotCalc = riskUSD / (stopDistance * 100.0);
      }

      // Clamp lot size to broker min 0.01, max 5.00, 2 decimals
      double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double maxLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      if(minLot <= 0) minLot = 0.01;
      if(maxLot <= 0 || maxLot > 5.0) maxLot = 5.00;
      if(stepLot <= 0) stepLot = 0.01;

      lotCalc = MathFloor(lotCalc / stepLot) * stepLot;
      if(lotCalc < minLot) lotCalc = minLot;
      if(lotCalc > maxLot) lotCalc = maxLot;
      out.calcLot = NormalizeDouble(lotCalc, 2);
   }
};

