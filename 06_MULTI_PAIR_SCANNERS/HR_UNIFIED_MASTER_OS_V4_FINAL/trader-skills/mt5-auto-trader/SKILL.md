---
name: mt5-auto-trader
description: Automated order execution engine executing A+ setups (Touch 21 + Retest + Close) once user or bot confirms.
---

# MT5 Auto Trader

## Overview
Automated order execution engine executing A+ setups (Touch 21 + Retest + Close) once user or bot confirms.

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
