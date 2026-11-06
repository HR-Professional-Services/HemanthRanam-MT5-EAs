import sys

def evaluate_risk(account_equity=5000.0, risk_pct=1.0, stop_pips=25.0, open_positions=0):
    risk_amount = account_equity * (risk_pct / 100.0)
    max_positions = 4
    can_trade = open_positions < max_positions
    return {
        "account_equity": account_equity,
        "risk_dollars": risk_amount,
        "max_risk_pct": risk_pct,
        "open_positions": f"{open_positions}/{max_positions}",
        "risk_status": "APPROVED" if can_trade else "REJECTED_MAX_EXPOSURE"
    }

if __name__ == "__main__":
    print(evaluate_risk())
