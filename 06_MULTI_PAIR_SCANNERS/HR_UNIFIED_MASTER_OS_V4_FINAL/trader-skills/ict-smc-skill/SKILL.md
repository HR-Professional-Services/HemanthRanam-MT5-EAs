---
name: ict-smc-skill
description: Identifies Market Structure Shifts, CHOCH, BOS, Buy Side Liquidity (BSL), Sell Side Liquidity (SSL), and Fair Value Gaps (FVG).
---

# ICT / Smart Money Concepts Skill

## Overview
Identifies Market Structure Shifts, CHOCH, BOS, Buy Side Liquidity (BSL), Sell Side Liquidity (SSL), and Fair Value Gaps (FVG).

## Standard Parameters & Guardrails
- **Symbols**: XAUUSD, XAGUSD, US500, USTEC
- **Strategy**: 9/21 EMA pullback, 200 EMA trend filter (1H), ATR gap verification
- **Risk Limit**: Max 1% equity risk per trade, 1:1.5 R:R minimum
- **Execution**: Paper trading by default (`paper: true`)

## Tools & Usage
Run the bundled Python tool:
```bash
python tool.py
```
