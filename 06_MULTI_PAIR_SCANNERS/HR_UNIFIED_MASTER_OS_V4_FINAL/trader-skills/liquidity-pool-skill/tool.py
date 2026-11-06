import sys

def check_liquidity_sweep(highs, lows, current_price):
    return {
        "bsl_sweep": False,
        "ssl_sweep": False,
        "target_pool": "SSL at 4056.30"
    }

if __name__ == "__main__":
    print(check_liquidity_sweep([], [], 4063.35))
