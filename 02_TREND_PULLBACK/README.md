# EA 2 — Trend Pullback and Continuation (`TREND_PULLBACK_CONTINUATION_EA.mq5`)

## 1. Trading Hypothesis
Attempting to chase extended breakout moves frequently results in buying the top or selling the bottom. In sustained directional markets, institutional participants execute orders on shallow pullbacks to dynamic value areas. This strategy filters for unambiguous structural trends (200 EMA baseline with aligned 9/21 EMAs) and enters strictly when price retests the 9/21 corridor and displays directional resumption momentum.

## 2. Entry Conditions
- **Bullish Trend Setup**:
  1. **Macro Trend Filter**: Price is above the 200 EMA (`InpMacroEMA = 200`).
  2. **Tactical Alignment**: 9 EMA > 21 EMA > 200 EMA.
  3. **Corridor Retracement**: The preceding candle's low retests or pierces into the 9/21 EMA value corridor.
  4. **Resumption Confirmation**: Trigger candle closes green (bullish) and firmly closes above the 9 EMA.
- **Bearish Trend Setup**:
  1. **Macro Trend Filter**: Price is below the 200 EMA.
  2. **Tactical Alignment**: 9 EMA < 21 EMA < 200 EMA.
  3. **Corridor Retracement**: Preceding candle retests or pierces into the 9/21 EMA corridor from below.
  4. **Resumption Confirmation**: Trigger candle closes red (bearish) and firmly closes below the 9 EMA.

## 3. Exit & Risk Management
- **Protective Stop Loss**: Set at the recent swing pullback low/high or the 21 EMA + 5 points buffer.
- **Take Profit Target**: Enforces a minimum **1:2.2 Reward-to-Risk ratio** (`InpRewardToRiskRatio = 2.2`).
- **Break-Even Protection**: Activates automatically at **+1.0R** floating profit.
- **Position Sizing**: Dynamically calibrated to **0.5% equity risk** per trade.

## 4. Multi-Symbol Scanning
Monitors the global multi-asset watchlist from a single chart:
`XAUUSD, XAGUSD, US500, US100, USOIL, EURUSD, GBPUSD, USDJPY`.

## 5. Verification Status
- **Classification**: `Backtest Evaluated` / `Ready for Exness Demo Verification`
- **Recommended Timeframe**: M15
- **Best Suited Market Conditions**: Clear trending regimes during London and New York sessions.
