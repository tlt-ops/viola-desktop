#!/usr/bin/env python3
"""Source-pixel-only registered character extraction. No synthesized body pixels."""
from pathlib import Path
import json, hashlib, shutil
import numpy as np
from PIL import Image,ImageDraw,ImageFont,ImageFilter
from scipy import ndimage
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'Assets/reference-v0.2.29'; QC=ROOT/'build/reference-v0.2.29'; STAGE=QC/'stage'; ASSETS=STAGE/'character-assets'
BASE=Path('cache/source/Sources/ViolaDesktop/Resources/Characters/Viola')
for p in (OUT,QC,ASSETS):p.mkdir(parents=True,exist_ok=True)
source=Image.open(OUT/'user-original.png').convert('RGB'); RGB=np.array(source); W,H=source.size

def poly(points):
    im=Image.new('L',(W,H));ImageDraw.Draw(im).polygon(points,fill=255);return np.array(im)>0
# Only border-connected neutral near-black pixels are eligible for removal.
# Explicit inside-garment protection stops the neutral flood through dark frill seams.
protect=poly([(325,814),(428,810),(488,836),(547,902),(573,943),(586,1018),(566,1140),(557,1024),(517,1007),(468,1005),(447,976),(391,993),(336,1016),(264,996),(271,943),(290,901)])
protect |= poly([(454,970),(491,984),(498,1035),(478,1050),(460,1037)])
protect |= poly([(392,943),(430,945),(437,1048),(420,1049),(406,1033)])
ma=RGB.max(2);eligible=(ma<=42)&((ma-RGB.min(2))<=9)&~protect
seed=np.zeros((H,W),bool);seed[0]=eligible[0];seed[-1]=eligible[-1];seed[:,0]=eligible[:,0];seed[:,-1]=eligible[:,-1]
bg=ndimage.binary_propagation(seed,mask=eligible);FG=~bg
# Remove isolated dark background noise while preserving hair connected to the figure.
labels,n=ndimage.label(FG);sizes=np.bincount(labels.ravel());FG &= sizes[labels]>=4
RGBA=np.dstack([RGB,FG.astype('uint8')*255]);Image.fromarray(RGBA).save(OUT/'source-transparent.png')
PET=[(361,297),(381,296),(399,309),(410,351),(412,453),(399,492),(398,525),(380,579),(390,619),(395,645),(383,649),(372,616),(368,668),(357,678),(348,636),(348,668),(337,675),(329,637),(326,665),(316,662),(306,638),(309,603),(311,578),(300,585),(291,573),(291,550),(311,511),(310,483),(339,420),(349,347)]
LAP=[(610,292),(634,287),(653,291),(667,311),(681,383),(717,465),(729,512),(717,548),(669,580),(654,602),(631,600),(617,596),(591,607),(558,625),(544,625),(536,616),(528,623),(521,620),(525,602),(535,583),(556,569),(579,563),(594,556),(609,526),(610,489),(608,450),(607,397),(610,333)]
BACKLEG=[(247,606),(308,604),(290,637),(269,693),(256,756),(232,840),(205,917),(180,990),(174,1058),(191,1093),(193,1126),(181,1146),(181,1174),(171,1174),(170,1148),(156,1179),(121,1214),(43,1234),(43,1220),(72,1181),(99,1090),(115,1030),(126,985),(153,841),(176,731),(192,661),(205,630)]
FRONTLEG=[(547,601),(593,608),(612,616),(640,644),(663,686),(651,715),(638,731),(647,799),(655,867),(664,939),(669,1022),(664,1068),(686,1110),(684,1151),(669,1194),(641,1243),(559,1272),(558,1257),(570,1214),(579,1174),(575,1130),(581,1091),(590,1049),(590,1004),(576,935),(553,866),(536,808),(522,750),(513,683),(516,641)]
SKIRT=[(198,578),(306,558),(391,548),(548,522),(634,540),(684,602),(714,650),(747,682),(854,760),(909,847),(895,867),(859,827),(790,819),(724,804),(691,781),(666,728),(649,694),(608,615),(554,624),(495,660),(481,678),(443,642),(383,614),(291,615),(217,628)]
TOP=[(0,0),(1144,0),(1144,858),(900,858),(865,821),(800,798),(742,745),(681,690),(631,599),(583,594),(494,627),(481,675),(414,614),(320,613),(249,626),(206,637),(0,637)]
HEAD=[(300,0),(690,0),(685,285),(635,307),(577,318),(543,291),(526,273),(503,294),(465,289),(428,277),(383,269),(331,250),(307,212)]
FRBACK=[(287,889),(327,897),(360,923),(367,985),(376,1016),(371,1056),(354,1130),(350,1166),(364,1185),(362,1202),(326,1243),(310,1268),(284,1273),(274,1279),(246,1265),(212,1274),(193,1270),(179,1270),(170,1260),(202,1236),(233,1218),(251,1207),(235,1190),(228,1161),(245,1110),(267,1038),(265,1021),(247,1003),(251,965),(266,937)]
FRFRONT=[(496,886),(543,892),(578,930),(598,969),(611,1016),(584,1012),(587,1112),(573,1192),(560,1234),(541,1266),(510,1303),(475,1308),(443,1312),(428,1311),(410,1304),(395,1307),(388,1298),(405,1283),(440,1260),(458,1239),(451,1226),(438,1199),(438,1172),(454,1122),(467,1052),(465,1024),(456,1005),(467,951)]
# Disjoint rest ownership: every matte pixel belongs to one source part.
owner=np.full((H,W),'seating',dtype=object)
def assign(id,points):owner[poly(points)&FG]=id
assign('body',TOP);assign('viola_skirt',SKIRT);assign('leg_back',BACKLEG);assign('leg_front',FRONTLEG);assign('head',HEAD);assign('resting_pet_arm',PET);assign('resting_lap_arm',LAP)
friend=owner=='seating';owner[poly(FRBACK)&friend]='friend_rest_back';owner[poly(FRFRONT)&friend]='friend_rest_front'
# Source hue and precise overlap boundaries keep hair/cloth pixels with their owner.
# These operations only repartition retained source pixels, never recolor them.
rgb16=RGB.astype('int16'); rr,gg,bb=[rgb16[:,:,i] for i in range(3)]
purpleHair=(bb-rr>3)&(rr-gg>5)
greenHair=(gg>rr-5)&(gg>bb+5)&(rr<155)
owner[((owner=='leg_back')|(owner=='resting_pet_arm'))&purpleHair]='seating'
# Finger gaps contain the friend's hair, and stay with that head.
Y,X=np.indices((H,W));sourceSkin=(rr>bb+3)&(rr>gg+5)
owner[(owner=='resting_pet_arm')&(Y>=583)&~sourceSkin]='seating'
owner[((owner=='resting_pet_arm')|(owner=='resting_lap_arm')|(owner=='viola_skirt'))&greenHair]='body'
friendHead=poly([(302,620),(330,607),(382,606),(423,611),(460,635),(491,669),(515,718),(520,764),(498,811),(476,840),(444,875),(399,899),(335,910),(282,889),(253,864),(231,816),(234,760),(247,706),(268,659)])
owner[friendHead&FG&((owner=='body')|(owner=='viola_skirt')|(owner=='leg_back'))]='seating'
owner[(owner=='viola_skirt')&purpleHair&(np.indices((H,W))[0]>690)]='seating'
# Tight lower-leg contour excludes the friend's blouse and skirt along the right edge.
frontKeep=poly([(516,640),(544,612),(586,603),(613,626),(623,666),(615,708),(620,746),(628,796),(638,856),(648,918),(657,979),(665,1041),(660,1075),(683,1097),(686,1149),(670,1198),(641,1246),(558,1274),(557,1255),(570,1210),(579,1173),(574,1125),(583,1088),(591,1048),(589,1004),(576,935),(553,866),(536,808),(522,750),(513,683)])
owner[(owner=='leg_front')&~frontKeep]='seating'
# The visible bare upper thigh belongs to the top character, not the friend dress.
frontSkin=poly([(592,600),(616,607),(638,634),(660,678),(668,697),(651,718),(633,721),(616,706),(605,676),(598,637)])
owner[frontSkin&FG&(rr>gg+10)&(gg>bb+3)]='leg_front'
# Fine original purple sleeve edge pixels remain in their own moving arm layer.
Y,X=np.indices((H,W)); sleevePurple=(bb-rr>12)&(rr-gg>10)
owner[(owner=='seating')&sleevePurple&(Y>1000)&(Y<1218)&(X>215)&(X<380)]='friend_rest_back'
owner[(owner=='seating')&sleevePurple&(Y>1000)&(Y<1255)&(X>427)&(X<590)]='friend_rest_front'
# Complete hand edge pixels in original registration belong to the friend arms.
owner[(owner=='seating')&FG&(Y>=1205)&(Y<=1282)&(X>=165)&(X<=331)]='friend_rest_back'
owner[(owner=='seating')&FG&(Y>=1237)&(Y<=1315)&(X>=384)&(X<=538)]='friend_rest_front'
# Split at calibrated knee with shared source coordinates. Runtime may move shins.
yy,xx=np.indices((H,W));owner[(owner=='leg_back')&(yy<665)]='leg_back_thigh';owner[(owner=='leg_front')&(yy<684)]='leg_front_thigh'
manifest={'version':1,'id':'viola','name':'Viola Original Reference v0.2.29','canvas':[800,960],'rigProfile':'reference-v0.2.29','sprites':[]}
meta={'source':'user-original.png','sourceSHA256':hashlib.sha256((OUT/'user-original.png').read_bytes()).hexdigest(),'mapping':{'worldX':'24 + 0.64 * sourceX','worldY':'940 - 0.64 * sourceY'},'matteMethod':'border-connected neutral near-black with hand-calibrated dark garment protection','parts':{},'closedEyeMethod':'sampled original skin tones and original eyelash tone, ordinary pixel overlay'}
# Hidden original-color backing closes independently resampled rider/friend
# occlusion boundaries. Every destination is underneath original rider pixels;
# all donors belong to the original friend. Nothing expands the outer silhouette.
friendOwner=(owner=='seating')|(owner=='friend_rest_back')|(owner=='friend_rest_front')
friendInterior=ndimage.binary_erosion(friendOwner&FG,iterations=2)
friendDonor=friendInterior&(xx>=220)&(yy>=590)&(bb>=rr+1)&(rr>=gg+3)
distance,indices=ndimage.distance_transform_edt(~friendDonor,return_indices=True)
frontDest=((owner=='leg_front')|(owner=='leg_front_thigh'))&(yy>=590)&(distance<=32)
backDest=(owner=='leg_back')&(yy>=590)&(distance<=12)
clothDest=((owner=='viola_skirt')|(owner=='body'))&(yy>=590)&(distance<=8)
petDest=(owner=='resting_pet_arm')&(yy>=585)&(yy<=685)&(distance<=8)
lining=(frontDest|backDest|clothDest|petDest)&FG
allowedDistance=np.where(frontDest,32,np.where(backDest,12,8))
liningRGB=RGB.copy();donorY=indices[0].copy();donorX=indices[1].copy()
# Prefer exact original color within the same source row when within that band's
# local limit. Otherwise use the nearest original friend pixel in two dimensions.
for row in range(585,H):
    donors=np.flatnonzero(friendDonor[row]);targets=np.flatnonzero(lining[row])
    if not len(donors) or not len(targets):continue
    pos=np.searchsorted(donors,targets)
    lo=donors[np.clip(pos-1,0,len(donors)-1)];hi=donors[np.clip(pos,0,len(donors)-1)]
    chosen=np.where(abs(lo-targets)<=abs(hi-targets),lo,hi)
    close=abs(chosen-targets)<=allowedDistance[row,targets]
    donorY[row,targets[close]]=row;donorX[row,targets[close]]=chosen[close]
