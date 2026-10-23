# parse_mt5_report.py
import sys
import os
import re

def parse_report(report_path):
    if not os.path.exists(report_path):
        print(f"[ERROR] Report file not found: {report_path}")
        return None

    # MT5 Strategy Tester reports are saved in UTF-16 LE
    content = ""
    for enc in ["utf-16", "utf-16-le", "utf-8", "cp1252"]:
        try:
            with open(report_path, "r", encoding=enc) as f:
                content = f.read()
            if "Strategy Tester Report" in content:
                break
        except Exception:
            continue

    if not content:
        print(f"[ERROR] Could not decode file: {report_path}")
        return None

    # Strip HTML tags
    clean_text = re.sub(r"<[^>]+>", " ", content)
    clean_text = re.sub(r"&nbsp;", " ", clean_text)
    clean_text = re.sub(r"\s+", " ", clean_text)

    metrics = {}
    patterns = {
        "History Quality": r"History Quality\s*([0-9]+%)",
        "Total Net Profit": r"Total Net Profit:\s*(-?[0-9\s\.,]+)",
        "Gross Profit": r"Gross Profit:\s*([0-9\s\.,]+)",
        "Gross Loss": r"Gross Loss:\s*(-?[0-9\s\.,]+)",
        "Profit Factor": r"Profit Factor:\s*([0-9\.]+)",
        "Expected Payoff": r"Expected Payoff:\s*(-?[0-9\s\.,]+)",
        "Equity DD Maximal": r"Equity Drawdown Maximal:\s*([0-9\s\.,]+)\s*\(([0-9\.]+%)\)",
        "Total Trades": r"Total Trades:\s*([0-9]+)",
        "Short Trades": r"Short Trades \(won %\):\s*([0-9]+)\s*\(([0-9\.]+%)\)",
        "Long Trades": r"Long Trades \(won %\):\s*([0-9]+)\s*\(([0-9\.]+%)\)",
        "Profit Trades": r"Profit Trades \(% of total\):\s*([0-9]+)\s*\(([0-9\.]+%)\)",
        "Loss Trades": r"Loss Trades \(% of total\):\s*([0-9]+)\s*\(([0-9\.]+%)\)",
    }

    for key, pat in patterns.items():
        m = re.search(pat, clean_text)
        if m:
            metrics[key] = m.groups()
        else:
            metrics[key] = "N/A"

    print(f"=== Report: {os.path.basename(report_path)} ===")
    for k, v in metrics.items():
        print(f"  {k}: {v}")
    return metrics

if __name__ == "__main__":
    if len(sys.argv) > 1:
        parse_report(sys.argv[1])
    else:
        print("Usage: python parse_mt5_report.py <path_to_htm>")
