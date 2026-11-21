"""Tiny pixel-art toolkit: PNG read/write, canvas, iso projection matching Za's art."""
import zlib, struct, math


def hexc(h):
    h = h.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def write_png(path, w, h, px):
    rows = []
    for y in range(h):
        row = bytearray(b'\x00')
        for x in range(w):
            row += bytes(px.get((x, y), (0, 0, 0, 0)))
        rows.append(bytes(row))
    raw = b''.join(rows)

    def chunk(t, d):
        return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    data = (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))
    with open(path, 'wb') as f:
        f.write(data)


def read_png(path):
    with open(path, 'rb') as f:
        data = f.read()
    pos = 8
    idat = b''
    plte = None
    trns = None
    while pos < len(data):
        ln = struct.unpack('>I', data[pos:pos + 4])[0]
        t = data[pos + 4:pos + 8]
        d = data[pos + 8:pos + 8 + ln]
        pos += 12 + ln
        if t == b'IHDR':
            w, h, bd, ct = struct.unpack('>IIBB', d[:10])
        elif t == b'PLTE':
            plte = [tuple(d[i:i + 3]) for i in range(0, len(d), 3)]
        elif t == b'tRNS':
            trns = d
        elif t == b'IDAT':
            idat += d
    assert bd == 8, bd
    bpp = {6: 4, 2: 3, 3: 1, 4: 2, 0: 1}[ct]
    raw = zlib.decompress(idat)
    stride = w * bpp
    prev = bytearray(stride)
    px = {}
    i = 0
    for y in range(h):
        ft = raw[i]; i += 1
        line = bytearray(raw[i:i + stride]); i += stride
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0
            b = prev[x]
            c = prev[x - bpp] if x >= bpp else 0
            if ft == 1: line[x] = (line[x] + a) & 255
            elif ft == 2: line[x] = (line[x] + b) & 255
            elif ft == 3: line[x] = (line[x] + (a + b) // 2) & 255
            elif ft == 4:
                p = a + b - c; pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[x] = (line[x] + pr) & 255
        prev = line
        for x in range(w):
            if ct == 6: col = tuple(line[x * 4:x * 4 + 4])
            elif ct == 2: col = tuple(line[x * 3:x * 3 + 3]) + (255,)
            elif ct == 3:
                idx = line[x]
                al = trns[idx] if trns and idx < len(trns) else 255
                col = plte[idx] + (al,)
            elif ct == 4: col = (line[x * 2],) * 3 + (line[x * 2 + 1],)
            else: col = (line[x],) * 3 + (255,)
            if col[3]:
                px[(x, y)] = col
    return w, h, px


class Canvas:
    def __init__(self, w, h):
        self.w, self.h, self.p = w, h, {}

    def set(self, x, y, c):
        if c is not None and 0 <= x < self.w and 0 <= y < self.h:
            self.p[(x, y)] = c

    def get(self, x, y):
        return self.p.get((x, y))

    def poly(self, pts, c):
        ys = [q[1] for q in pts]
        n = len(pts)
        for y in range(max(0, int(math.floor(min(ys))) - 1), min(self.h, int(math.ceil(max(ys))) + 1)):
            yc = y + 0.5
            xs = []
            for i in range(n):
                (x1, y1), (x2, y2) = pts[i], pts[(i + 1) % n]
                if (y1 <= yc < y2) or (y2 <= yc < y1):
                    xs.append(x1 + (yc - y1) * (x2 - x1) / (y2 - y1))
            xs.sort()
            for a, b in zip(xs[0::2], xs[1::2]):
                for x in range(int(math.ceil(a - 0.5 - 1e-9)), int(math.ceil(b - 0.5 - 1e-9))):
                    self.set(x, y, c)

    def line(self, a, b, c, bias=0.5):
        """Pixel line; for shallow iso lines picks rows like Za's tabletop edges."""
        (x1, y1), (x2, y2) = a, b
        if abs(x2 - x1) >= abs(y2 - y1):
            if x1 > x2: (x1, y1), (x2, y2) = (x2, y2), (x1, y1)
            for x in range(int(round(x1)), int(round(x2))):
                t = x + 0.5
                y = y1 + (t - x1) * (y2 - y1) / (x2 - x1) if x2 != x1 else y1
                self.set(x, int(math.floor(y + bias)), c)
        else:
            if y1 > y2: (x1, y1), (x2, y2) = (x2, y2), (x1, y1)
            for y in range(int(round(y1)), int(round(y2))):
                t = y + 0.5
                x = x1 + (t - y1) * (x2 - x1) / (y2 - y1)
                self.set(int(math.floor(x)), y, c)

    def ellipse(self, cx, cy, rx, ry, c, c_right=None):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                if dx * dx + dy * dy <= 1.0:
                    self.set(x, y, c_right if (c_right and x + 0.5 > cx) else c)

    def blit(self, other, ox, oy, flip=False):
        for (x, y), col in other.p.items():
            self.set(ox + (other.w - 1 - x if flip else x), oy + y, col)

    def flipped(self):
        c = Canvas(self.w, self.h)
        c.blit(self, 0, 0, flip=True)
        return c


class Iso:
    """u axis runs down-right, v axis runs down-left, h is up. One cell = 32x16 px."""
    def __init__(self, cv, ox, oy):
        self.cv, self.ox, self.oy = cv, ox, oy

    def P(self, u, v, h=0):
        return (self.ox + 16 * (u - v), self.oy + 8 * (u + v) - h)

    def box(self, u0, u1, v0, v1, h0, h1, top=None, left=None, right=None):
        P = self.P
        if left: self.cv.poly([P(u0, v1, h1), P(u1, v1, h1), P(u1, v1, h0), P(u0, v1, h0)], left)
        if right: self.cv.poly([P(u1, v0, h1), P(u1, v1, h1), P(u1, v1, h0), P(u1, v0, h0)], right)
        if top: self.cv.poly([P(u0, v0, h1), P(u1, v0, h1), P(u1, v1, h1), P(u0, v1, h1)], top)

    def top_edges(self, u0, u1, v0, v1, h, cl, cr=None):
        """Front edges of a top face (the light rim on Za's tables / counter)."""
        P = self.P
        self.cv.line(P(u0, v1, h), P(u1, v1, h), cl)
        self.cv.line(P(u1, v1, h), P(u1, v0, h), cr or cl)

    def back_edges(self, u0, u1, v0, v1, h, c):
        P = self.P
        self.cv.line(P(u0, v1, h), P(u0, v0, h), c, bias=0.0)
        self.cv.line(P(u0, v0, h), P(u1, v0, h), c, bias=0.0)

    def lrect(self, v, u0, u1, h0, h1, c):
        """Rectangle drawn on a left-facing (constant v) plane."""
        P = self.P
        self.cv.poly([P(u0, v, h1), P(u1, v, h1), P(u1, v, h0), P(u0, v, h0)], c)

    def rrect(self, u, v0, v1, h0, h1, c):
        """Rectangle drawn on a right-facing (constant u) plane."""
        P = self.P
        self.cv.poly([P(u, v0, h1), P(u, v1, h1), P(u, v1, h0), P(u, v0, h0)], c)

    def lline(self, v, u0, u1, h, c):
        self.cv.line(self.P(u0, v, h), self.P(u1, v, h), c, bias=0.0)

    def rline(self, u, v0, v1, h, c):
        self.cv.line(self.P(u, v0, h), self.P(u, v1, h), c, bias=0.0)

    def cyl(self, u, v, r, h0, h1, side_l, side_r, rim, inner=None):
        cx, cy = self.P(u, v, 0)
        rx, ry = 16 * math.sqrt(2) * r, 8 * math.sqrt(2) * r
        for h in range(int(h0), int(h1)):
            self.cv.ellipse(cx, cy - h, rx, ry, side_l, side_r)
        self.cv.ellipse(cx, cy - h1, rx, ry, rim)
        if inner:
            self.cv.ellipse(cx, cy - h1, rx - 1.5, ry - 1, inner)
