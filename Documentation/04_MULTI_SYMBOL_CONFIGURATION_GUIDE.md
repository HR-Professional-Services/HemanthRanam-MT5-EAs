# Multi-Symbol Watchlist & Broker Suffix Configuration Guide

## 1. Single-Chart Multi-Symbol Architecture

All five EAs in the **Hemanth Ranam MT5 Suite** utilize the `CSymbolScanner` engine (`Include/SymbolScanner.mqh`).

Instead of opening a separate chart for every currency pair, commodity, and index, you attach the EA to **one single chart** (e.g. `EURUSD M15`). The internal timer asynchronously queries market rates, spreads, and indicator buffers for all symbols listed in the `InpWatchlist` parameter.

---

## 2. Default Multi-Asset Watchlist

```ini
InpWatchlist="XAUUSD,XAGUSD,US500,US100,USOIL,EURUSD,GBPUSD,USDJPY"
```

| Symbol | Asset Class | Description | Exness Typical Name |
| :--- | :--- | :--- | :--- |
| **XAUUSD** | Commodity / Metal | Gold vs US Dollar | `XAUUSD`, `XAUUSDm` |
| **XAGUSD** | Commodity / Metal | Silver vs US Dollar | `XAGUSD`, `XAGUSDm` |
| **US500** | Index | S&P 500 Index | `US500`, `US500m`, `SPX500` |
| **US100** | Index | Nasdaq 100 Index | `US100`, `US100m`, `USTEC`, `NAS100` |
| **USOIL** | Energy | WTI Crude Oil | `USOIL`, `USOILm`, `XTIUSD` |
| **EURUSD** | Forex Major | Euro vs US Dollar | `EURUSD`, `EURUSDm` |
| **GBPUSD** | Forex Major | British Pound vs US Dollar | `GBPUSD`, `GBPUSDm` |
| **USDJPY** | Forex Major | US Dollar vs Japanese Yen | `USDJPY`, `USDJPYm` |

---

## 3. How Exness Suffix Resolution Operates

Exness accounts append suffixes depending on your account tier:
- **Exness Standard Account**: Appends `m` (e.g. `EURUSDm`, `XAUUSDm`).
- **Exness Standard Cent**: Appends `c` (e.g. `EURUSDc`).
- **Exness Pro Account**: Often raw names (`EURUSD`, `XAUUSD`) or `.pro`.
- **Exness Zero / Raw**: Raw names or `_i` / `.r`.

### Automatic Resolution Flow:
1. `CSymbolScanner` checks if the base symbol (e.g. `XAUUSD`) exists in the broker Market Watch.
2. If not found, it automatically iterates through candidate suffixes: `m`, `c`, `_i`, `.a`, `.pro`, `.raw`.
3. If `XAUUSDm` is detected, it logs:
   ```
   [SymbolScanner] Auto-resolved 'XAUUSD' -> 'XAUUSDm'
   ```
4. It calls `SymbolSelect(resolvedSymbol, true)` to ensure the symbol is active in the Market Watch.

---

## 4. Customizing Your Watchlist

You can customize the symbols scanned at runtime in the EA's input dialog:
- **Gold-Only Focus**: `InpWatchlist="XAUUSD,XAGUSD"`
- **Indices-Only Focus**: `InpWatchlist="US500,US100"`
- **Forex-Only Focus**: `InpWatchlist="EURUSD,GBPUSD,USDJPY,AUDUSD,USDCAD"`

Each symbol's position sizing, stop-loss distance, and tick specifications are calculated independently using broker telemetry.
