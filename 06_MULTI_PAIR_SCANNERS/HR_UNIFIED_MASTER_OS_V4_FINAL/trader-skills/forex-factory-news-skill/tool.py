import sys
import datetime

def check_calendar():
    return {
        "events": [
            {"currency": "GBP", "event": "BoE Rate Decision", "impact": "HIGH", "time": "12:00", "block_trading": True},
            {"currency": "USD", "event": "Non-Farm Payrolls (NFP)", "impact": "HIGH", "time": "Tomorrow 13:30", "block_trading": False}
        ],
        "circuit_breaker": "ACTIVE_FOR_GBP"
    }

if __name__ == "__main__":
    print(check_calendar())
