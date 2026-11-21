"""Draw-order test boxes, laid out like the object guides in art_templates/.

Used by tests/test_visual_draw_order.gd. To redraw them (from this folder):
    python gen_test_boxes.py . .

Each sheet has one frame per facing (0-3, left to right); frame width 16 * (cells across
+ cells deep), footprint diamond at the bottom. Station boxes are blue; the probe (a
pawn stand-in) is magenta with a wider "shoulder" band, like arms or a carried box.
"""
import sys, os
sys.path.insert(0, sys.argv[1])
from px import *

OUT = sys.argv[2]
os.makedirs(OUT, exist_ok=True)
TOP, LEFT, RIGHT = hexc('5FB4E8'), hexc('3A86C8'), hexc('235E9A')


def box_frame(fu, fv, frame_h, h, top=TOP, left=LEFT, right=RIGHT):
    w = 16 * (fu + fv)
    cv = Canvas(w, frame_h)
    iso = Iso(cv, 16 * fv, frame_h - 8 * (fu + fv))
    iso.box(0, fu, 0, fv, 0, h, top, left, right)
    return cv


def sheet(name, frames):
    w = sum(f.w for f in frames)
    h = max(f.h for f in frames)
    cv = Canvas(w, h)
    x = 0
    for f in frames:
        cv.blit(f, x, h - f.h)
        x += f.w
    write_png(os.path.join(OUT, name), cv.w, cv.h, cv.p)
    print(name, cv.w, cv.h)


# Station boxes on each guide. A footprint (fu, fv) at facing 0 is turned to (fv, fu) at
# facings 1 and 3.
sheet('box_1x1.png', [box_frame(1, 1, 64, 40)] * 4)
sheet('box_2x1_low.png', [box_frame(2, 1, 64, 16), box_frame(1, 2, 64, 16)] * 2)
sheet('box_2x1_tall.png', [box_frame(2, 1, 64, 40), box_frame(1, 2, 64, 40)] * 2)
sheet('box_2x2.png', [box_frame(2, 2, 80, 40)] * 4)
sheet('box_3x3.png', [box_frame(3, 3, 96, 40)] * 4)

# Probe: a pawn-sized box on one cell, 36 tall, with a band from 18 to 30 up that reaches
# 3 px past the cell on each side (like arms, or a carried box held out in front).
P_TOP, P_LEFT, P_RIGHT, P_BAND = hexc('F06AD8'), hexc('C83FB0'), hexc('9A2486'), hexc('FF9CEC')
probe = Canvas(38, 64)
iso = Iso(probe, 19, 48)
iso.box(0.25, 0.75, 0.25, 0.75, 0, 36, P_TOP, P_LEFT, P_RIGHT)
cx, cy = iso.P(0.5, 0.5, 0)
for y in range(int(cy - 30), int(cy - 18)):
    for x in range(int(cx - 19), int(cx + 19)):
        probe.set(x, y, P_BAND)
write_png(os.path.join(OUT, 'probe.png'), probe.w, probe.h, probe.p)
print('probe.png')
