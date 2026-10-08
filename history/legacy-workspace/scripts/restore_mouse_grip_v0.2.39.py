#!/usr/bin/env python3
"""Restore the accepted v0.2.25 frontal mouse grip by retaining source pixels.

The hand outline is traced from the existing illustration. It follows the
finger/mouse borders and the inner cuff arch; no skin-color threshold or color
repainting is used. The mouse and sleeve remain separate renderer assets.
"""
from pathlib import Path
import hashlib
import json
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'Sources/ViolaDesktop/Resources/Characters/Viola/frontal-arms-v0.2.5.png'
OUT = ROOT / 'Assets/MouseGrip-v0.2.39'
QC = ROOT / 'build/mouse-grip-v0.2.39/asset-qc'
OUT.mkdir(parents=True, exist_ok=True)
QC.mkdir(parents=True, exist_ok=True)
SOURCE_CROP = (870, 0, 1290, 1024)
LEGACY_RECT = [401.0, 517.0, 106.0, 247.0]
WRIST = [210.0, 695.0]
# Crop-local x, full-source y. The three upward indents are transparent
# mouse gaps between the thumb/index, index/middle, and middle/ring fingers.
OUTLINE = [
    (136,721),(143,700),(158,685),(180,674),(205,671),(229,675),
    (253,683),(276,698),(296,719),(300,734),(319,742),(342,760),
    (364,782),(384,807),(398,834),(401,846),(401,856),(395,878),
    (383,901),(366,924),(350,940),(340,944),(332,940),(327,932),
    (324,918),(322,903),(320,888),(318,870),(316,852),(312,837),
    (307,825),(300,813),(297,806),(300,827),(300,844),(298,864),
    (296,882),(292,899),(285,913),(274,921),(264,924),(254,921),
    (246,915),(242,906),(239,892),(238,876),(238,858),(238,840),
    (238,823),(236,810),(232,800),(229,792),(214,790),(211,807),
    (209,829),(207,851),(205,874),(202,892),(196,905),(186,912),
    (175,914),(163,910),(154,900),(149,885),(146,866),(144,847),
    (144,828),(145,812),(146,803),(136,812),(127,824),(122,839),
    (123,850),(120,869),(116,888),(109,903),(100,911),(90,914),
    (81,910),(75,901),(68,884),(63,871),(57,860),(52,851),
    (50,838),(51,822),(57,805),(70,791),(90,774),(109,755),
    (125,737),
]
source_image = Image.open(SOURCE).convert('RGBA')
source = source_image.crop(SOURCE_CROP)
scale = 4
mask_large = Image.new('L', (420*scale,1024*scale))
ImageDraw.Draw(mask_large).polygon([(x*scale,y*scale) for x,y in OUTLINE], fill=255)
mask = mask_large.resize(source.size, Image.Resampling.LANCZOS)
src = np.array(source)
mask_array = np.array(mask)
alpha = (src[:,:,3].astype(np.uint16)*mask_array.astype(np.uint16)+127)//255
result = src.copy()
result[:,:,3] = alpha.astype(np.uint8)
bounds = Image.fromarray(result).getchannel('A').getbbox()
assert bounds is not None
x0,y0,x1,y1 = bounds
hand = Image.fromarray(result).crop(bounds)
hand_path = OUT / 'mouse-grip-hand-only-v0.2.39.png'
hand.save(hand_path)
# The world frame uses the old accepted hand/desk group translation [-80,+75].
rect = [LEGACY_RECT[0]+x0/420*LEGACY_RECT[2],
        LEGACY_RECT[1]+(1024-y1)/1024*LEGACY_RECT[3],
        (x1-x0)/420*LEGACY_RECT[2], (y1-y0)/1024*LEGACY_RECT[3]]
anchor = [(WRIST[0]-x0)/(x1-x0),(y1-WRIST[1])/(y1-y0)]
wrist_world = [LEGACY_RECT[0]+WRIST[0]/420*LEGACY_RECT[2],
               LEGACY_RECT[1]+(1024-WRIST[1])/1024*LEGACY_RECT[3]]
