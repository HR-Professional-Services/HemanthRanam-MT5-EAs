# TRADER SKILLS INSTALLED

- **Date Installed**: 2026-11-06
- **Total Skills**: 27 (11 Trader Skills + 15 Forex/MT5 Skills + Agent Reach)
- **Status**: Installed, tested, and ready for later use.

---

## 1. Installed Skills List

1. `trader-copycat`
2. `trader-news`
3. `trader-budget`
4. `trader-pelosi`
5. `trader-analyst`
6. `trader-screener`
7. `trader-risk`
8. `trader-broker`
9. `trader-tax`
10. `trader-alerts`
11. `trader-rebalance`
12. `forex-mt5-skill`
13. `mt5-ea-builder`
14. `mt5-optimizer`
15. `forex-factory-news-skill`
16. `tradingview-to-mt5`
17. `ta-lib-skill`
18. `ict-smc-skill`
19. `ema-engine-skill`
20. `liquidity-pool-skill`
21. `mt5-risk-manager`
22. `position-sizer`
23. `dxy-correlator`
24. `telegram-trading-bot`
25. `mt5-auto-trader`
26. `prop-firm-challenge-skill`
27. `agent-reach`

---

## 2. Configuration (`trader/config.json`)

```json
{
  "sec_user_agent": "Hemanth Ranam hemanth.ranam@example.com",
  "paper": true,
  "budget": 5000,
  "cash_buffer_percent": 10,
  "cap_percent": 25,
  "risk_per_trade_percent": 1,
  "symbols": ["XAUUSD", "XAGUSD", "US500", "USTEC"],
  "ema_fast": 9,
  "ema_mid": 21,
  "ema_slow": 200,
  "h1_filter": true,
  "atr_gap_filter": true,
  "broker": "Exness-MT5Trial8",
  "telegram_enabled": false,
  "dxy_symbol": "DXY",
  "mt5_account": "279630904",
  "agent_reach_enabled": true,
  "agent_reach_platforms": ["web", "twitter", "reddit", "youtube", "github", "rss"],
  "news_sources": ["forexfactory", "investing", "bloomberg", "twitter", "reddit"]
}
```

---

## 3. How to Use Later

- `/trader-copycat "copy Berkshire top 5"`
- `/trader-news`
- `/trader-budget --budget 5000 --write`
- `/trader-risk check`
- `/trader-broker ticket show`
- `/trader-pelosi`
- `/trader-alerts`
- `/trader-analyst AAPL`
- `/trader-screener`
- `/trader-rebalance --band 5`
- `/trader-tax harvest`
- `agent-reach search "XAUUSD"`
- `agent-reach github search "trader-skill"`
- `agent-reach youtube search "BoE rate decision"`