liningRGB[lining]=RGB[donorY[lining],donorX[lining]]
Image.fromarray(np.dstack([liningRGB,lining.astype('uint8')*255])).save(QC/'hidden-friend-lining.png')
liningReview=source.copy();overlay=Image.new('RGBA',(W,H));overlay.putalpha(Image.fromarray(lining.astype('uint8')*170));red=Image.new('RGBA',(W,H),(255,40,30,0));red.putalpha(overlay.getchannel('A'));liningReview=liningReview.convert('RGBA');liningReview.alpha_composite(red);liningReview.save(QC/'hidden-lining-ownership.png')
registered={}
def emit(id,mask,anchor=None,contact=None,full=False,rgb=None,**fields):
    if full:b=(0,0,W,H)
    else:
        ys,xs=np.where(mask&FG)
        if not len(xs):return
        b=(max(0,int(xs.min())-2),max(0,int(ys.min())-2),min(W,int(xs.max())+3),min(H,int(ys.max())+3))
        if anchor:b=(min(b[0],int(anchor[0])-2),min(b[1],int(anchor[1])-2),max(b[2],int(anchor[0])+3),max(b[3],int(anchor[1])+3))
        if contact:b=(min(b[0],int(contact[0])-2),min(b[1],int(contact[1])-2),max(b[2],int(contact[0])+3),max(b[3],int(contact[1])+3))
    l,t,r,bt=b; alpha=(mask&FG).astype('uint8')*255; im=Image.fromarray(np.dstack([RGB if rgb is None else rgb,alpha])).crop(b)
    name=id+'-original-v0.2.29.png';im.save(OUT/name);shutil.copy2(OUT/name,ASSETS/name)
    spr={'id':id,'file':name,'rect':[24+.64*l,940-.64*bt,.64*(r-l),.64*(bt-t)]}
    for key,value in [('anchor',anchor),('contact',contact)]:
        if value:spr[key]=[(value[0]-l)/(r-l),1-(value[1]-t)/(bt-t)]
    spr.update(fields);manifest['sprites'].append(spr);registered[id]=(b,im)
    meta['parts'][id]={'sourceBounds':list(b),'sourceAnchor':anchor,'sourceContact':contact,'pixels':int((mask&FG).sum()),'preservesSourceRGB':rgb is None}

