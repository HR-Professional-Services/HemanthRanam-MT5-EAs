import sys

def detect_smc(symbol="XAUUSD", high=4096.10, low=4056.30, price=4063.35):
    range_span = high - low
    discount_level = low + (range_span * 0.5)
    return {
        "symbol": symbol,
        "bsl": high,
        "ssl": low,
        "current_price": price,
        "zone": "DISCOUNT Buy" if price < discount_level else "PREMIUM Sell",
        "choch": "LH Lower High Detected"
    }

if __name__ == "__main__":
    print(detect_smc())
