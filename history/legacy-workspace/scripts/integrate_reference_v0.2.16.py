from pathlib import Path
import json,copy,shutil
import numpy as np
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[1];D=ROOT/'build/previews-v0.2.16-reference-full'
# Snapshot once: installing this candidate must not change its integration inputs.
base=D/'integration-base-v0.2.15.json'
if not base.exists():
 shutil.copy2(ROOT/'Sources/ViolaDesktop/Resources/Characters/Viola/character.json',base)
j=json.loads((D/'character-layout.json').read_text());meta=json.loads((D/'source-coordinates.json').read_text());old=json.loads(base.read_text());O={s['id']:s for s in old['sprites']};B={s['id']:s for s in j['sprites']}
# The v0.2.15 extraction outline is narrower than this reference's back calf.
# Transfer its residual stocking edge out of the seated friend, retaining the
# exact source RGB and the established crop/frame for both sprites. Above the
# hair's lower edge, the source's purple hair remains with the friend.
source=np.asarray(Image.open(D/'reference-source.png').convert('RGBA'))
back_outline=[(414,588),(434,588),(434,602),(431,610),(425,620),(420,630),
 (416,640),(414,650),(411,660),(408,675),(406,690),(405,705),(411,720),
 (410,750),(408,770),(406,790),(403,812),(399,824),(398,834),(388,846),
 (381,861),(374,875),(367,890),(363,902),(358,917),(358,931),(363,943),
 (363,958),(358,974),(351,986),(345,1000),(341,1016),(338,1032),
 (337,1049),(334,1066),(331,1080),(323,1093),(314,1104),(302,1114),
 (288,1116),(267,1116),(251,1105),(242,1088),(244,1070),(254,1042),
 (266,1015),(278,984),(284,958),(293,937),(302,912),(308,887),
 (315,859),(317,835),(321,810),(328,784),(334,759),(340,735),
 (349,708),(357,680),(364,655),(370,631),(378,607),(391,595)]
edge_mask=Image.new('L',(source.shape[1],source.shape[0]));ImageDraw.Draw(edge_mask).polygon(back_outline,fill=255)
edge=np.asarray(edge_mask)>0
rgb=source[:,:,:3].astype(np.int16)
upper=np.arange(source.shape[0])[:,None]<824
stocking=(rgb[:,:,2]-rgb[:,:,1]<=17)&(rgb[:,:,2]-rgb[:,:,0]<=5)
edge &= ~upper|stocking
original_parts={}
for sprite_id in ['leg_back','seating']:
 snapshot=D/('integration-base-'+sprite_id+'-v0.2.16.png')
 if not snapshot.exists():
  shutil.copy2(D/'character-assets'/B[sprite_id]['file'],snapshot)
 original_parts[sprite_id]=np.array(Image.open(snapshot).convert('RGBA'))
seat_x,seat_y,seat_w,seat_h=meta['parts']['seating']['sourceCrop']
seat_alpha=np.zeros(source.shape[:2],dtype=np.uint8)
seat_alpha[seat_y:seat_y+seat_h,seat_x:seat_x+seat_w]=original_parts['seating'][:,:,3]
back_x,back_y,back_w,back_h=meta['parts']['leg_back']['sourceCrop']
back_crop=np.zeros(source.shape[:2],dtype=bool)
back_crop[back_y:back_y+back_h,back_x:back_x+back_w]=True
# Move only pixels already owned by seating and inside the existing calf crop.
# This keeps the complete static alpha silhouette identical, including its AA.
edge &= (seat_alpha>0)&back_crop
for sprite_id in ['leg_back','seating']:
 path=D/'character-assets'/B[sprite_id]['file'];rgba=original_parts[sprite_id].copy()
 x,y,w,h=meta['parts'][sprite_id]['sourceCrop'];local=edge[y:y+h,x:x+w]
 assert rgba.shape[:2]==(h,w)
 if sprite_id=='leg_back':rgba[:,:,3]=np.maximum(rgba[:,:,3],np.where(local,seat_alpha[y:y+h,x:x+w],0))
 else:rgba[:,:,3]=np.where(local,0,rgba[:,:,3])
 Image.fromarray(rgba).save(path)
