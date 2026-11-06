import sys

def compute_ema(series, period):
    if len(series) < period:
        return []
    k = 2.0 / (period + 1)
    ema = [sum(series[:period]) / period]
    for price in series[period:]:
        ema.append(price * k + ema[-1] * (1 - k))
    return ema

if __name__ == "__main__":
    prices = [100.0 + i for i in range(50)]
    print(f"Calculated EMA-9 latest: {compute_ema(prices, 9)[-1]:.2f}")