retained = alpha > 0
rgb_differences = np.any(result[:,:,:3] != src[:,:,:3],axis=2)
assert not np.any(rgb_differences & retained)
# Probes include nail, bright skin, deep shaded skin, and painted fold shadows.
probes = {'wrist':(210,695),'thumb-nail':(88,879),'thumb-shadow':(110,833),
          'index-nail':(179,882),'index-fold':(174,809),
          'middle-nail':(265,890),'middle-shadow':(278,837),'middle-right-shadow':(295,860),
          'ring-nail':(326,906),'ring-fold':(327,825),
          'little-finger':(373,851),'little-shadow':(362,904)}
probe_rows = []
for name,(x,y) in probes.items():
    before = src[y,x].tolist(); after = result[y,x].tolist()
    assert after[3] > 0, (name,(x,y),'finger probe removed')
    assert before[:3] == after[:3]
    probe_rows.append({'name':name,'cropLocal':[x,y],'sourceRGBA':before,'outputRGBA':after})
# These seeded mouse-body and scroll-wheel pixels must be absent from the hand.
mouse_probes = [(220,862),(230,900),(221,944),(132,877),(310,870),(243,952)]
for x,y in mouse_probes:
    assert int(alpha[y,x]) == 0, ((x,y),'mouse pixel retained')
for name,image in [('hand-only-gray',hand),('source-grip-gray',source.crop((40,650,410,1000)))]:
    bg = Image.new('RGBA',image.size,(225,225,225,255)); bg.alpha_composite(image)
    bg.convert('RGB').resize((image.width*3,image.height*3),Image.Resampling.NEAREST).save(QC/(name+'.png'))
# Retained source RGB is shown beside the alpha-only mask for boundary review.
mask.crop(bounds).resize((hand.width*3,hand.height*3),Image.Resampling.NEAREST).save(QC/'hand-alpha.png')
metadata = {
    'source':str(SOURCE.relative_to(ROOT)),
    'sourceSHA256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
    'sourceCrop':list(SOURCE_CROP),'outlineCropLocal':OUTLINE,
    'sourceHandBoundsCropLocal':list(bounds),'wristCropLocal':WRIST,
    'legacyWholeSpriteTranslatedRect':LEGACY_RECT,'wristWorld':wrist_world,
    'sprite':{'file':hand_path.name,'rect':rect,'anchor':anchor},
    'outputPixels':list(hand.size),'retainedSourcePixels':int(retained.sum()),
    'visibleRGBDifferentFromSource':int((rgb_differences & retained).sum()),
    'originalAlphaRetainedInteriorPixels':int(((mask_array==255)&(alpha==src[:,:,3])&(alpha>0)).sum()),
    'allFingerProbeRGBPreserved':True,'fingerProbes':probe_rows,
    'mouseProbeAlpha':[[x,y,int(alpha[y,x])] for x,y in mouse_probes],
    'sourceMouseIsEmbedded':True,'outputMouseIsTransparent':True,
    'currentIndependentMouseRect':[431,524,53,48],
    'oldAcceptedIndependentMouseRectTranslated':[431,524,53,48],
    'method':'Manually registered color-independent source outline; alpha-only extraction with 4x boundary coverage; source RGB unchanged.',
    'registrationNotes':'True skin wrist is crop-local (210,695), not the legacy whole-arm anchor at source y609.28. Old frontal illustration embeds a wider mouse silhouette than the independent 53x48 mouse; only hand pixels are retained here. Check renderer registration and material seam visually.'
}
(OUT/'geometry.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2)+'\n')
(QC/'pixel-preservation.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'file':str(hand_path),'sprite':metadata['sprite'],'wristWorld':wrist_world,'bounds':list(bounds),'retainedPixels':int(retained.sum())},ensure_ascii=False))
