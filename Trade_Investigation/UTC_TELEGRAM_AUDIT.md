# Telegram Timestamp & UK Time Conversion Audit

## 1. Discrepancy Overview

The user reported:
> **"Telegram notifications currently display approximately TWO HOURS LESS than the actual UK time."**

---

## 2. Codebase Investigation: `GetUKTime()`

In `9_21_EMA_MULTI_PAIR_SCANNER_EA.mq5` (lines 880-892):
```mql5
datetime GetUKTime(datetime serverTime = 0) {
   datetime utc = 0;
   if(serverTime > 0) {
      utc = serverTime - (InpBrokerUTCOffset * 3600);
   } else {
      utc = TimeGMT();
      if(utc <= 0) {
         utc = TimeCurrent() - (InpBrokerUTCOffset * 3600);
      }
   }
   int ukOffset = IsUKDaylightSavingTime(utc) ? 1 : 0; // BST (+1) or GMT (+0)
   return utc + (ukOffset * 3600);
}
```

### The Root Causes of the 2-Hour Error:

#### Cause 1: `TimeGMT()` Returns Zero or Local Machine UTC
In MetaTrader 5, `TimeGMT()` depends on the client terminal's OS clock sync. If `TimeGMT()` returns a valid UTC timestamp, `GetUKTime()` calculates:
$$\text{UK Time} = \text{TimeGMT()} + \text{ukOffset}$$
However, notice line 2514, 2744, 3680:
```mql5
datetime ukTime = GetUKTime(TimeCurrent());
```
When `TimeCurrent()` (Broker Server Time) is passed into `GetUKTime()`, the function executes:
```mql5
utc = serverTime - (InpBrokerUTCOffset * 3600);
```

#### Cause 2: Exness Broker Timezone Mismatch
* Exness live & trial servers operate on **GMT+0** during winter and **GMT+0** or **GMT+2 / GMT+3** depending on the specific server cluster.
* In our terminal log audit from today (`20261104.log`):
  * Local Windows machine time: `23:03 GMT+0`
  * Exness terminal start log:
    ```
    Windows 11 ... GMT+0
    22:31:09 Terminal started
    22:31:22 authorized on Exness-MT5Trial8
    ```
* If Exness server time is **GMT+0**, but `InpBrokerUTCOffset` is set to **`2`** (the default in input line 143):
  $$\text{Calculated UTC} = \text{ServerTime} - (2 \times 3600) = \text{ServerTime} - 2\text{ hours}!$$
* Since UK in November is on **GMT (UTC+0)**:
  $$\text{Calculated UK Time} = (\text{ServerTime} - 2) + 0 = \text{ServerTime} - 2\text{ hours}!$$
* **This subtracts 2 hours from the true UK time**, precisely creating the exact 2-hour deficit reported by the user!

---

## 3. The Structural Solution

1. **Auto-Detect Broker Server Offset dynamically**:
   Instead of forcing the user to guess whether their broker is on GMT+0, GMT+2, or GMT+3, compare `TimeTradeServer()` (or `TimeCurrent()`) directly with `TimeGMT()`:
   ```mql5
   int detectedBrokerOffset = (int)MathRound((double)(TimeTradeServer() - TimeGMT()) / 3600.0);
   ```
2. **Canonical UK Time Resolution**:
   ```mql5
   datetime GetCanonicalUKTime(datetime sTime = 0) {
      datetime curServer = (sTime > 0) ? sTime : TimeCurrent();
      datetime curGMT = TimeGMT();
      datetime trueUTC = 0;
      
      if(curGMT > 0) {
         trueUTC = curGMT;
      } else {
         int offset = InpBrokerUTCOffset;
         trueUTC = curServer - (offset * 3600);
      }
      
      int ukOffset = IsUKDaylightSavingTime(trueUTC) ? 1 : 0;
      return trueUTC + (ukOffset * 3600);
   }
   ```
3. **Explicit Display Format in Telegram Alerts**:
   Always print both UK time and UTC time for complete traceability:
   `🕒 14:35 UK (14:35 UTC)` in winter, or `🕒 15:35 UK (14:35 UTC)` in summer.
