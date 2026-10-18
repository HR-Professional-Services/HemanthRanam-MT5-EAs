# 08 — Multi-Strategy Scanners

This directory contains the composite Multi-Strategy Scanner architecture developed for MetaTrader 5 on Exness. Instead of relying on a single indicator or setup type, this scanner incorporates three complementary institutional strategies under a unified risk governor and real-time scanning engine.

---

## Systems Catalog

| EA File | Matching Documentation | Incorporated Strategy Modules | Portfolio Risk Cap |
| :--- | :--- | :--- | :--- |
| [`MULTI_STRATEGY_SCANNER_EA.mq5`](file:///Users/rh/.gemini/antigravity-ide/scratch/Trading/HemanthRanam-MT5-EAs/08_MULTI_STRATEGY_SCANNERS/MULTI_STRATEGY_SCANNER_EA.mq5) | [`MULTI_STRATEGY_SCANNER_EA_README.md`](file:///Users/rh/.gemini/antigravity-ide/scratch/Trading/HemanthRanam-MT5-EAs/08_MULTI_STRATEGY_SCANNERS/MULTI_STRATEGY_SCANNER_EA_README.md) | 1. Session VWAP Reclaim<br>2. Market Structure BOS Retest<br>3. Momentum Expansion Continuation | 6.0% Total Open Risk across max 5 positions |

---

## Strategic Advantages

1. **Strategy Diversification**:
   - Reduces portfolio drawdown by trading three distinct market mechanics: Mean Reversion to VWAP, Structural Trend Following (BOS), and Volatility Momentum Continuation.
2. **Centralized Risk Governor**:
   - Prevents position stacking and correlation overexposure across metals, indices, and currency pairs.
   - Enforces a maximum total open risk limit (default 6.0%) and maximum concurrent positions per symbol (default 2).
3. **100% Standalone Architecture**:
   - Compiles cleanly in MetaEditor 5 without external `.mqh` files or dependencies.
