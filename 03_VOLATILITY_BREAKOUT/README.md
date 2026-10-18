# EA 3 — Volatility Expansion Breakout (`VOLATILITY_EXPANSION_BREAKOUT_EA.mq5`)

## 1. Trading Hypothesis
Asset volatility is cyclical: low volatility compression regimes inevitably transition into rapid volatility expansion. Narrow consolidation ranges represent institutional order accumulation where price energy is stored. When price penetrates the defined range boundaries with measurable volume acceleration, strong directional trend runs are initiated.

## 2. Entry Conditions
- **Squeeze / Compression Gate**:
  1. The high-to-low range over the lookback window (`InpCompressionBars = 20`) is evaluated against current ATR.
  2. Range must be tightly compressed: `BoxHeight <= (ATR * InpMaxCompressionATR)` (e.g. `<= 1.8x ATR`).
- **Volume Surge Filter**:
  1. Breakout candle must register a tick volume of at least **1.25x** the 20-bar average volume.
- **Directional Breakout Triggers**:
  - **Bullish Breakout**: Trigger bar closes green and decisively above the compression ceiling (`boxHigh`).
  - **Bearish Breakout**: Trigger bar closes red and decisively below the compression floor (`boxLow`).

## 3. Exit & Risk Management
- **Protective Stop Loss**: Anchored dynamically at the consolidation range midpoint or trigger bar extreme + 5 points buffer.
- **Take Profit Target**: Enforces a minimum **1:2.5 Reward-to-Risk ratio** (`InpRewardToRiskRatio = 2.5`).
- **Break-Even & Dynamic Trailing Stop**: Trailing stop (`InpEnableTrailing = true`, default 55 points) automatically locks in explosive expansion momentum.
- **Position Sizing**: Dynamically calibrated to **0.5% equity risk** per trade.

## 4. Multi-Symbol Scanning
Monitors all 8 core instruments concurrently from a single chart attachment:
`XAUUSD, XAGUSD, US500, US100, USOIL, EURUSD, GBPUSD, USDJPY`.

## 5. Verification Status
- **Classification**: `Backtest Evaluated` / `Ready for Exness Demo Verification`
- **Recommended Timeframe**: M15
- **Best Suited Market Conditions**: Pre-market session transitions (e.g. European opening 07:00–08:00 GMT, US opening 12:30–13:30 GMT).
