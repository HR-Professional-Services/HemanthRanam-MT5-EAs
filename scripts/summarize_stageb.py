# summarize_stageb.py
import os
import glob
from parse_mt5_report import parse_report

REPORTS_DIR = r"C:\Users\vaibh\.gemini\antigravity-ide\scratch\HemanthRanam-MT5-EAs\reports\phase10_stageb"

reports = sorted(glob.glob(os.path.join(REPORTS_DIR, "*.htm")))

print(f"Found {len(reports)} reports.\n")
print(f"{'Report Name':<55} | {'Trades':<7} | {'WinRate':<7} | {'NetProfit ($)':<14} | {'PF':<6} | {'MaxDD (%)':<9}")
print("-" * 105)

for r in reports:
    name = os.path.basename(r).replace(".htm", "")
    m = parse_report(r)
    trades = m.get("Total Trades", ("N/A",))[0]
    wr = m.get("Profit Trades", ("N/A", "N/A"))[1] if len(m.get("Profit Trades", ())) > 1 else "N/A"
    profit = m.get("Total Net Profit", ("N/A",))[0].strip()
    pf = m.get("Profit Factor", ("N/A",))[0].strip()
    dd = m.get("Equity DD Maximal", ("N/A", "N/A"))[1] if len(m.get("Equity DD Maximal", ())) > 1 else "N/A"
    print(f"{name:<55} | {trades:<7} | {wr:<7} | {profit:<14} | {pf:<6} | {dd:<9}")
