# run_mt5_test.py
import sys
import os
import shutil
import subprocess
import time

MT5_PATH = r"C:\Program Files\MetaTrader 5\terminal64.exe"
DATA_DIR = r"C:\Users\vaibh\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075"
REPORTS_DIR = os.path.join(DATA_DIR, "reports")

def run_test(expert_name, symbol, from_date, to_date, dest_report_path, inputs_dict=None):
    """
    expert_name: e.g. "100_EMA_EA.ex5"
    symbol: e.g. "USTEC"
    from_date: e.g. "2021.01.01"
    to_date: e.g. "2023.12.31"
    dest_report_path: absolute path where the final HTML report should be saved
    inputs_dict: optional dict of inputs e.g. {"InpUseWickBounce": "true"}
    """
    config_file = os.path.join(DATA_DIR, "tester_stageb_temp.ini")
    
    # MT5 saves relative Report paths under %APPDATA%\MetaQuotes\Terminal\<ID>\reports\<rel_name>
    filename = os.path.basename(dest_report_path)
    rel_report_name = f"reports\\{filename}"
    appdata_report_path = os.path.join(REPORTS_DIR, filename)

    if os.path.exists(appdata_report_path):
        os.remove(appdata_report_path)
    if os.path.exists(dest_report_path):
        os.remove(dest_report_path)

    ini_content = f"""[Common]
Login=279423140
Server=Exness-MT5Trial8

[Tester]
Expert={expert_name}
Symbol={symbol}
Period=M5
Optimization=0
Model=1
FromDate={from_date}
ToDate={to_date}
ForwardMode=0
Deposit=10000
Currency=USD
Leverage=100
ExecutionMode=196
Visual=0
ShutdownTerminal=1
Report={rel_report_name}
ReplaceReport=1

[TesterInputs]
"""
    if inputs_dict:
        for k, v in inputs_dict.items():
            ini_content += f"{k}={v}\n"

    with open(config_file, "w", encoding="utf-8") as f:
        f.write(ini_content)

    print(f"[*] Starting MT5 Backtest: {expert_name} | {symbol} | {from_date} - {to_date}")
    cmd = [MT5_PATH, f"/config:{config_file}"]
    
    start_time = time.time()
    proc = subprocess.Popen(cmd)
    proc.wait()
    elapsed = time.time() - start_time
    print(f"[*] MT5 process exited in {elapsed:.1f}s. Checking report...")

    # Wait briefly for file write
    for _ in range(5):
        if os.path.exists(appdata_report_path):
            break
        time.sleep(1.0)

    if os.path.exists(appdata_report_path):
        os.makedirs(os.path.dirname(dest_report_path), exist_ok=True)
        shutil.copy2(appdata_report_path, dest_report_path)
        print(f"[+] Report generated and copied to: {dest_report_path}")
        return True
    else:
        print(f"[-] Report generation failed: {appdata_report_path}")
        return False

if __name__ == "__main__":
    pass
