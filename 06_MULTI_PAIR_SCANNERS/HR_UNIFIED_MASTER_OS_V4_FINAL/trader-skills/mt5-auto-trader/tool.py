import sys

def execute_signal(symbol="XAUUSD", setup="A+ READY", approved=True):
    if not approved:
        return {"status": "BLOCKED", "reason": "Explicit approval required"}
    return {
        "status": "FILLED",
        "symbol": symbol,
        "setup": setup,
        "lot": 0.31,
        "order_type": "SELL"
    }

if __name__ == "__main__":
    print(execute_signal())
