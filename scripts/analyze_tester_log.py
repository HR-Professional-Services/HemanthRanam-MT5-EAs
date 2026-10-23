# analyze_tester_log.py
import re
import sys

def parse_tester_log(log_path):
    try:
        with open(log_path, "r", encoding="utf-16-le", errors="ignore") as f:
            lines = f.readlines()
    except Exception:
        with open(log_path, "r", encoding="utf-8", errors="ignore") as f:
            lines = f.readlines()

    deals = []
    tests = []
    cur_test = {}

    for line in lines:
        if "automatic testing started" in line:
            if cur_test:
                tests.append(cur_test)
            cur_test = {"deals": [], "sl_rejects": 0}
        
        # Order / deal tracking
        if "deal #" in line and "done" in line:
            m = re.search(r"deal #(\d+) (buy|sell) ([\d\.]+) ([\w]+) at ([\d\.]+)", line)
            if m:
                cur_test.setdefault("deals", []).append(m.groups())

        if "SL_REJECT" in line:
            cur_test["sl_rejects"] = cur_test.get("sl_rejects", 0) + 1

        if "final balance" in line:
            m = re.search(r"final balance ([\d\.]+) USD", line)
            if m:
                cur_test["final_balance"] = float(m.group(1))

        if "bars generated" in line:
            m = re.search(r"([\w]+),M5: (\d+) ticks, (\d+) bars generated.*passed in ([\d:\.]+)", line)
            if m:
                cur_test["symbol"] = m.group(1)
                cur_test["ticks"] = int(m.group(2))
                cur_test["bars"] = int(m.group(3))
                cur_test["time"] = m.group(4)

    if cur_test:
        tests.append(cur_test)

    print(f"Total test runs parsed: {len(tests)}")
    for i, t in enumerate(tests):
        print(f"Run {i+1}: Symbol={t.get('symbol')} | Bars={t.get('bars')} | Final Balance=${t.get('final_balance', 0):.2f} | Net Profit=${t.get('final_balance', 10000)-10000:.2f} | Deals={len(t.get('deals', []))} | SL Rejects={t.get('sl_rejects', 0)}")

if __name__ == "__main__":
    parse_tester_log(r"C:\Users\vaibh\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\Tester\logs\20261023.log")
