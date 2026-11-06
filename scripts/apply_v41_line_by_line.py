file_path = r"C:\Users\vaibh\.gemini\antigravity-ide\scratch\HemanthRanam-MT5-EAs\06_MULTI_PAIR_SCANNERS\HR_UNIFIED_MASTER_OS_V4_FINAL\HR_Dashboard_Premium.mqh"
with open(file_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

new_lines = []
skip_until = -1

for i, line in enumerate(lines):
    if i <= skip_until:
        continue
        
    # 1. Update card height clamp (line 623)
    if "if(cardH < 350) cardH = 350;" in line:
        new_lines.append("      if(cardH < 380) cardH = 380;\n")
        continue

    # 2. Update Header Row 2 (line 647 to ~683)
    if "int row2Y = headY + 36;" in line:
        # Find where DXY bar starts
        dxy_idx = -1
        for j in range(i, i + 40):
            if "// MACRO DXY BAR" in lines[j]:
                dxy_idx = j
                break
        if dxy_idx != -1:
            row2_code = """      // Row 2: Sub-Metrics & Live Risk Watchdog
      int row2Y = headY + 36;
      m_canvas.Line(sidePad + 16, row2Y - 4, sidePad + contentW - 16, row2Y - 4, colInnerBrd);

      m_canvas.FontSet("Segoe UI Bold", 13, FW_BOLD);
      m_canvas.TextOut(sidePad + 16, row2Y, "Active Session:", colTextMuted);

      // Session Pill: ASIA gray #6B7280, LONDON blue #2563EB, NY green #10B981, BLOCK red #EF4444
      uint sessPillBg = 0xFF6B7280;
      string sessPillTxt = sessIntel.activeSessionName;
      if(sessIntel.activeSessionName == "LONDON") sessPillBg = 0xFF2563EB;
      else if(sessIntel.activeSessionName == "NY") sessPillBg = 0xFF10B981;
      else if(StringFind(sessIntel.activeSessionName, "BLOCK") >= 0) sessPillBg = 0xFFEF4444;

      DrawPill(sidePad + 115, row2Y - 2, 72, 22, sessPillTxt, sessPillBg, colPillText, 11, true);

      m_canvas.FontSet("Segoe UI Bold", 13, FW_BOLD);
      m_canvas.TextOut(sidePad + 195, row2Y, "Server: " + TimeToString(serverTime, TIME_MINUTES) + " | UK: " + TimeToString(ukTime, TIME_MINUTES), colTextBlack);

      int rx = sidePad + contentW - 740;
      m_canvas.TextOut(rx, row2Y, "Daily Drawdown:", colTextMuted);
      m_canvas.FontSet("Consolas", 15, FW_BOLD);
      uint ddCol = (dailyDD <= -2.0 ? colBearDark : (dailyDD < 0 ? colBearRed : colBullDark));
      m_canvas.TextOut(rx + 112, row2Y, StringFormat("%.2f%%", dailyDD), ddCol);

      m_canvas.FontSet("Segoe UI Bold", 13, FW_BOLD);
      m_canvas.TextOut(rx + 182, row2Y, "Open Risk:", colTextMuted);
      m_canvas.FontSet("Consolas", 15, FW_BOLD);
      m_canvas.TextOut(rx + 252, row2Y, StringFormat("%.2f%%", openRisk), (openRisk >= maxRisk ? colBearDark : colBullDark));

      m_canvas.FontSet("Segoe UI Bold", 13, FW_BOLD);
      m_canvas.TextOut(rx + 322, row2Y, "Positions:", colTextMuted);
      m_canvas.FontSet("Consolas", 15, FW_BOLD);
      uint posCol = (openPos >= maxPos ? colBearRed : colBullDark);
      m_canvas.TextOut(rx + 392, row2Y, StringFormat("%d/%d", openPos, maxPos), posCol);

      // Small Lot Calc & Risk / RR readout
      m_canvas.FontSet("Segoe UI Bold", 11, FW_BOLD);
      string lotCalcStr = StringFormat("Lot: %.2f | Risk: $%.0f | R:R 1:1.5", data[0].calcLot, data[0].riskAmountUSD);
      m_canvas.TextOut(rx + 440, row2Y + 1, lotCalcStr, colTextMuted);

"""
            new_lines.append(row2_code)
            skip_until = dxy_idx - 1
            continue

    # 3. Add News Block pill next to Active Trading Killzones
    if 'DrawPill(sidePad + contentW - 200, macroY + 5, 185, 28, "Active Trading Killzones"' in line:
        new_lines.append('      DrawPill(sidePad + contentW - 470, macroY + 5, 255, 28, "NEWS: BoE 12:00 BLOCK | NFP Tomorrow 13:30", 0xFFFEE2E2, 0xFF991B1B, 10, true);\n')
        new_lines.append(line)
        continue

    # 4. Insert A+ Setup Footer Strip inside each card below the trajectory chart
    if "DrawTrajectoryArea(v3_x + 10, curY + 22" in line:
        new_lines.append(line)
        footer_strip = """
         // ====================================================================
         // SECTION D: A+ SETUP FOOTER STRIP (Height 38px, Full Card Width)
         // ====================================================================
         int footY = cy2 - 38;
         m_canvas.FillRectangle(cx1 + 1, footY, cx2 - 1, cy2 - 1, 0xFFF9FAFB);
         m_canvas.Line(cx1, footY, cx2, footY, 0xFFE5E7EB);

         // Left side: 3-step tracker with icons [v] Touch [v] Retest [ ] Close
         int stepX = cx1 + 14;
         int stepY = footY + 11;
         m_canvas.FontSet("Segoe UI Bold", 10, FW_BOLD);

         string iconTouch = (data[i].stepTouch ? "[✓] Touch" : "[○] Touch");
         uint colTouch = (data[i].stepTouch ? colBullDark : colTextSubtle);
         m_canvas.TextOut(stepX, stepY, iconTouch, colTouch);

         string iconRetest = (data[i].stepRetest ? "[✓] Retest" : "[○] Retest");
         uint colRetest = (data[i].stepRetest ? colBullDark : colTextSubtle);
         m_canvas.TextOut(stepX + 68, stepY, iconRetest, colRetest);

         string iconClose = (data[i].stepClose ? "[✓] Close" : "[○] Close");
         uint colClose = (data[i].stepClose ? colBullDark : colTextSubtle);
         m_canvas.TextOut(stepX + 138, stepY, iconClose, colClose);

         // Center: Signal pill (e.g. SELL READY 85% or WAIT 40%)
         int pillX = stepX + 215;
         int pillW = 115;
         int pillH = 22;
         DrawPill(pillX, footY + 8, pillW, pillH, data[i].signalText, data[i].signalPillBg, colPillText, 10, true);

         // Right side: Entry / Stop / TP / Lot readout
         int paramX = pillX + pillW + 12;
         m_canvas.FontSet("Consolas", 10, FW_BOLD);
         string levelsStr;
         if(i == 1) // Silver 3 decimals
         {
            levelsStr = StringFormat("Entry: %.3f | Stop: %.3f | TP: %.3f | Lot: %.2f",
                                     data[i].calcEntry, data[i].calcStop, data[i].calcTP, data[i].calcLot);
         }
         else
         {
            levelsStr = StringFormat("Entry: %.2f | Stop: %.2f | TP: %.2f | Lot: %.2f",
                                     data[i].calcEntry, data[i].calcStop, data[i].calcTP, data[i].calcLot);
         }
         m_canvas.TextOut(paramX, footY + 11, levelsStr, colTextBlack);
"""
        new_lines.append(footer_strip)
        continue

    new_lines.append(line)

with open(file_path, "w", encoding="utf-8") as f:
    f.writelines(new_lines)

print("HR_Dashboard_Premium.mqh successfully updated line by line!")
