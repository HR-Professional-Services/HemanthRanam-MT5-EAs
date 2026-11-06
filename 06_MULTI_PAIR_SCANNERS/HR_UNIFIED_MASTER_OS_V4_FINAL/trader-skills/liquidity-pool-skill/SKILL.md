---
name: liquidity-pool-skill
description: Tracks equal highs (EQH) and equal lows (EQL), detects institutional stop hunts, and validates pool sweep reversals.
---

# Liquidity Pool & Sweep Detector

## Overview
Tracks equal highs (EQH) and equal lows (EQL), detects institutional stop hunts, and validates pool sweep reversals.

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
