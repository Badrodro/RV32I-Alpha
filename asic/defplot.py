"""Plot a routed DEF as a two-panel PNG: (a) placement, (b) signal wires and power grid.

usage: python3 defplot.py <cells.lef> <design.def> <out.png>
Pure Python + Pillow; no EDA viewer needed.
"""
import re
import sys
from collections import defaultdict
from PIL import Image, ImageDraw, ImageFont

lef_path, def_path, out_path = sys.argv[1:4]

# ---- cell sizes from the LEF (microns) ----
size = {}
macro = None
for line in open(lef_path):
    t = line.split()
    if not t:
        continue
    if t[0] == 'MACRO':
        macro = t[1]
    elif t[0] == 'SIZE' and macro:
        size[macro] = (float(t[1]), float(t[3]))
    elif t[0] == 'END' and len(t) > 1 and t[1] == macro:
        macro = None

# ---- DEF: die, components, nets ----
dbu = 1000.0
die = None
cells = []                      # (master, x, y, orient)
de_nets = defaultdict(list)     # net -> instances whose DE pin it drives
rf_q = set()                    # instances whose Q output drives a register-file net
wires = defaultdict(list)       # layer -> [(x0, y0, x1, y1)] in microns
power = []                      # (layer, width, shape, x0, y0, x1, y1) in microns
SPECIAL = re.compile(r'(?:ROUTED|NEW)\s+(met\d)\s+(\d+)\s+\+\s+SHAPE\s+(STRIPE|FOLLOWPIN)\s+'
                     r'\(\s*(\S+)\s+(\S+)\s*\)\s+\(\s*(\S+)\s+(\S+)\s*\)')
section = None
net_buf = []


def parse_route(stmt):
    toks = stmt.replace('(', ' ( ').replace(')', ' ) ').split()
    i = 0
    while i < len(toks):
        if toks[i] in ('ROUTED', 'NEW', 'FIXED', 'COVER') and i + 1 < len(toks):
            layer = toks[i + 1]
            i += 2
            pts = []
            while i < len(toks) and toks[i] == '(':
                j = toks.index(')', i)
                v = toks[i + 1:j]
                px = pts[-1][0] if v[0] == '*' else float(v[0]) / dbu
                py = pts[-1][1] if v[1] == '*' else float(v[1]) / dbu
                pts.append((px, py))
                i = j + 1
            for a, b in zip(pts, pts[1:]):
                wires[layer].append((a[0], a[1], b[0], b[1]))
        else:
            i += 1


for line in open(def_path):
    s = line.strip()
    if s.startswith('UNITS DISTANCE MICRONS'):
        dbu = float(s.split()[3])
    elif s.startswith('DIEAREA'):
        n = [float(v) / dbu for v in re.findall(r'-?\d+', s)]
        die = (n[0], n[1], n[2], n[3])
    elif s.startswith('COMPONENTS'):
        section = 'C'
    elif s.startswith('END COMPONENTS'):
        section = None
    elif s.startswith('NETS'):
        section = 'N'
    elif s.startswith('END NETS'):
        section = None
    elif s.startswith('SPECIALNETS'):
        section = 'S'
    elif s.startswith('END SPECIALNETS'):
        section = None
    elif section == 'S':
        m = SPECIAL.search(s)
        if m and int(m.group(2)) > 0:
            xa, ya = float(m.group(4)) / dbu, float(m.group(5)) / dbu
            xb = xa if m.group(6) == '*' else float(m.group(6)) / dbu
            yb = ya if m.group(7) == '*' else float(m.group(7)) / dbu
            power.append((m.group(1), int(m.group(2)) / dbu, m.group(3), xa, ya, xb, yb))
    elif section == 'C' and s.startswith('-'):
        m = re.match(r'-\s+(\S+)\s+(\S+).*?(?:PLACED|FIXED)\s+\(\s*(-?\d+)\s+(-?\d+)\s*\)\s+(\S+)', s)
        if m:
            cells.append((m.group(1), m.group(2), float(m.group(3)) / dbu,
                          float(m.group(4)) / dbu, m.group(5)))
    elif section == 'N':
        net_buf.append(s)
        if s.endswith(';'):
            stmt = ' '.join(net_buf)
            net_buf = []
            name = stmt.split()[1]
            for inst in re.findall(r'\(\s*(\S+)\s+DE\s*\)', stmt):
                de_nets[name].append(inst)
            if re.search(r'rf\.regs', name):
                rf_q.update(re.findall(r'\(\s*(\S+)\s+Q\s*\)', stmt))
            parse_route(stmt)

# Register-file flip-flops: the flops driving the nets named rf.regs[..] when the netlist keeps
# that name; otherwise the enable flops on the 31 write-enable nets that each drive 32 of them.
regfile = set(rf_q)
if not regfile:
    for insts in de_nets.values():
        if len(insts) == 32:
            regfile.update(insts)

