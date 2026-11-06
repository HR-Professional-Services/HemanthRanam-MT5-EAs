import os
import re

repo_dir = r"C:\Users\vaibh\.gemini\antigravity-ide\scratch\HemanthRanam-MT5-EAs"
v4_dir = os.path.join(repo_dir, "06_MULTI_PAIR_SCANNERS", "HR_UNIFIED_MASTER_OS_V4_FINAL")
src_file = os.path.join(repo_dir, "00_UNIFIED_SYSTEM", "HR_UNIFIED_MULTI_STRATEGY_EA.mq5")

with open(src_file, "r", encoding="utf-8") as f:
    text = f.read()

start_term = text.find("class CBloombergTerminal")
end_term = text.find("class CQuantAnalyticsEngine")

prefix = text[:start_term]
suffix = text[end_term:]

# In prefix:
# Replace top header comment
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

# Find where #include <Trade\Trade.mqh> starts in prefix
trade_inc = prefix.find("#include <Trade\\Trade.mqh>")
prefix_before_trade = prefix[:trade_inc]
prefix_after_trade = prefix[trade_inc:]

# Remove duplicate definitions of SessionIntelligence and InstrumentQuantAnalytics because they are now in HR_Utils.mqh
struct_sess_pos = prefix_after_trade.find("struct SessionIntelligence")
# find where class CBloombergTerminal was right after
# Everything between struct SessionIntelligence and the end of prefix can be replaced or cleared
prefix_clean = header_comment + prefix_after_trade[prefix_after_trade.find("#define NUM_INSTRUMENTS 4"):struct_sess_pos]

# Now let's work on suffix
# In CQuantAnalyticsEngine::ComputeInstrumentAnalytics:
# We can enhance it to call CHR_EMA_Engine, CHR_ICT_SMC, CHR_Indicators, CHR_Macro!
# Let's inspect ComputeInstrumentAnalytics in suffix
print("Prefix clean length:", len(prefix_clean))
