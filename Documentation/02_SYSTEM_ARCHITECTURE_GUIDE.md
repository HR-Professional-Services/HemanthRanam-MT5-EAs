# System Architecture & Shared Module Engineering Guide

## 1. High-Level Architectural Diagram

```
+----------------------------------------------------------------------------------------------------+
|                                    PRIMARY TRADING SYSTEMS (EAs)                                   |
|                                                                                                    |
|  [01_LIQUIDITY_SWEEP]      [02_TREND_PULLBACK]      [03_VOLATILITY_BREAKOUT]                      |
|  Liquidity Reversal        9/21 Corridor Pullback   Squeeze & Expansion                           |
|                                                                                                    |
|  [04_STRUCTURE_MOMENTUM]   [05_ADAPTIVE_REGIME]                                                    |
|  Fractal BOS & Momentum    Trend / Range / Squeeze Dynamic Router                                 |
+----------------------------------------------------------------------------------------------------+
                                                  │
                                                  ▼
+----------------------------------------------------------------------------------------------------+
|                                  SHARED INCLUDE ARCHITECTURE (Include/)                            |
|                                                                                                    |
|  ┌─────────────────────┐   ┌─────────────────────┐   ┌─────────────────────┐                      |
|  │   RiskManager.mqh   │   │  SymbolScanner.mqh  │   │  TradeExecutor.mqh  │                      |
|  │  • 0.5% Risk Sizing │   │  • Multi-Symbol     │   │  • CTrade Native    │                      |
|  │  • 2.0% Daily DD    │   │  • Suffix Resolver  │   │  • Break-Even (+1R) │                      |
|  │  • 1.5% Open Risk   │   │  • Spread Guards    │   │  • Trailing Stop    │                      |
|  └─────────────────────┘   └─────────────────────┘   └─────────────────────┘                      |
|                                                                                                    |
|  ┌─────────────────────┐   ┌─────────────────────┐   ┌─────────────────────┐                      |
|  │  MarketFilters.mqh  │   │ RegimeClassifier.mqh│   │     Logger.mqh      │                      |
|  │  • London/NY Session│   │  • ADX / ATR Engine │   │  • Terminal Logging │                      |
|  │  • Rollover Blackout│   │  • Trend vs Range   │   │  • Push Alerts      │                      |
|  └─────────────────────┘   └─────────────────────┘   └─────────────────────┘                      |
+----------------------------------------------------------------------------------------------------+
                                                  │
                                                  ▼
+----------------------------------------------------------------------------------------------------+
|                                  METATRADER 5 TRADE SERVER & BROKER                                |
|                                                                                                    |
|  • Exness MT5 Terminal (Windows ThinkPad)                                                          |
|  • Native MQL5 Standard Trading Classes (<Trade\Trade.mqh>, <Trade\SymbolInfo.mqh>)               |
+----------------------------------------------------------------------------------------------------+
```

---

## 2. Shared Modules Deep Dive

### A. `RiskManager.mqh`
The central guardian of account capital:
- **Exact Risk Sizing**:
  $$\text{Risk Amount} = \text{Equity} \times \left(\frac{\text{Risk \%}}{100}\right)$$
  $$\text{Lot Size} = \frac{\text{Risk Amount}}{\left(\frac{\text{SL Distance}}{\text{Tick Size}}\right) \times \text{Tick Value}}$$
- **Daily Drawdown Limit**: Automatically calculates starting equity at 00:00 server time. If current equity drops by 2.0% (`InpMaxDailyDrawdown`), sets an internal lock preventing all new order submissions until the next trading day.
- **Aggregate Open Risk Limit**: Scans all active open positions across the account. If current open risk + new order risk exceeds 1.5% (`InpMaxPortfolioRisk`), the order is rejected.

### B. `SymbolScanner.mqh`
Enables single-chart multi-instrument surveillance:
- **Broker Suffix Auto-Resolution**: Automatically probes and maps standard symbols (e.g. `XAUUSD`) to their broker-specific equivalents on Exness (`XAUUSDm`, `XAUUSD.a`, etc.).
- **Live Spread Verification**: Checks real-time bid-ask spread in points against `InpMaxSpreadPoints` before evaluating signals.

### C. `TradeExecutor.mqh`
Standardized order lifecycle handling:
- **Mandatory Protective Stop Loss**: Rejects any order where the stop loss is invalid, missing, or improperly placed relative to current bid/ask.
- **Break-Even at +1R**: When floating price exceeds the initial stop distance ($+1.0R$), modifies position stop loss to $\text{Open Price} + \text{Buffer}$ (5 points) to cover trading costs.
- **Trailing Stop**: Dynamic ATR-based or point-based trailing stop updates.

### D. `MarketFilters.mqh`
Eliminates low-probability execution windows:
- **Session Filter**: Enforces trading during high-liquidity London (07:00–16:00 GMT) and New York (13:00–21:30 GMT) sessions.
- **Rollover Blackout**: Strictly blocks trading between **21:55 and 22:15 GMT** when broker spreads widen drastically.

### E. `RegimeClassifier.mqh`
Mathematical market state classifier:
- Evaluates ADX(14), Fast/Slow/Macro EMAs (9, 21, 200), and ATR(14).
- Distinguishes Trend Bull/Bear, Range Consolidation, Volatility Squeeze, and High-Risk Unstable states.

### F. `Logger.mqh`
- Standardized logging format across all 5 EAs for trade journals and terminal diagnostics.
