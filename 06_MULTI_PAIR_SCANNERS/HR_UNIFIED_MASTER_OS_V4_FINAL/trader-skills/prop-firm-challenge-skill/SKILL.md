---
name: prop-firm-challenge-skill
description: Rulesets for FTMO, FundedNext, and MFF: strict daily drawdown (3.0% / 5.0%), maximum loss, and trading day rules.
---

# Prop Firm Challenge Risk Engine

## Overview
Rulesets for FTMO, FundedNext, and MFF: strict daily drawdown (3.0% / 5.0%), maximum loss, and trading day rules.

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
