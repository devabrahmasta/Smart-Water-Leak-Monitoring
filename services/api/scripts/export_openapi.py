"""
Skrip Ekspor OpenAPI Specification dari FastAPI ke packages/contracts/openapi.json (R-07).
Dijalankan via: make contracts atau python services/api/scripts/export_openapi.py
"""

import os
import sys
import json
from pathlib import Path

# Matikan scheduler agar tidak berjalan saat generate schema
os.environ["ENABLE_SCHEDULER"] = "false"

# Pastikan services/api berada dalam sys.path
api_dir = Path(__file__).resolve().parent.parent
if str(api_dir) not in sys.path:
    sys.path.insert(0, str(api_dir))

root_dir = api_dir.parent.parent
output_path = root_dir / "packages" / "contracts" / "openapi.json"

from app.main import app


def export_openapi():
    schema = app.openapi()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(schema, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print(f"OpenAPI schema successfully exported to: {output_path}")


if __name__ == "__main__":
    export_openapi()
