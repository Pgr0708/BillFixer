#!/usr/bin/env python3
"""Generate BillFixer screens 10-32 as Figma-importable SVG.

Every element carries an id -> Figma uses it as the layer name.
<text> imports as editable text; <rect>/<ellipse>/<path> as real vector nodes.
"""
import os, html

W, H = 390, 844
OUT = "screens"

# ── tokens (mirror of the Figma styles) ────────────────────────────────
NAVY="#0B2B5C"; NAVY2="#123A7A"; NAVY_DEEP="#07203F"
BLUE="#2E7DF6"; BLUE2="#5B9BFF"; BLUE_SOFT="#E8F1FE"; BLUE_PALE="#F4F8FF"
TEAL="#00BFA5"; TEAL2="#22D3BB"; TEAL_SOFT="#E2F9F5"
GREEN="#22C07A"; GREEN2="#3BDC93"; GREEN_SOFT="#E6F9EF"
AMBER="#F5A623"; AMBER2="#FFC554"; AMBER_SOFT="#FFF5E2"
RED="#EF4444"; RED_SOFT="#FEF0F0"
VIOLET="#7C6BFF"; VIOLET_SOFT="#F0EDFF"; PINK="#FF8FB1"
T1="#14213D"; T2="#4A5A75"; T3="#8492AB"; T4="#B4BECE"
WHITE="#FFFFFF"; BG="#F7F9FD"; LINE="#E9EEF6"
DBG="#0D1117"; DSURF="#161B26"; DLINE="#232B3A"
SKIN="#F5C9A4"; SKIN_D="#E6A97E"; HAIR="#2B2A45"; HAIR2="#3D3A5E"

FS="Plus Jakarta Sans"; FD="DM Sans"; FM="JetBrains Mono"
FO="Outfit"; FF="Figtree"; FL="Lora"

def esc(s): return html.escape(str(s), quote=True)

# ── primitives ─────────────────────────────────────────────────────────
def rect(id, x, y, w, h, r=0, fill=WHITE, op=None, stroke=None, sw=1, dash=None):
    a = f'<rect id="{esc(id)}" x="{x}" y="{y}" width="{w}" height="{h}"'
    if isinstance(r,(list,tuple)):
        # per-corner not supported by plain rect; approximate with uniform max
        a += f' rx="{max(r)}"'
    elif r: a += f' rx="{r}"'
    a += f' fill="{fill}"'
    if op is not None: a += f' fill-opacity="{op}"'
    if stroke: a += f' stroke="{stroke}" stroke-width="{sw}"'
    if dash: a += f' stroke-dasharray="{dash}"'
    return a + '/>'

def ell(id, cx, cy, rx, ry=None, fill=WHITE, op=None, stroke=None, sw=1):
    ry = rx if ry is None else ry
    a = f'<ellipse id="{esc(id)}" cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{fill}"'
    if op is not None: a += f' fill-opacity="{op}"'
    if stroke: a += f' stroke="{stroke}" stroke-width="{sw}"'
    return a + '/>'

def path(id, d, fill="none", stroke=None, sw=2, op=None, cap="round", join="round"):
    a = f'<path id="{esc(id)}" d="{d}" fill="{fill}"'
    if op is not None: a += f' fill-opacity="{op}"'
    if stroke: a += f' stroke="{stroke}" stroke-width="{sw}" stroke-linecap="{cap}" stroke-linejoin="{join}"'
    return a + '/>'

def txt(id, s, x, y, size=14, fill=T1, family=FS, weight=600, anchor="start",
        ls=None, op=None):
    a = (f'<text id="{esc(id)}" x="{x}" y="{y}" font-family="{family}" '
         f'font-size="{size}" font-weight="{weight}" fill="{fill}" text-anchor="{anchor}"')
    if ls is not None: a += f' letter-spacing="{ls}"'
    if op is not None: a += f' fill-opacity="{op}"'
    return a + f'>{esc(s)}</text>'

def lines(id, items, x, y, lh, size=14, fill=T2, family=FD, weight=400, anchor="start"):
    """multi-line text as separate <text> so Figma keeps each line editable"""
    return g(id, [txt(f"{id} line {i+1}", s, x, y + i*lh, size, fill, family, weight, anchor)
                  for i, s in enumerate(items)])

def g(id, children, transform=None, op=None):
    a = f'<g id="{esc(id)}"'
    if transform: a += f' transform="{transform}"'
    if op is not None: a += f' opacity="{op}"'
    return a + '>' + "".join(children) + '</g>'

def icon(id, d, color, x, y, size=24, sw=2, fill=False):
    sc = size/24.0
    inner = (f'<path d="{d}" fill="{color}"/>' if fill else
             f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{sw}" '
             f'stroke-linecap="round" stroke-linejoin="round"/>')
    return f'<g id="{esc(id)}" transform="translate({x},{y}) scale({sc:.4f})">{inner}</g>'

# ── icon path data (M/L/C/Z only, Figma-safe) ──────────────────────────
I = {
 "back":  "M15 6 L9 12 L15 18",
 "chev":  "M9 6 L15 12 L9 18",
 "chevD": "M6 9 L12 15 L18 9",
 "plus":  "M12 5 L12 19 M5 12 L19 12",
 "check": "M4 12 L10 18 L20 6",
 "x":     "M18 6 L6 18 M6 6 L18 18",
 "search":"M18 11 C18 14.9 14.9 18 11 18 C7.1 18 4 14.9 4 11 C4 7.1 7.1 4 11 4 C14.9 4 18 7.1 18 11 Z M20 20 L15.7 15.7",
 "bell":  "M18 8 C18 4.7 15.3 2 12 2 C8.7 2 6 4.7 6 8 C6 15 3 16 3 16 L21 16 C21 16 18 15 18 8 Z M13.7 21 C13.3 21.6 12.7 22 12 22 C11.3 22 10.7 21.6 10.3 21",
 "doc":   "M14 2 L6 2 C4.9 2 4 2.9 4 4 L4 20 C4 21.1 4.9 22 6 22 L18 22 C19.1 22 20 21.1 20 20 L20 8 Z M14 2 L14 8 L20 8",
 "mail":  "M2 7 C2 5.9 2.9 5 4 5 L20 5 C21.1 5 22 5.9 22 7 L22 17 C22 18.1 21.1 19 20 19 L4 19 C2.9 19 2 18.1 2 17 Z M2 7 L12 14 L22 7",
 "phone": "M22 16.9 L22 19.9 C22 21.1 21 22 19.8 21.9 C16.7 21.6 13.8 20.5 11.2 18.9 C8.8 17.4 6.8 15.4 5.2 12.9 C3.6 10.3 2.5 7.3 2.2 4.1 C2.1 3 3 2 4.1 2 L7.1 2 C8.1 2 9 2.7 9.1 3.7 C9.2 4.7 9.5 5.6 9.8 6.5 C10.1 7.2 9.9 8.1 9.3 8.6 L8.1 9.9 C9.6 12.5 11.5 14.4 14.1 15.9 L15.4 14.6 C15.9 14 16.8 13.8 17.5 14.1 C18.4 14.4 19.3 14.7 20.3 14.8 C21.3 14.9 22 15.8 22 16.9 Z",
 "shield":"M12 2 L20 6 L20 12 C20 17 16.6 20.8 12 22 C7.4 20.8 4 17 4 12 L4 6 Z",
 "shieldC":"M12 2 L20 6 L20 12 C20 17 16.6 20.8 12 22 C7.4 20.8 4 17 4 12 L4 6 Z M8.5 12 L11 14.5 L16 9",
 "cam":   "M23 19 C23 20.1 22.1 21 21 21 L3 21 C1.9 21 1 20.1 1 19 L1 8 C1 6.9 1.9 6 3 6 L7 6 L9 3 L15 3 L17 6 L21 6 C22.1 6 23 6.9 23 8 Z M16 13 C16 15.2 14.2 17 12 17 C9.8 17 8 15.2 8 13 C8 10.8 9.8 9 12 9 C14.2 9 16 10.8 16 13 Z",
 "clock": "M12 21 C7 21 3 17 3 12 C3 7 7 3 12 3 C17 3 21 7 21 12 C21 17 17 21 12 21 Z M12 7 L12 12 L15 14",
 "warn":  "M10.3 3.9 L1.8 18 C1.4 18.7 1.9 19.6 2.7 19.6 L21.3 19.6 C22.1 19.6 22.6 18.7 22.2 18 L13.7 3.9 C13.3 3.2 12.3 3.2 11.9 3.9 Z M12 9 L12 13 M12 17 L12.01 17",
 "info":  "M12 22 C6.5 22 2 17.5 2 12 C2 6.5 6.5 2 12 2 C17.5 2 22 6.5 22 12 C22 17.5 17.5 22 12 22 Z M12 16 L12 12 M12 8 L12.01 8",
 "trash": "M3 6 L21 6 M8 6 L8 4 C8 2.9 8.9 2 10 2 L14 2 C15.1 2 16 2.9 16 4 L16 6 M19 6 L18 20 C18 21.1 17.1 22 16 22 L8 22 C6.9 22 6 21.1 6 20 L5 6",
 "share": "M4 12 L4 20 C4 21.1 4.9 22 6 22 L18 22 C19.1 22 20 21.1 20 20 L20 12 M16 6 L12 2 L8 6 M12 2 L12 16",
 "copy":  "M9 9 L19 9 C20.1 9 21 9.9 21 11 L21 19 C21 20.1 20.1 21 19 21 L11 21 C9.9 21 9 20.1 9 19 Z M5 15 L4 15 C2.9 15 2 14.1 2 13 L2 4 C2 2.9 2.9 2 4 2 L13 2 C14.1 2 15 2.9 15 4 L15 5",
 "crown": "M3 18 L5 7 L9.5 12 L12 5 L14.5 12 L19 7 L21 18 Z",
 "edit":  "M11 4 L6 4 C4.9 4 4 4.9 4 6 L4 18 C4 19.1 4.9 20 6 20 L18 20 C19.1 20 20 19.1 20 18 L20 13 M18.5 2.5 C19.3 1.7 20.7 1.7 21.5 2.5 C22.3 3.3 22.3 4.7 21.5 5.5 L12 15 L8 16 L9 12 Z",
 "folder":"M4 6 C4 4.9 4.9 4 6 4 L10 4 L12 7 L18 7 C19.1 7 20 7.9 20 9 L20 18 C20 19.1 19.1 20 18 20 L6 20 C4.9 20 4 19.1 4 18 Z",
 "home":  "M3 10 L12 3 L21 10 L21 20 C21 21.1 20.1 22 19 22 L5 22 C3.9 22 3 21.1 3 20 Z",
 "cases": "M3 7 C3 5.9 3.9 5 5 5 L10 5 L12 7 L19 7 C20.1 7 21 7.9 21 9 L21 18 C21 19.1 20.1 20 19 20 L5 20 C3.9 20 3 19.1 3 18 Z",
 "learn": "M4 4 L10 4 C11.7 4 13 5.3 13 7 L13 20 C13 18.6 11.9 17.5 10.5 17.5 L4 17.5 Z M20 4 L14 4 C12.3 4 11 5.3 11 7 L11 20 C11 18.6 12.1 17.5 13.5 17.5 L20 17.5 Z",
 "gear":  "M4 21 L4 14 M4 10 L4 3 M12 21 L12 12 M12 8 L12 3 M20 21 L20 16 M20 12 L20 3 M1 14 L7 14 M9 8 L15 8 M17 16 L23 16",
 "user":  "M20 21 L20 19 C20 16.8 18.2 15 16 15 L8 15 C5.8 15 4 16.8 4 19 L4 21 M16 7 C16 9.2 14.2 11 12 11 C9.8 11 8 9.2 8 7 C8 4.8 9.8 3 12 3 C14.2 3 16 4.8 16 7 Z",
 "star":  "M12 2 L15 8.5 L22 9.5 L17 14.5 L18.2 21.5 L12 18.2 L5.8 21.5 L7 14.5 L2 9.5 L9 8.5 Z",
 "up":    "M12 19 L12 5 M5 12 L12 5 L19 12",
 "send":  "M22 2 L11 13 M22 2 L15 22 L11 13 L2 9 Z",
 "arrowR":"M5 12 L19 12 M13 6 L19 12 L13 18",
 "lock":  "M4 11 L20 11 C21.1 11 22 11.9 22 13 L22 19 C22 20.1 21.1 21 20 21 L4 21 C2.9 21 2 20.1 2 19 L2 13 C2 11.9 2.9 11 4 11 Z M7 11 L7 7 C7 4.2 9.2 2 12 2 C14.8 2 17 4.2 17 7 L17 11",
 "scale": "M12 3 L12 21 M4 7 L20 7 M6 7 L3 14 L9 14 Z M18 7 L21 14 L15 14 Z",
 "help":  "M12 22 C6.5 22 2 17.5 2 12 C2 6.5 6.5 2 12 2 C17.5 2 22 6.5 22 12 C22 17.5 17.5 22 12 22 Z M9.1 9 C9.6 7.6 11 6.8 12.4 7 C13.9 7.3 15 8.6 15 10.1 C15 12 12 13 12 13 M12 17 L12.01 17",
 "sparkle":"M12 1 L14.6 7.4 L21 10 L14.6 12.6 L12 19 L9.4 12.6 L3 10 L9.4 7.4 Z",
}

