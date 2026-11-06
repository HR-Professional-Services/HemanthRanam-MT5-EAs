import os
import re

repo_dir = r"C:\Users\vaibh\.gemini\antigravity-ide\scratch\HemanthRanam-MT5-EAs"
src_file = os.path.join(repo_dir, "00_UNIFIED_SYSTEM", "HR_UNIFIED_MULTI_STRATEGY_EA.mq5")

with open(src_file, "r", encoding="utf-8") as f:
    text = f.read()

# Let's locate the CBloombergTerminal class
start_term = text.find("class CBloombergTerminal")
end_term = text.find("class CQuantAnalyticsEngine")

print(f"CBloombergTerminal from {start_term} to {end_term}")

# Let's find InitInstruments
pos_init_inst = text.find("void InitInstruments()")
print(f"InitInstruments at {pos_init_inst}")

# Let's find RenderDashboard
pos_render_dash = text.find("void RenderDashboard()")
print(f"RenderDashboard at {pos_render_dash}")

# Let's find OnInit, OnDeinit, OnTimer, OnTick
pos_on_init = text.find("int OnInit()")
pos_on_deinit = text.find("void OnDeinit(")
pos_on_timer = text.find("void OnTimer()")
pos_on_tick = text.find("void OnTick()")
print(f"OnInit: {pos_on_init}, OnDeinit: {pos_on_deinit}, OnTimer: {pos_on_timer}, OnTick: {pos_on_tick}")
