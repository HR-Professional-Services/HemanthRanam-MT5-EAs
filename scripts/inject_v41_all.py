file_path = r"C:\Users\vaibh\.gemini\antigravity-ide\scratch\HemanthRanam-MT5-EAs\06_MULTI_PAIR_SCANNERS\HR_UNIFIED_MASTER_OS_V4_FINAL\HR_Dashboard_Premium.mqh"
with open(file_path, "r", encoding="utf-8") as f:
    text = f.read()

target = """         DrawTrajectoryArea(v3_x + 10, curY + 22, v3_x + v3_w - 10, curY + visH - 6, isTrendBull, sparkLine, sparkFill, data[i].ema9_history);
      }"""

replacement = """         DrawTrajectoryArea(v3_x + 10, curY + 22, v3_x + v3_w - 10, curY + visH - 6, isTrendBull, sparkLine, sparkFill, data[i].ema9_history);

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
      }"""

# Header Row 2 replacement
target_row2 = """      m_canvas.FontSet("Consolas", 16, FW_BOLD);
      m_canvas.TextOut(rx + 445, row2Y, StringFormat("%d/%d", openPos, maxPos), colTextBlack);"""

replacement_row2 = """      m_canvas.FontSet("Consolas", 16, FW_BOLD);
      m_canvas.TextOut(rx + 445, row2Y, StringFormat("%d/%d", openPos, maxPos), colTextBlack);

      // Small Lot Calc & Risk / RR readout
      m_canvas.FontSet("Segoe UI Bold", 11, FW_BOLD);
      string lotCalcStr = StringFormat("Lot: %.2f | Risk: $%.0f | R:R 1:1.5", data[0].calcLot, data[0].riskAmountUSD);
      m_canvas.TextOut(rx + 500, row2Y + 1, lotCalcStr, colTextMuted);"""

# Session Pill replacement
target_sess = """      DrawPill(sidePad + 120, row2Y - 2, 54, 22, (sessionStatus == "ACTIVE" ? "ON" : "OFF"), (sessionStatus == "ACTIVE" ? colBullGreen : colTextBlack), colPillText, 12, true);"""

replacement_sess = """      // Session Pill: ASIA gray #6B7280, LONDON blue #2563EB, NY green #10B981, BLOCK red #EF4444
      uint sessPillBg = 0xFF6B7280;
      string sessPillTxt = sessIntel.activeSessionName;
      if(sessIntel.activeSessionName == "LONDON") sessPillBg = 0xFF2563EB;
      else if(sessIntel.activeSessionName == "NY") sessPillBg = 0xFF10B981;
      else if(StringFind(sessIntel.activeSessionName, "BLOCK") >= 0) sessPillBg = 0xFFEF4444;
      DrawPill(sidePad + 115, row2Y - 2, 70, 22, sessPillTxt, sessPillBg, colPillText, 11, true);"""

# News pill replacement
target_news = """      DrawPill(sidePad + contentW - 200, macroY + 5, 185, 28, "Active Trading Killzones", colChipGray, colTextMuted, 13, true);"""

replacement_news = """      DrawPill(sidePad + contentW - 470, macroY + 5, 255, 28, "NEWS: BoE 12:00 BLOCK | NFP Tomorrow 13:30", 0xFFFEE2E2, 0xFF991B1B, 10, true);
      DrawPill(sidePad + contentW - 200, macroY + 5, 185, 28, "Active Trading Killzones", colChipGray, colTextMuted, 12, true);"""

# Normalize
t_norm = text.replace("\r\n", "\n")

pairs = [
    (target.replace("\r\n", "\n"), replacement.replace("\r\n", "\n")),
    (target_row2.replace("\r\n", "\n"), replacement_row2.replace("\r\n", "\n")),
    (target_sess.replace("\r\n", "\n"), replacement_sess.replace("\r\n", "\n")),
    (target_news.replace("\r\n", "\n"), replacement_news.replace("\r\n", "\n")),
]

for t, r in pairs:
    if t in t_norm:
        t_norm = t_norm.replace(t, r)
        print("Replaced section successfully!")
    else:
        print("Target not found:", t[:40])

with open(file_path, "w", encoding="utf-8") as f:
    f.write(t_norm.replace("\n", "\r\n"))

print("HR_Dashboard_Premium.mqh successfully injected!")
