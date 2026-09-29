#!/usr/bin/env python3
"""Rebuild screens 01-04 with the user's uploaded artwork embedded as image fills."""
import base64, os
from gen import (rect, ell, path, txt, lines, g, icon, status_bar, home_bar, button,
                 DEFS, W, H, I, esc,
                 NAVY, NAVY2, BLUE, BLUE2, BLUE_SOFT, TEAL, TEAL2, TEAL_SOFT,
                 AMBER, AMBER_SOFT, VIOLET, VIOLET_SOFT, GREEN,
                 T1, T2, T3, T4, WHITE, BG, LINE, FS, FD, FO, FF, FM)

OUT = "screens"

def b64(p):
    with open(p, "rb") as f:
        return "data:image/png;base64," + base64.b64encode(f.read()).decode()

def img(id, src, x, y, w, h, par="xMidYMid meet"):
    return (f'<image id="{esc(id)}" x="{x}" y="{y}" width="{w}" height="{h}" '
            f'preserveAspectRatio="{par}" xlink:href="{src}"/>')

EXTRA_DEFS = '''<linearGradient id="scrimBottom" x1="0" y1="0" x2="0" y2="1">
  <stop offset="0" stop-color="#061432" stop-opacity="0"/>
  <stop offset="1" stop-color="#061432" stop-opacity="0.58"/></linearGradient>'''

def screen2(name, body, bg=BG):
    defs = DEFS.replace("</defs>", EXTRA_DEFS + "</defs>")
    return (f'<svg xmlns="http://www.w3.org/2000/svg" '
            f'xmlns:xlink="http://www.w3.org/1999/xlink" '
            f'width="{W}" height="{H}" viewBox="0 0 {W} {H}" fill="none">\n{defs}\n'
            f'<g id="{esc(name)}">\n<rect id="Background" width="{W}" height="{H}" fill="{bg}"/>\n'
            f'{body}\n</g>\n</svg>\n')

def write2(num, slug, name, body, bg=BG):
    fn = os.path.join(OUT, f"{num:02d}-{slug}.svg")
    open(fn, "w").write(screen2(name, body, bg))
    return fn, os.path.getsize(fn)

# ── 01 SPLASH ─────────────────────────────────────────────────────────
def s01():
    src = b64("assets/splash-bg.png")
    p = [g("Splash artwork", [img("artwork", src, 0, 0, 390, 844, "xMidYMid slice")],
             "translate(20,0)"),
      rect("Bottom scrim", 0, 540, 390, 304, 0, "url(#scrimBottom)"),
      status_bar("light"), home_bar("light"),
      txt("Wordmark", "BillFixer", 195, 262, 45, WHITE, FF, 900, "middle", -4),
      txt("Tagline", "Your medical bill, decoded.", 195, 296, 16, WHITE, FD, 400, "middle", None, 0.78),
      lines("Value props", ["Find errors.", "Know your rights.", "Take action."],
            195, 676, 26, 14.5, WHITE, FS, 600, "middle"),
      rect("Dot 1 active", 168, 772, 26, 6, 3, TEAL2),
      rect("Dot 2", 198, 772, 6, 6, 3, WHITE, 0.34),
      rect("Dot 3", 208, 772, 6, 6, 3, WHITE, 0.34)]
    return g("Screen 01 Splash", p)

# ── ONBOARDING SHELL ──────────────────────────────────────────────────
def onboarding(idx, artwork, art_box, title_lines, body_lines, cta, dot_color, dim_dot, bokeh):
    ax, ay, aw, ah = art_box
    p = [status_bar(), home_bar()]
    for i,(bx,by,br,bc,bo) in enumerate(bokeh):
        p.append(ell(f"Bokeh {i+1}", bx, by, br, br, bc, bo))
    p.append(txt("Skip", "Skip", 366, 82, 15, BLUE, FO, 600, "end"))
    p.append(img(f"Onboarding {idx} artwork", artwork, ax, ay, aw, ah))
    ty = 500
    for i, line in enumerate(title_lines):
        p.append(txt(f"Title line {i+1}", line, 28, ty + i*38, 35, T1, FO, 700, "start", -3.5))
    by0 = ty + len(title_lines)*38 + 24
    p.append(lines("Body", body_lines, 28, by0, 27, 16.5, T2, FD, 400))
    wide = cta != "Next"
    total = 24 + 8 + 8 + 14
    cx = (390 - total) / 2 if wide else 28
    dy = 712 if wide else 744
    for i in range(3):
        wpx = 24 if i == idx-1 else 8
        col = dot_color if i == idx-1 else dim_dot
        p.append(rect(f"Dot {i+1}", cx, dy, wpx, 8, 4, col))
        cx += wpx + 7
    if wide:
        p.append(button(f"Button {cta}", cta, 28, 744, 334, 56,
                        "url(#gradNavy)", WHITE, 18, None, "shBtnNavy"))
    else:
        p.append(button(f"Button {cta}", cta, 212, 720, 150, 56,
                        "url(#gradNavy)", WHITE, 18, None, "shBtnNavy", I["arrowR"]))
    return g(f"Screen 0{idx+1} Onboarding {idx}", p)

def s02():
    return onboarding(1, b64("assets/onb1.png"), (38, 104, 314, 334),
      ["Scan your", "medical bill"],
      ["Upload a photo, PDF, or take a quick", "scan. We'll extract the details for you."],
      "Next", BLUE, "#CDD9E8",
      [(214, 38, 224, "#D9EBFF", 0.6), (-20, 212, 148, "#E2F9F5", 0.85), (298, 340, 92, "#FFF0D6", 0.75)])

def s03():
    return onboarding(2, b64("assets/onb2.png"), (14, 164, 362, 252),
      ["We find", "potential issues"],
      ["We check the math, find duplicate", "charges, compare with your EOB, and",
       "look up your hospital's published prices."],
      "Next", AMBER, "#E3D6BC",
      [(-34, 60, 192, "#FFF0D6", 0.8), (254, 208, 164, BLUE_SOFT, 0.85), (258, 54, 84, "#FFE8E3", 0.75)])

def s04():
    return onboarding(3, b64("assets/onb3.png"), (14, 164, 362, 252),
      ["Get a plan", "and take action"],
      ["Receive clear explanations, ready-to-send", "letters, and phone scripts. Track your",
       "progress in one place."],
      "Get Started", VIOLET, "#D5D0EE",
      [(-18, 40, 176, "#E7E2FF", 0.75), (236, 158, 188, "#DFF7F1", 0.75), (278, 50, 80, BLUE_SOFT, 0.85)])

if __name__ == "__main__":
    jobs = [(1, "splash", "Splash", s01(), NAVY),
            (2, "onboarding-1", "Onboarding 1", s02(), WHITE),
            (3, "onboarding-2", "Onboarding 2", s03(), WHITE),
            (4, "onboarding-3", "Onboarding 3", s04(), WHITE)]
    for num, slug, name, body, bg in jobs:
        fn, size = write2(num, slug, name, body, bg)
        print(f"  {fn}  ({round(size/1024)} KB)")