# ── shared chrome ──────────────────────────────────────────────────────
def status_bar(theme="dark"):
    ink = T1 if theme == "dark" else WHITE
    parts = [txt("Time", "9:41", 29, 44, 15, ink, FS, 700)]
    for i, (bx, by, bh) in enumerate([(0,7,4),(4.5,5,6),(9,2.5,8.5),(13.5,0,11)]):
        parts.append(rect(f"Signal bar {i+1}", 300+bx, 33+by, 3, bh, 0.7, ink))
    parts += [rect("Battery shell", 322, 33, 20, 11, 3, "none", None, ink, 1),
              rect("Battery fill", 324, 35, 15, 7, 1.8, ink),
              rect("Battery nub", 343.5, 36, 2, 5, 1, ink, 0.45)]
    return g("Status bar", parts)

def home_bar(theme="dark"):
    ink = T1 if theme == "dark" else WHITE
    return g("Home indicator", [rect("bar", 126, 831, 138, 5, 3, ink, 0.3)])

def tab_bar(active="Home", theme="light"):
    bg   = WHITE if theme=="light" else DSURF
    hair = LINE if theme=="light" else DLINE
    idle = "#9BA7BC" if theme=="light" else "#6B7689"
    act  = BLUE if theme=="light" else BLUE2
    y0 = 756
    parts = [rect("Tab bar bg", 0, y0, 390, 88, 0, bg),
             rect("Hairline", 0, y0, 390, 0.5, 0, hair)]
    cols = [("Home","home",39),("Cases","cases",117),("Learn","learn",273),("Settings","gear",351)]
    for label, ico, cx in cols:
        on = (label == active)
        c = act if on else idle
        parts.append(icon(f"{label} icon", I[ico], c, cx-12, y0+14, 24, 1.9))
        parts.append(txt(f"{label} label", label, cx, y0+52, 10.5, c, FS, 700 if on else 600, "middle"))
    parts += [ell("Scan ring", 195, y0+32, 32, 32, bg),
              ell("Scan button", 195, y0+32, 27, 27, "url(#gradBlue)"),
              icon("Scan icon", I["cam"], WHITE, 183, y0+20, 24, 2),
              txt("Scan label", "Scan", 195, y0+62, 10, idle, FS, 600, "middle")]
    return g("Tab bar", parts)

def card(id, x, y, w, h, r=18, fill=WHITE, shadow=True, stroke=None, sw=1):
    a = (f'<rect id="{esc(id)}" x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}"'
         + (f' stroke="{stroke}" stroke-width="{sw}"' if stroke else '')
         + (' filter="url(#shCard)"' if shadow else '') + '/>')
    return a

def pill(id, label, x, y, bg, fg, pad=10, size=11, dot=None):
    wpx = len(label) * size * 0.58 + pad*2 + (11 if dot else 0)
    parts = [rect(f"{id} bg", x, y, wpx, 24, 12, bg)]
    tx = x + pad
    if dot:
        parts.append(ell(f"{id} dot", x+pad+3, y+12, 3, 3, dot)); tx += 11
    parts.append(txt(f"{id} label", label, tx, y+16, size, fg, FS, 700))
    return g(id, parts), wpx

def button(id, label, x, y, w, h=56, fill="url(#gradNavy)", fg=WHITE, r=18,
           stroke=None, shadow="shBtnNavy", icon_path=None, size=17):
    parts = [f'<rect id="{esc(id)} bg" x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" '
             f'fill="{fill}"' + (f' stroke="{stroke}" stroke-width="1.5"' if stroke else '')
             + (f' filter="url(#{shadow})"' if shadow else '') + '/>']
    if icon_path:
        parts.append(icon(f"{id} icon", icon_path, fg, x+w/2-len(label)*size*0.29-16, y+h/2-10, 20, 2))
        parts.append(txt(f"{id} label", label, x+w/2+12, y+h/2+6, size, fg, FS, 700, "middle"))
    else:
        parts.append(txt(f"{id} label", label, x+w/2, y+h/2+6, size, fg, FS, 700, "middle"))
    return g(id, parts)

DEFS = f'''<defs>
<linearGradient id="gradNavy" x1="0" y1="0" x2="1" y2="1">
  <stop offset="0" stop-color="{NAVY2}"/><stop offset="1" stop-color="{NAVY}"/></linearGradient>
<linearGradient id="gradBlue" x1="0" y1="0" x2="1" y2="1">
  <stop offset="0" stop-color="{BLUE2}"/><stop offset="1" stop-color="{BLUE}"/></linearGradient>
<linearGradient id="gradTeal" x1="0" y1="0" x2="1" y2="1">
  <stop offset="0" stop-color="{TEAL2}"/><stop offset="1" stop-color="{TEAL}"/></linearGradient>
<linearGradient id="gradAmber" x1="0" y1="0" x2="1" y2="1">
  <stop offset="0" stop-color="{AMBER2}"/><stop offset="1" stop-color="{AMBER}"/></linearGradient>
<linearGradient id="gradGreen" x1="0" y1="0" x2="1" y2="1">
  <stop offset="0" stop-color="{GREEN2}"/><stop offset="1" stop-color="{GREEN}"/></linearGradient>
<linearGradient id="gradSplash" x1="0" y1="0" x2="0.7" y2="1">
  <stop offset="0" stop-color="{NAVY}"/><stop offset="0.36" stop-color="{NAVY2}"/>
  <stop offset="0.72" stop-color="#1B62C4"/><stop offset="1" stop-color="{BLUE}"/></linearGradient>
<linearGradient id="gradDark" x1="0" y1="0" x2="0.6" y2="1">
  <stop offset="0" stop-color="#0A0D14"/><stop offset="0.5" stop-color="#12161F"/>
  <stop offset="1" stop-color="#1A1A28"/></linearGradient>
<linearGradient id="gradSky" x1="0" y1="0" x2="0" y2="1">
  <stop offset="0" stop-color="#DCEEFF"/><stop offset="0.34" stop-color="#EBF5FF"/>
  <stop offset="1" stop-color="{WHITE}"/></linearGradient>
<linearGradient id="gradDonut" x1="0" y1="0" x2="1" y2="1">
  <stop offset="0" stop-color="{RED}"/><stop offset="0.42" stop-color="{AMBER}"/>
  <stop offset="0.72" stop-color="{BLUE}"/><stop offset="1" stop-color="{TEAL}"/></linearGradient>
<filter id="shCard" x="-30%" y="-30%" width="160%" height="180%">
  <feDropShadow dx="0" dy="3" stdDeviation="5" flood-color="#102346" flood-opacity="0.06"/>
  <feDropShadow dx="0" dy="10" stdDeviation="15" flood-color="#102346" flood-opacity="0.05"/></filter>
<filter id="shFloat" x="-30%" y="-30%" width="160%" height="180%">
  <feDropShadow dx="0" dy="6" stdDeviation="10" flood-color="#102346" flood-opacity="0.10"/>
  <feDropShadow dx="0" dy="16" stdDeviation="24" flood-color="#102346" flood-opacity="0.08"/></filter>
<filter id="shBtnNavy" x="-30%" y="-30%" width="160%" height="200%">
  <feDropShadow dx="0" dy="5" stdDeviation="7" flood-color="{NAVY}" flood-opacity="0.30"/></filter>
<filter id="shBtnBlue" x="-30%" y="-30%" width="160%" height="200%">
  <feDropShadow dx="0" dy="5" stdDeviation="7" flood-color="{BLUE}" flood-opacity="0.32"/></filter>
<filter id="shBtnAmber" x="-30%" y="-30%" width="160%" height="200%">
  <feDropShadow dx="0" dy="5" stdDeviation="8" flood-color="{AMBER}" flood-opacity="0.40"/></filter>
<filter id="shGold" x="-40%" y="-40%" width="180%" height="200%">
  <feDropShadow dx="0" dy="0" stdDeviation="10" flood-color="{AMBER}" flood-opacity="0.35"/></filter>
</defs>'''

def screen(name, body, bg=BG):
    bgel = (f'<rect id="Background" width="{W}" height="{H}" fill="{bg}"/>')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
            f'viewBox="0 0 {W} {H}" fill="none">\n{DEFS}\n'
            f'<g id="{esc(name)}">\n{bgel}\n{body}\n</g>\n</svg>\n')

def write(num, name, body, bg=BG):
    os.makedirs(OUT, exist_ok=True)
    slug = f"{num:02d}-{name.lower().replace(' ','-').replace('—','').replace('--','-').replace('/','-')}"
    slug = slug.replace("'", "")
    fn = os.path.join(OUT, slug + ".svg")
    with open(fn, "w") as f:
        f.write(screen(name, body, bg))
    return fn

