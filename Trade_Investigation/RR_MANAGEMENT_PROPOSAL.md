# Proposed R-Based Trade Management Framework

## 1. Principles of Robust R-Multiple Management

The goal of active trade management is to protect capital without suffocating valid trade setups. An active trade must be given room for normal market noise and intra-candle retests of the dynamic 9/21 EMA zone.

---

## 2. Dynamic Risk & R Tracking Engine Architecture

### 2.1 Initial Risk Isolation & Persistence
At the exact moment a position is confirmed and filled by the broker:
1. `entryPrice` = `PositionGetDouble(POSITION_PRICE_OPEN)`
2. `initialSL` = `PositionGetDouble(POSITION_SL)`
3. Initial Risk Distance:
   * **BUY**: $\text{RiskDist} = \text{entryPrice} - \text{initialSL}$
   * **SELL**: $\text{RiskDist} = \text{initialSL} - \text{entryPrice}$
4. $\text{RiskDist}$ is saved into a persistent data structure (`VirtualTrade` / global file cache) and **NEVER altered** when S/L is subsequently modified.

### 2.2 Execution-Price R Calculation
Current floating R must be calculated against the **executable exit price**:
* For **BUY** positions (closed at Bid):
  $$\text{Current R} = \frac{\text{Bid} - \text{entryPrice}}{\text{RiskDist}}$$
* For **SELL** positions (closed at Ask):
  $$\text{Current R} = \frac{\text{entryPrice} - \text{Ask}}{\text{RiskDist}}$$

---

## 3. The 3-Tier Break-Even Progression Guardrail

To eliminate premature sub-second BE stops, the engine implements a 3-tier safety check:

```
                  ┌──────────────────────────────────────────────┐
                  │          Trade Opens with Valid SL           │
                  └──────────────────────┬───────────────────────┘
                                         │
                    Current R < 1.0R     ▼
                  ┌──────────────────────────────────────────────┐
                  │       HOLD INITIAL STOP LOSS UNTOUCHED       │
                  │   (Allow natural retests of 9/21 EMA zone)   │
                  └──────────────────────┬───────────────────────┘
                                         │
           Current R >= InpBreakEven_R (Default 1.0R or 1.2R)
                                  AND
         Candle Confirmation OR Minimum Points / Duration Gate Passed
                                         │
                                         ▼
                  ┌──────────────────────────────────────────────┐
                  │          MOVE STOP LOSS TO BREAK-EVEN        │
                  │     S/L = Entry + (SpreadBuffer + Cost)      │
                  └──────────────────────┬───────────────────────┘
                                         │
                   Current R >= 1.5R - 2.0R
                                         │
                                         ▼
                  ┌──────────────────────────────────────────────┐
                  │      TP1 PARTIAL CLOSE (50%) OR RUNNER       │
                  │          (Trail SL via EMA 21 or ATR)        │
                  └──────────────────────────────────────────────┘
```

### Protection Rules:
1. **Minimum Stop Loss Distance Floor**:
   Enforce that $\text{RiskDist}$ cannot be smaller than the minimum asset volatility:
   * Gold (`XAUUSD`): Min SL = 200–300 points ($2.00–$3.00)
   * S&P 500 (`US500`): Min SL = 350 points (3.5 pts)
   * Nasdaq (`USTEC`): Min SL = 2500 points (25.0 pts)
   * Forex: Min SL = 120–150 points (12–15 pips)
2. **Break-Even Trigger Options**:
   * Mode A: **Bar Close Confirmation**: Only trigger BE if an M5 candle closes with $\text{Close} \ge \text{Entry} + 1.0R$.
   * Mode B: **Intrabar Buffer Gate**: If intrabar BE is desired, require at least **1.2R** before moving SL, ensuring normal 0.3R–0.5R wicks do not hit entry.
3. **Realistic BE Safety Buffer**:
   Replace flawed pip multipliers with dynamic spread-aware buffers:
   $$\text{SafetyBuffer} = \max(\text{Spread} \times 1.5, \, \text{RiskDist} \times 0.05)$$
   This prevents trades from closing at negative values due to broker spread on exit.
