import sys

def format_alert(symbol="XAUUSD", signal="SELL READY 85%", price=4063.35, h1="BELOW 200", m5="BEARISH"):
    return f"Alert 🚨 {symbol} {signal} @ {price:.2f} | H1 {h1} | M5 {m5}"

if __name__ == "__main__":
    print(format_alert())
