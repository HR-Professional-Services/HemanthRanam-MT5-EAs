import os

repo_dir = r"C:\Users\vaibh\.gemini\antigravity-ide\scratch\HemanthRanam-MT5-EAs"
src_file = os.path.join(repo_dir, "00_UNIFIED_SYSTEM", "HR_UNIFIED_MULTI_STRATEGY_EA.mq5")

with open(src_file, "r", encoding="utf-8") as f:
    text = f.read()

# Let's inspect lines 540 to 575
lines = text.split("\n")
for i in range(538, 575):
    if i < len(lines):
        print(f"{i+1}: {lines[i]}")
