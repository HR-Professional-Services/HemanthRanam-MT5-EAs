import sys
import json

def parse_webhook(payload):
    data = json.loads(payload) if isinstance(payload, str) else payload
    return {
        "action": data.get("action", "BUY"),
        "symbol": data.get("symbol", "XAUUSD"),
        "lot": data.get("lot", 0.31),
        "sl": data.get("sl"),
        "tp": data.get("tp")
    }

if __name__ == "__main__":
    sample = {"action": "BUY", "symbol": "XAUUSD", "lot": 0.31, "sl": 4056.3, "tp": 4075.0}
    print(parse_webhook(sample))