# ══════════════════════════════════════════════════════════════════════
# SCREEN 10 — OCR Review
# ══════════════════════════════════════════════════════════════════════
def s10():
    p = [status_bar(), home_bar(),
      icon("Back", I["back"], BLUE, 26, 68, 24, 2.4),
      txt("Title", "Extracted Information", 195, 80, 17, T1, FS, 800, "middle", -0.4),
      rect("Progress track", 24, 108, 342, 6, 3, "#E4EBF5"),
      rect("Progress fill", 24, 108, 171, 6, 3, BLUE),
      txt("Step", "STEP 2 OF 4", 366, 134, 9.5, T3, FS, 700, "end", 1.4)]
    for i,(lbl,val) in enumerate([("Provider","Riverside Medical Center"),("Date of Service","Mar 15, 2024")]):
        y = 150 + i*76
        p += [card(f"Field {lbl}", 24, y, 342, 66, 16),
              txt(f"{lbl} label", lbl, 40, y+26, 10.5, T3, FS, 700, "start", 1.2),
              txt(f"{lbl} value", val, 40, y+50, 16, T1, FS, 700, "start", -0.2),
              icon(f"{lbl} edit", I["edit"], T4, 328, y+22, 20, 1.9)]
    p += [card("Field Total Amount", 24, 302, 342, 74, 16),
          rect("Low confidence rail", 24, 302, 5, 74, 2.5, AMBER),
          txt("Total label", "Total Amount", 42, 328, 10.5, T3, FS, 700, "start", 1.2),
          txt("Total value", "$2,845.00", 42, 356, 19, T1, FM, 700),
          rect("Low conf pill", 240, 328, 112, 26, 13, AMBER_SOFT),
          txt("Low conf label", "Low confidence", 296, 345, 10.5, "#B5730A", FS, 700, "middle"),
          card("Field Patient Responsibility", 24, 390, 342, 66, 16),
          txt("Resp label", "Patient Responsibility", 40, 416, 10.5, T3, FS, 700, "start", 1.2),
          txt("Resp value", "$1,234.56", 40, 440, 17, T1, FM, 700),
          icon("Resp edit", I["edit"], T4, 328, 412, 20, 1.9),
          card("Card Line Items", 24, 470, 342, 190, 16),
          txt("Line items title", "Line Items (12)", 40, 492, 14, T1, FS, 800, "start", -0.2),
          txt("Expand", "Expand", 350, 492, 12, BLUE, FS, 700, "end")]
    for i,(code,desc,amt,flag) in enumerate([("99284","Emergency Dept Visit","$850.00",False),
                                             ("71046","Chest X-Ray","$420.00",True),
                                             ("93000","EKG","$210.00",False)]):
        y = 518 + i*38
        if flag: p.append(rect("Duplicate row bg", 32, y-14, 326, 34, 8, RED, 0.06))
        p += [txt(f"Code {code}", code, 40, y+6, 11.5, RED if flag else T3, FM, 500),
              txt(f"Desc {code}", desc, 100, y+4, 13.5, T1, FS, 700 if flag else 500),
              txt(f"Amount {code}", amt, 350, y+4, 13.5, RED if flag else T1, FM, 700, "end")]
        if i < 2: p.append(rect(f"Divider {i+1}", 40, y+16, 310, 1, 0, "#F2F5F9"))
    p += [rect("Add line item box", 40, 610, 310, 38, 11, "none", None, "#CBD5E4", 1.5, "5 4"),
          icon("Add plus", I["plus"], BLUE, 130, 622, 14, 2.4),
          txt("Add label", "Add Line Item", 152, 634, 13, BLUE, FS, 700),
          button("Button Continue to Analysis", "Continue to Analysis", 24, 700, 342)]
    return g("Screen 10 OCR Review", p)

# ══════════════════════════════════════════════════════════════════════
# SCREEN 11 — Analysis Progress
# ══════════════════════════════════════════════════════════════════════
def s11():
    steps = [("Extracting text","Completed","done"),("Checking bill arithmetic","Completed","done"),
             ("Finding duplicate charges","In progress...","active"),("Comparing with your EOB",None,"idle"),
             ("Looking up hospital prices",None,"idle"),("Checking your rights",None,"idle"),
             ("Generating results",None,"idle")]
    p = [status_bar(), home_bar(),
      ell("Bokeh blue", 330, 120, 110, 110, BLUE_SOFT, 0.6),
      ell("Bokeh teal", 40, 300, 80, 80, TEAL_SOFT, 0.7),
      icon("Back", I["back"], BLUE, 26, 68, 24, 2.4),
      txt("Title", "Analyzing Your Bill", 195, 82, 20, T1, FS, 800, "middle", -0.6),
      txt("Subtitle", "Everything runs on-device first", 195, 106, 12.5, T3, FD, 400, "middle")]
    for i,(label, sub, state) in enumerate(steps):
        y = 146 + i*66
        if state == "done":
            p += [ell(f"Step {i+1} disc", 46, y+14, 15, 15, GREEN),
                  path(f"Step {i+1} check", f"M39 {y+14} L44 {y+19} L53 {y+8}", "none", WHITE, 2.6)]
        elif state == "active":
            p += [ell(f"Step {i+1} ring", 46, y+14, 14, 14, "none", None, BLUE_SOFT, 3),
                  path(f"Step {i+1} arc", f"M46 {y} C53.7 {y} 60 {y+6.3} 60 {y+14}", "none", BLUE, 3)]
        else:
            p.append(ell(f"Step {i+1} ring", 46, y+14, 13, 13, "none", None, "#DCE4EF", 2))
        op = None if state!="idle" else 0.55
        p.append(txt(f"Step {i+1} label", label, 78, y+12, 15,
                     T1 if state!="idle" else T3, FS, 700 if state!="idle" else 500, "start", None, op))
        if sub:
            p.append(txt(f"Step {i+1} status", sub, 78, y+30, 11.5,
                         GREEN if state=="done" else BLUE, FS, 600))
        if i < len(steps)-1:
            p.append(rect(f"Rail {i+1}", 45, y+30, 2, 36, 1, GREEN if state=="done" else "#E4EBF5"))
    p += [card("Card Estimate", 24, 620, 342, 96, 20, BLUE_SOFT, False),
          ell("Estimate avatar bg", 78, 668, 30, 30, WHITE, 0.8),
          icon("Estimate avatar", I["user"], BLUE, 66, 656, 24, 1.9),
          txt("Estimate line 1", "This usually takes 30–60 seconds.", 120, 660, 13, "#1E4C8A", FS, 700),
          txt("Estimate line 2", "We'll notify you when it's done.", 120, 680, 12.5, "#2E5A96", FD, 400)]
    return g("Screen 11 Analysis Progress", p)

# ══════════════════════════════════════════════════════════════════════
# SCREEN 12 — Results Overview
# ══════════════════════════════════════════════════════════════════════
def donut(cx, cy, r, sw, dash_offset=86, circ=465):
    return [ell("Donut track", cx, cy, r, r, "none", None, "#E9EEF5", sw),
            f'<circle id="Donut value" cx="{cx}" cy="{cy}" r="{r}" fill="none" '
            f'stroke="url(#gradDonut)" stroke-width="{sw}" stroke-linecap="round" '
            f'stroke-dasharray="{circ}" stroke-dashoffset="{dash_offset}" '
            f'transform="rotate(-90 {cx} {cy})"/>']

def s12(dark=False):
    bgc  = DBG if dark else BG
    surf = DSURF if dark else WHITE
    t1   = "#E6EBF4" if dark else T1
    t3   = "#7C8899" if dark else T3
    p = [status_bar("light" if dark else "dark"), home_bar("light" if dark else "dark"),
      icon("Back", I["back"], BLUE if not dark else BLUE2, 26, 68, 24, 2.4),
      txt("Title", "Analysis Complete", 195, 80, 17, t1, FS, 800, "middle", -0.4),
      icon("Share", I["share"], t3, 332, 68, 22, 2)]
    p += donut(195, 226, 74, 15)
    p += [txt("Findings count", "5", 195, 246, 52, t1, FS, 800, "middle", -2),
          txt("Findings label", "FINDINGS", 195, 270, 10, t3, FM, 500, "middle", 2.6)]
    chips = [("2","Strong",RED,RED_SOFT),("1","Likely",AMBER,AMBER_SOFT),
             ("1","Possible",BLUE,BLUE_SOFT),("1","Info",T3,"#EEF1F6")]
    for i,(n,lbl,c,bgp) in enumerate(chips):
        x = 24 + i*87
        p += [rect(f"Chip {lbl} bg", x, 336, 79, 62, 14, bgp if not dark else DSURF),
              txt(f"Chip {lbl} count", n, x+39.5, 364, 21, c, FS, 800, "middle"),
              txt(f"Chip {lbl} label", lbl, x+39.5, 384, 10.5, c, FS, 700, "middle")]
    p += [card("Card Overcharge", 24, 418, 342, 92, 20, AMBER_SOFT if not dark else "#2A2313", False,
               "#F8E3BC" if not dark else "#463A1B", 1.5),
          rect("Overcharge icon tile", 42, 438, 48, 48, 15, "url(#gradAmber)"),
          icon("Overcharge icon", I["sparkle"], WHITE, 54, 450, 24, 2, True),
          txt("Overcharge label", "You may be overcharged", 104, 456, 11.5, "#8A6208" if not dark else AMBER2, FS, 700),
          txt("Overcharge amount", "$892", 104, 488, 30, "#6B4A02" if not dark else AMBER2, FS, 800, "start", -1.2),
          txt("Overcharge sub", "Based on our analysis", 186, 486, 11.5, "#9A7420" if not dark else "#B99753", FD, 400),
          button("Button View Findings", "View Findings", 24, 532, 342, 56, "url(#gradTeal)", WHITE, 18, None, None, I["arrowR"]),
          txt("Jump label", "Or jump to an action", 195, 618, 11, t3, FM, 500, "middle", 2)]
    acts = [("Generate Letter", I["mail"]), ("Phone Script", I["phone"]), ("View Rights", I["shield"])]
    for i,(lbl,ico) in enumerate(acts):
        x = 24 + i*114
        p += [card(f"Action {lbl}", x, 636, 102, 82, 16, surf, not dark,
                   DLINE if dark else None, 1),
              icon(f"{lbl} icon", ico, BLUE if not dark else BLUE2, x+41, 656, 20, 1.9),
              txt(f"{lbl} label", lbl.split()[0], x+51, 700, 11.5, t1, FS, 700, "middle"),
              txt(f"{lbl} label 2", lbl.split()[1], x+51, 714, 11.5, t1, FS, 700, "middle")]
    return g("Screen 12 Results Overview", p)

