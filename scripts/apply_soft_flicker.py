import os

files_to_update = [
    r"C:\Users\vaibh\.gemini\antigravity-ide\scratch\HemanthRanam-MT5-EAs\06_MULTI_PAIR_SCANNERS\HR_UNIFIED_MASTER_OS_V4_FINAL\HR_Dashboard_Premium.mqh",
    r"C:\Users\vaibh\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\06_MULTI_PAIR_SCANNERS\HR_UNIFIED_MASTER_OS_V4_FINAL\HR_Dashboard_Premium.mqh",
    r"C:\Users\vaibh\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\06_MULTI_PAIR_SCAN\HR_UNIFIED_MASTER_OS_V4_FINAL\HR_Dashboard_Premium.mqh"
]

target_old = """      // 1. Price Flicker: 300ms flash Light Green #D1FAE5 / Light Red #FEE2E2
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
      }"""

replacement = """      // 1. Price Flicker: Smooth, very gentle 220ms soft pastel gradient tint (Same colors, subtle calm tint)
      if(m_flicker.prevPrice[idx] > 0.0 && newPrice != m_flicker.prevPrice[idx])
      {
         if(newPrice > m_flicker.prevPrice[idx])
         {
            m_flicker.priceFlickerBg[idx]  = 0xFFF0FDF4; // Very soft pale mint (#F0FDF4)
            m_flicker.priceFlickerTxt[idx] = 0xFF15803D; // Same deep forest green (#15803D)
         }
         else
         {
            m_flicker.priceFlickerBg[idx]  = 0xFFFEF2F2; // Very soft pale blush rose (#FEF2F2)
            m_flicker.priceFlickerTxt[idx] = 0xFFB91C1C; // Same deep rich crimson (#B91C1C)
         }
         m_flicker.priceFlickerEnd[idx] = now + 220;
      }
      m_flicker.prevPrice[idx] = newPrice;

      // 2. Percentage Change Flicker: Gentle soft gradient tint
      if(m_flicker.prevPct[idx] != 0.0 && MathAbs(newPct - m_flicker.prevPct[idx]) > 0.01)
      {
         m_flicker.pctFlickerBg[idx]  = (newPct >= 0.0 ? 0xFFF0FDF4 : 0xFFFEF2F2);
         m_flicker.pctFlickerEnd[idx] = now + 220;
      }
      m_flicker.prevPct[idx] = newPct;

      // 3. EMA Regime Pill Flicker: Soft subtle warm amber cream
      if(m_flicker.prevEmaM5[idx] != "" && newEmaM5 != m_flicker.prevEmaM5[idx])
      {
         m_flicker.emaFlickerBg[idx]  = 0xFFFEF3C7; // Gentle soft cream yellow (#FEF3C7)
         m_flicker.emaFlickerEnd[idx] = now + 280;
      }
      m_flicker.prevEmaM5[idx] = newEmaM5;

      // 4. RSI Overbought/Oversold Cross Flicker: Very soft cream ivory
      if((newRsi >= 70.0 && m_flicker.prevRsi[idx] < 70.0) || (newRsi <= 30.0 && m_flicker.prevRsi[idx] > 30.0))
      {
         m_flicker.gaugeFlickerBg[idx]  = 0xFFFFFBEB; // Delicate warm ivory (#FFFBEB)
         m_flicker.gaugeFlickerEnd[idx] = now + 300;
      }
      m_flicker.prevRsi[idx] = newRsi;

      // 5. BSL / SSL Swept Flicker: Soft delicate peach
      if((m_flicker.prevBsl[idx] > 0.0 && newBsl != m_flicker.prevBsl[idx]) || (m_flicker.prevSsl[idx] > 0.0 && newSsl != m_flicker.prevSsl[idx]))
      {
         m_flicker.bslFlickerBg[idx]  = 0xFFFFEDD5; // Delicate soft peach (#FFEDD5)
         m_flicker.bslFlickerEnd[idx] = now + 300;
      }
      m_flicker.prevBsl[idx] = newBsl;
      m_flicker.prevSsl[idx] = newSsl;

      // 6. Buy Pressure shift: Soft mint tint
      if(m_flicker.prevBuyPress[idx] > 0.0 && MathAbs(newBuyPress - m_flicker.prevBuyPress[idx]) >= 5.0)
      {
         m_flicker.volFlickerBg[idx]  = 0xFFA7F3D0; // Soft pastel emerald (#A7F3D0)
         m_flicker.volFlickerEnd[idx] = now + 220;
      }"""

# Also soften the price background rectangle in RenderTerminal
old_rect = """         // Check if Price is flickering
         if(now < m_flicker.priceFlickerEnd[i])
         {
            // Flash Price Background Badge for 300ms
            m_canvas.FillRectangle(prcX - 6, prcY - 2, cx2 - 12, prcY + 48, m_flicker.priceFlickerBg[i]);
            m_canvas.Rectangle(prcX - 6, prcY - 2, cx2 - 12, prcY + 48, colBorder);
            prcColor = m_flicker.priceFlickerTxt[i];
         }"""

new_rect = """         // Check if Price is flickering (Gentle soft gradient glow, no harsh contrast)
         if(now < m_flicker.priceFlickerEnd[i])
         {
            // Soft subtle gradient tint behind digits
            m_canvas.FillRectangle(prcX - 4, prcY, cx2 - 14, prcY + 44, m_flicker.priceFlickerBg[i]);
            m_canvas.Rectangle(prcX - 4, prcY, cx2 - 14, prcY + 44, 0xFFE2E8F0);
            prcColor = m_flicker.priceFlickerTxt[i];
         }"""

for fpath in files_to_update:
    if os.path.exists(fpath):
        with open(fpath, "r", encoding="utf-8") as f:
            c = f.read()
        
        # normalize
        c_norm = c.replace("\r\n", "\n")
        t_norm = target_old.replace("\r\n", "\n")
        r_norm = replacement.replace("\r\n", "\n")
        
        o_rect_norm = old_rect.replace("\r\n", "\n")
        n_rect_norm = new_rect.replace("\r\n", "\n")
        
        updated = False
        if t_norm in c_norm:
            c_norm = c_norm.replace(t_norm, r_norm)
            updated = True
        if o_rect_norm in c_norm:
            c_norm = c_norm.replace(o_rect_norm, n_rect_norm)
            updated = True
            
        if updated:
            with open(fpath, "w", encoding="utf-8") as f:
                f.write(c_norm.replace("\n", "\r\n"))
            print(f"Updated {fpath}")
        else:
            print(f"Pattern not found in {fpath}")
