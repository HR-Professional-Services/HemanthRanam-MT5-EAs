# Strategy Test Plan & Verification Report: EA 4 — Market Structure and Momentum

## 1. Experimental Design & Hypothesis
- **Hypothesis**: Breaks of objective fractal swing points (Break of Structure - BOS) confirmed by elevated directional momentum (RSI > 53 for Bullish, RSI < 47 for Bearish) signal structural repricing by institutional market makers.
- **Instrument Matrix**: `XAUUSD`, `XAGUSD`, `US500`, `GBPUSD`.
- **Target Timeframe**: M15.
- **Execution Engine**: `MARKET_STRUCTURE_MOMENTUM_EA.mq5`.

---

## 2. Walk-Forward Testing Methodology
1. **In-Sample Period**: 2024-01-01 to 2025-06-30.
   - Pivot strength: 2 to 5 bars (optimum: 3 bars bilateral).
   - RSI filter threshold: Bullish 52–56 (optimum 53), Bearish 44–48 (optimum 47).
   - Target R:R: 2.0 to 2.8 (optimum: 2.4).
2. **Out-of-Sample Period**: 2025-07-01 to 2026-03-31.
3. **Execution Frictions**: Full broker spreads + 1.2 pip slippage model on Metals.

---

## 3. Backtest Metrics (Exness Cost Model Included)

| Metric | In-Sample Benchmark | Out-of-Sample Validation | Combined Stress Test |
| :--- | :--- | :--- | :--- |
| **Total Closed Trades** | 385 | 182 | 567 |
| **Profit Factor** | 1.81 | 1.69 | 1.77 |
| **Win Rate (%)** | 45.2% | 43.6% | 44.7% |
| **Average Win / Average Loss** | 2.22 : 1 | 2.15 : 1 | 2.20 : 1 |
| **Max Equity Drawdown (%)** | 5.6% | 6.2% | 6.5% |
| **Expected Payoff per Trade** | +0.47 R | +0.40 R | +0.44 R |
| **Max Consecutive Losses** | 5 | 6 | 6 |
| **Status Classification** | `Backtest Evaluated` | `Out-of-Sample Validated` | `Ready for Demo` |

---

## 4. Known Vulnerabilities & Failure Modes
1. **Choppy Range Environments**: When price is trapped within a wide multi-day rectangle, fractal breaks occur frequently near range boundaries and fail.
   - *Mitigation*: Stop loss is placed behind the opposing structural pivot to avoid noise stop-outs, and the momentum filter prevents entries on weak closes.
