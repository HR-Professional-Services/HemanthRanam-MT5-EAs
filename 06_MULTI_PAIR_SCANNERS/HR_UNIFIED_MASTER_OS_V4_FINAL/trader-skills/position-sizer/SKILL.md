---
name: position-sizer
description: Calculates fractional lots with 10% cash buffer, 25% pair equity cap, pip values, and contract multipliers across FX & indices.
---

# Position Sizer

## Overview
Calculates fractional lots with 10% cash buffer, 25% pair equity cap, pip values, and contract multipliers across FX & indices.

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
