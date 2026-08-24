#!/usr/bin/env python3
from pathlib import Path
source = Path(__file__).with_name("validate_v0341_image_vision.py").read_text(encoding="utf-8")
source = source.replace('"schema 23": "schemaVersion = 23" in db', '"schema 24": "schemaVersion = 24" in db')
exec(compile(source, "validate_v0341_image_vision.py", "exec"))
