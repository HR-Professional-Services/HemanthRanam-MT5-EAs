with open(r"C:\Users\vaibh\.gemini\antigravity-ide\scratch\HemanthRanam-MT5-EAs\06_MULTI_PAIR_SCANNERS\HR_UNIFIED_MASTER_OS_V4_FINAL\HR_Dashboard_Premium.mqh", "r", encoding="utf-8") as f:
    lines = f.readlines()

print("Total lines:", len(lines))
for idx, line in enumerate(lines):
    if "DrawTrajectoryArea(v3_x + 10" in line:
        print("DrawTrajectoryArea call at line:", idx+1)
    if "int row2Y = headY + 36;" in line:
        print("row2Y at line:", idx+1)
    if "int cardH  = (availH - gridGap) / 2;" in line:
        print("cardH at line:", idx+1)
