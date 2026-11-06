import os
import re

repo_dir = r"C:\Users\vaibh\.gemini\antigravity-ide\scratch\HemanthRanam-MT5-EAs"
src_file = os.path.join(repo_dir, "00_UNIFIED_SYSTEM", "HR_UNIFIED_MULTI_STRATEGY_EA.mq5")
with open(src_file, "r", encoding="utf-8") as f:
    text = f.read()

start_term = text.find("class CBloombergTerminal")
end_term = text.find("class CQuantAnalyticsEngine")
term_code = text[start_term:end_term]

# We need to adapt term_code into HR_Dashboard_Premium.mqh:
# 1. Add flicker state member:
#    BloombergFlickerState m_flicker;
# 2. Add flicker check methods or integrate directly into RenderTerminal
# 3. Update DrawTrajectoryArea to plot actual ema9_history if available
# 4. Use flicker colors when active

# Let's inspect where DrawTrajectoryArea is defined
draw_traj_pos = term_code.find("void DrawTrajectoryArea(")
print("DrawTrajectoryArea pos:", draw_traj_pos)
