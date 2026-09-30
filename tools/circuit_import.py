"""Converts real-circuit GeoJSON centre lines (bacinger/f1-circuits, MIT) into game curves.
Usage: python3 circuit_import.py <geojson> <px_per_m> <out_png> [start_index] [reverse]"""
import json, math, sys
from PIL import Image, ImageDraw
def load(path):
    d = json.load(open(path))
    coords = d["features"][0]["geometry"]["coordinates"]
    lon0 = sum(c[0] for c in coords) / len(coords); lat0 = sum(c[1] for c in coords) / len(coords)
    R = 6371000.0
    pts = [((c[0]-lon0)*math.pi/180*R*math.cos(lat0*math.pi/180), -(c[1]-lat0)*math.pi/180*R) for c in coords]
    if math.dist(pts[0], pts[-1]) < 1: pts = pts[:-1]
    return pts, d["features"][0]["properties"]
def length(p): return sum(math.dist(p[i], p[(i+1)%len(p)]) for i in range(len(p)))
def area(p): return sum(p[i][0]*p[(i+1)%len(p)][1]-p[(i+1)%len(p)][0]*p[i][1] for i in range(len(p)))/2
if __name__ == "__main__":
    pts, props = load(sys.argv[1]); s = float(sys.argv[2])
    print(props.get("Name"), "points", len(pts), "len m", round(length(pts)), "signed area (screen, >0 = clockwise)", round(area(pts)))
    P = [(x*s, y*s) for x, y in pts]
    xs=[p[0] for p in P]; ys=[p[1] for p in P]
    mnx,mny=min(xs)-300,min(ys)-300; sc=0.08
    im=Image.new("RGB",(int((max(xs)-mnx+300)*sc),int((max(ys)-mny+300)*sc)),(40,100,40)); d=ImageDraw.Draw(im)
    Q=[((x-mnx)*sc,(y-mny)*sc) for x,y in P]
    d.line(Q+[Q[0]],fill=(200,200,200),width=3)
    for i in range(0,len(Q),max(1,len(Q)//40)):
        d.text((Q[i][0]+3,Q[i][1]),str(i),fill=(255,255,0))
    d.ellipse([Q[0][0]-5,Q[0][1]-5,Q[0][0]+5,Q[0][1]+5],fill=(255,0,0))
    d.ellipse([Q[5][0]-4,Q[5][1]-4,Q[5][0]+4,Q[5][1]+4],fill=(0,200,255))
    im.save(sys.argv[3]); print("size", im.size)
