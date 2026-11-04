# Implementation Report: 9/21 EMA BE, R-Multiple & Telegram Time Repair

## 1. Branch Information & Repository State
* **Branch**: `fix/921-ema-be-rr-utc-repair`
* **Status**: Cleanly isolated; zero commits pushed to GitHub; live demo terminal untouched.
* **Modified Files**:
  1. `06_MULTI_PAIR_SCANNERS/9_21_EMA_MULTI_PAIR_SCANNER_EA.mq5`
  2. `07_EMA_EAS/9_21_EMA_EA.mq5`

---

## 2. Technical Repairs Applied

### A. Immutable Initial Risk Isolation
* In `06_MULTI_PAIR_SCANNERS/9_21_EMA_MULTI_PAIR_SCANNER_EA.mq5`:
  * Enforced that `meta.initialRiskDist = MathAbs(realEntry - realSL)` is stored at the moment of order fill and is **never mutated** when S/L is adjusted.
  * Preserved through terminal restarts via persistent binary cache (`ActiveTrades.bin`).
* In `07_EMA_EAS/9_21_EMA_EA.mq5`:
  * Upgraded `struct TradeRecord` with `initialRiskDist` and `reachedBE`.
  * Added `GetInitialRiskForTicket()` and `SetTicketReachedBE()` so trade journal tracks immutable initial risk.

### B. Minimum Risk Distance (Stop Loss Floor) Protection
* Implemented `GetMinRiskDistanceFloor(sym)` to prevent sub-point stops on volatile assets:
  * **XAUUSD (Gold)**: Floor = 250 points ($2.50)
  * **XAGUSD (Silver)**: Floor = 80 points ($0.08)
  * **US500**: Floor = 350 points (3.5 index pts)
  * **USTEC (Nasdaq 100)**: Floor = 2500 points (25.0 index pts)
  * **Forex**: Floor = 150 points (15 pips)
* Prevents the microscopic 1.5–3.0 point denominators that triggered instant 3-second BEs.

### C. Spread-Aware Dynamic Break-Even Offset
* Implemented `CalculateDynamicBEOffset(sym, initialRiskDist)`:
  $$\text{Offset} = \max(\text{Spread} \times 1.5, \, \text{RiskDist} \times 0.05)$$
* Guaranteed compliance with broker `SYMBOL_TRADE_STOPS_LEVEL` and `SYMBOL_TRADE_FREEZE_LEVEL`.
* Eliminates the flawed `0.01` cent offset that caused slippage losses (-$0.35, -$0.24) upon BE liquidation.

### D. Multi-Configuration BE Trigger & Confirmation Gate
* Added `ENUM_BE_CONFIRMATION_MODE`:
  * `BE_CONFIRM_CLOSED_M5_BAR` (Default): Requires an M5 candle to complete and close with $\ge 1.0\text{R}$ profit before moving SL. This eliminates intra-candle noise and tick wicks.
  * `BE_CONFIRM_INTRABAR_TICK`: Allows immediate intrabar BE for high-speed scalping setups.
* Configurable trigger levels: `1.0R` (Standard), `1.2R` (Conservative), `1.5R` (Ultra-Conservative).

### E. Telegram UK Timezone & Auto-Offset Architecture
* Implemented `GetDynamicBrokerUTCOffset()`:
  * Compares `TimeTradeServer()` / `TimeCurrent()` with `TimeGMT()` to dynamically auto-detect whether the broker is GMT+0, GMT+2, or GMT+3.
  * Eliminates the hardcoded -2 hour error on Exness GMT+0 servers.
* Correct Europe/London seasonal rule:
  * Automatically switches between GMT (UTC+0 in winter) and BST (UTC+1 in summer).
  * Injects `Time: HH:MM UK` clearly into Telegram alerts for unambiguous verification.

---

## 3. Compilation Verification
Both EAs were compiled via `MetaEditor64.exe`:
* `06_MULTI_PAIR_SCANNERS/9_21_EMA_MULTI_PAIR_SCANNER_EA.mq5`: **0 errors, 0 warnings** (elapsed 4025 ms).
* `07_EMA_EAS/9_21_EMA_EA.mq5`: **0 errors, 0 warnings** (elapsed 1504 ms).