# ══════════════════════════════════════════════════════════════════════
# SCREEN 13 — Finding Detail
# ══════════════════════════════════════════════════════════════════════
def s13():
    p = [status_bar(), home_bar(),
      icon("Back", I["back"], BLUE, 26, 68, 24, 2.4),
      rect("Strong finding pill", 138, 62, 114, 28, 14, RED),
      txt("Strong finding label", "Strong Finding", 195, 81, 11.5, WHITE, FS, 700, "middle"),
      icon("More", I["info"], T3, 334, 66, 20, 2),
      card("Card Finding", 24, 110, 342, 178, 20, RED_SOFT, False, "#F8D4D4", 1.5),
      rect("Finding icon tile", 42, 130, 46, 46, 14, WHITE),
      icon("Finding icon", I["warn"], RED, 53, 143, 24, 2),
      txt("Finding title", "Duplicate Charge Detected", 102, 150, 16.5, T1, FS, 800, "start", -0.4),
      txt("Finding amount", "$420.00", 102, 182, 28, RED, FM, 700, "start", -1),
      lines("Finding explanation", ["This charge appears 2 times on your bill",
                                    "for the same service and date."], 42, 226, 22, 13.5, "#8F2020", FD, 400),
      txt("Evidence heading", "Evidence", 24, 322, 12, T3, FS, 800, "start", 1.4)]
    for i,(ln, code, date, amt) in enumerate([("Line Item 3","71046 — Chest X-Ray","Mar 15, 2024","$420.00"),
                                              ("Line Item 7","71046 — Chest X-Ray","Mar 15, 2024","$420.00")]):
        y = 340 + i*86
        p += [card(f"Evidence {i+1}", 24, y, 342, 74, 16),
              rect(f"Evidence rail {i+1}", 24, y, 4, 74, 2, TEAL if i==0 else RED),
              txt(f"Evidence {i+1} line", ln, 44, y+24, 13, T1, FS, 800),
              txt(f"Evidence {i+1} code", code, 44, y+45, 12, T2, FM, 500),
              txt(f"Evidence {i+1} date", date, 44, y+62, 11, T3, FD, 400),
              txt(f"Evidence {i+1} amount", amt, 348, y+45, 15, T1, FM, 700, "end")]
    p += [card("Card Why", 24, 518, 342, 104, 18, RED_SOFT, False),
          txt("Why title", "Why this matters", 42, 546, 14, "#8F2020", FS, 800),
          lines("Why body", ["You may be charged twice for the same",
                             "service. This is a common billing error."], 42, 572, 21, 13, "#7A2323", FD, 400),
          button("Button Generate Dispute Letter", "Generate Dispute Letter", 24, 644, 342, 56,
                 "url(#gradNavy)", WHITE, 18, None, "shBtnNavy", I["mail"]),
          button("Button Mark as Resolved", "Mark as Resolved", 24, 712, 342, 52,
                 WHITE, T1, 18, LINE, None)]
    return g("Screen 13 Finding Detail", p)

# ══════════════════════════════════════════════════════════════════════
# SCREEN 14 — Letter Generation
# ══════════════════════════════════════════════════════════════════════
def s14():
    body = ["I am writing to dispute charges on my medical",
            "bill for services received on March 15, 2024.",
            "The Explanation of Benefits from my insurance",
            "company shows my patient responsibility as",
            "$342.56, but your bill shows $1,234.56.",
            "",
            "Please review the attached EOB and provide a",
            "corrected, itemized statement within 30 days."]
    p = [status_bar(), home_bar(),
      icon("Back", I["back"], BLUE, 26, 68, 24, 2.4),
      txt("Title", "Dispute Letter", 195, 80, 17, T1, FS, 800, "middle", -0.4)]
    for i,(n,lbl) in enumerate([("1","Template"),("2","Review"),("3","Send")]):
        x = 24 + i*114; on = i==0
        p += [rect(f"Step {n} bg", x, 106, 102, 34, 10, NAVY if on else "#EDF1F7"),
              ell(f"Step {n} disc", x+18, 123, 9, 9, WHITE if on else "#C8D3E2"),
              txt(f"Step {n} num", n, x+18, 127, 10, NAVY if on else WHITE, FM, 700, "middle"),
              txt(f"Step {n} label", lbl, x+34, 128, 11.5, WHITE if on else T3, FS, 700)]
    p += [txt("Letter kind", "EOB Mismatch Dispute Letter", 195, 172, 15, T1, FS, 800, "middle", -0.3),
          txt("Letter sub", "Pre-filled with your details", 195, 192, 12, T3, FD, 400, "middle"),
          card("Letter paper", 24, 210, 342, 430, 10, "#FEFDFA", True, "#EDE8DC", 1),
          txt("Letter date", "March 20, 2024", 44, 246, 12.5, T2, FL, 400),
          lines("Letter address", ["Billing Department","Riverside Medical Center",
                                   "123 Health Way","Anytown, ST 12345"], 44, 282, 20, 12.5, T2, FL, 400),
          txt("Letter re", "Re: Account #12345678", 44, 386, 12.5, T1, FL, 700),
          txt("Letter salutation", "To Whom It May Concern,", 44, 418, 12.5, T1, FL, 400),
          lines("Letter body", body, 44, 448, 22, 12.5, T1, FL, 400),
          txt("Letter signoff", "Sincerely,", 44, 610, 12.5, T1, FL, 400),
          button("Button Copy to Clipboard", "Copy to Clipboard", 24, 660, 164, 52,
                 "url(#gradNavy)", WHITE, 16, None, "shBtnNavy", I["copy"], 14),
          button("Button Share", "Share", 202, 660, 164, 52,
                 "url(#gradTeal)", WHITE, 16, None, None, I["share"], 14),
          txt("Disclaimer", "Review before sending. This is not legal advice.",
              195, 740, 11, T4, FD, 400, "middle")]
    return g("Screen 14 Letter Generation", p)

# ══════════════════════════════════════════════════════════════════════
# SCREEN 15 — Case Management
# ══════════════════════════════════════════════════════════════════════
def s15(dark=False, active="Cases"):
    surf = DSURF if dark else WHITE
    t1 = "#E6EBF4" if dark else T1
    t3 = "#7C8899" if dark else T3
    p = [status_bar("light" if dark else "dark"), home_bar("light" if dark else "dark"),
      ell("Avatar", 45, 85, 21, 21, "url(#gradBlue)"),
      txt("Avatar initial", "A", 45, 92, 17, WHITE, FS, 800, "middle"),
      txt("Title", "My Cases", 78, 93, 24, t1, FS, 800, "start", -1),
      ell("Add button", 344, 85, 20, 20, "url(#gradBlue)"),
      icon("Add icon", I["plus"], WHITE, 334, 75, 20, 2.6)]
    for i,(lbl,n,on) in enumerate([("Active","3",True),("Resolved","1",False),("Closed","1",False)]):
        x = 24 + i*112
        p += [rect(f"Filter {lbl} bg", x, 124, 104, 36, 18, NAVY if on else (DSURF if dark else WHITE),
                   None, None if on else (DLINE if dark else LINE), 1),
              txt(f"Filter {lbl} label", f"{lbl} ({n})", x+52, 147, 12.5,
                  WHITE if on else t3, FS, 700, "middle")]
    cases = [("Riverside Medical Center","Mar 15, 2024","Analysis Complete",AMBER,AMBER_SOFT,"#B5730A","3 findings","$2,845"),
             ("St. Mary's Hospital","Feb 2, 2024","Letter Sent",VIOLET,VIOLET_SOFT,"#5B4BD6","2 findings","$1,420"),
             ("City Health Clinic","Jan 10, 2024","In Review",BLUE,BLUE_SOFT,"#1E5FC4","1 finding","$320")]
    for i,(prov,date,st,dot,pbg,pfg,find,amt) in enumerate(cases):
        y = 180 + i*116
        p += [card(f"Case {i+1}", 24, y, 342, 100, 18, surf, not dark, DLINE if dark else None, 1),
              txt(f"Case {i+1} provider", prov, 42, y+30, 15, t1, FS, 800, "start", -0.3),
              txt(f"Case {i+1} date", date, 42, y+52, 12, t3, FS, 500),
              rect(f"Case {i+1} pill", 42, y+64, len(st)*6.6+30, 24, 12, pbg if not dark else DSURF),
              ell(f"Case {i+1} dot", 55, y+76, 3.5, 3.5, dot),
              txt(f"Case {i+1} status", st, 66, y+80, 11, pfg if not dark else dot, FS, 700),
              txt(f"Case {i+1} findings", find, 348, y+46, 11.5, t3, FS, 500, "end"),
              txt(f"Case {i+1} amount", amt, 348, y+76, 20, t1, FM, 700, "end")]
    p.append(tab_bar(active, "dark" if dark else "light"))
    return g("Screen 15 Case Management", p)

# ══════════════════════════════════════════════════════════════════════
# SCREEN 16 — Go Premium
# ══════════════════════════════════════════════════════════════════════
def s16():
    feats = ["Unlimited bill & EOB scans","Hospital price comparisons",
             "Full analysis with all findings","All letter templates & phone scripts",
             "Unlimited active cases","Deadline reminders"]
    p = [status_bar("light"), home_bar("light"),
      ell("Glow", 195, 150, 190, 190, AMBER, 0.10),
      icon("Close", I["x"], "#7C8899", 330, 66, 20, 2.4),
      icon("Crown", I["crown"], AMBER2, 173, 98, 44, 2.4, True),
      txt("Title", "Go Premium", 195, 186, 30, WHITE, FS, 800, "middle", -1.2),
      lines("Subtitle", ["Unlock your full bill analysis","and take control."],
            195, 216, 22, 14, "#93A0B5", FD, 400, "middle")]
    for i,f in enumerate(feats):
        y = 278 + i*42
        p += [ell(f"Feature {i+1} disc", 42, y, 11, 11, GREEN, 0.18),
              path(f"Feature {i+1} check", f"M37 {y} L40.5 {y+3.5} L47 {y-4}", "none", GREEN2, 2.4),
              txt(f"Feature {i+1} label", f, 66, y+5, 14, "#E6EBF4", FS, 600)]
    p += [rect("Monthly card", 24, 546, 164, 92, 18, "none", None, "#2A3142", 1.5),
          txt("Monthly label", "Monthly", 106, 578, 15, "#93A0B5", FS, 700, "middle"),
          txt("Monthly price", "$7.99", 106, 606, 22, "#E6EBF4", FM, 700, "middle"),
          txt("Monthly period", "per month", 106, 624, 11, "#6B7689", FD, 400, "middle"),
          rect("Annual card", 202, 546, 164, 92, 18, AMBER, 0.08, AMBER, 1.5),
          rect("Save badge", 252, 534, 64, 22, 11, "url(#gradAmber)"),
          txt("Save label", "SAVE 37%", 284, 549, 9.5, "#3A2600", FS, 800, "middle", 0.6),
          txt("Annual label", "Annual", 284, 582, 15, AMBER2, FS, 700, "middle"),
          txt("Annual price", "$59.99", 284, 610, 22, WHITE, FM, 700, "middle"),
          txt("Annual period", "per year", 284, 628, 11, "#B99753", FD, 400, "middle"),
          button("Button Continue with Annual", "Continue with Annual", 24, 664, 342, 56,
                 "url(#gradAmber)", "#3A2600", 18, None, "shBtnAmber"),
          txt("Fine print", "Cancel anytime · Restore Purchases", 195, 744, 11.5, "#6B7689", FD, 400, "middle")]
    return g("Screen 16 Go Premium", p)

