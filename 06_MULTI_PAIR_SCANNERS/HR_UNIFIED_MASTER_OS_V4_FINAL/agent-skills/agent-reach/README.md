# Agent Reach: Internet Capability Router for HR Unified Master OS

- **Repository**: [Panniantong/Agent-Reach](https://github.com/Panniantong/Agent-Reach) (78.5k stars)
- **License**: MIT
- **Capabilities**: Zero API fees, 15+ internet platforms, 50+ tools.

---

## 1. Role in HR Unified Master OS MT5 System

Agent Reach serves as the external intelligence router for market monitoring and research:
- **Macro News Feed**: Scrapes Forex Factory, economic releases, and rate announcements (BoE, NFP, CPI, FOMC) to feed the dashboard NEWS pill.
- **DXY Telemetry**: Fetches Dollar Index live updates and market sentiment.
- **Correlation & Sentiment**: Fetches cross-asset discussions and signals across Twitter/X, Reddit, GitHub, and Xueqiu.
- **Strategy Research**: Searches algorithmic EA repositories and Pine Script technical workflows without paid API overhead.

---

## 2. CLI Usage Examples

```bash
# Web search
agent-reach search "XAUUSD gold price forecast"

# GitHub code & repo search
agent-reach github search "trader-skill"

# YouTube video/transcript lookup
agent-reach youtube search "BoE rate decision"

# Reddit market sentiment
agent-reach reddit search "Gold breakout"

# Read web link directly
agent-reach read https://www.forexfactory.com/calendar
```
