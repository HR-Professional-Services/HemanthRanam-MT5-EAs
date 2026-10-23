import os

eas = ['21_EMA_EA', '50_EMA_EA', '100_EMA_EA']
base_dir = r"C:\Users\vaibh\.gemini\antigravity-ide\scratch\HemanthRanam-MT5-EAs\07_EMA_EAS"

for ea in eas:
    p = os.path.join(base_dir, ea + '.mq5')
    with open(p, 'r', encoding='utf-8') as f:
        txt = f.read()

    # 1. Add input InpUseWickBounce to Strategy Parameters
    old_input = 'input int             InpMinSLPoints       = 100;            // Minimum SL Floor Distance (Points, Custom only)'
    new_input = 'input int             InpMinSLPoints       = 100;            // Minimum SL Floor Distance (Points, Custom only)\ninput bool            InpUseWickBounce     = false;          // Enable Wick Bounce Pullback Entry (Replaces Full Cross)'
    if 'InpUseWickBounce' not in txt:
        txt = txt.replace(old_input, new_input)

    # 2. Update the Buy/Sell logic in OnTick
    old_logic = """   // 8. High-Quality Breakout Setup Filter (Closed bar validation with Volume & Quality)
   // - Bullish: Preceding candle (1) closed cleanly ABOVE the EMA (emaLTF[1]), while candle (2) was below or touched it (emaLTF[2]).
   bool isHighQualityBuy  = isBullishBias && isVolumeConfirmed && isBodyQualityOk && (closePrice1 > emaLTF[1] && closePrice2 <= emaLTF[2] && closePrice1 > openPrice1);
   bool isHighQualitySell = isBearishBias && isVolumeConfirmed && isBodyQualityOk && (closePrice1 < emaLTF[1] && closePrice2 >= emaLTF[2] && closePrice1 < openPrice1);"""

    new_logic = """   // 8. High-Quality Breakout / Pullback Setup Filter (Closed bar validation with Volume & Quality)
   bool isSetupBuy  = false;
   bool isSetupSell = false;

   if(!InpUseWickBounce)
   {
      // Baseline Full-Cross Mode: Preceding candle (1) closed cleanly ABOVE the EMA, while candle (2) was below or touched it
      isSetupBuy  = (closePrice1 > emaLTF[1] && closePrice2 <= emaLTF[2] && closePrice1 > openPrice1);
      isSetupSell = (closePrice1 < emaLTF[1] && closePrice2 >= emaLTF[2] && closePrice1 < openPrice1);
   }
   else
   {
      // Experiment B1 Wick-Bounce Mode: Trend pullback where candle wicked into/below EMA, but closed in trend direction
      // Preceding trend confirmed on LTF: emaLTF[1] > emaLTF[2]
      // Pullback wick test: lowPrice1 <= emaLTF[1] or lowPrice2 <= emaLTF[2], but closePrice1 > emaLTF[1] with bullish body
      isSetupBuy  = (emaLTF[1] > emaLTF[2] && (lowPrice1 <= emaLTF[1] || lowPrice2 <= emaLTF[2]) && closePrice1 > emaLTF[1] && closePrice1 > openPrice1);
      isSetupSell = (emaLTF[1] < emaLTF[2] && (highPrice1 >= emaLTF[1] || highPrice2 >= emaLTF[2]) && closePrice1 < emaLTF[1] && closePrice1 < openPrice1);
   }

   bool isHighQualityBuy  = isBullishBias && isVolumeConfirmed && isBodyQualityOk && isSetupBuy;
   bool isHighQualitySell = isBearishBias && isVolumeConfirmed && isBodyQualityOk && isSetupSell;"""

    txt = txt.replace(old_logic, new_logic)

    with open(p, 'w', encoding='utf-8') as f:
        f.write(txt)
    print(f"Added InpUseWickBounce option to {ea}.mq5")

print("EAs updated with InpUseWickBounce option.")
