$file = "C:\Users\vaibh\.gemini\antigravity-ide\scratch\HemanthRanam-MT5-EAs\06_MULTI_PAIR_SCANNERS\HR_UNIFIED_MASTER_OS_V4_FINAL\HR_Dashboard_Premium.mqh"
$content = [System.IO.File]::ReadAllText($file)

# 1. Replace CheckFlicker with gentle pastel gradient tints
$oldCheck = @"
      // 1. Price Flicker: 300ms flash Light Green #D1FAE5 / Light Red #FEE2E2
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
      }
"@

$newCheck = @"
      // 1. Price Flicker: Smooth, very gentle 220ms soft pastel gradient tint (Same colors, light calm tint)
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
      }
"@

# Normalize newlines
$normContent = $content.Replace("`r`n", "`n")
$normOld = $oldCheck.Replace("`r`n", "`n")
$normNew = $newCheck.Replace("`r`n", "`n")

if ($normContent.Contains($normOld)) {
    $normContent = $normContent.Replace($normOld, $normNew)
    [System.IO.File]::WriteAllText($file, $normContent.Replace("`n", "`r`n"))
    Write-Host "Successfully updated CheckFlicker to light gradient tints!"
} else {
    Write-Host "Old block not matched directly, inspecting..."
}
