---
name: ema-engine-skill
description: Multi-timeframe 9/21/200 EMA alignment, 3-bar slope detection, separation percentage, and trend health scoring.
---

# EMA Engine Multi-Timeframe Alignment

## Overview
Multi-timeframe 9/21/200 EMA alignment, 3-bar slope detection, separation percentage, and trend health scoring.

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
