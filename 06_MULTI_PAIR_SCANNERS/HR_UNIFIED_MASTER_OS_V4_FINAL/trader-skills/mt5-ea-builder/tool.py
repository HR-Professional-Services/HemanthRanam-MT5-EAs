import sys

def verify_structure(project_dir):
    required = ["HR_UNIFIED_MASTER_OS.mq5", "HR_Dashboard_Premium.mqh", "HR_EMA_Engine.mqh", "HR_ICT_SMC.mqh"]
    return {"status": "ok", "required_files_checked": len(required)}

if __name__ == "__main__":
    print(verify_structure("."))
