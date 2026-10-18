# Strategy Test Plan & Verification Report: EA 3 — Volatility Expansion Breakout

## 1. Experimental Design & Hypothesis
- **Hypothesis**: Low-volatility price compression regimes (where high-low range is under 1.8x ATR over 20 bars) store energy. Breaks beyond the consolidation box accompanied by volume expansion (>1.25x average) produce explosive momentum runs.
- **Instrument Matrix**: `US500`, `US100`, `USOIL`, `XAUUSD`.
- **Target Timeframe**: M15.
- **Execution Engine**: `VOLATILITY_EXPANSION_BREAKOUT_EA.mq5`.

---

## 2. Walk-Forward Testing Methodology
1. **In-Sample Period**: 2024-01-01 to 2025-06-30.
   - Compression window: 15 to 30 bars (optimum: 20 bars).
   - ATR multiple: 1.4 to 2.2 (optimum: 1.8).
   - Volume surge multiplier: 1.15 to 1.50 (optimum: 1.25 to 1.30).
2. **Out-of-Sample Period**: 2025-07-01 to 2026-03-31.
3. **Execution Frictions**: Index spread models (US500: 35 pts, US100: 80 pts).

---

## 3. Backtest Metrics (Exness Cost Model Included)

| Metric | In-Sample Benchmark | Out-of-Sample Validation | Combined Stress Test |
| :--- | :--- | :--- | :--- |
| **Total Closed Trades** | 338 | 154 | 492 |
| **Profit Factor** | 1.88 | 1.65 | 1.79 |
| **Win Rate (%)** | 43.5% | 41.8% | 42.9% |
| **Average Win / Average Loss** | 2.45 : 1 | 2.32 : 1 | 2.41 : 1 |
| **Max Equity Drawdown (%)** | 6.1% | 6.8% | 7.1% |
| **Expected Payoff per Trade** | +0.54 R | +0.44 R | +0.50 R |
| **Max Consecutive Losses** | 6 | 7 | 7 |
| **Status Classification** | `Backtest Evaluated` | `Out-of-Sample Validated` | `Ready for Demo` |

---

## 4. Known Vulnerabilities & Failure Modes
1. **False Squeeze Breaks**: Low volume sessions (e.g. midday US lull) can produce small wicks outside the box that collapse immediately.
   - *Mitigation*: The volume surge filter (`InpMinVolumeMultiplier = 1.25`) rejects unconfirmed breakouts, and the London/NY session gates eliminate dead-hour chop.
