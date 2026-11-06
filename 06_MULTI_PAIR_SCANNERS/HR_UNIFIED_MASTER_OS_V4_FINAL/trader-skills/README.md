# Trader Skills for HR Unified Master OS MT5 EA

This directory contains the trading skills configured for the **HR Unified Master OS MT5 EA** 4-pair 9/21 EMA system (XAUUSD, XAGUSD, US500, USTEC).

---

## 1. Skill Suite Overview (26+ Skills)

### Main Trader Skills (11 from jakeschincariol/trader-skill)
- `trader-copycat`: Mirror institutional 13F filings from the SEC.
- `trader-news`: Curate market headlines and company filings.
- `trader-budget`: Allocate capital with position caps and cash buffer.
- `trader-pelosi`: Track US Congressional stock disclosures (House & Senate).
- `trader-analyst`: Fundamental metrics from SEC 10-K / 10-Q XBRL data.
- `trader-screener`: Filter stocks by fundamental criteria and ratios.
- `trader-risk`: Guardrails, margin checks, trade limits, and order safety.
- `trader-broker`: Alpaca / IBKR paper trading order execution.
- `trader-tax`: Tax-loss harvesting and wash-sale identification.
- `trader-alerts`: Market hours, price targets, and trailing stops.
- `trader-rebalance`: Portfolio drift analysis and rebalancing orders.

### MT5 / Forex Specific Skills (15 Skills)
- `forex-mt5-skill`: MT5 connector and account/order execution bridge.
- `mt5-ea-builder`: Multi-pair MQL5 EA architect with CCanvas UI.
- `mt5-optimizer`: Parameter scanner for 9/21/200 EMA pullback.
- `forex-factory-news-skill`: Live economic calendar circuit breaker (BoE, NFP, CPI).
- `tradingview-to-mt5`: Pine Script alert webhook to MT5 order execution.
- `ta-lib-skill`: Technical indicator suite (EMA 9/21/200, ATR14, RSI14).
- `ict-smc-skill`: Market structure shifts, CHOCH, BOS, BSL, SSL, FVG.
- `ema-engine-skill`: Multi-timeframe 9/21/200 EMA alignment, 3-bar slope, separation %.
- `liquidity-pool-skill`: Equal highs/lows sweep detection.
- `mt5-risk-manager`: 1% risk per trade, daily loss circuit breakers.
- `position-sizer`: Fractional lot sizing with 10% cash buffer.
- `dxy-correlator`: Dollar Index tracker with rolling asset correlations.
- `telegram-trading-bot`: Real-time trade telemetry and alert dispatcher.
- `mt5-auto-trader`: Auto execution for verified A+ signals.
- `prop-firm-challenge-skill`: FTMO/FundedNext drawdown and risk rules.

---

## 2. EA Strategy Integration
- **4 Core Assets**: XAUUSD, XAGUSD, US500, USTEC.
- **Entry Rules**: 9/21 EMA pullback + Retest + Engulfing Close on M5.
- **Trend Filter**: 1H EMA 200 filter (Price > 200: Long Only | Price < 200: Short Only).
- **Risk Guardrails**: Max 1% risk per trade on equity, 1:1.5 R:R minimum.
