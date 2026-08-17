#!/usr/bin/env python3
from pathlib import Path
source = Path(__file__).with_name("validate_v0320_somatic_contract.py").read_text(encoding="utf-8")
source = source.replace("static const int schemaVersion = 23;", "static const int schemaVersion = 24;")
exec(compile(source, "validate_v0320_somatic_contract.py", "exec"))
