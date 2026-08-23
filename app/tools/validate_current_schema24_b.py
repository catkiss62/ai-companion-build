#!/usr/bin/env python3
from pathlib import Path
source = Path(__file__).with_name("validate_v0320_somatic_contract.py").read_text(encoding="utf-8")
source = source.replace("static const int schemaVersion = 23;", "static const int schemaVersion = 24;")
# Keep the frozen v0.32 contract intact while allowing the current release
# identity to move beyond the last version listed in that historical regex.
source = source.replace(
    "|4\\+79))\\s*$",
    "|4\\+79|5\\+80|6\\+81|7\\+82|8\\+83|9\\+84)|0\\.36\\.(?:0\\+85|1\\+86|2\\+87|3\\+88)|0\\.37\\.(?:0\\+89|1\\+90|2\\+91|3\\+92|4\\+93|5\\+94))\\s*$",
)
exec(compile(source, "validate_v0320_somatic_contract.py", "exec"))