# ══════════════════════════════════════════════════════════════════════
# SCREEN 17 — You're All Set
# ══════════════════════════════════════════════════════════════════════
def s17():
    p = [status_bar(), home_bar(),
      ell("Bokeh green", 195, 236, 150, 150, GREEN_SOFT, 0.7),
      ell("Halo outer", 195, 236, 96, 96, GREEN, 0.10),
      ell("Halo inner", 195, 236, 76, 76, GREEN, 0.16),
      ell("Check disc", 195, 236, 58, 58, "url(#gradGreen)"),
      path("Check mark", "M170 237 L187 254 L221 218", "none", WHITE, 7),
      txt("Title", "You're All Set!", 195, 356, 30, T1, FS, 800, "middle", -1.2),
      txt("Subtitle", "Welcome to BillFixer Premium", 195, 386, 15, T2, FD, 400, "middle")]
    for i,f in enumerate(["Your subscription is active","All features unlocked","Start scanning your first bill"]):
        y = 440 + i*52
        p += [card(f"Row {i+1}", 24, y, 342, 44, 14, GREEN_SOFT, False),
              ell(f"Row {i+1} disc", 48, y+22, 10, 10, GREEN),
              path(f"Row {i+1} check", f"M43.5 {y+22} L46.8 {y+25.3} L52.5 {y+18.5}", "none", WHITE, 2.2),
              txt(f"Row {i+1} label", f, 72, y+27, 13.5, "#146245", FS, 600)]
    p += [button("Button Start Scanning", "Start Scanning", 24, 636, 342, 56,
                 "url(#gradNavy)", WHITE, 18, None, "shBtnNavy", I["cam"]),
          txt("Manage note", "Manage your subscription in Settings", 195, 724, 12, T3, FD, 400, "middle")]
    return g("Screen 17 You're All Set", p)

# ══════════════════════════════════════════════════════════════════════
# SCREEN 18 — Case Timeline
# ══════════════════════════════════════════════════════════════════════
def s18():
    ev = [("Bill uploaded","Mar 15, 2024 · 10:24 AM","doc",BLUE,BLUE_SOFT,None),
          ("Analysis complete","Mar 15, 2024 · 10:25 AM","check",GREEN,GREEN_SOFT,"5 findings"),
          ("Dispute letter generated","Mar 16, 2024 · 9:12 AM","mail",VIOLET,VIOLET_SOFT,None),
          ("Letter sent","Mar 16, 2024 · 9:15 AM","send",TEAL,TEAL_SOFT,"Certified mail"),
          ("Provider response","Mar 22, 2024 · 2:41 PM","phone",AMBER,AMBER_SOFT,"Duplicate removed"),
          ("Balance reduced","Mar 28, 2024 · 11:20 AM","up",GREEN,GREEN_SOFT,"−$635")]
    p = [status_bar(), home_bar(),
      icon("Back", I["back"], BLUE, 26, 68, 24, 2.4),
      txt("Title", "Case Timeline", 195, 80, 17, T1, FS, 800, "middle", -0.4),
      txt("Provider", "Riverside Medical Center", 195, 104, 12.5, T3, FD, 400, "middle")]
    for i,(label, when, ico, c, cbg, extra) in enumerate(ev):
        y = 142 + i*104
        if i < len(ev)-1:
            p.append(rect(f"Rail {i+1}", 45, y+46, 2, 58, 1, "#DDE5F0"))
        p += [rect(f"Node {i+1}", 26, y, 40, 40, 13, cbg),
              icon(f"Node {i+1} icon", I[ico], c, 34, y+8, 24, 2),
              card(f"Event {i+1}", 82, y-6, 284, 76 if extra else 58, 14),
              txt(f"Event {i+1} label", label, 100, y+18, 14, T1, FS, 800, "start", -0.2),
              txt(f"Event {i+1} time", when, 100, y+38, 11, T3, FM, 500)]
        if extra:
            p += [rect(f"Event {i+1} tag bg", 100, y+46, len(extra)*6.6+20, 20, 10, cbg),
                  txt(f"Event {i+1} tag", extra, 110, y+60, 10.5, c, FS, 700)]
    p.append(button("Button Add Note", "Add a note", 24, 760, 342, 52, WHITE, T1, 16, LINE, None, I["plus"], 15))
    return g("Screen 18 Case Timeline", p)

# ══════════════════════════════════════════════════════════════════════
# SCREEN 19 — Your Rights
# ══════════════════════════════════════════════════════════════════════
def s19():
    rights = [("No Surprises Act","Out-of-network charges may be","protected under federal law.",
               "shieldC",BLUE,BLUE_SOFT,"Likely"),
              ("Financial Assistance","You may qualify based on your","income and hospital type.",
               "help",RED,RED_SOFT,"Check"),
              ("Request an Itemized Bill","You have the right to request a","detailed, itemized bill.",
               "doc",TEAL,TEAL_SOFT,"Always"),
              ("Compare with Your EOB","Your bill should match your EOB","patient responsibility.",
               "scale",AMBER,AMBER_SOFT,"Review")]
    p = [status_bar(), home_bar(),
      icon("Back", I["back"], BLUE, 26, 68, 24, 2.4),
      txt("Title", "Your Rights May Apply", 195, 80, 17, T1, FS, 800, "middle", -0.4),
      card("Card Notice", 24, 112, 342, 74, 18, BLUE_SOFT, False),
      icon("Notice icon", I["info"], BLUE, 42, 132, 24, 2),
      lines("Notice body", ["Based on your provider type and how this",
                            "bill was generated. We flag what to check."],
            78, 142, 20, 12.5, "#1E4C8A", FD, 400)]
    for i,(title, l1, l2, ico, c, cbg, tag) in enumerate(rights):
        y = 204 + i*132
        p += [card(f"Right {i+1}", 24, y, 342, 116, 18),
              rect(f"Right {i+1} tile", 42, y+22, 46, 46, 14, cbg),
              icon(f"Right {i+1} icon", I[ico], c, 53, y+33, 24, 2),
              txt(f"Right {i+1} title", title, 102, y+42, 15, T1, FS, 800, "start", -0.3),
              rect(f"Right {i+1} tag bg", 348-len(tag)*7.2-20, y+26, len(tag)*7.2+20, 22, 11, cbg),
              txt(f"Right {i+1} tag", tag, 348-10, y+41, 10.5, c, FS, 700, "end"),
              txt(f"Right {i+1} line 1", l1, 102, y+66, 12.5, T2, FD, 400),
              txt(f"Right {i+1} line 2", l2, 102, y+84, 12.5, T2, FD, 400),
              icon(f"Right {i+1} chev", I["chev"], T4, 336, y+80, 18, 2.2)]
    return g("Screen 19 Your Rights", p)

# ══════════════════════════════════════════════════════════════════════
# SCREEN 20 — Settings
# ══════════════════════════════════════════════════════════════════════
def s20():
    rows = [("Account","user",None),("Subscription","star","Premium (Annual)"),
            ("Notifications","bell",None),("Help & Support","help",None),
            ("Privacy Policy","lock",None),("Terms of Service","doc",None)]
    p = [status_bar(), home_bar(),
      txt("Title", "Settings", 24, 92, 28, T1, FS, 800, "start", -1.2),
      ell("Search bg", 344, 84, 20, 20, WHITE),
      icon("Search", I["search"], T2, 334, 74, 20, 2),
      card("Card Profile", 24, 120, 342, 92, 18),
      ell("Avatar", 70, 166, 26, 26, "url(#gradBlue)"),
      txt("Avatar initial", "A", 70, 175, 21, WHITE, FS, 800, "middle"),
      txt("Name", "Alex Johnson", 112, 160, 17, T1, FS, 800, "start", -0.4),
      txt("Email", "alex@example.com", 112, 182, 12.5, T3, FD, 400)]
    for i,(label, ico, value) in enumerate(rows):
        y = 232 + i*72
        p += [card(f"Row {label}", 24, y, 342, 60, 16),
              rect(f"Row {label} tile", 42, y+14, 32, 32, 10, BLUE_SOFT),
              icon(f"Row {label} icon", I[ico], BLUE, 50, y+22, 16, 2),
              txt(f"Row {label} label", label, 88, y+36, 15, T1, FS, 600)]
        if value:
            p.append(txt(f"Row {label} value", value, 318, y+36, 12.5, AMBER, FS, 700, "end"))
        p.append(icon(f"Row {label} chev", I["chev"], T4, 332, y+21, 18, 2.2))
    p += [card("Row Delete Account", 24, 664, 342, 60, 16, WHITE, True, "#F8D4D4", 1),
          rect("Delete tile", 42, 678, 32, 32, 10, RED_SOFT),
          icon("Delete icon", I["trash"], RED, 50, 686, 16, 2),
          txt("Delete label", "Delete Account", 88, 700, 15, RED, FS, 700),
          txt("Version", "Bill Fixer 1.0.0 (build 42)", 195, 760, 11.5, T4, FM, 500, "middle")]
    return g("Screen 20 Settings", p)

# ══════════════════════════════════════════════════════════════════════
# SCREEN 22 — No Cases Yet
# ══════════════════════════════════════════════════════════════════════
def s22():
    p = [status_bar(), home_bar(),
      txt("Title", "My Cases", 24, 92, 24, T1, FS, 800, "start", -1),
      ell("Add button", 344, 85, 20, 20, "url(#gradBlue)"),
      icon("Add icon", I["plus"], WHITE, 334, 75, 20, 2.6),
      ell("Bokeh", 195, 300, 128, 128, BLUE_SOFT, 0.55),
      ell("Folder shadow", 195, 372, 66, 9, NAVY, 0.08),
      # folder illustration
      path("Folder back", "M128 250 L166 250 L178 264 L262 264 C268.6 264 274 269.4 274 276 L274 354 C274 360.6 268.6 366 262 366 L128 366 C121.4 366 116 360.6 116 354 L116 262 C116 255.4 121.4 250 128 250 Z", "url(#gradBlue)"),
      g("Folder paper", [rect("paper", 146, 232, 100, 74, 6, WHITE)], "rotate(-6 196 269)"),
      g("Folder paper lines", [rect("line 1", 158, 248, 48, 4, 2, "#C4D2E4"),
                                rect("line 2", 158, 260, 64, 4, 2, "#DCE5F0"),
                                rect("line 3", 158, 272, 38, 4, 2, "#DCE5F0")], "rotate(-6 196 269)"),
      path("Folder front", "M116 288 L274 288 C280.6 288 286 293.4 286 300 L286 354 C286 360.6 280.6 366 274 366 L128 366 C121.4 366 116 360.6 116 354 Z", "#4A8BD6"),
      icon("Sparkle 1", I["star"], AMBER, 268, 218, 28, 2, True),
      icon("Sparkle 2", I["star"], TEAL2, 104, 206, 20, 2, True),
      ell("Dot 1", 296, 306, 6, 6, TEAL, 0.5),
      ell("Dot 2", 96, 320, 4.5, 4.5, AMBER, 0.5),
      txt("Title empty", "No Cases Yet", 195, 448, 26, T1, FS, 800, "middle", -1),
      lines("Body", ["Scan your first medical bill to get started.",
                     "We'll check for errors, compare prices, and",
                     "help you take action."], 195, 486, 24, 15, T2, FD, 400, "middle"),
      button("Button Scan Your First Bill", "Scan Your First Bill", 24, 600, 342, 56,
             "url(#gradTeal)", WHITE, 18, None, None, I["cam"]),
      icon("Privacy shield", I["shield"], TEAL, 128, 678, 16, 2),
      txt("Privacy note", "Nothing leaves your phone unredacted", 152, 691, 12, T3, FD, 400),
      tab_bar("Cases", "light")]
    return g("Screen 22 No Cases Yet", p)

