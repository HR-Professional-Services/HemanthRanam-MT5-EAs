# MQL5 Institutional EA Engineering & Architectural Standard

This document establishes the official engineering architecture and standards for all Expert Advisors, Multi-Pair Scanners, and Quantitative Trading Engines maintained across the `@HR-Professional-Services` and `@Chartora` ecosystems.

---

## 1. Architectural Architecture (Decoupled MVC Pattern)

Every production EA must adhere to decoupled architecture:

```
┌────────────────────────────────────────────────────────┐
│                      CONTROLLER                        │
│   OnInit() | OnDeinit() | OnTick() | OnTimer()        │
└───────────┬────────────────────────────────┬───────────┘
            │                                │
            ▼                                ▼
┌──────────────────────┐         ┌───────────────────────┐
│        MODEL         │         │         VIEW          │
│ • Quantitative Logic │         │ • CCanvas Zero-Flicker│
│ • Indicator Buffers  │         │ • CAppDialog Controls │
│ • CTrade Gateway     │         │ • Double-Buffered UI  │
│ • Risk & Lot Sizing  │         │ • 100-250ms UI Timer  │
│ • FILE_COMMON State  │         │ • Bloomberg Theme     │
└──────────────────────┘         └───────────────────────┘
```

---

## 2. High-Performance Dashboard Design (CCanvas)

- **Zero-Flicker Guarantee**: All visual widgets, ribbons, and matrices must use `CCanvas` bitmap rendering in memory. Never spawn hundreds of chart label objects (`OBJ_LABEL`).
- **Decoupled Timer**: `OnTick()` is reserved exclusively for order execution and fast risk trailing. The UI is updated via `OnTimer()` or millisecond timers (capped between 4 and 10 FPS).
- **Legibility**: Minimum 12-18pt bold fonts with high-contrast color schemes to eliminate text overlap across standard and 4K displays.

---

## 3. Execution, Risk Management & Safeguards

- **Order Execution Gateway (`CTrade`)**:
  - Full parameterization and symbol suffix auto-resolution.
  - Strict pre-execution checks: Spread limits, Stops Level floors, Freeze Levels, and Margin validation.
- **Trade Lifecycle Model**:
  - **1:1 BE Shift**: Move Stop Loss to Entry + Broker Spread padding when trade hits +1.0R.
  - **1:2 TP1 Partial**: Close 50% of the volume at +2.0R to lock in gains.
  - **Trend Runner**: Trail remaining volume until opposite EMA cross or structural break.
- **State Persistence**:
  - Binary serialization via `FILE_COMMON/<EA_Name>/ScannerState.bin` ensures zero lost trades on terminal restart.

---

## 4. 24/7 Scanning & Telegram Telemetry

- **24/7 Operations**: Default input `InpEnableSessionFilter = false` ensures uninterrupted scanning without session or weekend close restrictions.
- **Telegram Formatting Standard**:
  - First line **MUST** include direction, symbol, and lot size:
    `🟢 BUY XAUUSD — Lot: 0.12`
  - High-resolution chart snapshot uploaded as photo with alert caption.

---

## 5. Strategy Tester & Quantitative Backtest Protocol

- Closed-bar signal security (`bar[1]`) guarantees **0% signal repainting**.
- Tested under "Every tick based on real ticks" with broker-realistic spreads, commissions, and simulated network delays.
