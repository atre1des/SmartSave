"""Validate the local landing-page links and assemble the static site."""
from html.parser import HTMLParser
from pathlib import Path
from shutil import copy2, copytree
from urllib.parse import urlsplit


class Page(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids = set()
        self.links = []
        self.headings = []

    def handle_starttag(self, tag, attributes):
        attrs = dict(attributes)
        element_id = attrs.get("id")
        if element_id:
            if element_id in self.ids:
                raise ValueError(f"Duplicate ID: {element_id}")
            self.ids.add(element_id)
        for key in ("href", "src"):
            if attrs.get(key):
                self.links.append(attrs[key])
        if tag == "meta" and attrs.get("property") == "og:image":
            self.links.append(attrs["content"])
        if tag in {"h1", "h2", "h3", "h4", "h5", "h6"}:
            self.headings.append(int(tag[1]))
        if tag == "img" and "alt" not in attrs:
            raise ValueError(f"Image has no alt attribute: {attrs['src']}")


root = Path(__file__).resolve().parent
page = Page()
page.feed((root / "index.html").read_text(encoding="utf-8"))
if page.headings[0] != 1 or page.headings.count(1) != 1:
    raise ValueError("Expected a single page heading")
if any(right > left + 1 for left, right in zip(page.headings, page.headings[1:])):
    raise ValueError("Heading levels must be sequential")
for link in page.links:
    target = urlsplit(link)
    if target.scheme or target.netloc:
        continue
    if target.path and not (root / target.path).is_file():
        raise ValueError(f"Missing local asset: {target.path}")
    if target.fragment and not target.path and target.fragment not in page.ids:
        raise ValueError(f"Missing page anchor: {target.fragment}")

output = root / "dist"
output.mkdir(exist_ok=True)
for name in ("index.html", "styles.css", "menu.js"):
    copy2(root / name, output / name)
copytree(root / "assets", output / "assets", dirs_exist_ok=True)
print(f"Validated {len(page.links)} references and built {output}")
