import shutil
import os

src_dir = r"C:\Users\vaibh\.gemini\antigravity-ide\scratch\HemanthRanam-MT5-EAs\06_MULTI_PAIR_SCANNERS\HR_UNIFIED_MASTER_OS_V4_FINAL"
dst_dir = r"C:\Users\vaibh\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\06_MULTI_PAIR_SCANNERS\HR_UNIFIED_MASTER_OS_V4_FINAL"

for f in os.listdir(src_dir):
    if f.endswith(".mqh") or f.endswith(".mq5"):
        src = os.path.join(src_dir, f)
        dst = os.path.join(dst_dir, f)
        shutil.copy2(src, dst)
        print("Copied", f)
