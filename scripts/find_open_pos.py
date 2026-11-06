with open(r"C:\Users\vaibh\.gemini\antigravity-ide\scratch\HemanthRanam-MT5-EAs\06_MULTI_PAIR_SCANNERS\HR_UNIFIED_MASTER_OS_V4_FINAL\HR_Dashboard_Premium.mqh", "r", encoding="utf-8") as f:
    lines = f.readlines()

for i, l in enumerate(lines):
    if "openPos, maxPos" in l:
        print(f"openPos around {i+1}:")
        for k in range(max(0, i-4), min(len(lines), i+6)):
            print(f"{k+1}: {repr(lines[k])}")
