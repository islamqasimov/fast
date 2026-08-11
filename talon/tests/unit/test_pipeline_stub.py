from talon.pipeline import run_pipeline
from pathlib import Path

def test_pipeline_runs_offline():
    output = run_pipeline(mode="offline")
    assert Path(output).exists()
    with open(output, "r") as f:
        lines = f.readlines()
        assert len(lines) >= 1
