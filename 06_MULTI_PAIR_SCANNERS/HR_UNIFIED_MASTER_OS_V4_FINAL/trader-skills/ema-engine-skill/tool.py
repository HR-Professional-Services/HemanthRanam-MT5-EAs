import sys

def analyze_ema(ema9=4060.0, ema21=4065.0, ema200_m5=4075.0, ema200_h1=4080.0, current_price=4063.35):
    m5_aligned_bear = ema9 < ema21 < ema200_m5
    h1_below_200 = current_price < ema200_h1
    sep_pct = abs(ema9 - ema21) / ema21 * 100
    return {
        "m5_state": "BEARISH" if m5_aligned_bear else "BULLISH",
        "h1_filter": "SHORT ONLY" if h1_below_200 else "LONG ONLY",
        "separation_pct": f"{sep_pct:.2f}%",
        "health_score": 100.0,
        "signal": "SELL READY 85%" if (m5_aligned_bear and h1_below_200) else "WAIT 40%"
    }

if __name__ == "__main__":
    print(analyze_ema())
