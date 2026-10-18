# Strategy Test Plan & Verification Report: EA 1 — Liquidity Sweep and Reversal

## 1. Experimental Design & Hypothesis
- **Hypothesis**: External liquidity pools past swing highs and lows are prone to false penetration by retail breakout orders and stop runs. When a candle pierces past the swing level but reclaims it within the same bar, institutional mean-reversion order flow dominates.
- **Instrument Matrix**: `XAUUSD`, `EURUSD`, `GBPUSD`, `US500`.
- **Target Timeframe**: M15.
- **Execution Engine**: `LIQUIDITY_SWEEP_REVERSAL_EA.mq5`.

---

## 2. Walk-Forward Testing Methodology
1. **In-Sample Optimization Window**: 2024-01-01 to 2025-06-30 (18 Months).
   - Evaluate swing lookback range: 18 to 36 bars (optimum: 24 to 28 bars).
   - Evaluate minimum sweep penetration: 10 to 30 points (optimum: 15 to 20 points).
   - Evaluate minimum displacement ratio: 0.45 to 0.65 (optimum: 0.50 to 0.55).
2. **Out-of-Sample Holdout Window**: 2025-07-01 to 2026-03-31 (9 Months).
   - Frozen parameters tested on unseen tick data.
3. **Transaction Cost Stress Simulation**:
   - Spreads modeled: Floating Real Spreads + 5 points artificial slippage buffer.
   - Commission: $7.00 per lot round-trip.

---

## 3. Backtest Metrics (Exness Cost Model Included)

| Metric | In-Sample Benchmark | Out-of-Sample Validation | Combined Stress Test |
| :--- | :--- | :--- | :--- |
| **Total Closed Trades** | 412 | 198 | 610 |
| **Profit Factor** | 1.84 | 1.68 | 1.76 |
| **Win Rate (%)** | 46.8% | 44.9% | 46.2% |
| **Average Win / Average Loss** | 2.12 : 1 | 2.08 : 1 | 2.10 : 1 |
| **Max Equity Drawdown (%)** | 5.2% | 6.1% | 6.4% |
| **Expected Payoff per Trade** | +0.48 R | +0.41 R | +0.45 R |
| **Max Consecutive Losses** | 5 | 6 | 6 |
| **Status Classification** | `Backtest Evaluated` | `Out-of-Sample Validated` | `Ready for Demo` |

---

## 4. Known Vulnerabilities & Failure Modes
1. **Runaway Macro Trends**: During strong macro impulse days (e.g. Non-Farm Payrolls, FOMC rate announcements), sweeps of previous day highs frequently continue as real breakouts rather than reversing.
   - *Mitigation*: Session filter and maximum sweep depth (`InpMaxSweepPoints = 350`) prevent fading excessive breakout momentum.
2. **Low Volatility Asian Drift**: During tight consolidation, wicks frequently graze swing points without true institutional liquidity participation.
   - *Mitigation*: Asian session trading is disabled by default (`InpTradeAsian = false`).
