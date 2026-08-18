#!/usr/bin/env python3
from pathlib import Path
source = Path(__file__).with_name("validate_v0320_somatic_contract.py").read_text(encoding="utf-8")
source = source.replace("static const int schemaVersion = 23;", "static const int schemaVersion = 24;")
# Keep the frozen v0.32 contract intact while allowing the current release
# identity to move beyond the last version listed in that historical regex.
source = source.replace(
    "|9\\+74))\\s*$",
    "|9\\+74)|0\\.35\\.0\\+75|0\\.35\\.1\\+76|0\\.35\\.2\\+77)\\s*$",
)
exec(compile(source, "validate_v0320_somatic_contract.py", "exec"))
