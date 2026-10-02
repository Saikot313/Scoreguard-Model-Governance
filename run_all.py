"""Run the ScoreGuard model-monitoring and governance pipeline."""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
for step in ["01_generate_data.py", "02_scorecard.py", "04_monitoring.py"]:
    print(f"== {step}")
    subprocess.run([sys.executable, str(ROOT / "python" / step)], cwd=ROOT, check=True)
print("ScoreGuard monitoring and governance pipeline completed successfully.")
