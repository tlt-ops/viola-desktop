#!/usr/bin/env python3
"""Pixel-only front thigh material correction; preserves all sprite geometry."""
from pathlib import Path
import json,copy,shutil,hashlib
import numpy as np
from PIL import Image,ImageDraw
from scipy import ndimage
R=Path(__file__).resolve().parents[1];BASE=R/'build/reference-v0.2.29/stage';SOURCE=R/'Assets/reference-v0.2.29';OUT=R/'Assets/reference-v0.2.30';QC=R/'build/thigh-v0.2.30';STAGE=QC/'stage';TARGET=STAGE/'character-assets'
for p in [OUT,QC,TARGET]:p.mkdir(parents=True,exist_ok=True)
manifest=json.loads((BASE/'character-layout.json').read_text());meta=json.loads((SOURCE/'extraction-metadata.json').read_text())
original=Image.open(SOURCE/'user-original.png').convert('RGB');rgb=np.array(original).astype(float);H,W=rgb.shape[:2];Y,X=np.indices((H,W));leg=np.zeros((H,W),bool)
for id in ['leg_front_thigh','leg_front']:
 spr=next(s for s in manifest['sprites'] if s['id']==id);p=np.array(Image.open(BASE/'character-assets'/spr['file']).convert('RGBA'));l,t,r,b=meta['parts'][id]['sourceBounds'];leg[t:b,l:r]|=p[:,:,3]>0
originalLegAlpha=leg.copy()
# The visible old cuff also crosses pixels previously assigned to the lap/skirt
# and a few seating residuals. Correct the same anatomical source surface only.
semantic=Image.new('L',(W,H));ImageDraw.Draw(semantic).polygon([(530,632),(542,619),(559,611),(569,603),(589,601),(609,608),(640,642),(663,685),(656,707),(640,720),(625,717),(627,738),(525,738),(515,692),(519,658)],fill=255)
rr,gg,bb=[rgb[:,:,i] for i in range(3)]
semanticExtra=(np.array(semantic)>0)&((X>=535)|((bb<=rr+10)&(rr>=gg)))
leg=leg|semanticExtra
existingSkin=(rr>165)&(gg>105)&(rr>gg+15)&(gg>bb+2)
# Curve models the new cloth edge lower on the same original leg surface.
cuffY=710+9*(1-np.clip((X-570)/54,-1.3,1.3)**2)+.08*(X-570)
handSkin=existingSkin&(Y<620)&(X<609)
handEdge=(ndimage.distance_transform_edt(~handSkin)<=1)&(rr<70)&(Y<619)&(X<603)
stock=leg&~existingSkin&(Y>=600)&(Y<=738)
interiorDistance=ndimage.distance_transform_edt(leg)
edgeWeight=np.where((X<535)&(Y>645),np.clip(interiorDistance-1,0,1),1.0)
inside=edgeWeight>0
# Analytic supersampling of the source-coordinate curved material boundary.
# Sprite alpha remains exact; only RGB receives these antialias coverage weights.
cuffCoverage=np.zeros((H,W),float);bandCoverage=np.zeros((H,W),float)
for sx in (np.arange(8)+.5)/8-.5:
    subCuff=710+9*(1-np.clip((X+sx-570)/54,-1.3,1.3)**2)+.08*(X+sx-570)
    for sy in (np.arange(8)+.5)/8-.5:
        cuffCoverage+=(Y+sy<subCuff)/64
        bandCoverage+=((Y+sy>=subCuff)&(Y+sy<subCuff+1))/64
