import os

repo_dir = r"C:\Users\vaibh\.gemini\antigravity-ide\scratch\HemanthRanam-MT5-EAs"
v4_dir = os.path.join(repo_dir, "06_MULTI_PAIR_SCANNERS", "HR_UNIFIED_MASTER_OS_V4_FINAL")
src_file = os.path.join(repo_dir, "00_UNIFIED_SYSTEM", "HR_UNIFIED_MULTI_STRATEGY_EA.mq5")

with open(src_file, "r", encoding="utf-8") as f:
    text = f.read()

# Let's inspect where CBloombergTerminal starts and ends
start_term = text.find("class CBloombergTerminal")
end_term = text.find("class CQuantAnalyticsEngine")

# Everything before CBloombergTerminal
prefix = text[:start_term]
# Everything after CBloombergTerminal
suffix = text[end_term:]

print("Prefix length:", len(prefix), "Suffix length:", len(suffix))
