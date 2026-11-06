---
name: mt5-optimizer
description: Walk-forward optimizer and parameter scanner for 9/21/200 EMA pullback and ATR multipliers.
---

# MT5 Optimizer

## Overview
Walk-forward optimizer and parameter scanner for 9/21/200 EMA pullback and ATR multipliers.

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
