# Exness & Windows Lenovo ThinkPad MT5 Deployment Guide

This step-by-step guide walks you through deploying the **Hemanth Ranam MT5 EA Suite** on your **Lenovo ThinkPad** running **MetaTrader 5** connected to **Exness**.

---

## 1. Cloning or Transferring Files to Lenovo ThinkPad

### Option A: Using Git on Windows (Recommended)
Open Git Bash or Command Prompt on your ThinkPad:
```bash
git clone https://github.com/HR-Professional-Services/HemanthRanam-MT5-EAs.git
```

### Option B: Direct Copy to MT5 Data Folder
1. On your ThinkPad, open **MetaTrader 5**.
2. Click **File** > **Open Data Folder** (or press `Ctrl + Shift + D`).
3. Navigate into the `MQL5` directory.
4. Copy the repository folders into `MQL5` as follows:
   - Copy `Include/` files into `MQL5\Include\`
   - Copy `01_LIQUIDITY_SWEEP/`, `02_TREND_PULLBACK/`, `03_VOLATILITY_BREAKOUT/`, `04_STRUCTURE_MOMENTUM/`, and `05_ADAPTIVE_REGIME/` into `MQL5\Experts\`

---

## 2. Compiling the EAs in MetaEditor

1. Inside MetaTrader 5, press `F4` to open **MetaEditor**.
2. In the left **Navigator** pane, expand the `Experts` folder.
3. Open each EA entry point:
   - `01_LIQUIDITY_SWEEP\LIQUIDITY_SWEEP_REVERSAL_EA.mq5`
   - `02_TREND_PULLBACK\TREND_PULLBACK_CONTINUATION_EA.mq5`
   - `03_VOLATILITY_BREAKOUT\VOLATILITY_EXPANSION_BREAKOUT_EA.mq5`
   - `04_STRUCTURE_MOMENTUM\MARKET_STRUCTURE_MOMENTUM_EA.mq5`
   - `05_ADAPTIVE_REGIME\ADAPTIVE_MARKET_REGIME_EA.mq5`
4. Click **Compile** (or press `F7`).
5. Confirm the compiler outputs:
   ```
   0 errors, 0 warnings
   ```
   The compiled `.ex5` executable will immediately appear in your MT5 Navigator.

---

## 3. Configuring Terminal Permissions

1. In MetaTrader 5, click **Tools** > **Options** (or press `Ctrl + O`).
2. Navigate to the **Expert Advisors** tab:
   - Check **Allow Algo Trading**.
   - (Optional) If sending Telegram alerts, check **Allow WebRequest for listed URL** and add:
     - `https://api.telegram.org`
3. Click **OK**.
4. Ensure the **Algo Trading** button in the main MT5 toolbar is toggled **ON** (Green Play icon).

---

## 4. Single-Chart Multi-Symbol Attachment

You do **NOT** need to open 8 separate charts!
1. Open one clean **EURUSD M15** chart (or **XAUUSD M15**).
2. From the Navigator pane under `Experts`, drag your chosen EA (e.g. `ADAPTIVE_MARKET_REGIME_EA`) onto the chart.
3. In the **Inputs** tab:
   - Verify `InpWatchlist`: `XAUUSD,XAGUSD,US500,US100,USOIL,EURUSD,GBPUSD,USDJPY`
   - If using an Exness Standard account with suffix `m`, the EA will auto-resolve it. Alternatively, specify `XAUUSDm,EURUSDm,US500m...`.
   - Verify `InpRiskPercent` is set to `0.5%`.
4. Click **OK**.
5. Check the **Experts** log tab at the bottom to confirm:
   ```
   [SymbolScanner] Watchlist ready with 8 tradable instruments.
   [RiskManager] Daily baseline reset. Starting Equity: ...
   ```

---

## 5. Recommended MT5 Strategy Tester Verification
1. Open Strategy Tester (`Ctrl + R`).
2. Select EA: `ADAPTIVE_MARKET_REGIME_EA.ex5`.
3. Select Symbol: `XAUUSD` (or `EURUSD`).
4. Timeframe: `M15`.
5. Modeling: `Every tick based on real ticks`.
6. Deposit: `$10,000` (or your account balance).
7. Load preset: `Tests_And_Reports\Presets\AdaptiveRegime_Portfolio.set`.
8. Click **Start** to run backtest.
