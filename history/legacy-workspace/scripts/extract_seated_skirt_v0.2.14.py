from pathlib import Path
import json
from PIL import Image,ImageDraw,ImageChops
root=Path(__file__).resolve().parents[1]
source=Image.open(root/'Assets/Source/reference-seating.png').convert('RGBA')
mask=Image.new('L',source.size,0)
draw=ImageDraw.Draw(mask)
# Original ivory folds above the original desk; the removed desk remains transparent.
draw.polygon([(596,497),(608,497),(622,505),(637,511),(650,502),(674,498),(688,501),(682,514),(674,527),(649,530),(638,529),(620,532),(600,534),(593,527)],fill=255)
# Original long plum panel and ivory hem below the desk. The inner contour
# follows its raised knee opening instead of retaining skin or stockings.
draw.polygon([(607,584),(642,581),(682,576),(721,574),(757,572),(802,571),(851,567),(878,582),(901,607),(932,651),(953,696),(973,728),(995,757),(1004,768),(999,776),(983,770),(967,753),(934,740),(909,745),(891,747),(873,744),(864,730),(844,718),(827,704),(818,689),(848,689),(853,679),(845,660),(823,632),(796,608),(768,586),(750,579),(735,578),(713,582),(696,587),(683,599),(672,619),(661,635),(650,632),(639,621),(628,602),(614,591)],fill=255)
# Guard the original thigh cut-out explicitly; edge detail stays in the ivory rim.
draw.polygon([(742,568),(766,575),(789,590),(812,615),(836,645),(855,675),(859,688),(842,693),(819,684),(805,657),(788,625),(771,596),(748,579)],fill=0)
alpha=ImageChops.multiply(source.getchannel('A'),mask)
source.putalpha(alpha)
box=(590,497,1010,777)
out=source.crop(box)
# Clear hidden RGB as well; all visible pixels remain unmodified source pixels.
out.putdata([(0,0,0,0) if a==0 else (r,g,b,a) for r,g,b,a in out.getdata()])
name='viola-skirt-reference-crop-v0.2.14.png'
asset=root/'Assets/Source'/name
# Remove the detached left folded patch: in the assembled pose it falls over the friend's hair.
for y in range(60,160):
 for x in range(170): out.putpixel((x,y),(0,0,0,0))
out.save(asset)
# A unique local file is added through the candidate's asset directory; the old
# generated skirt remains recoverable. Only the owned skirt record is modified.
candidate=root/'build/previews-v0.2.14-integrated/character-layout.json'
assetdir=candidate.parent/'character-assets'
out.save(assetdir/name)
j=json.loads(candidate.read_text())
for sprite in j['sprites']:
 if sprite['id']=='viola_skirt':
  sprite['file']=name
  sprite['rect']=[285,455-260*280/420,260,260*280/420]
  sprite.pop('crop',None)
  sprite.pop('polygon',None)
  sprite.pop('cutouts',None)
  sprite.pop('alphaMask',None)
  break
else:raise RuntimeError('viola_skirt missing')
candidate.write_text(json.dumps(j,ensure_ascii=False,indent=2)+'\n')
record={'source':'Assets/Source/reference-seating.png','sourceCrop':[590,497,420,280],'output':str(asset),'dimensions':[420,280],'mapping':'Original pixels and polygon alpha only; no recoloring, synthesis or fill. Width 260 at original aspect; top455.','sprite':next(s for s in j['sprites'] if s['id']=='viola_skirt')}
(candidate.parent/'skirt-extraction/extraction.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
print(asset)
