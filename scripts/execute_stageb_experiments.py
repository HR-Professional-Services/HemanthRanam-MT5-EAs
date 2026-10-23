# execute_stageb_experiments.py
import os
import sys
import time
import json
from run_mt5_test import run_test
from parse_mt5_report import parse_report

BASE_DIR = r"C:\Users\vaibh\.gemini\antigravity-ide\scratch\HemanthRanam-MT5-EAs"
REPORTS_DIR = os.path.join(BASE_DIR, "reports", "phase10_stageb")

DISCOVERY_FROM = "2021.01.01"
DISCOVERY_TO   = "2023.12.31"
VALIDATION_FROM = "2024.01.01"
VALIDATION_TO   = "2024.12.31"
OBSERVED_FROM   = "2025.01.01"
OBSERVED_TO     = "2026.10.21"

def format_metric(val):
    if isinstance(val, tuple):
        return " / ".join(val)
    return str(val)

def run_experiment_pair(exp_id, ea_name, symbol, base_inputs, cand_inputs, run_observed=False):
    """
    Runs baseline vs candidate across Discovery (2021-2023) and Validation (2024).
    Optionally runs Observed (2025-2026).
    """
    periods = [
        ("Discovery_2021_2023", DISCOVERY_FROM, DISCOVERY_TO),
        ("Validation_2024", VALIDATION_FROM, VALIDATION_TO),
    ]
    if run_observed:
        periods.append(("Observed_2025_2026", OBSERVED_FROM, OBSERVED_TO))

    results = {"baseline": {}, "candidate": {}}

    for period_name, f_date, t_date in periods:
        # 1. Run Baseline
        base_rep_name = f"{exp_id}_{ea_name.replace('.ex5','')}_{symbol}_{period_name}_Baseline.htm"
        base_rep_path = os.path.join(REPORTS_DIR, base_rep_name)
        print(f"\n==========================================")
        print(f"RUNNING BASELINE: {base_rep_name}")
        print(f"==========================================")
        run_test(ea_name, symbol, f_date, t_date, base_rep_path, base_inputs)
        m_base = parse_report(base_rep_path)
        results["baseline"][period_name] = m_base

        # 2. Run Candidate
        cand_rep_name = f"{exp_id}_{ea_name.replace('.ex5','')}_{symbol}_{period_name}_Candidate.htm"
        cand_rep_path = os.path.join(REPORTS_DIR, cand_rep_name)
        print(f"\n==========================================")
        print(f"RUNNING CANDIDATE: {cand_rep_name}")
        print(f"==========================================")
        run_test(ea_name, symbol, f_date, t_date, cand_rep_path, cand_inputs)
        m_cand = parse_report(cand_rep_path)
        results["candidate"][period_name] = m_cand

    return results

if __name__ == "__main__":
    target_exp = sys.argv[1] if len(sys.argv) > 1 else "B1"
    
    if target_exp == "B1":
        print("[*] Starting Experiment B1: Pullback Wick-Bounce Filter")
        # Target 100 EMA on USTEC
        b1_100_ustec = run_experiment_pair(
            "ExpB1", "100_EMA_EA.ex5", "USTEC",
            {"InpUseWickBounce": "false"},
            {"InpUseWickBounce": "true"},
            run_observed=True
        )
        with open(os.path.join(REPORTS_DIR, "ExpB1_100_EMA_USTEC_results.json"), "w") as f:
            json.dump(b1_100_ustec, f, indent=2)

        # Target 21 EMA on US500
        b1_21_us500 = run_experiment_pair(
            "ExpB1", "21_EMA_EA.ex5", "US500",
            {"InpUseWickBounce": "false"},
            {"InpUseWickBounce": "true"},
            run_observed=True
        )
        with open(os.path.join(REPORTS_DIR, "ExpB1_21_EMA_US500_results.json"), "w") as f:
            json.dump(b1_21_us500, f, indent=2)

    elif target_exp == "B2":
        print("[*] Starting Experiment B2: ATR-Proportional Break-Even")
        # Target 9 EMA on XAGUSD
        b2_9_xagusd = run_experiment_pair(
            "ExpB2", "9_EMA_EA.ex5", "XAGUSD",
            {"InpUseBE": "true", "InpBEPoints": "120", "InpUseATR_BE": "false"},
            {"InpUseBE": "true", "InpBEPoints": "120", "InpUseATR_BE": "true", "InpBEATRMultiplier": "1.5"},
            run_observed=True
        )
        with open(os.path.join(REPORTS_DIR, "ExpB2_9_EMA_XAGUSD_results.json"), "w") as f:
            json.dump(b2_9_xagusd, f, indent=2)

        # Target 21 EMA on XAGUSD
        b2_21_xagusd = run_experiment_pair(
            "ExpB2", "21_EMA_EA.ex5", "XAGUSD",
            {"InpUseBE": "true", "InpBEPoints": "120", "InpUseATR_BE": "false"},
            {"InpUseBE": "true", "InpBEPoints": "120", "InpUseATR_BE": "true", "InpBEATRMultiplier": "1.5"},
            run_observed=True
        )
        with open(os.path.join(REPORTS_DIR, "ExpB2_21_EMA_XAGUSD_results.json"), "w") as f:
            json.dump(b2_21_xagusd, f, indent=2)

    elif target_exp == "B3":
        print("[*] Starting Experiment B3: USTEC HTF Slope Filter (100 EMA)")
        b3_100_ustec = run_experiment_pair(
            "ExpB3", "100_EMA_EA.ex5", "USTEC",
            {"InpUseHTFSlopeFilter": "false", "InpHTFMinSlopePoints": "0.0"},
            {"InpUseHTFSlopeFilter": "true", "InpHTFMinSlopePoints": "5.0"},
            run_observed=True
        )
        with open(os.path.join(REPORTS_DIR, "ExpB3_100_EMA_USTEC_results.json"), "w") as f:
            json.dump(b3_100_ustec, f, indent=2)

    elif target_exp == "B4":
        print("[*] Starting Experiment B4: US500 Take-Profit Multiple (100 EMA)")
        b4_100_us500 = run_experiment_pair(
            "ExpB4", "100_EMA_EA.ex5", "US500",
            {"InpTPRatio": "3"},
            {"InpTPRatio": "4"},
            run_observed=True
        )
        with open(os.path.join(REPORTS_DIR, "ExpB4_100_EMA_US500_results.json"), "w") as f:
            json.dump(b4_100_us500, f, indent=2)
