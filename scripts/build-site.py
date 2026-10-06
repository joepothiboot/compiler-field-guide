#!/usr/bin/env python3
"""Builds site/index.html, one page holding every markdown file:

    python3 scripts/build-site.py
"""
import os
import re

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "site", "index.html")
TEMPLATE = os.path.join(ROOT, "scripts", "site-template.html")
REPO = "https://github.com/joepothiboot/compiler-field-guide"
SKIP = {".git", ".pixi", "_templates", "site", "node_modules"}


def find_pages():
    pages = []
    for folder, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in SKIP]
        for name in files:
            if name.endswith(".md"):
                pages.append(os.path.relpath(os.path.join(folder, name), ROOT))
    return sorted(pages, key=sort_key)


def sort_key(path):
    folder, name = os.path.split(path)
    return (folder != "", folder, name != "README.md", name)


def page_tag(path):
    page_id = path[:-3]
    chapter = path.split(os.sep)[0] if os.sep in path else "root"
    text = open(os.path.join(ROOT, path), encoding="utf-8").read()
    text = re.sub(r"</script", r"<\\/script", text, flags=re.I)
    return f'<script type="text/markdown" id="{page_id}" data-chapter="{chapter}">{text}</script>'


def main():
    template = open(TEMPLATE, encoding="utf-8").read()
    tags = "\n".join(page_tag(p) for p in find_pages())
    html = template.replace("__PAGES__", tags).replace("__REPO__", REPO)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    open(OUT, "w", encoding="utf-8").write(html)
    print(f"wrote {OUT}")


main()
