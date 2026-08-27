#!/usr/bin/env python3
from pathlib import Path
source = Path(__file__).with_name("validate_v0320_somatic_contract.py").read_text(encoding="utf-8")
source = source.replace("static const int schemaVersion = 23;", "static const int schemaVersion = 31;")
source = source.replace(
    "不能据此越过当前 Session 的亲密边界",
    "它可以自然引出吸引、色色玩笑、身体联想、挑逗和更直接的亲密表达",
)
# Keep the frozen v0.32 contract intact while allowing the current release
# identity to move beyond the last version listed in that historical regex.
source = source.replace(
    "|4\\+79))\\s*$",
    "|4\\+79|5\\+80|6\\+81|7\\+82|8\\+83|9\\+84)|0\\.36\\.(?:0\\+85|1\\+86|2\\+87|3\\+88)|0\\.37\\.(?:0\\+89|1\\+90|2\\+91|3\\+92|4\\+93|5\\+94|6\\+95|7\\+96|8\\+97|9\\+98)|0\\.38\\.(?:0\\+99|1\\+100|2\\+101|3\\+102|4\\+103|5\\+104|6\\+105|7\\+106|8\\+107|9\\+108|10\\+109|11\\+110|12\\+111|13\\+112|14\\+113|15\\+114|16\\+115|18\\+117)|0\\.39\\.0\\+118)\\s*$",
)
exec(compile(source, "validate_v0320_somatic_contract.py", "exec"))
