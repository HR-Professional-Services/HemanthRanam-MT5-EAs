---
name: mt5-risk-manager
description: Enforces 1% maximum account equity risk, daily loss circuit breakers, 4-pair max exposure limits, and 1:1.5 minimum R:R.
---

# MT5 Risk Manager

## Overview
Enforces 1% maximum account equity risk, daily loss circuit breakers, 4-pair max exposure limits, and 1:1.5 minimum R:R.

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
