import MetaTrader5 as mt5
import datetime

mt5.initialize()

symbols = ['USTEC', 'US500', 'XAUUSD', 'XAGUSD']
years = [2021, 2022, 2023, 2024, 2025, 2026]

print("Year | Symbol | M5 Bars Count")
print("------------------------------")
for y in years:
    t_start = datetime.datetime(y, 1, 1)
    t_end = datetime.datetime(y+1, 1, 1) if y < 2026 else datetime.datetime(2026, 10, 23)
    for s in symbols:
        rates = mt5.copy_rates_range(s, mt5.TIMEFRAME_M5, t_start, t_end)
        count = len(rates) if rates is not None else 0
        print(f"{y} | {s:6s} | {count}")

mt5.shutdown()
