# clean_summary.py
import os
import glob
import re

REPORTS_DIR = r"C:\Users\vaibh\.gemini\antigravity-ide\scratch\HemanthRanam-MT5-EAs\reports\phase10_stageb"

def parse_rep(path):
    with open(path, "r", encoding="utf-16", errors="ignore") as f:
        text = f.read()
    text = re.sub(r"<[^>]+>", " ", text)
    text = re.sub(r"&nbsp;", " ", text)
    text = re.sub(r"\s+", " ", text)

    def get_val(pattern):
        m = re.search(pattern, text)
        return m.group(1).strip() if m else "N/A"

    def get_val2(pattern):
        m = re.search(pattern, text)
        return (m.group(1).strip(), m.group(2).strip()) if m else ("N/A", "N/A")

    trades = get_val(r"Total Trades:\s*([0-9]+)")
    wr = get_val2(r"Profit Trades \(% of total\):\s*([0-9]+)\s*\(([0-9\.]+%)\)")[1]
    net = get_val(r"Total Net Profit:\s*(-?[0-9\s\.,]+)")
    pf = get_val(r"Profit Factor:\s*([0-9\.]+)")
    dd = get_val2(r"Equity Drawdown Maximal:\s*([0-9\s\.,]+)\s*\(([0-9\.]+%)\)")[1]
    payoff = get_val(r"Expected Payoff:\s*(-?[0-9\s\.,]+)")

    return trades, wr, net, pf, dd, payoff

reports = sorted(glob.glob(os.path.join(REPORTS_DIR, "*.htm")))
for r in reports:
    name = os.path.basename(r).replace(".htm", "")
    t, wr, net, pf, dd, p = parse_rep(r)
    print(f"{name}|{t}|{wr}|{net}|{pf}|{dd}|{p}")
