import math, sys
from PIL import Image, ImageDraw
S = 1.0
PTS = [(0,0),(900,0),(1700,0),(2250,200),(2400,750),(2050,1200),(1450,1250),(1000,1500),
       (1050,2050),(1650,2250),(2300,2350),(2550,2900),(2150,3400),(1300,3450),(400,3350),
       (-400,3350),(-1050,3000),(-1150,2300),(-800,2000),(-420,1680),(-430,1250),(-850,950),(-1150,700),(-1150,280),(-800,40)]
PTS = [(x*S,y*S) for x,y in PTS]
n = len(PTS)
def handles(i, t=1/6):
    p0 = PTS[(i-1)%n]; p2 = PTS[(i+1)%n]
    return ((p2[0]-p0[0])*t, (p2[1]-p0[1])*t)
def bez(a,b,c,d,t):
    u=1-t
    return (u**3*a[0]+3*u*u*t*b[0]+3*u*t*t*c[0]+t**3*d[0], u**3*a[1]+3*u*u*t*b[1]+3*u*t*t*c[1]+t**3*d[1])
samples=[]
for i in range(n):
    p=PTS[i]; q=PTS[(i+1)%n]; h1=handles(i); h2=handles((i+1)%n)
    for k in range(40):
        samples.append(bez(p,(p[0]+h1[0],p[1]+h1[1]),(q[0]-h2[0],q[1]-h2[1]),q,k/40))
L=0; arc=[0]
for i in range(1,len(samples)):
    L+=math.dist(samples[i],samples[i-1]); arc.append(L)
L+=math.dist(samples[-1],samples[0])
print("length",round(L))
# min separation between non-local samples
best=1e9;where=None
for i in range(0,len(samples),2):
    for j in range(i+1,len(samples),2):
        da=abs(arc[j]-arc[i]); da=min(da,L-da)
        if da>900:
            d=math.dist(samples[i],samples[j])
            if d<best: best=d; where=(samples[i],samples[j])
print("min sep",round(best),where)
# min radius
minr=1e9
for i in range(len(samples)):
    a=samples[i-2];b=samples[i];c=samples[(i+2)%len(samples)]
    A=math.dist(a,b);B=math.dist(b,c);C=math.dist(a,c)
    cross=abs((b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0]))
    if cross>1e-6:
        r=A*B*C/(2*cross); 
        if r<minr: minr=r; wr=b
print("min radius",round(minr),wr)
xs=[p[0] for p in samples]; ys=[p[1] for p in samples]
mnx,mny=min(xs)-400,min(ys)-400; W=max(xs)+400-mnx; H=max(ys)+400-mny
sc=0.2
im=Image.new("RGB",(int(W*sc),int(H*sc)),(60,140,60)); d=ImageDraw.Draw(im)
P=[((x-mnx)*sc,(y-mny)*sc) for x,y in samples]
d.line(P+[P[0]],fill=(90,90,90),width=int(460*sc))
d.line(P+[P[0]],fill=(50,50,55),width=int(240*sc))
d.ellipse([P[0][0]-5,P[0][1]-5,P[0][0]+5,P[0][1]+5],fill=(255,255,255))
im.save("/tmp/track_preview.png")
if len(sys.argv)>1:
    # emit Curve2D points: in(-h), out(+h), pos ... closing point = first
    arr=[]
    for i in list(range(n))+[0]:
        h=handles(i); p=PTS[i]
        arr += [-h[0],-h[1],h[0],h[1],p[0],p[1]]
    print("PTS=", ", ".join(f"{v:.1f}" for v in arr))
    print("COUNT=", n+1)