# ---- drawing ----
SS = 3                          # supersampling factor
P = 860                         # panel size in output pixels
M = 40                          # margin around each panel
TOP = 70                        # room for panel titles
BOT = 84                        # room for scale bar / legend
BAR = 50                        # scale bar length, microns
W, H = 2 * (P + 2 * M), P + TOP + BOT
x0, y0, x1, y1 = die
scale = P / max(x1 - x0, y1 - y0)
ser = '/usr/share/fonts/truetype/liberation/LiberationSerif-Regular.ttf'
font = ImageFont.truetype(ser, 38 * SS)      # sized for a ~700 px wide web column
small = ImageFont.truetype(ser, 32 * SS)


def to_px(panel, x, y):
    ox = panel * (P + 2 * M) + M
    return ((ox + (x - x0) * scale) * SS, (TOP + (y1 - y) * scale) * SS)


img = Image.new('RGB', (W * SS, H * SS), 'white')
d = ImageDraw.Draw(img)

GREY = (200, 200, 200)
RF = (64, 96, 150)              # register file
FF = (170, 60, 50)              # other flip-flops
n_rf = n_ff = 0
for name, master, x, y, orient in cells:
    w, h = size.get(master, (0.46, 2.72))
    if orient in ('E', 'W', 'FE', 'FW'):
        w, h = h, w
    if re.search(r'__(fill|decap|tapvpwrvgnd|diode)', master):
        continue                # physical-only cells are left out
    elif name in regfile:
        col = RF; n_rf += 1
    elif re.search(r'__(e?df|dlx|dlr|sdf)', master):
        col = FF; n_ff += 1
    else:
        col = GREY
    a = to_px(0, x, y + h)
    b = to_px(0, x + w, y)
    d.rectangle([a[0], a[1], b[0] - 1, b[1] - 1], fill=col)

# Routing panel: power grid first (met1 rails, met4/met5 straps), then the signal wires,
# each layer on its own transparent overlay.
RAIL = (225, 225, 225)
STRAP = (150, 150, 150)
for layer, width, shape, xa, ya, xb, yb in power:
    col = RAIL if shape == 'FOLLOWPIN' else STRAP
    px = max(SS, round(width * scale * SS)) if shape == 'STRIPE' else SS
    d.line([to_px(1, xa, ya), to_px(1, xb, yb)], fill=col, width=px)
LAYERS = [('met1', (40, 90, 175)), ('met2', (190, 50, 45)), ('met3', (40, 140, 80)),
          ('met4', (120, 70, 160)), ('met5', (215, 140, 20))]
for layer, col in LAYERS:
    ov = Image.new('RGBA', img.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(ov)
    for xa, ya, xb, yb in wires.get(layer, []):
        od.line([to_px(1, xa, ya), to_px(1, xb, yb)], fill=col + (150,), width=SS)
    img.paste(ov, (0, 0), ov)

# Die outlines, titles, scale bars, legends.
for panel, title in ((0, '(a) Placement'), (1, '(b) Signal wires and power grid')):
    a = to_px(panel, x0, y1)
    b = to_px(panel, x1, y0)
    d.rectangle([a[0], a[1], b[0], b[1]], outline=(0, 0, 0), width=SS)
    d.text((a[0], (TOP - 14) * SS), title, font=font, fill=(0, 0, 0), anchor='ls')
    sb = to_px(panel, x0, y0)
    yb = sb[1] + 42 * SS
    bar_end = sb[0] + BAR * scale * SS
    d.line([sb[0], yb, bar_end, yb], fill=(0, 0, 0), width=2 * SS)
    for xx in (sb[0], bar_end):
        d.line([xx, yb - 9 * SS, xx, yb + 9 * SS], fill=(0, 0, 0), width=2 * SS)
    lab = '%d µm' % BAR
    d.text((bar_end + 12 * SS, yb), lab, font=small, fill=(0, 0, 0), anchor='lm')

    if panel == 0:
        items = [(RF, 'register file'), (FF, 'other flip-flops'), (GREY, 'logic')]
    else:
        items = [(None, 'metal')] + [(c, n[3:]) for n, c in LAYERS if wires.get(n)]
        items.append((STRAP, 'power grid'))
    lx = bar_end + 12 * SS + d.textlength(lab, font=small) + 44 * SS
    for col, label in items:
        if col is None:             # plain text before a group of swatches
            d.text((lx, yb), label, font=small, fill=(0, 0, 0), anchor='lm')
            lx += d.textlength(label, font=small) + 18 * SS
            continue
        d.rectangle([lx, yb - 11 * SS, lx + 22 * SS, yb + 11 * SS], fill=col)
        d.text((lx + 30 * SS, yb), label, font=small, fill=(0, 0, 0), anchor='lm')
        lx += 30 * SS + d.textlength(label, font=small) + (18 if panel else 30) * SS
    assert lx < (panel + 1) * (P + 2 * M) * SS, 'legend wider than the panel'

img = img.resize((W, H), Image.LANCZOS)
img.save(out_path, optimize=True)

tot = {k: sum(abs(a - c) + abs(b - e) for a, b, c, e in v) for k, v in wires.items()}
print('die %.1f x %.1f um' % (x1 - x0, y1 - y0))
print('cells', len(cells), 'regfile', n_rf, 'other ff', n_ff)
print('wire length (um) by layer', {k: round(v) for k, v in sorted(tot.items())})
print('total', round(sum(tot.values())))
