# Permanent IDE Instructions — MT5 EAs Repository

## 1. Objective and Authority
- **Repository**: [https://github.com/HR-Professional-Services/HemanthRanam-MT5-EAs](https://github.com/HR-Professional-Services/HemanthRanam-MT5-EAs)
- **Authoritative Workspace**: This repository is the permanent, authoritative workspace for all MT5 Expert Advisor development, maintenance, testing, and version control.
- **Remote**: `origin -> https://github.com/HR-Professional-Services/HemanthRanam-MT5-EAs.git`
- **Default Branch**: `main`
- **Core Requirement**: Every change must be preserved locally, committed with meaningful details, synchronized to GitHub, and recorded in an internal project activity log (`logs/CHANGELOG_INTERNAL.md`).

---

## 2. Session Startup Checks
At the beginning of every session or task:
1. Identify and verify repository root (`HemanthRanam-MT5-EAs`).
2. Read `AGENTS.md` and applicable project instructions.
3. Run `git status` to check working tree state.
4. Check current branch, upstream tracking, and remote configuration (`git branch -vv`, `git remote -v`).
5. Identify uncommitted work and remote divergence before editing files (`git fetch origin`, inspect `git status`).
6. Read the latest relevant entries in `logs/CHANGELOG_INTERNAL.md`.
7. Resume safely without overwriting or discarding existing work.

---

## 3. Mandatory Change Workflow
Whenever code, configuration, documentation, tests, or other tracked files change:
1. **Inspect Git Status**: Run `git status` to understand initial state.
2. **Review Local Modifications**: Protect unrelated work and uncommitted changes.
3. **Implement Changes**: Make the requested modifications cleanly.
4. **Run Validation & Compilation**:
   - For `.mq5` / `.mqh` files, compile using MetaEditor:
     ```powershell
     Start-Process -FilePath "C:\Program Files\MetaTrader 5\MetaEditor64.exe" -ArgumentList '/compile:"<path_to_file.mq5>"', '/log:"<path_to_log.log>"' -Wait
     Get-Content "<path_to_log.log>"
     ```
   - Verify compiler reports `0 errors, 0 warnings`.
   - Clean up transient test `.log` and `.ex5` files if not meant to be tracked.
5. **Review Complete Diff**: Run `git diff` to ensure correctness, lack of unintended modifications, no secret leaks, and no temporary debugging artifacts.
6. **Stage Intended Files**: Use `git add <file1> <file2>` (avoid blind `git add .`).
7. **Create Descriptive Commit**: Follow Commit Message Standards.
8. **Push to Remote**: Run `git push origin <branch>`.
9. **Verify Remote Push**: Check that remote tracking reflects the pushed commit (`git log origin/<branch> -n 1` or GitHub API / CLI).
10. **Append to Audit Log**: Update `logs/CHANGELOG_INTERNAL.md` with full details. (Group log entry with the change commit when practical, or in an immediate follow-up commit).
11. **Report Results**: Provide clean report with commit hash, push status, validation outcomes, and audit log link.

---

## 4. Commit Message Standards
Use clear, descriptive commit messages following the Conventional Commits format:
- `feat:` new feature or EA capability (e.g. `feat: add XAUUSD session filter`)
- `fix:` bug fix or logic correction (e.g. `fix: correct EMA entry validation`)
- `refactor:` code restructuring without logic change (e.g. `refactor: simplify trade management`)
- `test:` test plan, backtest preset, or validation suite (e.g. `test: add risk calculation checks`)
- `docs:` documentation, architecture guides, or README updates (e.g. `docs: update EA configuration guide`)
- `chore:` maintenance, gitignore, or workflow improvements (e.g. `chore: improve development workflow`)

For significant changes, include a commit body explaining:
- **What changed**: Detailed bullet points of modifications.
- **Why**: Rationale or problem solved.
- **Files**: Key components affected.
- **Validation**: Exact checks performed and results.
- **Known limitations**: Any residual constraints or assumptions.

Never use vague commit messages such as `update`, `changes`, `fixes`, or `latest`.

---

## 5. Internal Audit Log (`logs/CHANGELOG_INTERNAL.md`)
Maintain an append-only project activity log in `logs/CHANGELOG_INTERNAL.md`.

Every completed change must record:
- **Timestamp**: Date and time with timezone (e.g. `2026-10-21T23:15:00+01:00`).
- **Change Reference**: Short descriptive title.
- **Summary**: Concise summary of what was implemented.
- **Files Added / Modified / Deleted**: Explicit list of files.
- **Reason**: Clear rationale for the change.
- **Validation Performed**: Exact commands, tests, or compiler runs.
- **Validation Results**: Compiler status (errors/warnings), test outcomes.
- **Git Branch**: Branch name (e.g. `main`).
- **Commit Hash**: Verified commit hash.
- **GitHub Push Status**: Pushed and verified.
- **Outstanding Issues**: Any unresolved items or follow-ups.

### Integrity Rules:
- Append new entries; never silently edit or delete historical records.
- Correct historical errors only through a dated addendum entry.
- Never fabricate timestamps, commit hashes, or push statuses.
- If a change is blocked and cannot be committed, record the blocker clearly.

---

## 6. Local & Remote Synchronization Safety Policy
- **No Force Pushing**: Never use `git push --force` or `git reset --hard` as routine synchronization.
- **No Destructive Overwrites**: Never discard uncommitted work to make a pull or merge succeed.
- **No Blind History Rewrites**: Never rewrite published GitHub commit history.
- **Secrets Hygiene**: Never commit `.env` files, API keys, passwords, broker login IDs, investor passwords, private keys, or terminal session tokens.
- **Safe Blocker Escalation**: If authentication fails, merge conflicts arise, or pushes are rejected, preserve the local state, log the blocker, and request guidance. Never claim synchronization when a push has not completed.

---

## 7. MT5 / MQL5 Development Standards
- **Standalone Architecture**: Every `.mq5` must remain 100% self-contained and compile using only standard MetaTrader 5 libraries (`<Trade\Trade.mqh>`, `<Trade\SymbolInfo.mqh>`, `<Canvas\Canvas.mqh>`).
- **Risk Preservation**: Risk per trade strictly capped at 0.5%–1.0% equity; 2.0% daily equity circuit breaker.
- **Execution Safety**: Anti-repainting closed-bar confirmation on all entry signals. No look-ahead bias, duplicate ticket generation, or untracked orders.
- **Compiler Verification**: Compile with MetaEditor (`C:\Program Files\MetaTrader 5\MetaEditor64.exe`) and confirm 0 errors and 0 warnings before pushing.
- **Live Terminal Protection**: Never deploy directly to live accounts or modify broker settings without explicit authorization.

---

## 8. End-of-Task Reporting
At the conclusion of every task, report:
1. Implementation summary.
2. Files changed (added, modified, removed).
3. Tests and compilation results.
4. Git commit hash.
5. GitHub push verification.
6. Audit log entry status.
7. Any remaining blockers or recommended next steps.

---

## 9. MT5 Research Lab & Strategy Tester Automation Standards
- **External Archive Mandatory**: All historical datasets, candle CSVs, tick files, and Strategy Tester reports MUST reside strictly outside Git in `C:\MT5_Research_Lab\`.
- **Absolute Retention Invariant**: Never delete, roll over, or mutate original downloaded historical data. Incremental batches only.
- **Instrument Calibration Invariant**: Never assume identical point, pip, tick size, or contract specifications across symbols. Always query live broker specifications (`SYMBOL_POINT`, `SYMBOL_TRADE_TICK_SIZE`, `SYMBOL_TRADE_TICK_VALUE`, `SYMBOL_TRADE_CONTRACT_SIZE`).
  - XAUUSD (Gold): Digits=3, Contract=100 oz, Point=0.001, Tick Value=\$0.10.
  - XAGUSD (Silver): Digits=3, Contract=5000 oz, Point=0.001, Tick Value=\$5.00.
  - US500 (S&P 500): Digits=2, Contract=1.0, Point=0.01, Tick Value=\$0.01, Min Volume=0.14.
  - USTEC (Nasdaq 100): Digits=2, Contract=1.0, Point=0.01, Tick Value=\$0.01, Min Volume=0.05.
- **Testing Stages Standard**:
  - Stage A: Compile & Indicator Smoke Test.
  - Stage B: Fast screening.
  - Stage C: Historical validation (real ticks when available).
  - Stage D: Out-of-Sample chronological validation (minimum 30% unseen segment).
  - Stage E: Walk-forward robustness & parameter sensitivity testing.
- **Data Integrity & Provenance**: Every dataset must generate a machine-readable manifest recording canonical symbol, broker symbol, server, UTC range, row count, and SHA-256 hash.
- **Zero Fabrication**: Never fabricate fills, ticks, reports, win rates, or profitability claims.

---

## 10. MT5 Research Lab — Disciplined Research & Testing Methodology

### A. Core Objective
Establish a disciplined, professional MT5 EA research methodology to identify which strategies suit which instruments and timeframes. Optimize for **robust, repeatable performance**—never the highest backtest profit.

### B. Mandatory Testing Rules

1. **Test Selectively**:
   - Never run all EAs or instrument combinations automatically.
   - Test only combinations explicitly approved by the user.
   - Treat every EA–symbol–timeframe combination independently.
   - Zero live trading, EA logic mutations, Git commits, or remote pushes without explicit authorization.

2. **Understand the Strategy First**:
   - Thoroughly inspect the complete EA source code, entry/exit mechanics, indicators, filters, stop-loss/take-profit calculation, position sizing, trading sessions, and risk controls.
   - Identify intended market conditions and probable failure modes before selecting test parameters.

3. **Validate the Data**:
   - Audit date coverage, missing periods, duplicate timestamps, OHLC integrity, symbol specifications, time zones, and historical spread availability.
   - Rigorously distinguish genuine ticks, real-tick modelling, generated ticks, and 1-minute OHLC modelling.
   - Never describe synthetic or generated data as real ticks.

4. **Use Realistic Execution Assumptions**:
   - Account for broker-specific spread variations, commissions, overnight swaps, slippage, execution latency, minimum lot size, volume steps, contract size, tick value, margin, trading sessions, and weekend/holiday market closures.
   - Always query and enforce the correct live Exness symbol specifications.
   - Flag any assumption that cannot be verified empirically.

5. **Use a Staged Test Process**:
   - **Stage A**: Compile and inspect logic; identify implementation and risk-control defects.
   - **Stage B**: Run a baseline with documented default settings before optimizing.
   - **Stage C**: Evaluate strategy behaviour, trade quality, drawdown, costs, and failure cases.
   - **Stage D**: Optimize only a small, justified parameter set using a defined training period.
   - **Stage E**: Validate the selected configuration on untouched out-of-sample data.
   - **Stage F**: Perform walk-forward and parameter-sensitivity tests when sufficient quality data is available.
   - **Stage G**: Test alternate market regimes and realistic execution stress scenarios only when approved.

6. **Prevent Overfitting**:
   - Never select parameters solely because they maximize profit.
   - Avoid repeatedly tuning against the same out-of-sample period.
   - Compare neighbouring parameter values (parameter plateaus vs. fragile spikes).
   - Inspect trade distribution; flag results that depend on a few outlier trades or narrow market regimes.

7. **Evaluate the Right Metrics**:
   - Report net profit, return %, maximum equity drawdown, profit factor, expected payoff per trade, win rate, average win/loss ratio, trade count, market exposure, max consecutive losses, commissions, swaps, and recovery factor where available.
   - Include a benchmark and strictly distinguish balance drawdown from equity drawdown.
   - Report exact test dates, initial deposit, leverage, settings, modelling mode, and transaction costs.

8. **Judge Suitability, Not Just Profitability**:
   - Assess trend/range behaviour, volatility, spread relative to target size, trading frequency, stop distance, session effects, and instrument-specific contract rules.
   - Do not assume one configuration suits XAUUSD, XAGUSD, US500, USTEC, or every timeframe.
   - Reject or flag combinations that cannot be tested reliably with available data.

9. **Use Explicit Decision Gates**:
   - Categorize each result as:
     1. `Failed`
     2. `Inconclusive`
     3. `Promising but Unvalidated`
     4. `Robust Enough for Further Research`
   - Set minimum data-quality and sample-size requirements before testing.
   - Never invent universal thresholds or claim statistical certainty without evidence. A profitable backtest is not proof of future profitability.

10. **Preserve and Reproduce Everything**:
    - Save configuration files (`.set`, `.ini`), reports (`.html`, `.md`), logs, data provenance manifests, assumptions, errors, and test metadata in `C:\MT5_Research_Lab\`.
    - Keep raw data immutable.
    - Record any changes and their rationale. Never silently overwrite previous results.

### C. Current Project Restrictions
- **Approved Baseline**: The only approved baseline is `9_EMA_EA` on **XAUUSD M5**.
- **Standby Guardrail**: Do not start new tests, optimize `9_EMA_EA`, test additional pairs (XAGUSD, US500, USTEC), or modify EA logic until the user explicitly approves the next stage.
- **Lab Status**: Keep the research lab idle and ready for future use without starting further tests.

