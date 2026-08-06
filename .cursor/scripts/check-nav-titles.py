import re
from collections import defaultdict
from pathlib import Path

root = Path(__file__).resolve().parents[2]
titles = defaultdict(list)
parents = []
orphans = []

for path in sorted(root.rglob("*.md")):
    if ".cursor" in path.parts or "_site" in path.parts:
        continue
    text = path.read_text(encoding="utf-8")
    m = re.match(r"---\s*\n(.*?)\n---", text, re.S)
    if not m:
        continue
    fm = m.group(1)
    title_m = re.search(r"^title:\s*(.+)$", fm, re.M)
    parent_m = re.search(r"^parent:\s*(.+)$", fm, re.M)
    title = title_m.group(1).strip() if title_m else None
    parent = parent_m.group(1).strip() if parent_m else None
    if title:
        titles[title].append(str(path.relative_to(root)))
    if parent:
        parents.append((str(path.relative_to(root)), parent))

print("DUPLICATE TITLES:")
for title, files in sorted(titles.items()):
    if len(files) > 1:
        print(f"  {title!r}:")
        for f in files:
            print(f"    - {f}")

title_set = set(titles)
print("\nORPHAN PARENT REFERENCES:")
for file, parent in parents:
    if parent not in title_set:
        print(f"  {file} -> parent {parent!r} (missing)")

print("\nTOP-LEVEL NAV (no parent):")
for path in sorted(root.rglob("*.md")):
    if ".cursor" in path.parts:
        continue
    text = path.read_text(encoding="utf-8")
    m = re.match(r"---\s*\n(.*?)\n---", text, re.S)
    if not m:
        continue
    fm = m.group(1)
    if re.search(r"^parent:", fm, re.M):
        continue
    title_m = re.search(r"^title:\s*(.+)$", fm, re.M)
    nav_m = re.search(r"^nav_order:\s*(\d+)", fm, re.M)
    if title_m:
        print(f"  nav_order={nav_m.group(1) if nav_m else '-':>2}  {title_m.group(1).strip()}")
