---
name: tradingview-to-mt5
description: Translates Pine Script v5/v6 alert webhooks into instant MT5 trade orders and order ticket modifications.
---

# TradingView to MT5 Bridge

## Overview
Translates Pine Script v5/v6 alert webhooks into instant MT5 trade orders and order ticket modifications.

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