# ══════════════════════════════════════════════════════════════════════
# SCREEN 06/23 — Home (light + dark)
# ══════════════════════════════════════════════════════════════════════
def home(dark=False):
    surf = DSURF if dark else WHITE
    t1 = "#E6EBF4" if dark else T1
    t3 = "#7C8899" if dark else T3
    p = [status_bar("light" if dark else "dark"), home_bar("light" if dark else "dark"),
      ell("Avatar", 45, 85, 21, 21, "url(#gradBlue)"),
      txt("Avatar initial", "A", 45, 92, 17, WHITE, FS, 800, "middle"),
      txt("Greeting", "Good morning,", 78, 76, 13, t3, FS, 500),
      txt("Name", "Alex", 78, 98, 20, t1, FS, 800, "start", -0.6),
      ell("Bell bg", 344, 86, 20, 20, surf),
      icon("Bell", I["bell"], t1, 335, 76, 20, 1.9),
      card("Banner Free plan", 24, 128, 342, 56, 16,
           AMBER_SOFT if not dark else "#2A2313", False, "#F8E3BC" if not dark else "#463A1B", 1),
      rect("Lock tile", 36, 140, 32, 32, 10, AMBER),
      icon("Lock", I["lock"], WHITE, 44, 148, 16, 2.2),
      txt("Plan title", "Free Plan", 78, 152, 14, "#7A5405" if not dark else AMBER2, FS, 700),
      txt("Plan sub", "1 of 1 finding preview used", 78, 170, 11.5, "#B5730A" if not dark else "#B99753", FS, 500),
      icon("Plan chev", I["chev"], "#D3A054", 342, 148, 18, 2.2),
      card("Card Scan a Medical Bill", 24, 200, 342, 96, 22, "url(#gradNavy)", False),
      rect("Scan icon tile", 44, 226, 44, 44, 14, WHITE, 0.16),
      icon("Scan icon", I["cam"], WHITE, 55, 237, 22, 2),
      txt("Scan title", "Scan a Medical Bill", 104, 246, 17, WHITE, FS, 800, "start", -0.5),
      txt("Scan sub", "Photo, PDF or Camera", 104, 268, 12.5, "#9FC0F0", FS, 500),
      ell("Scan plus bg", 326, 248, 20, 20, WHITE, 0.18),
      icon("Scan plus", I["plus"], WHITE, 316, 238, 20, 2.4)]
    qa = [("Scan Bill", TEAL_SOFT, TEAL, "cam"), ("Add EOB", RED_SOFT, RED, "doc"),
          ("Import PDF", BLUE_SOFT, BLUE, "doc")]
    for i,(lbl,bgc,fg,ico) in enumerate(qa):
        x = 24 + i*114
        p += [card(f"Action {lbl}", x, 312, 102, 88, 18, surf, not dark, DLINE if dark else None, 1),
              rect(f"{lbl} tile", x+33, 328, 36, 36, 12, bgc if not dark else DSURF),
              icon(f"{lbl} icon", I[ico], fg, x+43, 338, 16, 1.9),
              txt(f"{lbl} label", lbl, x+51, 378, 12, t1, FS, 700, "middle")]
    p += [txt("Section Your Cases", "Your Cases", 24, 436, 16, t1, FS, 800, "start", -0.5),
          txt("See All", "See All", 366, 436, 13, BLUE if not dark else BLUE2, FS, 700, "end"),
          card("Card Case", 24, 456, 342, 96, 18, surf, not dark, DLINE if dark else None, 1),
          txt("Case provider", "Riverside Medical Center", 42, 488, 15, t1, FS, 800, "start", -0.3),
          txt("Case date", "Mar 15, 2024", 42, 510, 12, t3, FS, 500),
          rect("Case pill", 42, 518, 128, 24, 12, AMBER_SOFT if not dark else "#2A2313"),
          ell("Case dot", 55, 530, 3.5, 3.5, AMBER),
          txt("Case status", "Analysis Complete", 66, 534, 11, "#B5730A" if not dark else AMBER2, FS, 700),
          txt("Case findings", "3 findings", 348, 504, 11.5, t3, FS, 500, "end"),
          txt("Case amount", "$2,845", 348, 534, 20, t1, FM, 700, "end"),
          tab_bar("Home", "dark" if dark else "light")]
    return g("Screen Home", p)

# ══════════════════════════════════════════════════════════════════════
# SCREEN 25 — Findings List
# ══════════════════════════════════════════════════════════════════════
def s25():
    p = [status_bar(), home_bar(),
      icon("Back", I["back"], BLUE, 26, 68, 24, 2.4),
      txt("Title", "Your Findings", 195, 80, 17, T1, FS, 800, "middle", -0.4),
      rect("Count pill", 316, 64, 50, 26, 13, BLUE_SOFT),
      txt("Count label", "5 found", 341, 81, 11, BLUE, FS, 700, "middle"),
      card("Card Recommended", 24, 108, 342, 148, 18, WHITE, True, AMBER, 1.5),
      icon("Star", I["star"], AMBER, 42, 126, 16, 2, True),
      txt("Recommended label", "RECOMMENDED FIRST STEP", 66, 138, 9.5, "#B5730A", FS, 800, "start", 1.4),
      txt("Recommended title", "Request an itemized bill", 42, 170, 16.5, T1, FS, 800, "start", -0.4),
      lines("Recommended body", ["A summary statement hides the detail we need.",
                                 "Ask for full itemization before disputing."],
            42, 196, 20, 13, T2, FD, 400),
      button("Button Generate the request", "Generate the request", 42, 226, 306, 46,
             "url(#gradAmber)", "#3A2600", 14, None, "shBtnAmber", None, 14.5)]
    findings = [("Duplicate charge detected","CPT 71046 appears twice for the same","date of service at the same amount.",
                 "Strong",RED,RED_SOFT,"High confidence",TEAL_SOFT,"#0E8C78","$420.00",False),
                ("Bill doesn't match your EOB","Your EOB lists $342.56 but the bill","shows $1,234.56 — a $892 gap.",
                 "Likely",AMBER,AMBER_SOFT,"Medium",AMBER_SOFT,"#B5730A","$892.00",True)]
    for i,(title,l1,l2,sev,sc,sbg,conf,cbg,cfg,amt,blur) in enumerate(findings):
        y = 274 + i*172
        p += [card(f"Finding {i+1}", 24, y, 342, 156, 18, WHITE, True),
              rect(f"Finding {i+1} rail", 24, y, 5, 156, 2.5, sc),
              rect(f"Finding {i+1} sev pill", 44, y+18, 62, 24, 12, sc),
              txt(f"Finding {i+1} sev", sev, 75, y+34, 11, WHITE, FS, 700, "middle"),
              rect(f"Finding {i+1} conf pill", 348-len(conf)*6.6-20, y+18, len(conf)*6.6+20, 24, 12, cbg),
              txt(f"Finding {i+1} conf", conf, 338, y+34, 10.5, cfg, FS, 700, "end"),
              txt(f"Finding {i+1} title", title, 44, y+68, 16, T1, FS, 800, "start", -0.3),
              txt(f"Finding {i+1} line 1", l1, 44, y+92, 12.5, T2, FD, 400),
              txt(f"Finding {i+1} line 2", l2, 44, y+110, 12.5, T2, FD, 400),
              txt(f"Finding {i+1} amount", amt, 348, y+134, 17, sc, FM, 700, "end"),
              txt(f"Finding {i+1} evidence", "Evidence · 2 sources", 44, y+134, 12.5, BLUE, FS, 700)]
        if blur:
            p += [rect(f"Finding {i+1} lock scrim", 24, y, 342, 156, 18, WHITE, 0.72),
                  ell(f"Finding {i+1} lock disc", 195, y+58, 22, 22, "url(#gradAmber)"),
                  icon(f"Finding {i+1} lock icon", I["lock"], WHITE, 185, y+48, 20, 2.2),
                  txt(f"Finding {i+1} lock title", "Unlock 4 more findings", 195, y+98, 14, NAVY, FS, 800, "middle"),
                  rect(f"Finding {i+1} lock cta", 135, y+112, 120, 32, 16, NAVY),
                  txt(f"Finding {i+1} lock cta label", "Go Premium", 195, y+133, 12, WHITE, FS, 700, "middle")]
    p += [rect("Skeleton card", 24, 618, 342, 92, 18, WHITE, 0.55),
          rect("Skeleton pill", 44, 638, 70, 20, 10, "#EDF1F7"),
          rect("Skeleton line 1", 44, 668, 240, 14, 4, "#EDF1F7"),
          rect("Skeleton line 2", 44, 690, 160, 10, 4, "#F3F6FA")]
    return g("Screen 25 Findings List", p)

# ══════════════════════════════════════════════════════════════════════
# SCREEN 26 — Phone Script
# ══════════════════════════════════════════════════════════════════════
def s26():
    p = [status_bar(), home_bar(),
      icon("Back", I["back"], BLUE, 26, 68, 24, 2.4),
      txt("Title", "Phone Script", 195, 80, 17, T1, FS, 800, "middle", -0.4),
      rect("Context pill", 300, 64, 66, 26, 13, BLUE_SOFT),
      txt("Context label", "Billing", 333, 81, 11, BLUE, FS, 700, "middle"),
      card("Card Call", 24, 108, 342, 84, 18, NAVY, False),
      ell("Call avatar", 68, 150, 23, 23, "url(#gradTeal)"),
      icon("Call avatar icon", I["phone"], WHITE, 57, 139, 22, 2),
      txt("Call provider", "Riverside Billing Dept", 106, 144, 15, WHITE, FS, 800, "start", -0.3),
      txt("Call number", "(555) 019-4400 · Mon–Fri 8–5", 106, 166, 12, "#9FC0F0", FM, 500),
      ell("Call button", 330, 150, 19, 19, GREEN),
      icon("Call button icon", I["phone"], WHITE, 322, 142, 16, 2, True),
      txt("Step label", "STEP 1 · OPENING", 24, 224, 9.5, T3, FS, 800, "start", 1.8),
      card("Card Script", 24, 238, 342, 158, 18),
      rect("Script tab", 44, 236, 36, 4, 2, "url(#gradTeal)"),
      lines("Script body", ["“Hi, my name is Alex Johnson, account",
                            "4471-A. I've compared my statement to my",
                            "Explanation of Benefits and I'm seeing two",
                            "discrepancies. Can you pull up the itemized",
                            "detail with me?”"], 44, 278, 26, 14.5, T1, FL, 400),
      rect("Script divider", 44, 356, 302, 1, 0, LINE)]
    for i,(tone,tbg,tfg) in enumerate([("Calm",TEAL_SOFT,"#0E8C78"),("Specific",BLUE_SOFT,"#1E5FC4"),
                                       ("No accusation","#EEF1F6",T2)]):
        x = 44 + i*(len(tone)*7+30)
        p += [rect(f"Tone {tone} bg", x, 366, len(tone)*7+20, 22, 11, tbg),
              txt(f"Tone {tone} label", tone, x+10, 381, 10.5, tfg, FS, 700)]
    p.append(txt("Branch label", "WHAT DID THEY SAY?", 24, 428, 9.5, T3, FS, 800, "start", 1.8))
    branches = [("A","“The bill is correct as issued.”",TEAL_SOFT,"#0E8C78"),
                ("B","“I can't adjust that — it's final.”",AMBER_SOFT,"#B5730A"),
                ("C","“Let me review and call you back.”",GREEN_SOFT,"#146245"),
                ("D","“This is going to collections.”",RED_SOFT,"#8F2020")]
    for i,(k,label,kbg,kfg) in enumerate(branches):
        y = 444 + i*72
        p += [card(f"Branch {k}", 24, y, 342, 60, 16, WHITE, True,
                   RED if k=="D" else None, 1.5 if k=="D" else 1),
              rect(f"Branch {k} key bg", 42, y+16, 28, 28, 9, kbg),
              txt(f"Branch {k} key", k, 56, y+35, 12, kfg, FS, 800, "middle"),
              txt(f"Branch {k} label", label, 82, y+36, 13.5, T1, FS, 600),
              icon(f"Branch {k} chev", I["chev"], T4, 334, y+21, 18, 2.2)]
    return g("Screen 26 Phone Script", p)

