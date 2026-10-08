from PIL import Image, ImageDraw, ImageFilter
from pathlib import Path
import os
root=Path('/Users/tanlantian/Library/Caches/ViolaDesktop/source/Sources/ViolaDesktop/Resources/Characters/Viola')
cache=Path('/Users/tanlantian/Library/Caches/ViolaDesktop/natural-laugh-v0.2.46')
im=Image.open(root/'viola-natural-belly-laugh-v0.2.46.png').convert('RGBA')
box=(410,443,519,529)
poly=[(420,481),(423,477),(441,469),(464,461),(487,455),(501,455),(504,460),(505,475),(499,492),(489,507),(475,515),(460,517),(444,510),(433,501),(424,490)]
m=Image.new('L',im.size);ImageDraw.Draw(m).polygon(poly,fill=255)
m=m.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(1.2))
skin=im.copy();px=skin.load();src=im.load()
for x in range(410,520):
 a=(252,231,223,253);b=(253,232,224,253)
 for y in range(448,527):
  t=(y-448)/78
  px[x,y]=tuple(round(a[c]*(1-t)+b[c]*t) for c in range(4))
backing=m.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(1.4))
base=Image.composite(skin,im,backing)
patch=im.crop(box);patch.putalpha(m.crop(box))
for name,value in [('viola-natural-belly-laugh-base-v0.2.46.png',base),('viola-natural-belly-laugh-mouth-v0.2.46.png',patch)]:
 for folder in [root,cache]:
  tmp=folder/(name+'.tmp');value.save(tmp,format='PNG');os.replace(tmp,folder/name)
for s in [.75,1.0]:
 result=base.copy();mouth=patch.resize((109,round(86*s)),Image.Resampling.LANCZOS)
 # Top lip fixed at the upper cropped edge. CALayer uses this same top anchor.
 result.alpha_composite(mouth,(410,round(455+(443-455)*s)))
 result.crop((385,423,550,550)).resize((660,508)).save(cache/f'mouth-review-{s}.png')
