import json
from pathlib import Path
from datetime import datetime
from talon.models import IOC

# ---- 1. Fetch ----
def fetch(mode: str):
    print(f"[TALON] Fetching in {mode} mode...")
    path = Path("tests/fixtures/talon/fake.json")
    if not path.exists():
        raise FileNotFoundError("fake.json not found!")
    with open(path, "r") as f:
        return json.load(f)

# ---- 2. Normalize ----
def normalize(raw_iocs: list) -> list[IOC]:
    print(f"[TALON] Normalizing {len(raw_iocs)} items...")
    normalized = []
    for item in raw_iocs:
        item["first_seen"] = datetime.fromisoformat(item["first_seen"])
        item["last_seen"] = datetime.fromisoformat(item["last_seen"])
        normalized.append(IOC(**item))
    return normalized

# ---- 3. Dedup (Stub for now) ----
def dedup(normalized_iocs: list[IOC]) -> list[IOC]:
    print(f"[TALON] Deduping (stub) {len(normalized_iocs)} items...")
    return normalized_iocs

# ---- 4. Export (CDB list) ----
def export(deduped_iocs: list[IOC]) -> str:
    print(f"[TALON] Exporting to CDB list...")
    export_path = Path("var/exports/talon-iocs.list")
    export_path.parent.mkdir(parents=True, exist_ok=True)
    with open(export_path, "w") as f:
        for ioc in deduped_iocs:
            f.write(f"{ioc.value}\n")
    print(f"[TALON] Output: {export_path}")
    return str(export_path)

# ---- Main Pipeline ----
def run_pipeline(mode: str = "offline"):
    print(">>> T.A.L.O.N. Pipeline Started <<<")
    raw = fetch(mode)
    normalized = normalize(raw)
    deduped = dedup(normalized)
    output = export(deduped)
    print(f">>> Finished. Output: {output} <<<")
    return output
