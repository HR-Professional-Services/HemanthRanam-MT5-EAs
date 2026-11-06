file_path = r"C:\Users\vaibh\.gemini\antigravity-ide\scratch\HemanthRanam-MT5-EAs\06_MULTI_PAIR_SCANNERS\HR_UNIFIED_MASTER_OS_V4_FINAL\HR_Dashboard_Premium.mqh"

with open(file_path, "r", encoding="utf-8") as f:
    text = f.read()

# Collapse multiple consecutive newlines down to single newline
import re
cleaned = re.sub(r'\n{3,}', '\n\n', text)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(cleaned)

print("Original length:", len(text), "Cleaned length:", len(cleaned))
