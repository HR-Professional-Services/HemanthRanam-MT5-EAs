---
name: forex-mt5-skill
description: MetaTrader 5 Expert Advisor connector, live execution gateway, account query and order manager for XAUUSD, XAGUSD, US500, and USTEC.
---

# Forex MT5 Trading Skill

## Overview
MetaTrader 5 Expert Advisor connector, live execution gateway, account query and order manager for XAUUSD, XAGUSD, US500, and USTEC.

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
