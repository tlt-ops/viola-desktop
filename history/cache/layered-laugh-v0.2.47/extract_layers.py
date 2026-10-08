from PIL import Image,ImageDraw,ImageFilter,ImageChops
from pathlib import Path
import json,shutil
p=Path('/Users/tanlantian/Library/Caches/ViolaDesktop/source/Sources/ViolaDesktop/Resources/Characters/Viola')
clean=Image.open(p/'viola-layered-clean-v0.2.47.png').convert('RGBA')
main=Image.open(p/'viola-natural-belly-laugh-base-v0.2.46.png').convert('RGBA')
paint=Image.open(p/'viola-natural-belly-laugh-v0.2.46.png').convert('RGBA')
wipe=Image.open(p/'viola-natural-tear-wipe-v0.2.46.png').convert('RGBA')
def mask(poly,blur=1):
 m=Image.new('L',main.size);ImageDraw.Draw(m).polygon(poly,fill=255)
 return m.filter(ImageFilter.GaussianBlur(blur)) if blur else m
polys={
'head':[(0,0),(1211,0),(1211,380),(830,485),(774,541),(694,558),(655,538),(612,533),(578,563),(490,580),(408,566),(370,568),(373,704),(391,809),(350,841),(305,820),(277,739),(280,589),(220,566),(0,566)],
'chest':[(408,564),(487,579),(575,562),(616,537),(658,538),(700,557),(769,540),(795,604),(781,814),(804,934),(800,984),(832,1081),(1070,1299),(174,1299),(411,1050),(429,997),(414,940),(390,827),(384,667)],
'left-upper':[(328,540),(404,590),(429,726),(414,841),(403,936),(393,974),(331,1003),(239,984),(144,979),(158,872),(197,717),(242,590)],
'left-lower':[(144,919),(251,899),(385,940),(392,1004),(352,1044),(298,1089),(240,1101),(181,1042),(146,984)],
'left-hand':[(319,996),(389,1008),(433,1047),(486,1047),(536,1058),(574,1060),(572,1084),(536,1092),(578,1118),(619,1145),(639,1161),(620,1187),(590,1207),(554,1202),(509,1184),(467,1157),(397,1129),(351,1137),(306,1114),(294,1067)],
'right-upper':[(797,540),(848,535),(928,649),(1000,780),(1068,920),(1063,987),(986,997),(921,970),(882,910),(841,798),(815,661)],
'right-lower':[(900,898),(1034,883),(1071,947),(1040,1016),(960,1082),(918,1116),(863,1085),(835,1027),(812,1008),(862,948)],
'right-hand':[(818,1004),(874,1018),(915,1071),(924,1127),(880,1157),(842,1152),(805,1154),(757,1195),(698,1238),(651,1237),(610,1216),(598,1174),(634,1139),(676,1106),(726,1080),(792,1068)],
'wipe-hand':[(534,363),(575,362),(618,375),(651,388),(675,413),(686,455),(680,478),(673,496),(704,533),(731,576),(749,599),(784,639),(777,682),(739,728),(701,755),(669,722),(644,667),(648,636),(676,616),(656,566),(627,524),(599,505),(584,494),(574,469),(563,465),(550,457),(556,428),(567,411),(562,396),(536,396),(525,383)]}
records={}
for name,poly in polys.items():
 im=(wipe if name=='wipe-hand' else (clean if name=='head' else (clean if name=='chest' else paint))).copy()
 m=mask(poly,0.6 if 'hand' in name else 1.1)
 if name=='head':
  # Keep the preserved face but use the existing skin-only mouth plate beneath the animated mouth.
  im.paste(main.crop((410,455,519,541)),(410,455))
 if name.endswith('upper') or name.endswith('lower'):
  # Olive hair painted over a sleeve must remain owned by the hair layers.
  cm=Image.new('L',im.size); pix=im.load();out=cm.load()
  for yy in range(im.height):
   for xx in range(im.width):
    r,g,b,a=pix[xx,yy];out[xx,yy]=255 if b>=g+2 else 0
  m=ImageChops.multiply(m,cm.filter(ImageFilter.GaussianBlur(.7)))
 im.putalpha(ImageChops.multiply(im.getchannel('A'),m));fn=f'viola-layered-{name}-v0.2.47.png';im.save(p/fn);records[name]=poly
# Only long hair behind the shoulder line, with generous hidden overlap below the head.
back=clean.copy();m=Image.new('L',main.size);ImageDraw.Draw(m).rectangle((0,425,1211,1299),fill=255)
m=ImageChops.subtract(m,mask(polys['chest'],0).filter(ImageFilter.MinFilter(91)));m=ImageChops.subtract(m,mask(polys['head'],0))
# The old long-hair/skirt below the waist remains part of the retained lower body.
fade=Image.new('L',main.size); fd=ImageDraw.Draw(fade)
for yy in range(main.height):
 t=max(0,min(1,(yy-945)/170));v=int(255*(1-t*t*(3-2*t)));fd.line((0,yy,main.width,yy),fill=v)
back.putalpha(ImageChops.multiply(back.getchannel('A'),m));back.save(p/'viola-layered-hair-v0.2.47.png')
(p/'viola-layered-layers-v0.2.47.json').write_text(json.dumps({'size':list(main.size),'polygons':records},indent=2))
# Contact sheet for segmentation review, pure derivation from authored images.
items=list(polys)+['hair'];sheet=Image.new('RGBA',(4*310,3*355),(230,230,234,255));d=ImageDraw.Draw(sheet)
for i,name in enumerate(items):
 im=Image.open(p/f'viola-layered-{name}-v0.2.47.png');im.thumbnail((300,325));x=(i%4)*310;y=(i//4)*355
 sheet.alpha_composite(im,(x,y+25));d.text((x+5,y+5),name,fill='black')
sheet.convert('RGB').save('/Users/tanlantian/Library/Caches/ViolaDesktop/layered-laugh-v0.2.47/segmentation.png')
