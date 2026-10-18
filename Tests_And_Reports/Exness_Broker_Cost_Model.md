# Exness Broker Transaction Cost & Execution Model

## 1. Overview
Empirical quantitative trading requires rigorous friction accounting. Many backtests fail in live execution because they ignore broker spread variations, commissions, overnight financing (swap), and execution slippage. This document outlines the broker cost parameters applied across the **Hemanth Ranam MT5 EA Suite** when operating on an **Exness** trading terminal.

---

## 2. Exness Account Type Specifications

| Instrument | Exness Standard Account (Spread Only) | Exness Pro Account (Low Spread, Zero Commission) | Exness Raw Spread Account (Raw Spread + Commission) |
| :--- | :--- | :--- | :--- |
| **EURUSD** | Typical: 10–12 pts (1.0–1.2 pips) | Typical: 6–8 pts (0.6–0.8 pips) | 0.0–2.0 pts + $7.00 round-trip / lot |
| **GBPUSD** | Typical: 12–15 pts (1.2–1.5 pips) | Typical: 8–10 pts (0.8–1.0 pips) | 1.0–4.0 pts + $7.00 round-trip / lot |
| **USDJPY** | Typical: 11–13 pts (1.1–1.3 pips) | Typical: 7–9 pts (0.7–0.9 pips) | 0.5–2.5 pts + $7.00 round-trip / lot |
| **XAUUSD (Gold)** | Typical: 25–35 pts ($0.25–$0.35) | Typical: 16–22 pts ($0.16–$0.22) | 8–15 pts + $7.00 round-trip / lot |
| **XAGUSD (Silver)** | Typical: 20–30 pts | Typical: 14–20 pts | 6–12 pts + $7.00 round-trip / lot |
| **US500** | Typical: 35–50 pts | Typical: 25–35 pts | 20–30 pts (account specific) |
| **US100 (USTEC)** | Typical: 80–120 pts | Typical: 60–90 pts | 50–75 pts |
| **USOIL (WTI)** | Typical: 25–40 pts | Typical: 18–28 pts | 15–25 pts |

> [!RECOMMENDATION]
> For algorithmic trading with high execution precision, the **Exness Pro Account** or **Exness Raw Spread Account** is strongly recommended over the Standard account to minimize spread friction on lower-timeframe (M15) entries.

---

## 3. Rollover & Swap Hour Protection

Between **21:55 GMT and 22:15 GMT**, global liquidity providers widen spreads significantly during the daily bank rollover. On Gold (XAUUSD), spreads can widen from 15 points to over 150 points for several minutes.

### Protective Architecture:
All 5 EAs feature the **Rollover Blackout Guard** (`InpRolloverBlackout = true` in `Include/MarketFilters.mqh`):
- New trade entries are strictly prohibited between 21:55 and 22:15 GMT.
- Stops and targets are not adjusted during this window to prevent accidental stop-outs from artificial broker spread widening.

---

## 4. Slippage & Execution Latency

- **Target Latency**: Under 20ms to the Exness MT5 server. When running on your **Lenovo ThinkPad**, ensure a stable broadband connection or consider a VPS located in London (LD4) or Amsterdam (AMS) where Exness trade servers are routed.
- **Max Slippage Parameter**: Configured to `InpSlippagePoints = 10` across all EAs. If market execution slips price beyond 10 points (1 pip), the request is automatically rejected.
