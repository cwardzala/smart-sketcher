#!/usr/bin/env python3
"""
Generate app icons from assets/smart-sketcher-icon-512.svg.

Outputs:
  assets/Icon.icns                                  — macOS app icon
  assets/icon_preview.png                           — 512px preview
  apps/apple/.../AppIcon.appiconset/icon_*.png      — Xcode asset catalog
"""

import io
import shutil
import subprocess
from pathlib import Path

import cairosvg
from PIL import Image

REPO_ROOT = Path(__file__).parent.parent
SVG_SOURCE = REPO_ROOT / "assets" / "smart-sketcher-icon-512.svg"

ICONSET_ENTRIES = [
    ("icon_16x16.png",        16),
    ("icon_16x16@2x.png",     32),
    ("icon_32x32.png",        32),
    ("icon_32x32@2x.png",     64),
    ("icon_128x128.png",     128),
    ("icon_128x128@2x.png",  256),
    ("icon_256x256.png",     256),
    ("icon_256x256@2x.png",  512),
    ("icon_512x512.png",     512),
    ("icon_512x512@2x.png", 1024),
]


def render(size: int) -> Image.Image:
    """Rasterise the SVG at the given pixel size."""
    png_bytes = cairosvg.svg2png(
        url=str(SVG_SOURCE),
        output_width=size,
        output_height=size,
    )
    assert isinstance(png_bytes, bytes)
    return Image.open(io.BytesIO(png_bytes)).convert("RGBA")


def build_icns(out_path: Path) -> None:
    iconset_dir = out_path.parent / "Icon.iconset"
    iconset_dir.mkdir(parents=True, exist_ok=True)

    rendered: dict[int, Image.Image] = {}
    for filename, size in ICONSET_ENTRIES:
        if size not in rendered:
            print(f"  rendering {size}×{size}…")
            rendered[size] = render(size)
        rendered[size].save(iconset_dir / filename)

    subprocess.run(
        ["iconutil", "-c", "icns", str(iconset_dir), "-o", str(out_path)],
        check=True,
    )
    shutil.rmtree(iconset_dir)
    print(f"✓ Written: {out_path}")


def build_png(out_path: Path, size: int = 512) -> None:
    render(size).save(out_path)
    print(f"✓ Written: {out_path}")


def build_appiconset(out_dir: Path) -> None:
    """Write PNGs into an Xcode AppIcon.appiconset directory."""
    out_dir.mkdir(parents=True, exist_ok=True)
    sizes = [16, 32, 64, 128, 256, 512, 1024]
    rendered: dict[int, Image.Image] = {}
    for size in sizes:
        if size not in rendered:
            print(f"  rendering {size}×{size}…")
            rendered[size] = render(size)
        rendered[size].save(out_dir / f"icon_{size}.png")
    print(f"✓ Written: {out_dir}")


if __name__ == "__main__":
    assets = REPO_ROOT / "assets"
    assets.mkdir(exist_ok=True)

    print("Building Icon.icns…")
    build_icns(assets / "Icon.icns")

    print("Building icon_preview.png…")
    build_png(assets / "icon_preview.png", 512)

    print("Building Xcode AppIcon.appiconset…")
    appiconset = (
        REPO_ROOT
        / "apps/apple/SmartSketcher/Assets.xcassets/AppIcon.appiconset"
    )
    build_appiconset(appiconset)
