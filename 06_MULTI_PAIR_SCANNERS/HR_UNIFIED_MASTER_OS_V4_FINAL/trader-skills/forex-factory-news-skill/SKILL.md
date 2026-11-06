---
name: forex-factory-news-skill
description: Live economic calendar scraper, high-impact news circuit breaker (BoE, NFP, CPI, FOMC) with pre-event trading pause.
---

# Forex Factory News Skill

## Overview
Live economic calendar scraper, high-impact news circuit breaker (BoE, NFP, CPI, FOMC) with pre-event trading pause.

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
