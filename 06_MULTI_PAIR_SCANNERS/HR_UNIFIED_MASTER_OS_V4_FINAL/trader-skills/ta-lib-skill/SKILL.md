---
name: ta-lib-skill
description: Calculates 150+ technical indicators: EMA 9, 21, 200, ATR(14), RSI(14), MACD, Bollinger Bands, and candle patterns.
---

# TA-Lib Indicator Engine

## Overview
Calculates 150+ technical indicators: EMA 9, 21, 200, ATR(14), RSI(14), MACD, Bollinger Bands, and candle patterns.

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
