with open(r"C:\Users\vaibh\.gemini\antigravity-ide\scratch\HemanthRanam-MT5-EAs\06_MULTI_PAIR_SCANNERS\HR_UNIFIED_MASTER_OS_V4_FINAL\HR_Utils.mqh", "r", encoding="utf-8") as f:
    c = f.read()

# Add A+ Setup fields to InstrumentQuantAnalytics
old_struct_end = """   // Live M5 EMA 9 Sparkline Buffer (Last 20 bars)
   double            ema9_history[20];
};"""

new_struct_end = """   // Live M5 EMA 9 Sparkline Buffer (Last 20 bars)
   double            ema9_history[20];

   // --- V4.1 A+ 9-21-200 Scalper Engine ---
   bool              stepTouch;        // [✓] Low <= EMA21 <= High last 5 bars
   bool              stepRetest;       // [✓] Retest of 9/21 EMA band
   bool              stepClose;        // [✓] Directional close confirmation
   bool              isAPlusReady;     // True when A+ conditions fully aligned
   string            signalText;       // "SELL READY 85%", "BUY READY 85%", or "WAIT 40%"
   uint              signalPillBg;     // #EF4444 Red, #10B981 Green, #F59E0B Amber
   double            calcEntry;
   double            calcStop;
   double            calcTP;
   double            calcLot;
   double            riskAmountUSD;
   double            rewardRiskRatio;
};"""

c_norm = c.replace("\r\n", "\n")
o_norm = old_struct_end.replace("\r\n", "\n")
n_norm = new_struct_end.replace("\r\n", "\n")

if o_norm in c_norm:
    c_norm = c_norm.replace(o_norm, n_norm)
    with open(r"C:\Users\vaibh\.gemini\antigravity-ide\scratch\HemanthRanam-MT5-EAs\06_MULTI_PAIR_SCANNERS\HR_UNIFIED_MASTER_OS_V4_FINAL\HR_Utils.mqh", "w", encoding="utf-8") as f:
        f.write(c_norm.replace("\n", "\r\n"))
    print("HR_Utils.mqh updated with A+ setup fields.")
else:
    print("Failed to find struct end in HR_Utils.mqh")