skinWeight=cuffCoverage*edgeWeight*stock
skinMask=skinWeight>0
# Remove the old upper stocking seam before preserving the broad leg shading.
oldRim=Image.new('L',(W,H));ImageDraw.Draw(oldRim).polygon([(535,603),(572,608),(598,625),(615,649),(625,673),(623,695),(610,713),(597,704),(605,685),(604,660),(591,640),(569,625),(540,621)],fill=255)
rim=np.array(oldRim)>0
luma=.2126*rr+.7152*gg+.0722*bb
validTone=stock&~rim&(Y<729)&(ndimage.distance_transform_edt(leg)>4)
_,toneIndex=ndimage.distance_transform_edt(~validTone,return_indices=True)
structure=luma.copy();structure[rim&stock]=luma[toneIndex[0][rim&stock],toneIndex[1][rim&stock]]
structure=ndimage.gaussian_filter(structure,3.4)
# Warm skin colors follow original broad highlights and shadows. Color anchors
# come from the original exposed side of this same thigh.
skinColor=np.stack([236+.30*(structure-83),200+.52*(structure-83),189+.54*(structure-83)],axis=2)
skinDonor=leg&existingSkin&(Y>=606)&(Y<=716)&(X>=590)
distance,skinIndex=ndimage.distance_transform_edt(~skinDonor,return_indices=True)
adjacent=rgb[skinIndex[0],skinIndex[1]]
# Smooth donor-row variation without creating a flat block of color.
for c in range(3):adjacent[:,:,c]=ndimage.gaussian_filter(adjacent[:,:,c],4)
blend=np.exp(-distance/24)[...,None]*.90
skinColor=skinColor*(1-blend)+adjacent*blend
corrected=rgb.copy();corrected[skinMask]=rgb[skinMask]*(1-skinWeight[skinMask,None])+skinColor[skinMask]*skinWeight[skinMask,None]
# A thin darker cloth rim marks the moved stocking opening; calf remains original.
band=(bandCoverage>0)&stock&inside
bandTone=np.array([47,35,39],float)
bandWeight=bandCoverage*edgeWeight*.38
corrected[band]+=(bandTone-rgb[band])*bandWeight[band,None]
# Remove only the old internal cuff's antialiased dotted RGB remnants. Use a
# normalized skin-only neighborhood so actual clothing/finger contours cannot
# bleed into the skin repair. The new lower cuff is deliberately excluded.
oldLineZone=(ndimage.distance_transform_edt(~rim)<=4)&leg&(X>=570)&(Y>=608)&(Y<cuffY-4)
actualHandSkin=existingSkin&(X<585)&(Y<616)
oldLineZone &= ~actualHandSkin
skinSupport=leg&(corrected[:,:,0]>165)&(corrected[:,:,1]>110)&(Y<cuffY-3)
denominator=ndimage.gaussian_filter(skinSupport.astype(float),2.4)
filtered=np.empty_like(corrected)
for c in range(3):
    numerator=ndimage.gaussian_filter(corrected[:,:,c]*skinSupport,2.4)
    filtered[:,:,c]=np.divide(numerator,denominator,out=corrected[:,:,c].copy(),where=denominator>1e-6)
# Inner pixels receive complete cleanup; the surrounding RGB transition is soft.
lineWeight=ndimage.gaussian_filter(oldLineZone.astype(float),.8)
lineWeight[oldLineZone]=1
lineWeight*=leg&(Y<cuffY-3)&~actualHandSkin
corrected=corrected*(1-lineWeight[...,None])+filtered*lineWeight[...,None]
corrected=np.clip(np.round(corrected),0,255).astype('uint8');changed=np.any(corrected!=rgb.astype('uint8'),axis=2)
# One source-coordinate patch is applied to every overlapping source rider layer.
# Friend seating/backing is excluded from material edits.
modified=[];candidate=copy.deepcopy(manifest)
for spr in candidate['sprites']:
 sourcePath=BASE/'character-assets'/spr['file'];destination=TARGET/spr['file']
 if spr['id'] not in meta['parts'] or spr['id'] in ('friend_rest_back','friend_rest_front') or 'sourceBounds' not in meta['parts'][spr['id']]:
  shutil.copy2(sourcePath,destination);continue
 bounds=meta['parts'][spr['id']]['sourceBounds'];l,t,r,b=bounds;image=Image.open(sourcePath).convert('RGBA');a=np.array(image);m=changed[t:b,l:r]&(a[:,:,3]>0)
 if not m.any():shutil.copy2(sourcePath,destination);continue
 before=a.copy()
 if spr['id']=='seating':
  # Preserve every derived clothing-backing pixel, even where the source patch
  # overlaps. Only original-RGB stocking residuals receive the material fix.
  m &= np.all(a[:,:,:3]==rgb[t:b,l:r].astype('uint8'),axis=2)
  if not m.any():shutil.copy2(sourcePath,destination);continue
 a[:,:,:3][m]=corrected[t:b,l:r][m]
 newName=sourcePath.name.replace('v0.2.29','v0.2.30');spr['file']=newName;Image.fromarray(a).save(OUT/newName);shutil.copy2(OUT/newName,TARGET/newName)
 modified.append({'id':spr['id'],'file':newName,'changedSpritePixels':int(m.sum()),'alphaUnchanged':bool(np.array_equal(a[:,:,3],before[:,:,3])),'sourceBounds':bounds})
