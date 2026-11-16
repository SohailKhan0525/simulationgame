"""Draw the fictional product labels and their market posters at print resolution."""
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parents[1] / "assets/packaging"
FONT = "/usr/share/fonts/truetype/dejavu/"
def font(size, serif=False, bold=False):
    return ImageFont.truetype(FONT+("DejaVuSerif" if serif else "DejaVuSans")+("-Bold" if bold else "")+".ttf",size)


def sprig(draw, x,y, scale, fg):
    draw.line((x-58*scale,y+40*scale,x+59*scale,y-40*scale),fill=fg,width=max(2,int(3*scale)))
    for i in range(5):
        px=x+(-45+22*i)*scale;py=y+(32-16*i)*scale
        for side in [-1,1]:
            tip=(px+side*20*scale,py-20*scale if side<0 else py+11*scale)
            draw.polygon([(px,py),(tip[0]-5*scale,tip[1]+3*scale),tip,(px+7*scale,py-2*scale)], fill=fg)


products=[('tea','QUAYSIDE','TEA','CEYLON BLEND','203e36','e7d4a5','ae7b39'),
          ('soap','OLIVE GROVE','SOAP','BOTANICAL BAR','e8ddbc','254941','77825a'),
          ('cocoa','NIGHT FERRY','COCOA','DARK DRINKING CHOCOLATE','74392f','f5ddad','cca257'),
          ('oats','MILLHOUSE','OATS','ROLLED WHOLEGRAIN','debb84','433b2e','906e43'),
          ('pasta','TIDEWHEEL','PASTA','DURUM WHEAT • FUSILLI','aa642f','fff0d0','dfb66c'),
          ('rice','LANTERN','RICE','LONG GRAIN','aabd9e','243d34','718969')]
for key,brand,name,line,bg,fg,accent in products:
    bg,fg,accent=['#'+c for c in (bg,fg,accent)]
    im=Image.new('RGB',(384,480),bg);d=ImageDraw.Draw(im)
    d.rectangle((14,15,370,465),outline=accent,width=3)
    d.text((192,59),brand,font=font(28,bold=True),fill=fg,anchor='mm')
    d.line((42,92,342,92),fill=accent,width=3)
    if key=='cocoa':
        for off in [-28,0,28]:
            d.arc((100+off,115,241+off,249),-65,126,fill=accent,width=5)
        d.line((126,242,264,140),fill=fg,width=3)
    elif key=='pasta':
        for i in range(7):
            x=129+i*17
            d.arc((x,140,x+37,216),-68,200,fill=fg,width=6)
    elif key in ('oats','rice'):
        for offset in [-23, 10, 40]:
            d.line((169+offset,235,202+offset,137),fill=fg,width=3)
            for i in range(5):
                x,y=172+offset+i*5,214-i*15
                d.ellipse((x-12,y-12,x,y+2),fill=accent)
                d.ellipse((x+3,y-7,x+16,y+4),fill=fg)
    else:
        sprig(d,193,183,1.28,fg)
    d.text((192,301),name,font=font(76,True,True),fill=fg,anchor='mm')
    d.text((192,359),line,font=font(14,bold=True),fill=fg,anchor='mm')
    d.line((73,392,311,392),fill=accent,width=2)
    d.text((192,424),"HARBOR  •  PROVISIONS",font=font(16),fill=fg,anchor='mm')
    im.save(OUT/(key+'.png'),optimize=True)
