from pathlib import Path
from PIL import Image
import json, math
b=Path(__file__).parent
old={x['name']:x for x in json.loads((b/'baseline-old-laugh/source-arm-return-review.json').read_text())}
new={x['name']:x for x in json.loads((b/'review/source-arm-return-review.json').read_text())}
result={'samples':len(new),'old_laugh_geometry':{},'old_laugh_pixels':{},'normal_v43_pixels':{},'hidden_v43_pixels':{}}
previous=Path('/Users/tanlantian/Library/Caches/ViolaDesktop/keyboard-diagonal-v0.2.43/review')
def equal(a,z):
 x=Image.open(a).convert('RGBA');y=Image.open(z).convert('RGBA');return x.size==y.size and x.tobytes()==y.tobytes()
for name,x in new.items():
 if name.startswith('desk-laugh-') and x['arms']['laughWeight']>=.35:
  a=old[name]['arms']['arms']['reference_left_arm'];z=x['arms']['arms']['reference_left_arm'];error=math.hypot(a['wrist'][0]-z['wrist'][0],a['wrist'][1]-z['wrist'][1]);angle=abs(a['handAngle']-z['handAngle'])
  result['old_laugh_geometry'][name]={'wrist_error':error,'angle_error':angle};assert error<1e-7 and angle<1e-7,(name,error,angle)
for name in ['desk-laugh-8','desk-laugh-33','desk-laugh-60']:
 result['old_laugh_pixels'][name]=equal(b/'baseline-old-laugh'/(name+'.png'),b/'review'/(name+'.png'));assert result['old_laugh_pixels'][name],name
for name in ['desk-before','desk-after-settled','key-0','key-63','key-115','keyboard-release-settled']:
 result['normal_v43_pixels'][name]=equal(previous/(name+'.png'),b/'review'/(name+'.png'));assert result['normal_v43_pixels'][name],name
for name in ['hidden-before','hidden-laugh-60','hidden-after-settled']:
 result['hidden_v43_pixels'][name]=equal(previous/(name+'.png'),b/'review'/(name+'.png'));assert result['hidden_v43_pixels'][name],name
keys=[x for name,x in new.items() if name.startswith('key-')]
result['key_samples']=len(keys);result['max_key_contact_error']=max(x['arms']['keyboardReach']['contactError'] for x in keys)
result['old_laugh_geometry_samples']=len(result['old_laugh_geometry'])
(b/'verification.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k!='old_laugh_geometry'},ensure_ascii=False,indent=2))
