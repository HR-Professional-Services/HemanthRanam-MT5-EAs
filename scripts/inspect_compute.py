import os

repo_dir = r"C:\Users\vaibh\.gemini\antigravity-ide\scratch\HemanthRanam-MT5-EAs"
src_file = os.path.join(repo_dir, "00_UNIFIED_SYSTEM", "HR_UNIFIED_MULTI_STRATEGY_EA.mq5")

with open(src_file, "r", encoding="utf-8") as f:
    text = f.read()

start_term = text.find("class CBloombergTerminal")
end_term = text.find("class CQuantAnalyticsEngine")

prefix = text[:start_term]
trade_inc = prefix.find("#include <Trade\\Trade.mqh>")
prefix_after_trade = prefix[trade_inc:]
struct_sess_pos = prefix_after_trade.find("struct SessionIntelligence")

header_comment = """//+------------------------------------------------------------------+
//|                                        HR_UNIFIED_MASTER_OS.mq5  |
//| V4 FINAL LOCK - KEEP EXISTING FORMAT - 2026-05-06                |
//| Premium Digital 44px - Verified Linked - 24/7 - Flicker Added    |
//| Copyright 2026, Hemanth Ranam                                    |
//| https://github.com/HR-Professional-Services/HR-Bloomberg-Quant-Terminal-MT5 |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, Hemanth Ranam"
#property link        "https://github.com/HR-Professional-Services/HR-Bloomberg-Quant-Terminal-MT5"
#property version     "4.00"
#property description "HR Bloomberg Quant Terminal - Institutional Scalper Radar V4 Final Lock"
#property description "Locked 1:1 Architecture with Verified Linkage, Real-time Flicker, and 24/7 Stability"

#include <Trade\\Trade.mqh>
#include <Trade\\SymbolInfo.mqh>
#include <Trade\\PositionInfo.mqh>
#include <Trade\\AccountInfo.mqh>
#include <Trade\\OrderInfo.mqh>
#include <Canvas\\Canvas.mqh>

#include "HR_Utils.mqh"
#include "HR_EMA_Engine.mqh"
#include "HR_ICT_SMC.mqh"
#include "HR_Indicators.mqh"
#include "HR_Macro.mqh"
#include "HR_Dashboard_Premium.mqh"
"""

prefix_clean = header_comment + prefix_after_trade[prefix_after_trade.find("#define NUM_INSTRUMENTS 4"):struct_sess_pos]

suffix = text[end_term:]

# In suffix, we will:
# 1. Update ComputeInstrumentAnalytics to call CHR_EMA_Engine, CHR_ICT_SMC, CHR_Indicators
# 2. Add VerifyAllLinked() function
# 3. Enhance OnInit with 3-retry handle initialization + 24/7 error handling
# 4. Enhance OnDeinit with ObjectsDeleteAll(0, "HR_")
# 5. Enhance OnTimer to call VerifyAllLinked() every 2 seconds, check 00:05 daily restart, and handle auto-recovery if errorCount > 10
# 6. Enhance OnTick with fast-path price and percentage update

# Let's inspect ComputeInstrumentAnalytics in suffix
pos_compute = suffix.find("static void ComputeInstrumentAnalytics(")
pos_compute_end = suffix.find("//| Section 2: Input Parameters")

print("ComputeInstrumentAnalytics length:", pos_compute_end - pos_compute)
