from pathlib import Path
from PIL import Image, ImageChops, ImageDraw
import json, math
b=Path(__file__).parent
r=b/'review'
v=json.loads((r/'source-arm-return-review.json').read_text())
keys=[x for x in v if x['name'].startswith('key-')]
contacts=[float(x['arms']['keyboardReach']['contactError']) for x in keys]
left=[x['arms']['arms'].get('reference_left_arm',{}) for x in v if x['arms'].get('desksVisible')]
summary={'samples':len(v),'key_samples':len(keys),'max_settled_contact_error':max(contacts),'hidden_pixel_equal':{},'keyboard_arm_modes':sorted(set(x.get('mode','') for x in left))}
old=Path('/Users/tanlantian/Library/Caches/ViolaDesktop/keyboard-fit-v0.2.42/review')
for name in ['hidden-before','hidden-laugh-60','hidden-after-settled']:
    a=Image.open(old/(name+'.png')).convert('RGBA'); z=Image.open(r/(name+'.png')).convert('RGBA')
    summary['hidden_pixel_equal'][name]=a.size==z.size and a.tobytes()==z.tobytes()
names=['desk-before','key-63','key-115','key-0','key-36','keyboard-release-settled','desk-laugh-60','desk-after-settled']
w,h=650,360
sheet=Image.new('RGB',(2*w,4*h),'#eeeaf0'); d=ImageDraw.Draw(sheet)
for i,name in enumerate(names):
    im=Image.open(r/(name+'-arms.png')).convert('RGB'); im.thumbnail((w,h-28))
    x=(i%2)*w; y=(i//2)*h
    sheet.paste(im,(x+(w-im.width)//2,y+28)); d.text((x+10,y+8),name,fill='#20182d')
sheet.save(b/'diagonal-arm-contact-sheet.png')
(b/'verification.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(summary,ensure_ascii=False,indent=2))