anchors={'body':(479,586),'head':(477,280),'viola_skirt':(479,586),'leg_back_thigh':(262,613),'leg_back':(247,630),'leg_front_thigh':(595,621),'leg_front':(558,646),'resting_pet_arm':(380,310),'resting_lap_arm':(627,309)}
contacts={'leg_back':(117,1165),'leg_front':(617,1196),'resting_pet_arm':(350,622),'resting_lap_arm':(565,599),'friend_rest_back':(253,1242),'friend_rest_front':(455,1275)}
rest_order=['leg_back_thigh','seating','friend_rest_back','friend_rest_front','leg_back','leg_front_thigh','leg_front','viola_skirt','body','head','resting_pet_arm','resting_lap_arm']
# Separately resampled complementary alpha edges require source RGB overlap.
# Every overlap is confined to the original rider-owned domain, never the friend
# or outside silhouette. All anchors remain in original source coordinates.
riderIds={'body','head','viola_skirt','resting_pet_arm','resting_lap_arm','leg_back_thigh','leg_back','leg_front_thigh','leg_front'}
riderDomain=np.isin(owner,list(riderIds))&FG
partMasks={id:owner==id for id in rest_order}
def dilateSource(mask,radius):return ndimage.distance_transform_edt(~mask)<=radius
for id in ('body','head','viola_skirt','resting_pet_arm','resting_lap_arm'):
    partMasks[id]=dilateSource(owner==id,3)&riderDomain
