import sys

def calculate_lot(equity=5000.0, risk_dollars=50.0, sl_dist=20.0, symbol="XAUUSD"):
    # XAUUSD 1 lot = 100 oz ($10 per pt)
    lot = risk_dollars / (sl_dist * 10.0)
    capped_lot = min(round(lot, 2), 0.31)
    return {
        "symbol": symbol,
        "recommended_lot": capped_lot,
        "equity": equity,
        "cash_buffer_percent": 10.0,
        "cap_percent": 25.0
    }

if __name__ == "__main__":
    print(calculate_lot())
