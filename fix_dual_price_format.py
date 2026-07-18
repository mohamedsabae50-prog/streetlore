import re

with open(r"D:\codes\streetlore\tools\seed.dart", "r", encoding="utf-8") as f:
    content = f.read()

pattern = re.compile(
    r"(\s+'is_hidden_gem':)\s*\n(\s+)'price_local_egp':\s*(\d+),\s*\n(\s+)'price_foreigner_egp':\s*(\d+),\s*\n(\s+)(false|true),",
    re.MULTILINE
)

def fix(m):
    indent = m.group(2)
    indent2 = m.group(4)
    indent3 = m.group(6)
    local = m.group(3)
    foreign = m.group(5)
    bool_val = m.group(7)
    return f"{m.group(1)} {bool_val},\n{indent}'price_local_egp': {local},\n{indent2}'price_foreigner_egp': {foreign},\n"

content = pattern.sub(fix, content)

with open(r"D:\codes\streetlore\tools\seed.dart", "w", encoding="utf-8") as f:
    f.write(content)

print("Fixed formatting")
