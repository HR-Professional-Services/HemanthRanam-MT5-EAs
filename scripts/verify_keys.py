import os
import re

repo_dir = r"C:\Users\vaibh\.gemini\antigravity-ide\scratch\HemanthRanam-MT5-EAs"
src_file = os.path.join(repo_dir, "00_UNIFIED_SYSTEM", "HR_UNIFIED_MULTI_STRATEGY_EA.mq5")

with open(src_file, "r", encoding="utf-8") as f:
    text = f.read()

# Verify that all key parts exist
keys = [
    "class CBloombergTerminal",
    "class CQuantAnalyticsEngine",
    "void InitInstruments()",
    "void ReleaseInstrumentHandles()",
    "void RenderDashboard()",
    "int OnInit()",
    "void OnDeinit(",
    "void OnTimer()",
    "void OnTick()"
]

for k in keys:
    p = text.find(k)
    print(f"Key '{k}' found: {p >= 0} at {p}")
