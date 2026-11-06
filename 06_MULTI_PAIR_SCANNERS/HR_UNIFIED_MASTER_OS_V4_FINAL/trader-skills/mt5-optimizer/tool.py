import sys

def optimize_params():
    return {
        "ema_fast": [9],
        "ema_mid": [21],
        "ema_slow": [200],
        "atr_period": 14,
        "recommended_risk": 0.01
    }

if __name__ == "__main__":
    print(optimize_params())
