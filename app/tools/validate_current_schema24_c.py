#!/usr/bin/env python3
from pathlib import Path
source = Path(__file__).with_name("validate_v0313_overlay_picker.py").read_text(encoding="utf-8")
source = source.replace('        "static const int schemaVersion = 23;",\n    ))', '        "static const int schemaVersion = 23;",\n        "static const int schemaVersion = 31;",\n        "static const int schemaVersion = 32;",\n        "static const int schemaVersion = 39;",\n        "static const int schemaVersion = 43;",\n    ))')
exec(compile(source, "validate_v0313_overlay_picker.py", "exec"))