# Arm-to-torso and same-leg knee joins need a wider overlap under motion.
for arm in ('resting_pet_arm','resting_lap_arm'):
    partMasks[arm]|=dilateSource(owner==arm,6)&(owner=='body')&FG
    partMasks['body']|=dilateSource(owner=='body',6)&(owner==arm)&FG
for thigh,calf in [('leg_back_thigh','leg_back'),('leg_front_thigh','leg_front')]:
    pairDomain=((owner==thigh)|(owner==calf))&FG
    partMasks[thigh]=dilateSource(owner==thigh,6)&pairDomain
    partMasks[calf]=dilateSource(owner==calf,6)&pairDomain
for id in rest_order:
    opts={}
    if id in ('leg_back','leg_front'):opts={'swingMultiplier':.65,'sideSwingMultiplier':.6,'perspectiveDistance':760}
    if id.startswith('resting_'):opts['mode']='resting'
    mask=partMasks[id]
    if id=='seating':mask=mask|lining
    if id=='body':mask=mask|(poly([(466,270),(501,268),(527,254),(539,286),(549,308),(482,319),(464,296)])&FG)
    emit(id,mask,anchors.get(id),contacts.get(id),full=id in ('seating','friend_rest_back','friend_rest_front'),rgb=liningRGB if id=='seating' else None,**opts)
    if id=='seating':
        meta['parts'][id]['derivedHiddenLining']={'pixels':int(lining.sum()),'maxSourceDistances':{'frontLeg':32,'backLeg':12,'skirtLongHair':8,'petPalm':8},'destination':'original rider ownership and foreground only','donors':'nearest original friend-owned hair and garment RGB, interior donor mask and purple-tone selector exclude scattered rider edge and skin colors, same row preferred','fixedOwner':'friend seating under original rider pixels','preservesVisibleOriginalRGB':True,'bands':{'frontLegPixels':int(frontDest.sum()),'backLegPixels':int(backDest.sum()),'skirtLongHairPixels':int(clothDest.sum()),'petPalmPixels':int(petDest.sum())}}
