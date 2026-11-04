# Deployment Gate & Next Steps

## 1. Prerequisites Before Deployment
1. **User Confirmation**: This entire repair has been developed and verified strictly on the isolated Git branch `fix/921-ema-be-rr-utc-repair`. No files have been pushed to GitHub, and the live MT5 terminal has not been touched.
2. **Additional Screenshot Review**: The user indicated that additional trade screenshots will be uploaded. The evidence table in `BE_TRADE_ANALYSIS.md` will be updated immediately upon receipt.

---

## 2. Safe Demo Deployment Checklist
When approved by the user, the deployment procedure will follow these sequential steps:

1. **Commit Local Branch**:
   Commit the verified code on `fix/921-ema-be-rr-utc-repair` with clear conventional commit messages.
2. **Backup Existing Terminal EX5 Files**:
   Copy existing `.ex5` files in `C:\Users\vaibh\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\` to a timestamped backup directory.
3. **Deploy Compiled EX5 to Terminal**:
   Transfer the compiled binaries to the terminal's `Experts` directory.
4. **Terminal Verification**:
   * Verify Expert tab initializes with:
     ```
     [921 SCANNER] Initialized with R-Based BE: 1.0R | Mode: Closed M5 Bar | Spread Offset Multiplier: 1.5x
     [TIMEZONE] Dynamic Server Offset: GMT+0 | UK Time: HH:MM UK
     ```
   * Observe first 3 live signals on the demo account to verify that SL stays in place during the first M5 candle.

---

## 3. Rollback Procedure
If any discrepancy occurs during live demo testing:
* Re-attach the backed-up `.ex5` files or switch the chart template.
* Revert the branch via `git checkout main`.
