import sys

def evaluate_challenge(daily_dd=0.0, max_dd=0.0, firm="FTMO"):
    max_daily_allowed = 3.0
    max_total_allowed = 5.0
    return {
        "firm": firm,
        "daily_dd_pct": f"{daily_dd:.2f}%",
        "max_dd_pct": f"{max_dd:.2f}%",
        "safe_to_trade": daily_dd < max_daily_allowed and max_dd < max_total_allowed
    }

if __name__ == "__main__":
    print(evaluate_challenge())
