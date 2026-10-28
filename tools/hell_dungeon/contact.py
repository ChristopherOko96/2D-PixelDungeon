import sys,os,json
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import img
d=sys.argv[1]; names=sys.argv[3].split(',') if len(sys.argv)>3 else sorted(json.load(open(d+'/manifest.json')))
W=1500; x=y=8; rowh=0; ims=[]
for n in names:
    im=img.load(os.path.join(d,n+'.png'))
    if x+im.w>W-8: x=8; y+=rowh+8; rowh=0
    ims.append((im,x,y)); x+=im.w+8; rowh=max(rowh,im.h)
H=y+rowh+8
out=img.Img(W,H,bytearray([58,52,60,255])*(W*H))
for im,x,y in ims: out.paste(im,x,y)
img.save(out,sys.argv[2]); print(W,H)
