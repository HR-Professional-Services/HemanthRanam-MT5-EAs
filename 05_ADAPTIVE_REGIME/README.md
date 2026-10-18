# EA 5 — Adaptive Market-Regime Strategy (`ADAPTIVE_MARKET_REGIME_EA.mq5`)

## 1. Trading Hypothesis
Financial markets operate across non-stationary regimes: trending states, mean-reverting ranges, compression squeezes, and chaotic high-risk shocks. Static single-hypothesis strategies predictably suffer protracted drawdowns when market conditions violate their underlying assumptions (e.g. trend followers whipsawed in tight ranges; range faders liquidated during breakout trends). This system deploys an objective mathematical classifier to isolate the active regime and routes execution exclusively to statistically suitable sub-modules while enforcing complete capital protection during ambiguous or high-risk states.

## 2. Objective Regime Classifier
Driven by `Include/RegimeClassifier.mqh`:
1. **Strong Bullish Trend (`REGIME_TREND_BULL`)**: ADX > 25, Fast 9 EMA > Slow 21 EMA > Baseline 200 EMA.
2. **Strong Bearish Trend (`REGIME_TREND_BEAR`)**: ADX > 25, Fast 9 EMA < Slow 21 EMA < Baseline 200 EMA.
3. **Ranging Consolidation (`REGIME_RANGING`)**: ADX < 20 with non-expanding ATR.
4. **Volatility Squeeze (`REGIME_VOLATILITY_COMPRESS`)**: ATR < 0.65x 10-period moving average.
5. **High-Risk Unstable (`REGIME_UNSTABLE_HIGH_RISK`)**: ATR > 2.5x average or excessive spread expansion. **System strictly stands aside (Zero Trade Mode)**.

## 3. Sub-Module Execution
- **Trend Continuation Module**:
  - Activates when Bullish or Bearish Trend regime is verified.
  - Enters on controlled pullbacks into the 9 EMA corridor with rejection candle confirmation.
- **Range Reversion Module**:
  - Activates when Ranging Consolidation is verified.
  - Fades Bollinger Band (20, 2.0) outer extremes only when confirmed by oversold/overbought RSI(14) boundary conditions.
- **Capital Preservation Mode**:
  - Automatically suspends trading during ambiguous, transition, or high-risk volatility conditions.

## 4. Exit & Risk Management
- **Protective Stop Loss**: Fixed below/above trigger bar extremes or Bollinger envelopes.
- **Take Profit Target**: Enforces a minimum **1:2.2 Reward-to-Risk ratio** (`InpRewardToRiskRatio = 2.2`).
- **Break-Even Protection**: Activates automatically at **+1.0R** floating profit.
- **Position Sizing**: Dynamically calibrated to **0.5% equity risk** per trade.

## 5. Multi-Symbol Scanning
Monitors all 8 core instruments from a single chart attachment:
`XAUUSD, XAGUSD, US500, US100, USOIL, EURUSD, GBPUSD, USDJPY`.

## 6. Verification Status
- **Classification**: `Backtest Evaluated` / `Ready for Exness Demo Verification`
- **Recommended Timeframe**: M15
- **Best Suited Market Conditions**: All market cycles (automatically adapts or stands aside).