# Desk arm uses only original sleeve; separate original hand with calibrated wrist.
leftmask=partMasks['resting_pet_arm']&(yy<=580);rightmask=partMasks['resting_lap_arm']&((yy<550)|((xx>609)&(yy<593)))
emit('reference_left_arm',leftmask,(380,310),(341,563))
emit('reference_right_arm',rightmask,(627,309),(614,567))
hand=partMasks['resting_pet_arm']&(yy>=573)&(xx>=303)
palm=dilateSource(hand&(yy<=612),3)&hand
emit('left_palm',palm,(341,563),(348,609))
finger_polys={
 'left_pinky':([(303,609),(325,606),(332,635),(329,665),(316,665),(306,636)],(316,611),(321,657),'leftPinky'),
 'left_ring':([(326,606),(342,604),(348,639),(349,670),(337,676),(329,638)],(334,611),(340,669),'leftRing'),
 'left_middle':([(342,605),(359,605),(363,641),(369,669),(358,679),(349,641)],(350,611),(358,671),'leftMiddle'),
 'left_index':([(358,605),(374,607),(379,637),(374,666),(369,669),(362,641)],(365,612),(373,656),'leftIndex'),
 'left_thumb':([(371,596),(382,604),(393,629),(395,647),(383,650),(373,621)],(374,608),(386,640),'leftThumb')}