# ══════════════════════════════════════════════════════════════════════
# SCREEN 27 — Financial Assistance
# ══════════════════════════════════════════════════════════════════════
def s27():
    p = [status_bar(), home_bar(),
      ell("Bokeh amber", 320, 150, 110, 110, AMBER_SOFT, 0.8),
      ell("Bokeh warm", 40, 300, 76, 76, "#FFF0D6", 0.8),
      icon("Back", I["back"], BLUE, 26, 68, 24, 2.4),
      rect("Nonprofit pill", 222, 64, 144, 26, 13, AMBER_SOFT),
      txt("Nonprofit label", "§501(r) nonprofit", 294, 81, 11, "#8A6208", FS, 700, "middle"),
      ell("Hero disc", 195, 152, 42, 42, WHITE, 0.85),
      icon("Hero icon", I["help"], AMBER, 173, 130, 44, 2.2),
      txt("Title", "You may qualify for help", 195, 224, 24, T1, FS, 800, "middle", -1),
      lines("Subtitle", ["Riverside must screen you for financial",
                         "assistance before sending this to collections."],
            195, 250, 21, 13.5, T2, FD, 400, "middle"),
      card("Card Estimator", 24, 296, 342, 148, 18),
      txt("Estimator label", "QUICK ELIGIBILITY ESTIMATE", 42, 324, 9.5, T3, FS, 800, "start", 1.6),
      txt("Household label", "Household size", 42, 356, 13.5, T2, FS, 500),
      rect("Stepper bg", 250, 340, 98, 32, 10, "#F5F7FB"),
      txt("Stepper minus", "−", 266, 361, 16, T3, FS, 600, "middle"),
      txt("Stepper value", "3", 299, 361, 15, T1, FM, 700, "middle"),
      txt("Stepper plus", "+", 332, 361, 16, BLUE, FS, 600, "middle"),
      txt("Income label", "Annual household income", 42, 396, 13.5, T2, FS, 500),
      txt("Income value", "$48,000", 348, 396, 15, T1, FM, 700, "end"),
      rect("Slider track", 42, 410, 306, 6, 3, "#EDF1F6"),
      rect("Slider fill", 42, 410, 135, 6, 3, "url(#gradAmber)"),
      ell("Slider thumb", 177, 413, 10, 10, WHITE, None, AMBER, 3),
      txt("Slider min", "$0", 42, 434, 9.5, T4, FM, 500),
      txt("Slider max", "$120K", 348, 434, 9.5, T4, FM, 500, "end"),
      card("Card Result", 24, 458, 342, 128, 18, GREEN_SOFT, False, "#BDE9CF", 1.5),
      ell("Result disc", 54, 490, 13, 13, GREEN),
      path("Result check", "M48 490 L52 494 L61 484", "none", WHITE, 2.4),
      txt("Result title", "Likely eligible", 78, 496, 17, "#11713F", FS, 800, "start", -0.4),
      lines("Result body", ["At 3 people and $48,000 you're near 188% of the",
                            "Federal Poverty Level. Riverside discounts 100%",
                            "below 200% FPL."], 42, 522, 19, 12.5, "#1A6B45", FD, 400),
      rect("FPL tile 1", 42, 546, 148, 0, 0, "none"),
      card("Card Documents", 24, 600, 342, 126, 18),
      txt("Documents label", "DOCUMENTS YOU'LL NEED", 42, 628, 9.5, T3, FS, 800, "start", 1.6)]
    for i,(doc,done) in enumerate([("Last 2 pay stubs",True),("Most recent tax return",True),
                                   ("Proof of household size",False)]):
        y = 650 + i*24
        if done:
            p += [ell(f"Doc {i+1} disc", 48, y, 8, 8, GREEN),
                  path(f"Doc {i+1} check", f"M44.5 {y} L47 {y+2.5} L51.5 {y-2.5}", "none", WHITE, 1.8)]
        else:
            p.append(ell(f"Doc {i+1} ring", 48, y, 7.5, 7.5, "none", None, "#C3CBD8", 1.8))
        p.append(txt(f"Doc {i+1} label", doc, 68, y+4, 13, T1 if done else T2, FS, 500))
    p.append(button("Button Draft my assistance letter", "Draft my assistance letter", 24, 748, 342, 56,
                    "url(#gradAmber)", "#3A2600", 18, None, "shBtnAmber"))
    return g("Screen 27 Financial Assistance", p)

# ══════════════════════════════════════════════════════════════════════
# SCREEN 28 — Rights Detail (No Surprises Act)
# ══════════════════════════════════════════════════════════════════════
def s28():
    p = [status_bar(), home_bar(),
      icon("Back", I["back"], BLUE, 26, 68, 24, 2.4),
      txt("Title", "No Surprises Act", 195, 80, 17, T1, FS, 800, "middle", -0.4),
      card("Card Hero", 24, 108, 342, 128, 20, BLUE_SOFT, False),
      rect("Hero tile", 44, 128, 52, 52, 16, WHITE),
      icon("Hero icon", I["shieldC"], BLUE, 58, 142, 24, 2),
      txt("Hero label", "FEDERAL PROTECTION", 112, 144, 9.5, "#1E5FC4", FS, 800, "start", 1.6),
      txt("Hero title", "This likely applies", 112, 170, 18, "#0B2B5C", FS, 800, "start", -0.5),
      lines("Hero body", ["Your visit was an emergency at an in-network",
                          "facility — the core NSA condition."], 44, 204, 20, 12.5, "#1E4C8A", FD, 400),
      txt("What heading", "WHAT IT COVERS", 24, 272, 9.5, T3, FS, 800, "start", 1.6)]
    covers = [("Emergency services","Out-of-network ER care is billed at your in-network rate."),
              ("Ancillary providers","Anesthesiology, radiology and pathology at in-network facilities."),
              ("Air ambulance","Out-of-network air ambulance is covered at in-network cost-sharing.")]
    for i,(title, body) in enumerate(covers):
        y = 288 + i*88
        p += [card(f"Cover {i+1}", 24, y, 342, 72, 16),
              ell(f"Cover {i+1} disc", 50, y+36, 11, 11, BLUE_SOFT),
              txt(f"Cover {i+1} num", str(i+1), 50, y+40, 11, BLUE, FS, 800, "middle"),
              txt(f"Cover {i+1} title", title, 76, y+30, 14, T1, FS, 800, "start", -0.2),
              txt(f"Cover {i+1} body", body[:44], 76, y+50, 11.5, T2, FD, 400)]
    p += [card("Card Source", 24, 556, 342, 72, 16, "#F4F6FA", False),
          icon("Source icon", I["doc"], T3, 42, 578, 20, 2),
          txt("Source label", "SOURCE", 72, 582, 9, T3, FS, 800, "start", 1.4),
          txt("Source ref", "45 CFR §149.410 · Public Health Service Act", 72, 602, 12, T2, FM, 500),
          card("Card Caveat", 24, 644, 342, 76, 16, AMBER_SOFT, False),
          icon("Caveat icon", I["info"], "#B5730A", 42, 664, 20, 2),
          lines("Caveat body", ["We flag what to check. Confirm with your plan —",
                                "Bill Fixer does not practice law."], 72, 672, 19, 12, "#7A5405", FD, 400),
          button("Button Generate NSA letter", "Generate NSA dispute letter", 24, 740, 342, 56)]
    return g("Screen 28 Rights Detail NSA", p)

# ══════════════════════════════════════════════════════════════════════
# SCREEN 29 — Case Detail (Summary)
# ══════════════════════════════════════════════════════════════════════
def s29():
    p = [status_bar(), home_bar(),
      icon("Back", I["back"], BLUE, 26, 68, 24, 2.4),
      txt("Title", "Riverside Medical", 195, 80, 17, T1, FS, 800, "middle", -0.4),
      icon("More", I["info"], T3, 334, 68, 20, 2),
      card("Card Header", 24, 108, 342, 128, 20, "url(#gradNavy)", False),
      txt("Header service", "Emergency visit · Mar 15, 2024", 44, 140, 12.5, "#9FC0F0", FS, 500),
      rect("Header pill", 44, 152, 128, 24, 12, WHITE, 0.16),
      ell("Header dot", 57, 164, 3.5, 3.5, AMBER2),
      txt("Header status", "Analysis Complete", 68, 168, 11, WHITE, FS, 700),
      txt("Header original", "$3,480", 44, 210, 14, "#7FA3DB", FM, 500),
      icon("Header arrow", I["arrowR"], TEAL2, 104, 196, 18, 2.4),
      txt("Header current", "$2,845", 134, 214, 26, WHITE, FM, 700, "start", -1)]
    tabs = ["Summary","Docs","Findings","Letters","Timeline"]
    for i,tb in enumerate(tabs):
        x = 24 + i*70; on = i==0
        p += [rect(f"Tab {tb} bg", x, 252, 66, 30, 15, NAVY if on else WHITE),
              txt(f"Tab {tb} label", tb, x+33, 271, 10.5, WHITE if on else T3, FS, 700, "middle")]
    p += [card("Card Balance", 24, 298, 342, 108, 18),
          txt("Balance label", "OUTSTANDING BALANCE", 42, 326, 9.5, T3, FS, 800, "start", 1.6),
          txt("Balance value", "$2,845.00", 42, 366, 30, T1, FM, 700, "start", -1.2),
          rect("Balance track", 42, 382, 306, 6, 3, "#EDF1F6"),
          rect("Balance fill", 42, 382, 128, 6, 3, "url(#gradTeal)"),
          txt("Balance note", "42% toward resolution", 42, 400, 11, T3, FD, 400),
          card("Card Deadline", 24, 420, 342, 76, 18, AMBER_SOFT, False, "#F8E3BC", 1),
          icon("Deadline icon", I["clock"], "#B5730A", 42, 444, 24, 2),
          txt("Deadline label", "Dispute window closes in 3 days", 78, 456, 13.5, "#7A5405", FS, 700),
          txt("Deadline date", "Apr 19, 2024", 78, 476, 11.5, "#B5730A", FM, 500),
          card("Card Next action", 24, 510, 342, 128, 18, WHITE, True, AMBER, 1.5),
          icon("Next star", I["star"], AMBER, 42, 528, 16, 2, True),
          txt("Next label", "RECOMMENDED NEXT", 66, 540, 9.5, "#B5730A", FS, 800, "start", 1.4),
          txt("Next title", "Send the dispute letter", 42, 572, 16, T1, FS, 800, "start", -0.4),
          lines("Next body", ["Your draft is ready. Certified mail gives you",
                              "a delivery record for the timeline."], 42, 596, 19, 12.5, T2, FD, 400),
          button("Button Open letter", "Open the letter", 24, 656, 342, 56),
          button("Button Update balance", "Update balance", 24, 724, 342, 52, WHITE, T1, 18, LINE, None)]
    return g("Screen 29 Case Detail Summary", p)

