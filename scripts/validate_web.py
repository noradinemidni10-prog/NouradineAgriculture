#!/usr/bin/env python3
"""Validate the academy's HTML, JavaScript, service worker, and PWA manifest."""

import json
import pathlib
import subprocess
import tempfile

import html5lib

ROOT = pathlib.Path(__file__).resolve().parents[1]
HTML_FILE = ROOT / "index.html"
MANIFEST_FILE = ROOT / "manifest.webmanifest"
SERVICE_WORKER_FILE = ROOT / "sw.js"
HTML_NS = "{http://www.w3.org/1999/xhtml}"


def require(condition, message):
    if not condition:
        raise SystemExit("VALIDATION FAILED: " + message)


def main():
    html = HTML_FILE.read_text(encoding="utf-8")
    parser = html5lib.HTMLParser(strict=True)
    document = parser.parse(html)

    require(document.get("lang") == "ar", "HTML language must be Arabic (lang='ar').")
    require(document.get("dir") == "rtl", "HTML direction must be right-to-left.")
    require('name="viewport"' in html.lower(), "Responsive viewport meta tag is missing.")
    require('rel="manifest"' in html.lower(), "PWA manifest link is missing.")

    scripts = document.findall(".//" + HTML_NS + "script")
    inline_scripts = [
        "".join(script.itertext())
        for script in scripts
        if not script.get("src") and "".join(script.itertext()).strip()
    ]
    require(inline_scripts, "No inline JavaScript was found to validate.")

    with tempfile.TemporaryDirectory() as temp_dir:
        for number, source in enumerate(inline_scripts, start=1):
            script_path = pathlib.Path(temp_dir) / f"inline-{number}.js"
            script_path.write_text(source, encoding="utf-8")
            subprocess.run(["node", "--check", str(script_path)], check=True)

    subprocess.run(["node", "--check", str(SERVICE_WORKER_FILE)], check=True)

    manifest = json.loads(MANIFEST_FILE.read_text(encoding="utf-8"))
    for field in ("name", "short_name", "start_url", "scope", "display", "icons"):
        require(manifest.get(field), f"PWA manifest field '{field}' is missing.")

    require(
        manifest["display"] in ("standalone", "fullscreen", "minimal-ui"),
        "PWA display mode must support an installable app experience.",
    )
    require(isinstance(manifest["icons"], list) and manifest["icons"], "PWA icons are missing.")

    for icon in manifest["icons"]:
        icon_path = (ROOT / icon["src"]).resolve()
        require(icon_path.is_file(), f"PWA icon file does not exist: {icon['src']}")

    require(
        "serviceWorker.register" in html,
        "The page does not register its service worker.",
    )

    print("PASS: HTML5 document structure")
    print(f"PASS: {len(inline_scripts)} inline JavaScript block(s)")
    print("PASS: service worker JavaScript syntax")
    print("PASS: PWA manifest fields and icon files")
    print("PASS: service worker registration")


if __name__ == "__main__":
    main()