for id,(points,anchor,contact,finger) in finger_polys.items():emit(id,dilateSource(hand&poly(points),3)&hand,anchor,contact,finger=finger)
mousemask=partMasks['resting_lap_arm']&(yy>=551)&(xx<=631)
emit('mouse_hand',mousemask,(614,567),(565,599))
meta['internalSeamOverlap']={'method':'exact original RGB and alpha, Euclidean dilation clipped to original rider ownership and matte','generalRiderPixels':3,'armTorsoPixels':6,'sameLegThighCalfPixels':6,'handPalmFingerPixels':3,'exteriorDilationPixels':0,'friendOwnershipBorrowedPixels':0,'parts':{id:{'addedPixels':int((partMasks[id]&(owner!=id)).sum())} for id in riderIds}}
# Align extracted original fingers to the keyboard and palm to the mouse surface.
# The source shapes retain their original scale; reference sleeves reach these wrists.
leftGroup={'left_palm','left_pinky','left_ring','left_middle','left_index','left_thumb'}
for spr in manifest['sprites']:
    if spr['id'] in leftGroup:delta=(57,-29)
    elif spr['id']=='mouse_hand':delta=(150,-74)
    else:continue
    spr['rect'][0]+=delta[0];spr['rect'][1]+=delta[1]
    meta['parts'][spr['id']]['deskWorldTranslation']=list(delta)
meta['deskCalibration']={'leftMiddleTipWorld':[310.12,481.56],'leftWristWorld':[299.24,550.68],'mousePalmWorld':[535.6,482.64],'mouseWristWorld':[566.96,503.12]}
# Keep approved desk/keyboard/mouse geometry unchanged from baseline.
baseline=json.loads((BASE/'character.json').read_text())
for spr in baseline['sprites']:
    if spr['id'] in ('desk_keyboard','desk_mouse','keyboard','reference_mouse'):
        manifest['sprites'].append(spr);shutil.copy2(BASE/spr['file'],ASSETS/spr['file'])
# Whole desk interaction group is calibrated to this reference body's higher waist.
# Preserve desk shape, keyboard angle and hand-to-device registration as one group.
deskGroup=leftGroup|{'mouse_hand','desk_keyboard','desk_mouse','keyboard','reference_mouse'}
for spr in manifest['sprites']:
    if spr['id'] in deskGroup:
        spr['rect'][0]-=80;spr['rect'][1]+=75
        if spr['id'] in meta['parts']:
            previous=meta['parts'][spr['id']].get('deskWorldTranslation',[0,0])
            meta['parts'][spr['id']]['deskWorldTranslation']=[previous[0]-80,previous[1]+75]
for point in meta['deskCalibration'].values():point[0]-=80;point[1]+=75
meta['deskInteractionGroupTranslation']=[-80,75]
# Blink overlays from original palette. Small eye patches receive nearby skin colors.
def blink(id,bounds,line):
    l,t,r,b=bounds;patch=source.crop(bounds).convert('RGBA');ar=np.array(patch)
    # A close skin tone is sampled from the lower cheek edge of each source crop.
    tones=np.median(RGB[b+2:b+8,l:r],axis=0).astype('uint8')
    ar[:,:,:3]=tones[None,:,:]
    edge=Image.new('L',(r-l,b-t));ImageDraw.Draw(edge).ellipse((0,1,r-l-1,b-t-2),fill=255)
    # Feather only the outside edge of the small overlay; closed eyelid stays opaque.
    ar[:,:,3]=np.array(edge.filter(ImageFilter.GaussianBlur(1.5)))
    patch=Image.fromarray(ar);d=ImageDraw.Draw(patch);eyelash=tuple(map(int,RGB[line[0][1],line[0][0]]))
    start=np.array(line[0],float);end=np.array(line[-1],float)
    middle=np.mean(np.array(line[1:-1],float),axis=0)
    control=2*middle-.5*(start+end)
    curve=[]
    for z in np.linspace(0,1,80):
        xy=(1-z)**2*start+2*(1-z)*z*control+z*z*end
        curve.append((float(xy[0]-l),float(xy[1]-t)))
    d.line(curve,fill=eyelash+(255,),width=3)
    name=id+'-original-tones-v0.2.29.png';patch.save(OUT/name);shutil.copy2(OUT/name,ASSETS/name)
    # Archived only: SourceReferenceFaceRig owns blink in the active manifest.
    meta['parts'][id]={'sourceBounds':list(bounds),'preservesSourceRGB':False,'operation':'closed eyelid using sampled original tones','archivedOnly':True}
