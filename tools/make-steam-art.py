#!/usr/bin/env python3
"""Generate Rift Play Steam artwork (gui/res/steam_*.png) from SVG templates. Needs ImageMagick."""
import os, subprocess, tempfile

RES = os.path.join(os.path.dirname(__file__), '..', 'gui', 'res')
GRAD = '''<linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#7cf3ff"/><stop offset="0.5" stop-color="#b48cff"/><stop offset="1" stop-color="#ff7ad9"/></linearGradient>
<linearGradient id="bg" x1="0" y1="0" x2="0.6" y2="1"><stop offset="0" stop-color="#1c1742"/><stop offset="0.6" stop-color="#0b0a1d"/><stop offset="1" stop-color="#050409"/></linearGradient>
<radialGradient id="glow"><stop offset="0" stop-color="#9d7bff" stop-opacity="0.45"/><stop offset="1" stop-color="#9d7bff" stop-opacity="0"/></radialGradient>
<radialGradient id="glow2"><stop offset="0" stop-color="#7cf3ff" stop-opacity="0.25"/><stop offset="1" stop-color="#7cf3ff" stop-opacity="0"/></radialGradient>'''

def mark(x, y, s, solid='#f4efff'):
    return f'''<g transform="translate({x} {y}) scale({s})">
<path d="M120 20 L98 88 L122 106 L76 178 L98 193 L56 276 L67 199 L44 184 L84 116 L62 100 Z" fill="{solid}"/>
<g fill="none" stroke="url(#g)" stroke-width="9" stroke-linecap="round" stroke-linejoin="round">
<polygon points="178,52 202,92 154,92"/><circle cx="192" cy="176" r="21"/>
<rect x="-8" y="70" width="38" height="38" rx="4" transform="rotate(-18 11 89)"/>
<path d="M-4 190 L28 222 M28 190 L-4 222"/></g></g>'''

def word(x, y, size, anchor='middle'):
    return f'<text x="{x}" y="{y}" text-anchor="{anchor}" font-family="sans-serif" font-weight="bold" font-size="{size}" letter-spacing="{size*0.14:.0f}" fill="white">RIFT PLAY</text>'

def bg(w, h):
    return f'''<rect width="{w}" height="{h}" fill="url(#bg)"/>
<ellipse cx="{w*0.3}" cy="{h*0.35}" rx="{max(w,h)*0.6}" ry="{max(w,h)*0.5}" fill="url(#glow)"/>
<ellipse cx="{w*0.85}" cy="{h*0.8}" rx="{max(w,h)*0.4}" ry="{max(w,h)*0.35}" fill="url(#glow2)"/>'''

def svg(w, h, body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}"><defs>{GRAD}</defs>{body}</svg>'

ART = {
    'steam_landscape.png': svg(920, 430, bg(920, 430) + mark(90, 70, 1.05) + word(600, 245, 76)),
    'steam_portrait.png': svg(600, 900, bg(600, 900) + mark(160, 170, 1.4) + word(300, 680, 70)),
    'steam_hero.png': svg(3840, 1240, bg(3840, 1240) + mark(2700, 180, 3.2, solid='#f4efff')),
    'steam_logo.png': svg(1280, 720, mark(150, 210, 1.15) + word(800, 420, 110)),
    'steam_icon.png': svg(184, 184, f'<rect width="184" height="184" rx="40" fill="url(#bg)"/>' + mark(42, 18, 0.5)),
}

for name, data in ART.items():
    with tempfile.NamedTemporaryFile('w', suffix='.svg', delete=False) as f:
        f.write(data)
    subprocess.run(['magick', '-background', 'none', f.name, os.path.join(RES, name)], check=True)
    os.unlink(f.name)
    print('wrote', name)