(STAGE/'character-layout.json').write_text(json.dumps(candidate,indent=2)+'\n')
patch=Image.fromarray(np.dstack([corrected,changed.astype('uint8')*255]));patch.save(OUT/'front-thigh-correction-patch-v0.2.30.png')
Image.fromarray(corrected).save(OUT/'corrected-original-preview-v0.2.30.png')
box=(480,570,700,790);before=original.crop(box).resize((660,660));after=Image.fromarray(corrected).crop(box).resize((660,660));sheet=Image.new('RGB',(1320,690),(239,239,239));sheet.paste(before,(0,30));sheet.paste(after,(660,30));d=ImageDraw.Draw(sheet);d.text((12,10),'v0.2.29 original',fill=(25,25,25));d.text((672,10),'v0.2.30 candidate: lowered stocking edge',fill=(25,25,25));sheet.save(QC/'before-after-thigh-v4.png');after.save(QC/'after-thigh-detail-v4.png')
# Source-coordinate assembly checks exact shared color and stable alpha/geometry.
transparent=Image.open(SOURCE/'source-transparent.png').convert('RGBA');full=np.array(transparent);full[:,:,:3][changed]=corrected[changed];Image.fromarray(full).save(QC/'candidate-source-transparent.png')
ys,xs=np.where(changed);ranges=[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)]
qc={'classification':'MEDIUM / Sol HIGH','candidateRevision':4,'curveAntialiasSamplesPerPixel':64,'newStockingEdgeWidthSourcePixels':1,'changedOriginalPixels':int(changed.sum()),'sourceBoundsXYXY':ranges,'skinReplacementPixels':int(skinMask.sum()),'newStockingEdgePixels':int(band.sum()),'pixelsOutsideSemanticFrontThigh':int((changed&~leg).sum()),'pixelsOutsidePreviouslySplitFrontLegAlpha':int((changed&~originalLegAlpha).sum()),'seatingOriginalStockingResidualPixels':sum(p['changedSpritePixels'] for p in modified if p['id']=='seating'),'modifiedSprites':modified,'allSpriteAlphaUnchanged':all(p['alphaUnchanged'] for p in modified),'allGeometryAndAnchorsUnchanged':all({k:v for k,v in a.items() if k!='file'}=={k:v for k,v in b.items() if k!='file'} for a,b in zip(manifest['sprites'],candidate['sprites'])),'oldSourceSHA256':hashlib.sha256((SOURCE/'user-original.png').read_bytes()).hexdigest(),'unchangedRigProfile':candidate['rigProfile'],'friendBackingEdited':False,'stockingEdgeSourceY':'approximately 707 to 720 depending on x','method':'ordinary pixel transformation, original broad leg shading with original adjacent exposed-skin color anchors, old stocking rim tonal structure removed, unified source-coordinate patch applied to all rider overlaps'}
(QC/'qc.json').write_text(json.dumps(qc,indent=2)+'\n');(OUT/'correction-metadata.json').write_text(json.dumps(qc,indent=2)+'\n')
(QC/'README.md').write_text('Candidate only. Front leg (screen right) stocking opening moved to source y about 707-720. Existing outer skin, leg shape, sprite alpha, shoes, geometry, anchors and source-profile rig are retained. Old upper stocking seam is suppressed before mapping the broad original leg shading into skin tones sampled from this thigh. A unified patch updates every overlapping rider sprite; friend-derived seating backing is excluded; original visible stocking pixels misassigned to seating are synchronized. No installation or production edits performed.\n')
print(json.dumps(qc,indent=2))
