"""
Validator untuk payload MQTT berdasarkan JSON Schema pada packages/contracts/schemas/.
"""

import json
import logging
from pathlib import Path
from typing import Dict, Any, Tuple, Optional
import jsonschema

from app.config import ROOT_DIR

logger = logging.getLogger(__name__)

SCHEMAS_DIR = ROOT_DIR / "packages" / "contracts" / "schemas"

# Cache skema yang sudah dimuat
_LOADED_SCHEMAS: Dict[str, Dict[str, Any]] = {}


def get_schema(schema_name: str) -> Dict[str, Any]:
    """
    Memuat skema JSON dari disk jika belum dimuat ke memori.
    """
    if schema_name not in _LOADED_SCHEMAS:
        schema_file = SCHEMAS_DIR / f"{schema_name}.json"
        if not schema_file.exists():
            raise FileNotFoundError(f"Skema JSON tidak ditemukan: {schema_file}")
        with open(schema_file, "r", encoding="utf-8") as f:
            _LOADED_SCHEMAS[schema_name] = json.load(f)
    return _LOADED_SCHEMAS[schema_name]


def validate_payload(schema_name: str, payload: Dict[str, Any]) -> Tuple[bool, Optional[str]]:
    """
    Memvalidasi payload terhadap JSON Schema.
    Mengembalikan (True, None) jika valid, atau (False, "pesan kesalahan") jika gagal.
    """
    try:
        schema = get_schema(schema_name)
        jsonschema.validate(instance=payload, schema=schema)
        return True, None
    except jsonschema.ValidationError as err:
        return False, f"Validasi skema '{schema_name}' gagal: {err.message}"
    except Exception as err:
        return False, f"Error saat validasi skema '{schema_name}': {str(err)}"

