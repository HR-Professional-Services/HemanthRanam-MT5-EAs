# EA 4 — Market Structure and Momentum (`MARKET_STRUCTURE_MOMENTUM_EA.mq5`)

## 1. Trading Hypothesis & Differentiation
Unlike trend-following indicator crosses, structural order flow reflects the actual sequence of higher highs/lows or lower highs/lows. When price breaks an established structural swing point (Break of Structure - BOS), institutional market participants have absorbed opposing liquidity and are aggressively repricing the asset into a new valuation bracket. Combining verified fractal swing breaks with directional RSI momentum ensures participation in high-velocity expansion legs.

## 2. Core Differences from EA 2 (Trend Pullback)
- **EA 2 (Trend Pullback)**: Trades **counter-trend pullbacks** back into moving average dynamic corridors within an already aged, mature trend.
- **EA 4 (Market Structure)**: Trades the **initial structural break** of key pivot points, capturing the initiation of structural trend shifts (BOS / CHoCH) regardless of moving average position.

## 3. Entry Conditions
- **Fractal Pivot Detection**:
  - Automatically identifies objective swing highs and lows using multi-bar bilateral confirmation (`InpPivotStrength = 3` bars left, 3 bars right).
- **Bullish Break of Structure (BOS)**:
  1. Trigger candle breaks and closes decisively **above** the most recent confirmed structural swing high.
  2. Momentum confirmation: RSI(14) must be elevated above `InpBullishRSIMin = 53.0`.
- **Bearish Break of Structure (BOS)**:
  1. Trigger candle breaks and closes decisively **below** the most recent confirmed structural swing low.
  2. Momentum confirmation: RSI(14) must be suppressed below `InpBearishRSIMax = 47.0`.

## 4. Exit & Risk Management
- **Protective Stop Loss**: Anchored strictly behind the opposing structural pivot low/high + 5 points buffer.
- **Take Profit Target**: Enforces a minimum **1:2.4 Reward-to-Risk ratio** (`InpRewardToRiskRatio = 2.4`).
- **Break-Even Protection**: Activates at **+1.0R** floating profit.
- **Position Sizing**: Dynamically calibrated to **0.5% equity risk** per trade.

## 5. Multi-Symbol Scanning
Monitors all 8 core instruments from a single chart attachment:
`XAUUSD, XAGUSD, US500, US100, USOIL, EURUSD, GBPUSD, USDJPY`.

## 6. Verification Status
- **Classification**: `Backtest Evaluated` / `Ready for Exness Demo Verification`
- **Recommended Timeframe**: M15
- **Best Suited Market Conditions**: High-beta assets (Gold, US500, US100) experiencing directional volume breakouts.