def C(x):return copy.deepcopy(x)
def norm(id,p):
 b=meta['parts'][id]['sourceCrop'];return [(p[0]-b[0])/b[2],1-(p[1]-b[1])/b[3]]
def poly(id,pts):
 return [[norm(id,p)[0],1-norm(id,p)[1]] for p in pts]
def feature(oldid,id,center,size=None):
 s=C(O[oldid]);s['id']=id;w,h=size or s['rect'][2:];s['rect']=[center[0]-w/2,center[1]-h/2,w,h];return s
# Explicit source-space joints, with the complete reference texture retained.
legs={}
for side in ['back','front']:
 id='leg_'+side;s=C(B[id]);front=side=='front';b=meta['parts'][id]['sourceCrop']
 hip=[400,595] if not front else [790,587];knee=[345,845] if not front else [714,650];foot=[286,1070] if not front else [775,1100]
 upper=C(s);upper['id']=id+'_thigh';upper['anchor']=norm(id,hip)
 upper['anchor']=[max(0,min(1,v)) for v in upper['anchor']]
 end=(855 if not front else 670)-b[1];upper['polygon']=[[0,0],[1,0],[1,end/b[3]],[0,end/b[3]]]
 start=(825 if not front else 635)-b[1];s['polygon']=[[0,start/b[3]],[1,start/b[3]],[1,1],[0,1]]
 s['anchor']=norm(id,knee);s['contact']=norm(id,foot);s['swingMultiplier']=.65;s['sideSwingMultiplier']=.6;s['perspectiveDistance']=760
 legs[side]=[upper,s]
# Original dress pixels fill only a narrow area hidden by the seated front calf.
# Its source-space boundary stays inside the original calf/skirt silhouette.
underlay_bounds=[782,800,38,304]
underlay_points=[(795,800),(812,843),(820,926),(816,1020),(808,1104),(791,1104),(797,1010),(800,912),(782,837)]
underlay_file='reference_hidden_dress_strip.png'
Image.open(D/'reference-source.png').crop((835,808,873,1112)).save(D/'character-assets'/underlay_file)
ux,uy,uw,uh=underlay_bounds
underlay={'id':'friend_leg_underlay','file':underlay_file,'crop':[0,0,38,304],
 'rect':[40+.64*ux,860-.64*(uy+uh),.64*uw,.64*uh],
 'polygon':[[(x-ux)/uw,(y-uy)/uh] for x,y in underlay_points]}
# Original friend arms and free skirt become layers with identical registration.
seat=C(B['seating']);seat['polygon']=[[0,0],[1,0],[1,1],[0,1]];seat['cutouts']=[]
arm_regions={
 'back':[(412,826),(500,849),(483,974),(450,1065),(452,1134),(405,1153),(350,1150),(322,1123),(365,1068),(388,976),(397,874)],
 'front':[(601,839),(702,859),(691,953),(651,1064),(671,1157),(625,1186),(560,1198),(532,1161),(561,1103),(577,1010),(579,930)]}
rests=[]
for side,pts in arm_regions.items():
 s=C(B['seating']);s['id']='friend_rest_'+side;s['polygon']=poly('seating',pts);s['contact']=norm('seating',[385,1125] if side=='back' else [615,1155]);seat['cutouts'].append(s['polygon']);rests.append(s)
cloth=C(B['seating']);cloth['id']='friend_skirt';cloth['polygon']=poly('seating',[(773,824),(948,865),(1002,970),(1156,1083),(1161,1120),(1080,1140),(921,1175),(767,1155),(745,1010)])
seat['cutouts'].append(cloth['polygon'])
# Reference sleeves use a shoulder-fixed affine map, identity at rest.
for id in ['reference_left_arm','reference_right_arm']:
 B[id]['contact']=norm(id,meta['sourceContacts'][id]['wrist'])
# Restore the accepted v0.2.15 desk/device rig as one translated group. Keep its
# board depths, hinge, keyboard angle and mouse contact instead of moving each
# component independently. Existing curved fingers sit visibly on the keycaps.
desk_offset=[50,80]
def desk_part(id):
 s=C(O[id]);s['rect'][0]+=desk_offset[0];s['rect'][1]+=desk_offset[1];return s
