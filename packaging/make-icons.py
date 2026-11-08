#!/usr/bin/env python3
"""Regenerate the platform icons from packaging/linux/io.github.generalkael.Wordloom.svg.

Writes packaging/windows/wordloom.ico, packaging/macos/Wordloom.icns and
crates/wordloom-app/qml/icons/wordloom.png (the window icon). Needs
rsvg-convert and Pillow. Run from anywhere:  python3 packaging/make-icons.py
"""
import io
import pathlib
import subprocess

from PIL import Image

root = pathlib.Path(__file__).resolve().parent.parent
svg = root / "packaging/linux/io.github.generalkael.Wordloom.svg"


def render(size):
    png = subprocess.run(
        ["rsvg-convert", "-w", str(size), "-h", str(size), str(svg)],
        check=True, capture_output=True,
    ).stdout
    return Image.open(io.BytesIO(png)).convert("RGBA")


big = render(1024)
render(256).save(root / "packaging/windows/wordloom.ico",
                 sizes=[(s, s) for s in (16, 20, 24, 32, 40, 48, 64, 128, 256)])
big.save(root / "packaging/macos/Wordloom.icns")
render(256).save(root / "crates/wordloom-app/qml/icons/wordloom.png", optimize=True)
print("Icons written.")
