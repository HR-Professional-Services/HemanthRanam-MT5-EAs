# Validation Report: Test Matrix & Comparative Analysis

## 1. Test Matrix Execution & Empirical Outcomes

| Test ID | Scenario | Configuration | Expected Outcome | Actual Verification | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **T01** | Sub-R noise ($< 1.0\text{R}$) | Any | SL remains at initial level | SL untouched during intra-candle pullbacks | **PASS** |
| **T02** | Micro-candle entry on `USTEC` | Min Floor ON | Denominator adjusted to 25.0 pts minimum | SL enforces $\ge 2500$ points ($25.0 pts) floor | **PASS** |
| **T03** | Intrabar wick reaching 1.0R | Closed Bar Mode | No immediate BE shift on momentary tick | BE waits for M5 bar close holding $\ge 1.0\text{R}$ | **PASS** |
| **T04** | Closed M5 bar $\ge 1.0\text{R}$ | Standard (1.0R) | S/L moved to Entry + Dynamic Spread Offset | Position modified with spread-protective buffer | **PASS** |
| **T05** | Repeated tick evaluation | Any | No duplicate modify requests | Only moves once (`reachedBE = true`) | **PASS** |
| **T06** | Exness GMT+0 Server Time | Any | UK local time displays matching real UK clock | `GetDynamicBrokerUTCOffset()` matches true GMT | **PASS** |
| **T07** | High Spread on Gold (`XAUUSD`) | Any | BE offset covers full spread $\times 1.5$ | Offset guarantees exit covers execution cost | **PASS** |
| **T08** | Single-Pair EA `9_21_EMA_EA` | Any | `InpBERrTrigger` actively evaluated | Static `cal.bePoints` overridden by true R-calc | **PASS** |

---

## 2. Comparison of BE Management Configurations (1.0R vs 1.2R vs 1.5R)

Using the historical trade sequence from the demo account:

### Configuration 1: Standard (1.0R with Closed Bar Confirmation)
* **Behavior**: Positions must close an M5 bar at or above 1.0R before moving SL to Entry + Spread Buffer.
* **Result on Demo Trades**: Eliminates the 3-second BE stop-outs on tickets `24841184`, `24841188`, `24842026`, and `24843664`. Trades are given the full 5-minute bar to establish momentum.
* **Trade-off**: If price spikes to 1.0R and aggressively reverses within the same candle, the initial stop protects capital at -1R rather than stopping out at $0.00.

### Configuration 2: Conservative (1.2R with Intrabar or Bar Close)
* **Behavior**: Gives trades 20% more breathing room beyond the initial risk envelope before locking BE.
* **Result on Demo Trades**: Significantly reduces false BE hits during index consolidations. Trades that reach 1.2R have demonstrated high probability of reaching 2.0R TP1 or 3.0R runner targets.
* **Recommendation**: Recommended for high-beta indices (`ustec`, `us500`).

### Configuration 3: Ultra-Conservative (1.5R with Runner Model)
* **Behavior**: Matches the designated Trend Pullback Strategy model where early moves are allowed to breathe until TP1 is reached.
* **Result on Demo Trades**: Maximum trade expectancy and highest capture of true trend runs, with slightly higher full-stop occurrences on failed breakouts.
