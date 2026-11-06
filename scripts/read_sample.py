with open(r"C:\Users\vaibh\.gemini\antigravity-ide\scratch\HemanthRanam-MT5-EAs\06_MULTI_PAIR_SCANNERS\HR_UNIFIED_MASTER_OS_V4_FINAL\HR_Dashboard_Premium.mqh", "r", encoding="utf-8") as f:
    lines = [f.readline() for _ in range(20)]

for i, l in enumerate(lines):
    print(f"{i+1}: {repr(l)}")
