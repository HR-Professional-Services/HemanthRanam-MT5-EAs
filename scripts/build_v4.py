import os
import shutil
import re

terminal_experts_dir = r"C:\Users\vaibh\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\06_MULTI_PAIR_SCANNERS\HR_UNIFIED_MASTER_OS_V4_FINAL"
terminal_backup_dir = r"C:\Users\vaibh\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Files\Backup"
repo_dir = r"C:\Users\vaibh\.gemini\antigravity-ide\scratch\HemanthRanam-MT5-EAs"
repo_target_dir = os.path.join(repo_dir, "06_MULTI_PAIR_SCANNERS", "HR_UNIFIED_MASTER_OS_V4_FINAL")

src_file = os.path.join(repo_dir, "00_UNIFIED_SYSTEM", "HR_UNIFIED_MULTI_STRATEGY_EA.mq5")
with open(src_file, "r", encoding="utf-8") as f:
    orig = f.read()

# Let's inspect the sections in orig
print("Read original, bytes:", len(orig))
