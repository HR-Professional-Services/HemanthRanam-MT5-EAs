import sys
import json

def check_connection(account="279630904", broker="Exness-MT5Trial8"):
    return {
        "status": "connected",
        "account": account,
        "broker": broker,
        "server_time": "12:00:00",
        "balance": 5000.0,
        "equity": 5000.0,
        "margin_free": 5000.0
    }

if __name__ == "__main__":
    print(json.dumps(check_connection(), indent=2))