# ══════════════════════════════════════════════════════════════════════
# SCREEN 30 — Scripts Tab
# ══════════════════════════════════════════════════════════════════════
def s30():
    p = [status_bar(), home_bar(),
      txt("Title", "Scripts", 24, 92, 28, T1, FS, 800, "start", -1.2),
      ell("Search bg", 344, 84, 20, 20, WHITE),
      icon("Search", I["search"], T2, 334, 74, 20, 2),
      lines("Subtitle", ["Know exactly what to say. Every script is",
                         "branch-based — tap what they said."],
            24, 126, 20, 13.5, T2, FD, 400)]
    for i,(lbl,on) in enumerate([("All",True),("Billing",False),("Insurer",False),("Collections",False)]):
        x = 24 + i*86
        p += [rect(f"Filter {lbl} bg", x, 172, 78, 32, 16, NAVY if on else WHITE,
                   None, None if on else LINE, 1),
              txt(f"Filter {lbl} label", lbl, x+39, 192, 11.5, WHITE if on else T3, FS, 700, "middle")]
    scripts = [("Dispute a duplicate charge","Billing · 6 branches","phone",RED,RED_SOFT,"Most used"),
               ("Reconcile bill against EOB","Billing · 8 branches","scale",AMBER,AMBER_SOFT,None),
               ("Ask for financial assistance","Billing · 5 branches","help",GREEN,GREEN_SOFT,None),
               ("Appeal a denied claim","Insurer · 9 branches","shieldC",BLUE,BLUE_SOFT,None),
               ("Respond to a collector","Collections · 7 branches","warn",VIOLET,VIOLET_SOFT,"Know your rights")]
    for i,(title, meta, ico, c, cbg, tag) in enumerate(scripts):
        y = 222 + i*106
        p += [card(f"Script {i+1}", 24, y, 342, 90, 18),
              rect(f"Script {i+1} tile", 42, y+22, 46, 46, 14, cbg),
              icon(f"Script {i+1} icon", I[ico], c, 53, y+33, 24, 2),
              txt(f"Script {i+1} title", title, 102, y+42, 14.5, T1, FS, 800, "start", -0.3),
              txt(f"Script {i+1} meta", meta, 102, y+62, 11.5, T3, FM, 500),
              icon(f"Script {i+1} chev", I["chev"], T4, 336, y+36, 18, 2.2)]
        if tag:
            p += [rect(f"Script {i+1} tag bg", 102, y+70, len(tag)*6.4+18, 20, 10, cbg),
                  txt(f"Script {i+1} tag", tag, 111, y+84, 10, c, FS, 700)]
    p.append(tab_bar("Learn", "light"))
    return g("Screen 30 Scripts Tab", p)

# ══════════════════════════════════════════════════════════════════════
# SCREEN 31 — EOB Prompt
# ══════════════════════════════════════════════════════════════════════
def s31():
    p = [status_bar(), home_bar(),
      ell("Bokeh blue", 320, 160, 108, 108, BLUE_SOFT, 0.7),
      ell("Bokeh teal", 46, 300, 78, 78, TEAL_SOFT, 0.8),
      icon("Close", I["x"], T3, 330, 66, 20, 2.4),
      ell("Hero disc", 195, 200, 76, 76, WHITE, 0.9),
      rect("Doc bill", 158, 168, 44, 58, 6, WHITE, None, "#D6E2F2", 1.5),
      rect("Doc bill line 1", 166, 180, 24, 4, 2, BLUE, 0.5),
      rect("Doc bill line 2", 166, 190, 18, 4, 2, "#D6E2F2"),
      rect("Doc bill line 3", 166, 200, 22, 4, 2, "#D6E2F2"),
      rect("Doc eob", 192, 178, 44, 58, 6, WHITE, None, TEAL, 1.5),
      rect("Doc eob line 1", 200, 190, 24, 4, 2, TEAL, 0.5),
      rect("Doc eob line 2", 200, 200, 18, 4, 2, "#CFEDE7"),
      rect("Doc eob line 3", 200, 210, 22, 4, 2, "#CFEDE7"),
      icon("Link icon", I["scale"], AMBER, 178, 246, 34, 2.2),
      txt("Title", "Do you have an EOB?", 195, 320, 26, T1, FS, 800, "middle", -1),
      lines("Subtitle", ["An Explanation of Benefits from your insurer",
                         "unlocks our most accurate check — line-by-line",
                         "reconciliation against what was actually allowed."],
            195, 354, 24, 14.5, T2, FD, 400, "middle"),
      card("Card Benefit", 24, 448, 342, 108, 18, TEAL_SOFT, False),
      txt("Benefit label", "WITH AN EOB WE CAN", 42, 476, 9.5, "#0E8C78", FS, 800, "start", 1.6)]
    for i,b in enumerate(["Catch charges your plan never allowed",
                          "Verify your true patient responsibility"]):
        y = 502 + i*24
        p += [ell(f"Benefit {i+1} disc", 50, y, 7, 7, TEAL),
              path(f"Benefit {i+1} check", f"M47 {y} L49.2 {y+2.2} L53.4 {y-2.2}", "none", WHITE, 1.7),
              txt(f"Benefit {i+1} label", b, 68, y+4, 12.5, "#0B6157", FD, 400)]
    p += [button("Button Yes add EOB", "Yes — add my EOB", 24, 588, 342, 56,
                 "url(#gradTeal)", WHITE, 18, None, None, I["plus"]),
          button("Button Skip", "Skip for now", 24, 656, 342, 52, WHITE, T2, 18, LINE, None),
          card("Card Reduced", 24, 726, 342, 66, 16, "#F4F6FA", False),
          icon("Reduced icon", I["info"], T3, 42, 746, 18, 2),
          lines("Reduced body", ["Without an EOB we still check math, duplicates",
                                 "and hospital prices — at lower confidence."],
                70, 752, 17, 11.5, T2, FD, 400)]
    return g("Screen 31 EOB Prompt", p)

# ══════════════════════════════════════════════════════════════════════
# SCREEN 32 — Notification Permission
# ══════════════════════════════════════════════════════════════════════
def s32():
    p = [status_bar(), home_bar(),
      ell("Bokeh violet", 316, 152, 104, 104, VIOLET_SOFT, 0.85),
      ell("Bokeh amber", 52, 298, 74, 74, AMBER_SOFT, 0.8),
      ell("Hero disc", 195, 206, 74, 74, WHITE, 0.9),
      ell("Bell disc", 195, 206, 52, 52, "url(#gradBlue)"),
      icon("Bell icon", I["bell"], WHITE, 178, 189, 34, 2.2),
      ell("Bell badge", 226, 178, 13, 13, RED),
      txt("Bell badge count", "3", 226, 183, 11, WHITE, FS, 800, "middle"),
      txt("Title", "Never miss a deadline", 195, 320, 26, T1, FS, 800, "middle", -1),
      lines("Subtitle", ["Dispute windows close fast. We'll remind you",
                         "before a right expires — nothing else."],
            195, 354, 24, 14.5, T2, FD, 400, "middle")]
    items = [("Deadline reminders","Before a dispute or GFE window closes","clock",AMBER,AMBER_SOFT),
             ("Follow-up nudges","When a provider hasn't replied in 14 days","mail",BLUE,BLUE_SOFT),
             ("Analysis complete","The moment your findings are ready","check",GREEN,GREEN_SOFT)]
    for i,(title, body, ico, c, cbg) in enumerate(items):
        y = 424 + i*88
        p += [card(f"Item {i+1}", 24, y, 342, 72, 16),
              rect(f"Item {i+1} tile", 42, y+18, 40, 40, 13, cbg),
              icon(f"Item {i+1} icon", I[ico], c, 51, y+27, 22, 2),
              txt(f"Item {i+1} title", title, 96, y+34, 14, T1, FS, 800, "start", -0.2),
              txt(f"Item {i+1} body", body, 96, y+54, 11.5, T2, FD, 400)]
    p += [button("Button Turn on reminders", "Turn on reminders", 24, 692, 342, 56,
                 "url(#gradBlue)", WHITE, 18, None, "shBtnBlue"),
          txt("Not now", "Not now", 195, 778, 15, T3, FS, 700, "middle")]
    return g("Screen 32 Notification Permission", p)

# ══════════════════════════════════════════════════════════════════════
if __name__ == "__main__":
    jobs = [
      (10,"OCR Review",       s10(),        BG),
      (11,"Analysis Progress",s11(),        BG),
      (12,"Results Overview", s12(False),   BG),
      (13,"Finding Detail",   s13(),        BG),
      (14,"Letter Generation",s14(),        BG),
      (15,"Case Management",  s15(False),   BG),
      (16,"Go Premium",       s16(),        "url(#gradDark)"),
      (17,"Youre All Set",    s17(),        WHITE),
      (18,"Case Timeline",    s18(),        BG),
      (19,"Your Rights",      s19(),        BG),
      (20,"Settings",         s20(),        BG),
      (21,"Results Dark",     s12(True),    DBG),
      (22,"No Cases Yet",     s22(),        BG),
      (23,"Home Dark",        home(True),   DBG),
      (24,"Cases Dark",       s15(True),    DBG),
      (25,"Findings List",    s25(),        BG),
      (26,"Phone Script",     s26(),        BG),
      (27,"Financial Assistance", s27(),    BG),
      (28,"Rights Detail NSA",s28(),        BG),
      (29,"Case Detail Summary", s29(),     BG),
      (30,"Scripts Tab",      s30(),        BG),
      (31,"EOB Prompt",       s31(),        BG),
      (32,"Notification Permission", s32(), BG),
    ]
    made = []
    for num, name, body, bg in jobs:
        made.append(write(num, name, body, bg))
    print(f"wrote {len(made)} SVG files")
    for m in made: print("  " + m)
