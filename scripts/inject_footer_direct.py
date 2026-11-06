file_path = r"C:\Users\vaibh\.gemini\antigravity-ide\scratch\HemanthRanam-MT5-EAs\06_MULTI_PAIR_SCANNERS\HR_UNIFIED_MASTER_OS_V4_FINAL\HR_Dashboard_Premium.mqh"
with open(file_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

new_lines = []
for i, line in enumerate(lines):
    new_lines.append(line)
    
    # 1. Right after the DrawTrajectoryArea line, inject the A+ Footer Strip
    if "DrawTrajectoryArea(v3_x + 10, curY + 22" in line:
        footer_code = """
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
        new_lines.append(footer_code)

    # 2. Right after openPos, maxPos text out, inject the small Lot Calc
    if 'openPos, maxPos), colTextBlack);' in line:
        lot_code = """      // Small Lot Calc & Risk / RR readout
      m_canvas.FontSet("Segoe UI Bold", 11, FW_BOLD);
      string lotCalcStr = StringFormat("Lot: %.2f | Risk: $%.0f | R:R 1:1.5", data[0].calcLot, data[0].riskAmountUSD);
      m_canvas.TextOut(rx + 500, row2Y + 1, lotCalcStr, colTextMuted);
"""
        new_lines.append(lot_code)

with open(file_path, "w", encoding="utf-8") as f:
    f.writelines(new_lines)

print("Injected A+ footer strip and Lot Calc successfully!")
