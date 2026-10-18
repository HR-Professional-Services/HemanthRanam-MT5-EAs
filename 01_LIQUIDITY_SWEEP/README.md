# EA 1 — Liquidity Sweep and Reversal (`LIQUIDITY_SWEEP_REVERSAL_EA.mq5`)

## 1. Trading Hypothesis
Institutional liquidity clusters immediately outside obvious retail swing highs and lows (buy-side and sell-side liquidity). Breakout traders enter on new highs/lows while resting stops accumulate beyond those extremes. This strategy exploits failed breakout attempts where price penetrates beyond a defined swing level, exhausts liquidity, and immediately reclaims back inside the range with confirmed displacement.

## 2. Entry Conditions
- **Bullish Sweep Setup**:
  1. Price tests a lookback swing low (`InpSwingLookbackBars`, default 24 bars).
  2. The bar's low penetrates below the swing low by at least `InpMinSweepPoints` (15 pts) but no more than `InpMaxSweepPoints` (350 pts).
  3. The bar closes firmly back **above** the swing low level.
  4. Bullish displacement check: Candle closes in the upper 50% of its total range (`InpMinDisplacementR = 0.5`).
- **Bearish Sweep Setup**:
  1. Price tests a lookback swing high.
  2. The bar's high penetrates above the swing high by 15–350 pts.
  3. The bar closes firmly back **below** the swing high level.
  4. Bearish displacement check: Candle closes in the lower 50% of its total range.

## 3. Exit & Risk Management
- **Protective Stop Loss**: Fixed strictly at the extreme of the sweep wick + 5 points buffer.
- **Take Profit Target**: Calculated dynamically to guarantee a minimum **1:2.5 Reward-to-Risk ratio** (`InpRewardToRiskRatio = 2.5`).
- **Break-Even Functionality**: Moves Stop Loss to `Entry + Buffer` as soon as price achieves **+1.0R** in floating profit.
- **Position Sizing**: Dynamically calculated using broker tick value, tick size, and distance to stop loss based on **0.5% equity risk** per trade.

## 4. Multi-Symbol Scanning
Can be attached to a single chart (e.g. `EURUSD M15`) to monitor the complete watchlist:
`XAUUSD, XAGUSD, US500, US100, USOIL, EURUSD, GBPUSD, USDJPY`.
Automatically resolves broker-specific symbol suffixes (e.g. `XAUUSDm` on Exness).

## 5. Verification Status
- **Classification**: `Backtest Evaluated` / `Ready for Exness Demo Verification`
- **Recommended Timeframe**: M15
- **Best Suited Market Conditions**: High-volume London & New York session openings.
