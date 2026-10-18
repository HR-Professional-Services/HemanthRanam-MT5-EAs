# 07 — EMA Strategy EAs

This directory houses the dedicated Exponential Moving Average (EMA) Expert Advisor collection. These standalone systems evaluate individual and composite moving average pullbacks, momentum retests, and trend continuation behaviors across M5 and M15 charts on Exness MT5.

---

## Strategy Catalog

| EA File | Matching Documentation | Core Trading Hypothesis | Execution Timeframe | Trend Filter |
| :--- | :--- | :--- | :--- | :--- |
| [`9_EMA_EA.mq5`](file:///Users/rh/.gemini/antigravity-ide/scratch/Trading/HemanthRanam-MT5-EAs/07_EMA_EAS/9_EMA_EA.mq5) | [`9_EMA_EA_README.md`](file:///Users/rh/.gemini/antigravity-ide/scratch/Trading/HemanthRanam-MT5-EAs/07_EMA_EAS/9_EMA_EA_README.md) | Ultra-Fast Momentum Pullback (Aggressive Scalping) | M5 | H1 9 EMA Baseline |
| [`21_EMA_EA.mq5`](file:///Users/rh/.gemini/antigravity-ide/scratch/Trading/HemanthRanam-MT5-EAs/07_EMA_EAS/21_EMA_EA.mq5) | [`21_EMA_EA_README.md`](file:///Users/rh/.gemini/antigravity-ide/scratch/Trading/HemanthRanam-MT5-EAs/07_EMA_EAS/21_EMA_EA_README.md) | Intermediate Mean Reversion / Trend Equilibrium | M5 / M15 | H1 21 EMA Baseline |
| [`50_EMA_EA.mq5`](file:///Users/rh/.gemini/antigravity-ide/scratch/Trading/HemanthRanam-MT5-EAs/07_EMA_EAS/50_EMA_EA.mq5) | [`50_EMA_EA_README.md`](file:///Users/rh/.gemini/antigravity-ide/scratch/Trading/HemanthRanam-MT5-EAs/07_EMA_EAS/50_EMA_EA_README.md) | Swing Equilibrium & Dynamic Institutional Support | M15 | H1 50 EMA Baseline |
| [`100_EMA_EA.mq5`](file:///Users/rh/.gemini/antigravity-ide/scratch/Trading/HemanthRanam-MT5-EAs/07_EMA_EAS/100_EMA_EA.mq5) | [`100_EMA_EA_README.md`](file:///Users/rh/.gemini/antigravity-ide/scratch/Trading/HemanthRanam-MT5-EAs/07_EMA_EAS/100_EMA_EA_README.md) | Deep Macro Retest & Trend Defense Anchor | M15 / H1 | H1 100 EMA Baseline |
| [`9_21_EMA_EA.mq5`](file:///Users/rh/.gemini/antigravity-ide/scratch/Trading/HemanthRanam-MT5-EAs/07_EMA_EAS/9_21_EMA_EA.mq5) | [`9_21_EMA_EA_README.md`](file:///Users/rh/.gemini/antigravity-ide/scratch/Trading/HemanthRanam-MT5-EAs/07_EMA_EAS/9_21_EMA_EA_README.md) | Multi-Pair Auto Pilot 9/21 Pullback PRO with H1 200 EMA Filter | M5 (Multi-Pair) | H1 200 EMA Trend |

---

## Architectural Principles

1. **Zero Custom Dependencies**:
   - Every EA is 100% self-contained and compiles cleanly in MetaEditor without needing any external `.mqh` files or non-standard indicators.
2. **Multi-Timeframe Trend Confirmation**:
   - Low-timeframe execution (M5 or M15) is always synchronized with Higher-Timeframe trend alignment (H1), filtering out low-probability counter-trend traps.
3. **Realistic Reward-to-Risk**:
   - Single EMA systems utilize asymmetric reward-to-risk targets (up to 1:5) with aggressive Break-Even locking at +100 points, protecting capital while letting profitable runners capture extended trends.
4. **Consecutive Loss Accountability**:
   - Each strategy is stress-tested against losing streaks. Single fast-EMA strategies (e.g. 9 EMA) exhibit higher trade frequency with slightly longer losing streaks (6–8 losses), whereas higher-period EMAs (50 and 100 EMA) exhibit fewer trades, higher win rates, and shorter loss streaks (3–5 losses).
