"""Builds a game Curve2D (Godot .tscn point data) from a real circuit centre line.
Source outlines: https://github.com/bacinger/f1-circuits (MIT, (c) Tomislav Bacinger).
Pipeline: lat/lon -> metres -> px (px_per_m) -> resample -> light smoothing (limits the minimum
radius) -> Douglas-Peucker simplify -> Bezier handles along the local tangent (1/3 of each segment).
Usage: python3 make_circuit.py <geojson> <px_per_m> <smooth_iters> <out_prefix> [start_shift_m]"""
import json, math, sys
from PIL import Image, ImageDraw
from circuit_import import load

def resample(P, step):
    out = []; n = len(P); acc = 0.0
    segs = [(P[i], P[(i+1) % n]) for i in range(n)]
    carry = 0.0
    for a, b in segs:
        L = math.dist(a, b); t = carry
        while t < L:
            out.append((a[0] + (b[0]-a[0]) * t / L, a[1] + (b[1]-a[1]) * t / L)); t += step
        carry = t - L
    return out

def smooth(P, iters, lam=0.5):
    n = len(P)
    for _ in range(iters):
        P = [(P[i][0] + lam * ((P[i-1][0] + P[(i+1) % n][0]) / 2 - P[i][0]),
              P[i][1] + lam * ((P[i-1][1] + P[(i+1) % n][1]) / 2 - P[i][1])) for i in range(n)]
    return P

def local_radius(P, i, k=4):
    n = len(P); a, b, c = P[i-k], P[i], P[(i+k) % n]
    A, B, C = math.dist(a, b), math.dist(b, c), math.dist(a, c)
    cr = abs((b[0]-a[0])*(c[1]-a[1]) - (b[1]-a[1])*(c[0]-a[0]))
    return 1e9 if cr < 1e-6 else A*B*C/(2*cr)

def limit_radius(P, rmin, spread=6, max_rounds=600):
    """Smooths only around corners tighter than rmin (keeps straights/features elsewhere)."""
    n = len(P)
    for _ in range(max_rounds):
        bad = [i for i in range(n) if local_radius(P, i) < rmin]
        if not bad: break
        mark = set()
        for i in bad:
            for j in range(-spread, spread+1): mark.add((i+j) % n)
        Q = list(P)
        for i in mark:
            Q[i] = (P[i][0] + 0.5*((P[i-1][0]+P[(i+1) % n][0])/2 - P[i][0]),
                    P[i][1] + 0.5*((P[i-1][1]+P[(i+1) % n][1])/2 - P[i][1]))
        P = Q
    return P

def dp(P, eps):
    def rec(a, b):
        ax, ay = P[a]; bx, by = P[b]; dx, dy = bx-ax, by-ay; L = math.hypot(dx, dy) or 1e-9
        best, bi = 0, -1
        for i in range(a+1, b):
            d = abs(dy*(P[i][0]-ax) - dx*(P[i][1]-ay)) / L
            if d > best: best, bi = d, i
        if best > eps: return rec(a, bi)[:-1] + rec(bi, b)
        return [a, b]
    # closed loop (P[0] == P[-1]): split at the point farthest from the start
    far = max(range(len(P)), key=lambda i: math.dist(P[0], P[i]))
    idx = rec(0, far)[:-1] + rec(far, len(P)-1)
    return [P[i] for i in idx[:-1]]

def handles(Q):
    n = len(Q); H = []
    for i in range(n):
        p0, p1, p2 = Q[i-1], Q[i], Q[(i+1) % n]
        tx, ty = p2[0]-p0[0], p2[1]-p0[1]; tl = math.hypot(tx, ty) or 1e-9; tx, ty = tx/tl, ty/tl
        li = lo = math.dist(p0, p2) / 6
        H.append(((-tx*li, -ty*li), (tx*lo, ty*lo)))
    return H

