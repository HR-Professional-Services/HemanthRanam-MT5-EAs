import os

eas = ['9_EMA_EA', '21_EMA_EA']
base_dir = r"C:\Users\vaibh\.gemini\antigravity-ide\scratch\HemanthRanam-MT5-EAs\07_EMA_EAS"

for ea in eas:
    p = os.path.join(base_dir, ea + '.mq5')
    with open(p, 'r', encoding='utf-8') as f:
        txt = f.read()

    # 1. Add InpBEType and InpBEATRMult to Position Management inputs
    old_input = 'input int             InpBEPoints          = 100;            // Profit in Points to Trigger Break-Even (Custom only)'
    new_input = 'input int             InpBEPoints          = 100;            // Profit in Points to Trigger Break-Even (Custom only)\ninput bool            InpUseATR_BE         = false;          // Enable ATR-Proportional Break-Even Trigger\ninput double          InpBEATRMultiplier   = 1.5;            // ATR Multiplier for BE Trigger (e.g. 1.5x ATR)'
    if 'InpUseATR_BE' not in txt:
        txt = txt.replace(old_input, new_input)

    # 2. Update ManagePositions BE trigger logic
    old_be = """      // 1. Break-Even Protection Engine
      if(InpUseBE)
      {
         if(posType == POSITION_TYPE_BUY)
         {
            if((curPrice - openPrice) >= (activeBE * point))
            {
               double desiredBE = NormalizePriceToTick(openPrice + (activeBESafety * point));
               if(currentSL < desiredBE - (point * 0.5))
               {
                  if(trade.PositionModify(ticket, desiredBE, currentTP))
                  {
                     PrintFormat("[{EA_NAME}][BE_SECURED] BUY Ticket #%I64u locked to Break-Even @ %.5f", ticket, desiredBE);
                     currentSL = desiredBE;
                     beTriggered = true;
                  }
               }
               else
               {
                  beTriggered = true;
               }
            }
         }
         else if(posType == POSITION_TYPE_SELL)
         {
            if((openPrice - curPrice) >= (activeBE * point))
            {
               double desiredBE = NormalizePriceToTick(openPrice - (activeBESafety * point));
               if(currentSL > desiredBE + (point * 0.5) || currentSL == 0.0)
               {
                  if(trade.PositionModify(ticket, desiredBE, currentTP))
                  {
                     PrintFormat("[{EA_NAME}][BE_SECURED] SELL Ticket #%I64u locked to Break-Even @ %.5f", ticket, desiredBE);
                     currentSL = desiredBE;
                     beTriggered = true;
                  }
               }
               else
               {
                  beTriggered = true;
               }
            }
         }
      }""".replace('{EA_NAME}', ea)

    new_be = """      // 1. Break-Even Protection Engine (Fixed Points or Dynamic ATR-Proportional)
      if(InpUseBE)
      {
         double requiredBEProfitDist = (double)activeBE * point;
         if(InpUseATR_BE && handleATR != INVALID_HANDLE)
         {
            double atrVals[];
            ArraySetAsSeries(atrVals, true);
            if(CopyBuffer(handleATR, 0, 1, 1, atrVals) > 0 && atrVals[0] > 0.0)
            {
               requiredBEProfitDist = MathMax(requiredBEProfitDist, atrVals[0] * InpBEATRMultiplier);
            }
         }

         if(posType == POSITION_TYPE_BUY)
         {
            if((curPrice - openPrice) >= requiredBEProfitDist)
            {
               double desiredBE = NormalizePriceToTick(openPrice + (activeBESafety * point));
               if(currentSL < desiredBE - (point * 0.5))
               {
                  if(trade.PositionModify(ticket, desiredBE, currentTP))
                  {
                     PrintFormat("[{EA_NAME}][BE_SECURED] BUY Ticket #%I64u locked to Break-Even @ %.5f", ticket, desiredBE);
                     currentSL = desiredBE;
                     beTriggered = true;
                  }
               }
               else
               {
                  beTriggered = true;
               }
            }
         }
         else if(posType == POSITION_TYPE_SELL)
         {
            if((openPrice - curPrice) >= requiredBEProfitDist)
            {
               double desiredBE = NormalizePriceToTick(openPrice - (activeBESafety * point));
               if(currentSL > desiredBE + (point * 0.5) || currentSL == 0.0)
               {
                  if(trade.PositionModify(ticket, desiredBE, currentTP))
                  {
                     PrintFormat("[{EA_NAME}][BE_SECURED] SELL Ticket #%I64u locked to Break-Even @ %.5f", ticket, desiredBE);
                     currentSL = desiredBE;
                     beTriggered = true;
                  }
               }
               else
               {
                  beTriggered = true;
               }
            }
         }
      }""".replace('{EA_NAME}', ea)

    txt = txt.replace(old_be, new_be)

    with open(p, 'w', encoding='utf-8') as f:
        f.write(txt)
    print(f"Added ATR Break-Even option to {ea}.mq5")

print("9 and 21 EMA updated.")
