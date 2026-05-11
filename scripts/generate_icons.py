#!/usr/bin/env python3
"""
Generates JabJournal app icon PNGs for all platforms using rsvg-convert.

Usage: python3 scripts/generate_icons.py
"""

import os
import subprocess
import tempfile
import sys

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

VARIANTS = {
    'ocean':    '#0A2342',
    'forest':   '#0C3320',
    'amethyst': '#1E0F3D',
    'slate':    '#1D2B3A',
}

# Syringe icon SVG template. {bg} is replaced per variant.
# 1024×1024 canvas, syringe rotated 45° clockwise so needle points upper-right.
# Needle tip lands at ~(807, 217), plunger at ~(217, 807) — ~21% padding from edges.
SVG_TEMPLATE = '''\
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <rect width="1024" height="1024" fill="{bg}"/>
  <g transform="rotate(45, 512, 512)">
    <!-- Needle tip: triangle pointing upward before rotation -->
    <polygon points="499,238 525,238 512,98" fill="white"/>
    <!-- Barrel: main cylindrical body, spans y=234 to y=740 -->
    <rect x="452" y="234" width="120" height="506" rx="16" fill="white"/>
    <!-- Thumb ring / flange -->
    <rect x="422" y="738" width="180" height="62" rx="16" fill="white"/>
    <!-- Plunger rod -->
    <rect x="502" y="798" width="20" height="131" rx="10" fill="white"/>
  </g>
  <!-- Journal graduation marks inside barrel (drawn on top of barrel) -->
  <g transform="rotate(45, 512, 512)" fill="black" opacity="0.22">
    <rect x="471" y="370" width="82" height="18" rx="9"/>
    <rect x="471" y="485" width="82" height="18" rx="9"/>
    <rect x="471" y="600" width="82" height="18" rx="9"/>
  </g>
</svg>
'''


def render(svg_path: str, output_path: str, size: int) -> None:
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    subprocess.run(
        ['rsvg-convert', '-w', str(size), '-h', str(size), svg_path, '-o', output_path],
        check=True, capture_output=True
    )


def make_svg(bg_color: str) -> str:
    """Write a temp SVG file for the given background color and return its path."""
    f = tempfile.NamedTemporaryFile(suffix='.svg', mode='w', delete=False)
    f.write(SVG_TEMPLATE.format(bg=bg_color))
    f.close()
    return f.name


def generate_android(svgs: dict) -> None:
    densities = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
    res = os.path.join(BASE_DIR, 'android', 'app', 'src', 'main', 'res')

    for density, size in densities.items():
        d = os.path.join(res, f'mipmap-{density}')
        render(svgs['ocean'], os.path.join(d, 'ic_launcher.png'), size)
        render(svgs['ocean'], os.path.join(d, 'ic_launcher_round.png'), size)
        for variant in ('forest', 'amethyst', 'slate'):
            render(svgs[variant], os.path.join(d, f'ic_launcher_{variant}.png'), size)

    print('  Android PNGs done')


def generate_ios_main(svg_ocean: str) -> None:
    appiconset = os.path.join(
        BASE_DIR, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset'
    )
    sizes = {
        'Icon-App-20x20@1x.png':      20,
        'Icon-App-20x20@2x.png':      40,
        'Icon-App-20x20@3x.png':      60,
        'Icon-App-29x29@1x.png':      29,
        'Icon-App-29x29@2x.png':      58,
        'Icon-App-29x29@3x.png':      87,
        'Icon-App-40x40@1x.png':      40,
        'Icon-App-40x40@2x.png':      80,
        'Icon-App-40x40@3x.png':     120,
        'Icon-App-60x60@2x.png':     120,
        'Icon-App-60x60@3x.png':     180,
        'Icon-App-76x76@1x.png':      76,
        'Icon-App-76x76@2x.png':     152,
        'Icon-App-83.5x83.5@2x.png': 167,
        'Icon-App-1024x1024@1x.png': 1024,
    }
    for filename, size in sizes.items():
        render(svg_ocean, os.path.join(appiconset, filename), size)
    print('  iOS main AppIcon done')


def generate_ios_alternates(svgs: dict) -> None:
    runner = os.path.join(BASE_DIR, 'ios', 'Runner')
    for variant in ('forest', 'amethyst', 'slate'):
        name = variant.capitalize()
        render(svgs[variant], os.path.join(runner, f'AppIcon{name}.png'), 60)
        render(svgs[variant], os.path.join(runner, f'AppIcon{name}@2x.png'), 120)
        render(svgs[variant], os.path.join(runner, f'AppIcon{name}@3x.png'), 180)
    print('  iOS alternate icons done')


def generate_macos(svg_ocean: str) -> None:
    appiconset = os.path.join(
        BASE_DIR, 'macos', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset'
    )
    sizes = {
        'app_icon_16.png':   16,
        'app_icon_32.png':   32,
        'app_icon_64.png':   64,
        'app_icon_128.png': 128,
        'app_icon_256.png': 256,
        'app_icon_512.png': 512,
        'app_icon_1024.png': 1024,
    }
    for filename, size in sizes.items():
        render(svg_ocean, os.path.join(appiconset, filename), size)
    print('  macOS AppIcon done')


def generate_web(svg_ocean: str) -> None:
    web_icons = os.path.join(BASE_DIR, 'web', 'icons')
    render(svg_ocean, os.path.join(web_icons, 'Icon-192.png'), 192)
    render(svg_ocean, os.path.join(web_icons, 'Icon-512.png'), 512)
    render(svg_ocean, os.path.join(web_icons, 'Icon-maskable-192.png'), 192)
    render(svg_ocean, os.path.join(web_icons, 'Icon-maskable-512.png'), 512)
    print('  Web icons done')


def generate_in_app_previews(svgs: dict) -> None:
    icons_dir = os.path.join(BASE_DIR, 'assets', 'icons')
    for variant in ('ocean', 'forest', 'amethyst', 'slate'):
        render(svgs[variant], os.path.join(icons_dir, f'icon_{variant}.png'), 192)
    print('  In-app preview icons done')


def main() -> None:
    # Check rsvg-convert is available
    result = subprocess.run(['which', 'rsvg-convert'], capture_output=True)
    if result.returncode != 0:
        print('Error: rsvg-convert not found. Install with: brew install librsvg')
        sys.exit(1)

    print('Generating JabJournal icons...')

    svgs = {}
    try:
        for variant, bg in VARIANTS.items():
            svgs[variant] = make_svg(bg)

        generate_android(svgs)
        generate_ios_main(svgs['ocean'])
        generate_ios_alternates(svgs)
        generate_macos(svgs['ocean'])
        generate_web(svgs['ocean'])
        generate_in_app_previews(svgs)

    finally:
        for path in svgs.values():
            if os.path.exists(path):
                os.unlink(path)

    print('Done. All icon assets regenerated.')


if __name__ == '__main__':
    main()