def bez_samples(Q, H, per=24):
    out = []; n = len(Q)
    for i in range(n):
        a = Q[i]; b = Q[(i+1) % n]; c1 = (a[0]+H[i][1][0], a[1]+H[i][1][1]); c2 = (b[0]+H[(i+1) % n][0][0], b[1]+H[(i+1) % n][0][1])
        L = math.dist(a, b); k = max(4, int(L / 15))
        for j in range(k):
            t = j / k; u = 1-t
            out.append((u**3*a[0]+3*u*u*t*c1[0]+3*u*t*t*c2[0]+t**3*b[0], u**3*a[1]+3*u*u*t*c1[1]+3*u*t*t*c2[1]+t**3*b[1]))
    return out

def metrics(S, road_half, wall):
    n = len(S); arc = [0.0]
    for i in range(1, n): arc.append(arc[-1] + math.dist(S[i], S[i-1]))
    L = arc[-1] + math.dist(S[-1], S[0])
    minr = 1e9; where = None
    for i in range(n):
        a, b, c = S[i-3], S[i], S[(i+3) % n]
        A, B, C = math.dist(a, b), math.dist(b, c), math.dist(a, c)
        cr = abs((b[0]-a[0])*(c[1]-a[1]) - (b[1]-a[1])*(c[0]-a[0]))
        if cr > 1e-6:
            r = A*B*C/(2*cr)
            if r < minr: minr, where = r, b
    best = 1e9; bw = None
    step = max(1, n // 1500)
    for i in range(0, n, step):
        for j in range(i+1, n, step):
            da = abs(arc[j]-arc[i]); da = min(da, L-da)
            if da > 1200:
                d = math.dist(S[i], S[j])
                if d < best: best, bw = d, (S[i], S[j])
    return L, minr, where, best, bw

if __name__ == "__main__":
    src, ppm, iters, out = sys.argv[1], float(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
    shift = float(sys.argv[5]) if len(sys.argv) > 5 else 0.0
    pts, props = load(src)
    P = [(x*ppm, y*ppm) for x, y in pts]
    R = resample(P, 12.0)
    if shift:
        k = int(shift*ppm/12.0) % len(R); R = R[k:] + R[:k]
    R = smooth(R, iters)
    rmin = float(sys.argv[6]) if len(sys.argv) > 6 else 120.0
    R = limit_radius(R, rmin)
    # uniform resample + Catmull-Rom handles (C1, no kinks; ~70 px between curve points)
    Q = resample(R, 70.0)
    # translate so point 0 (start/finish) is at the origin
    ox, oy = Q[0]; Q = [(x-ox, y-oy) for x, y in Q]
    H = handles(Q)
    S = bez_samples(Q, H)
    L, minr, where, sep, bw = metrics(S, 100, 180)
    print(f"{props['Name']}: curve points {len(Q)}, game length {L:.0f} px (~{L/ppm:.0f} m real-scale), min radius {minr:.0f} px at {where}, min separation {sep:.0f} px at {bw}")
    arr = []
    for i in list(range(len(Q))) + [0]:
        arr += [H[i][0][0], H[i][0][1], H[i][1][0], H[i][1][1], Q[i][0], Q[i][1]]
    open(out + ".points", "w").write(json.dumps({"count": len(Q)+1, "points": [round(v, 1) for v in arr], "length": L}))
    xs = [p[0] for p in S]; ys = [p[1] for p in S]
    mnx, mny = min(xs)-400, min(ys)-400; sc = 0.05
    im = Image.new("RGB", (int((max(xs)-mnx+400)*sc), int((max(ys)-mny+400)*sc)), (45, 110, 45)); d = ImageDraw.Draw(im)
    T = [((x-mnx)*sc, (y-mny)*sc) for x, y in S]
    d.line(T+[T[0]], fill=(110, 110, 110), width=int(360*sc)); d.line(T+[T[0]], fill=(40, 40, 45), width=int(200*sc))
    d.ellipse([T[0][0]-4, T[0][1]-4, T[0][0]+4, T[0][1]+4], fill=(255, 255, 255))
    d.ellipse([T[40][0]-3, T[40][1]-3, T[40][0]+3, T[40][1]+3], fill=(0, 200, 255))
    im.save(out + ".png")
