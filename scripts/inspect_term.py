import os

repo_dir = r"C:\Users\vaibh\.gemini\antigravity-ide\scratch\HemanthRanam-MT5-EAs"
src_file = os.path.join(repo_dir, "00_UNIFIED_SYSTEM", "HR_UNIFIED_MULTI_STRATEGY_EA.mq5")
with open(src_file, "r", encoding="utf-8") as f:
    text = f.read()

start_term = text.find("class CBloombergTerminal")
end_term = text.find("class CQuantAnalyticsEngine")
term_code = text[start_term:end_term]

# Check occurrences of m_canvas.Update()
print("m_canvas.Update() in term_code:", term_code.count("m_canvas.Update()"))
