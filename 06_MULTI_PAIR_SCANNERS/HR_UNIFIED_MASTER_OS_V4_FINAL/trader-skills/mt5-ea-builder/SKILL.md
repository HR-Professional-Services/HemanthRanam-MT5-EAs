---
name: mt5-ea-builder
description: Architects, verifies, and packages high-frequency and multi-pair MQL5 Expert Advisors with CCanvas zero-flicker UI.
---

# MT5 EA Builder

## Overview
Architects, verifies, and packages high-frequency and multi-pair MQL5 Expert Advisors with CCanvas zero-flicker UI.

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