deskK=desk_part('desk_keyboard');deskM=desk_part('desk_mouse');keyboard=desk_part('keyboard')
hand=desk_part('left_palm');hand['anchor']=C(O['left_arm_forearm']['anchor'])
fingers=[desk_part(s['id']) for s in old['sprites'] if s.get('finger','').startswith('left')]
mousehand=desk_part('mouse_hand');mousehand['anchor']=C(O['right_arm_forearm']['anchor'])
mouse=desk_part('laugh_mouse');mouse['id']='reference_mouse';park=C(mouse);park['id']='laugh_mouse'
# The earlier curve rig already connects the wrist to every key without shearing
# the cuff. Align only its shoulder anchors to the complete reference torso.
arms=[]
for side in ['left','right']:
 upper=desk_part(side+'_arm');lower=desk_part(side+'_arm_forearm')
 shoulder=meta['worldContacts']['reference_'+side+'_arm']['shoulder']
 upper['rect'][0]=shoulder[0]-upper['anchor'][0]*upper['rect'][2]
 upper['rect'][1]=shoulder[1]-upper['anchor'][1]*upper['rect'][3]
 if side=='right':lower['rect']=C(upper['rect'])
 arms.extend([upper,lower])
# The reference extraction left disconnected fingertip pixels in the body layer.
# Remove only that source-space strip; the body texture and sleeve pixels stay.
B['body']['polygon']=[[0,0],[1,0],[1,1],[0,1]]
B['body']['cutouts']=B['body'].get('cutouts',[])+[poly('body',[(255,483),(357,483),(357,506),(255,506)])]
# Facial alternatives keep the original eye spacing.
blinks=[]
for side,crop,center,size in [('left',[197,216,62,62],[393.92,740.24],[30,28]),('right',[278,207,76,60],[444.48,742.24],[33,28])]:
 blinks.append({'id':'reference_blink_'+side,'file':'head_close.png','crop':crop,'rect':[center[0]-size[0]/2,center[1]-size[1]/2,*size],'feather':True})
laughmouth=feature('laugh_mouth','laugh_mouth',[418.24,708.96],[25.5,21.2]);laughbody=C(O['laugh_body']);laughbody['rect']=[319,519,298,163]
expressions=[]
for s0 in old['sprites']:
 if not s0.get('expression'):continue
 id=s0['id'];s=C(s0)
 center=[345.28,381.28] if 'eye_l' in id else [397.76,386.4] if 'eye_r' in id else [377.92,353.76]
 w,h=s['rect'][2:];w*=.95;h*=.85;s['rect']=[center[0]-w/2,center[1]-h/2,w,h];expressions.append(s)
# Existing helping-arm artwork is relocated from the previous source registration.
helpers=[]
for s0 in old['sprites']:
 if not (s0['id'].startswith('friend_help_') or s0['id'].startswith('friend_shoulder_')):continue
 s=C(s0);x,y,w,h=s['rect'];s['rect']=[193.6+(x-128.83399209486166)*.64/.6027667984199041,98.4+(y-80)*.64/.5952380952380952,w*.64/.6027667984199041,h*.64/.5952380952380952];helpers.append(s)
shoes={side:[C(O['shoe_'+side+'_rear']),C(O['shoe_'+side+'_front'])] for side in ['back','front']}
B['viola_skirt']['anchor']=[.5,1]
# Foreground tables hide the original desk's occluded band; hand layers sit on the devices.
j['sprites']=[legs['back'][0],seat,cloth,underlay,*rests,shoes['back'][0],legs['back'][1],shoes['back'][1],shoes['front'][0],legs['front'][0],legs['front'][1],shoes['front'][1],*helpers,*expressions,B['viola_thigh_skin'],B['viola_skirt'],B['body'],laughbody,B['head'],*blinks,laughmouth,*arms,deskK,deskM,keyboard,mouse,park,hand,*fingers,mousehand]
(D/'character-integrated.json').write_text(json.dumps(j,ensure_ascii=False,indent=2)+'\n')
# Art-only staged layout resolves all assets alongside its own file.
for s in j['sprites']:
 p=D/'character-assets'/s['file']
 if not p.exists():shutil.copy2(ROOT/'Sources/ViolaDesktop/Resources/Characters/Viola'/s['file'],p)
print(D/'character-integrated.json')
