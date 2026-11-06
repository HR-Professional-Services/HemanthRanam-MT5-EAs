import os
import re

repo_dir = r"C:\Users\vaibh\.gemini\antigravity-ide\scratch\HemanthRanam-MT5-EAs"
src_file = os.path.join(repo_dir, "00_UNIFIED_SYSTEM", "HR_UNIFIED_MULTI_STRATEGY_EA.mq5")

with open(src_file, "r", encoding="utf-8") as f:
    code = f.read()

print("Original code length:", len(code))