blink('reference_blink_left',(385,193,431,225),[(388,205),(397,214),(409,216),(422,210)])
blink('reference_blink_right',(459,179,502,211),[(460,192),(471,200),(484,200),(499,192)])
(STAGE/'character-layout.json').write_text(json.dumps(manifest,indent=2)+'\n');(OUT/'extraction-metadata.json').write_text(json.dumps(meta,indent=2)+'\n')
# Matched source registration reconstructs the full original rest pose exactly.
recon=Image.new('RGBA',(W,H)); sheet=Image.new('RGB',(1200,((len(rest_order)+3)//4)*470),(231,234,239));d=ImageDraw.Draw(sheet)
for i,id in enumerate(rest_order):
    bounds,im=registered[id];recon.alpha_composite(im,(bounds[0],bounds[1]));thumb=im.copy();thumb.thumbnail((290,435));sx=(i%4)*300;sy=(i//4)*470;sheet.paste(thumb,(sx+(300-thumb.width)//2,sy+28),thumb);d.text((sx+6,sy+7),id,fill=(25,30,40))
recon.save(QC/'reconstruction.png');sheet.save(QC/'layer-contact-sheet.png')
y,x=np.indices((H,W));checker=np.where(((x//24+y//24)%2)[...,None],210,240)*np.ones((1,1,3));check=np.where(FG[...,None],RGB,checker).astype('uint8');Image.fromarray(check).save(QC/'matte-candidate-checker.png')
control=Image.fromarray(check);d=ImageDraw.Draw(control);points={'seat':(479,586),'left shoulder':(380,310),'right shoulder':(627,309),'pet wrist':(341,563),'pet palm':(350,622),'lap wrist':(614,567),'lap palm':(565,599),'back knee':(247,630),'front knee':(558,646),'back shoe contact':(117,1165),'front shoe contact':(617,1196),'friend back shoulder':(306,919),'friend back elbow':(296,1098),'friend back palm':(253,1242),'friend front shoulder':(526,898),'friend front elbow':(501,1095),'friend front palm':(455,1275)}
for label,(px,py) in points.items():d.ellipse((px-5,py-5,px+5,py+5),fill=(255,70,20));d.text((px+8,py-8),label,fill=(255,70,20),stroke_width=1,stroke_fill=(255,255,255))
control.save(QC/'control-points.png')
R=np.array(recon);expected=RGBA.copy();expected[~FG]=0; RR=R.copy();RR[RR[:,:,3]==0]=0
qc={'sourceDimensions':[W,H],'matteForegroundPixels':int(FG.sum()),'reconstructionDifferentPixels':int(np.any(RR!=expected,axis=2).sum()),'manifestSprites':len(manifest['sprites']),'newSourceSpriteIds':list(registered),'oldBodyAssetsReferenced':False,'shoeVisuals':'original worn heels embedded in source leg sprites','missingOrSynthesizedAnatomy':False,'derivedHiddenGarmentLiningPixels':int(lining.sum()),'hiddenLiningDonorsBelongToFriend':bool(np.all(friendOwner[donorY[lining],donorX[lining]])),'hiddenLiningPixelsOutsideOriginalRiderOwnership':int((lining&~riderDomain).sum()),'hiddenLiningPixelsOutsideOriginalMatte':int((lining&~FG).sum()),'blinkOwner':'SourceReferenceFaceRig; palette overlay PNGs archived only','riderSeamOverlapPixelsOutsideOriginalRiderDomain':sum(int((partMasks[id]&~riderDomain).sum()) for id in riderIds),'sameLegInternalOverlapSourcePixels':6,'armTorsoOverlapSourcePixels':6,'generalRiderOverlapSourcePixels':3}
(QC/'qc.json').write_text(json.dumps(qc,indent=2)+'\n');print(json.dumps(qc,indent=2))
