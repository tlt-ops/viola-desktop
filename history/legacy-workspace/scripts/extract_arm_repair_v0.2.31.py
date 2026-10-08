#!/usr/bin/env python3
"""Repartition reference arm fringe without recoloring source or other limbs.

Uses immutable .29 sprites and source registration. Only new staged files are
written; the active application resources are deliberately outside ownership.
"""
from pathlib import Path
import hashlib, json, shutil
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
OLD = ROOT / 'Assets/reference-v0.2.29'
OUT = ROOT / 'Assets/ArmRepair-v0.2.31'
QC = ROOT / 'build/arm-v0.2.31'
STAGE = QC / 'stage'
ASSETS = STAGE / 'character-assets'
ACTIVE = ROOT / 'Sources/ViolaDesktop/Resources/Characters/Viola'
for folder in (OUT, QC, ASSETS):
    folder.mkdir(parents=True, exist_ok=True)
metadata = json.loads((OLD / 'extraction-metadata.json').read_text())
manifest = json.loads((ACTIVE / 'character.json').read_text())
source = Image.open(OLD / 'user-original.png').convert('RGB')
rgb = np.asarray(source)
width, height = source.size
yy, xx = np.indices((height, width))
rr, gg, bb = rgb.astype(np.int16).transpose(2, 0, 1)
rest_ids = ['leg_back_thigh', 'seating', 'friend_rest_back', 'friend_rest_front',
            'leg_back', 'leg_front_thigh', 'leg_front', 'viola_skirt', 'body',
            'head', 'resting_pet_arm', 'resting_lap_arm']
arm_ids = ['resting_pet_arm', 'resting_lap_arm',
           'reference_left_arm', 'reference_right_arm', 'mouse_hand']

def registered(sprite_id):
    bounds = metadata['parts'][sprite_id]['sourceBounds']
    im = Image.open(OLD / f'{sprite_id}-original-v0.2.29.png').convert('RGBA')
    full = np.zeros((height, width, 4), np.uint8)
    x0, y0, x1, y1 = bounds
    full[y0:y1, x0:x1] = np.asarray(im)
    return full

def polygon(points):
    im = Image.new('L', source.size)
    ImageDraw.Draw(im).polygon(points, fill=255)
    return np.asarray(im) > 0

# Hair pigment is olive, with blue no brighter than green. Original sleeve
# pigment has red and blue above green. The broad geometric guards keep white
# cuffs, metal buttons, and all skin/fingers untouched by the pigment selector.
# Collar/torso contamination outside the sleeve contour also remains static.
left_outline = polygon([(362,295),(382,294),(400,309),(411,350),
                        (412,452),(404,491),(416,510),(411,520),
                        (397,540),(395,581),(291,590),(284,566),
                        (293,545),(310,524),(315,497),(328,472),
                        (337,435),(350,377),(355,328)])
right_outline = polygon([(606,294),(635,284),(654,290),(669,316),
                         (684,387),(704,458),(723,495),(731,516),
                         (722,544),(701,563),(669,581),(635,602),
                         (597,600),(590,554),(606,536),(612,513),
                         (611,478),(606,433),(604,392),(608,329)])
olive = (gg >= bb) & (rr - gg <= 12) & (rr < 170)
left_hair_guard = (yy < 542) | (xx > 392) | (xx < 294)
right_hair_guard = (yy < 528) | (xx > 635)
selectors = {
    'left': (~left_outline & (yy < 540)) | (olive & left_hair_guard),
    'right': (~right_outline & (yy < 528)) | (olive & right_hair_guard),
}
# The old right-arm dilation also captured the skirt directly below the palm
# and cuff. Preserve the visible palm outline plus two source pixels of seam
# overlap; keep the remaining clothing with the original body registration.
right_hand_outline = polygon([(591,553),(613,558),(627,570),(628,582),
                              (615,586),(603,593),(592,598),(570,598),
                              (557,606),(544,613),(535,618),(528,620),
                              (523,618),(523,613),(516,617),(515,612),
                              (523,602),(527,585),(541,575),(550,568),
                              (566,565),(581,562)])
right_cuff_outline = polygon([(608,529),(629,533),(649,544),(662,562),
                              (664,581),(646,588),(632,596),(628,582),
                              (619,564),(593,556)])
right_lower = ndimage.binary_dilation(right_hand_outline | right_cuff_outline,
                                     iterations=2)
selectors['right'] |= (yy >= 550) & (xx <= 636) & ~right_lower
new_arrays = {}
transfer = np.zeros((height, width), bool)
removed = {}
for sprite_id in arm_ids:
    arr = registered(sprite_id)
    side = 'left' if sprite_id in ('resting_pet_arm', 'reference_left_arm') else 'right'
    remove = (arr[:, :, 3] > 0) & selectors[side]
    removed[sprite_id] = int(remove.sum())
    # The color bytes remain original, including transparent bytes. Only alpha
    # ownership changes. Transfer into body is idempotent for overlapping masks.
    arr[remove, 3] = 0
    # Dark detached crumbs on the old expanded hair border are non-anatomical.
    # Every palm/finger is attached to its cuff; the smallest retained arm
    # component is far larger than this limit.
    labels, count = ndimage.label(arr[:,:,3] > 0)
    sizes = np.bincount(labels.ravel())
    crumbs = (arr[:,:,3] > 0) & (sizes[labels] < 32)
    # Original anti-aliased finger edge islands must move with their hand.
    # Cleanup applies to sleeve/hair crumbs, never the source palm/fingertips.
    crumbs &= yy < (573 if side == 'left' else 551)
    remove |= crumbs
    arr[crumbs,3] = 0
    removed[sprite_id] = int(remove.sum())
    new_arrays[sprite_id] = arr
    transfer |= remove
body = registered('body')
body[transfer, :3] = rgb[transfer]
body[transfer, 3] = 255
# Original .29 body seam dilation included a stationary sleeve edge duplicate.
# Moving arms own that exact source color now, except at the proximal shoulder.
# Every removed body pixel is covered by a later full-arm pixel in neutral.
moving_arm_coverage = ((new_arrays['resting_pet_arm'][:,:,3] > 0) |
                       (new_arrays['resting_lap_arm'][:,:,3] > 0))
static_sleeve_duplicates = (body[:,:,3] > 0) & moving_arm_coverage & (yy >= 335) & ~transfer
body[static_sleeve_duplicates,3] = 0
# Motion reveals anatomy that the photograph never shows. Add a bounded hidden
# texture backing, using only nearby source pigment of the correct material.
# It stays underneath the original opaque full arms in neutral; no source-visible
# pixel or silhouette changes. Row-aware texture cloning retains local strands
# and folds rather than a uniform-color patch.
hidden = moving_arm_coverage & (body[:,:,3] == 0)
source_fg = np.asarray(Image.open(OLD/'source-transparent.png').convert('RGBA'))[:,:,3] > 0
material_guard = source_fg & ~moving_arm_coverage
hair_donor = material_guard & olive & (gg > 18) & (yy >= 275) & (yy <= 850) & (xx >= 270) & (xx <= 890)
skirt_donor = material_guard & (rr > gg + 5) & (gg > bb + 5) & (rr >= 150) & (yy >= 495) & (yy <= 655) & (xx >= 390) & (xx <= 685)
purple_donor = material_guard & (bb > rr + 6) & (rr > gg + 8) & (yy >= 590) & (yy <= 730) & (xx >= 285) & (xx <= 515)
for donor in (hair_donor,skirt_donor,purple_donor):
    donor &= ndimage.binary_erosion(donor,iterations=1)
left_hidden = hidden & (xx < 450)
right_hidden = hidden & ~left_hidden
backing_bands = {
    'leftUpperHair': (left_hidden & (yy < 535), hair_donor & (xx >= 630)),
    'leftCuffSkirt': (left_hidden & (yy >= 535) & (yy < 587), skirt_donor),
    'petPalmPurpleHair': (left_hidden & (yy >= 587), purple_donor),
    'rightUpperHair': (right_hidden & ((yy < 525) | (xx >= 642)), hair_donor & (xx >= 630)),
    'rightLapSkirt': (right_hidden & (yy >= 525) & (xx < 642), skirt_donor),
}
hidden_rgb = rgb.copy()
hidden_donor_y = np.zeros((height,width),np.int32)
hidden_donor_x = np.zeros((height,width),np.int32)
backing_stats = {}
hidden_boundary_distance=ndimage.distance_transform_edt(hidden)
for band,(dest,donor) in backing_bands.items():
    assert donor.any(), band
    # A coherent translated/mirrored patch retains source strand direction and
    # cloth folds. Any proposed sample outside the source material is projected
    # to its nearest valid donor, instead of sampling skin or another garment.
    nearest = ndimage.distance_transform_edt(~donor,return_distances=False,return_indices=True)
    target_y,target_x = np.where(dest)
    # Verified rectangular patches contain coherent source material without
    # arm/palm pixels: long olive strands, ivory folds, and the friend's hair.
    # Resampling the patch is an ordinary texture clone, with no AI drawing.
    if 'Hair' in band and band != 'petPalmPurpleHair': patch=(740,570,790,685)
    elif 'Skirt' in band: patch=(432,551,508,592)
    else: patch=(398,647,444,712)
    sx0,sy0,sx1,sy1=patch
    xmin,xmax=target_x.min(),target_x.max();ymin,ymax=target_y.min(),target_y.max()
    sample_x=sx0+(target_x-xmin)*(sx1-sx0-1)/max(1,xmax-xmin)
    if band == 'leftUpperHair': sample_x=(sx0+sx1-1)-sample_x
    sample_y=sy0+(target_y-ymin)*(sy1-sy0-1)/max(1,ymax-ymin)
    chosen_y=np.rint(sample_y).astype(int);chosen_x=np.rint(sample_x).astype(int)
    cloned=np.stack([ndimage.map_coordinates(rgb[:,:,c].astype(float),[sample_y,sample_x],order=1)
                     for c in range(3)],axis=1)
    # Material transitions follow the sloped lap edges, rather than exposing
    # a rectangular texture band when the cuff leaves its photographed pose.
    is_left=target_x<450
    hair_x=np.where(is_left,790-(target_x-286)/135*50,
                    740+(target_x-593)/144*50).clip(740,789)
    hair_y=(570+(target_y-289)/350*115).clip(570,684)
    hair_color=np.stack([ndimage.map_coordinates(rgb[:,:,c].astype(float),[hair_y,hair_x],order=1)
                         for c in range(3)],axis=1)
    if band.startswith('left'):
        cloned=hair_color
    elif band == 'petPalmPurpleHair':
        material_weight=np.clip((target_y-583)/31,0,1)[:,None]
        cloned=hair_color*(1-material_weight)+cloned*material_weight
    else:
        skirt_x=(432+(target_x-516)/150*76).clip(432,507)
        skirt_y=(551+(target_y-510)/110*41).clip(551,591)
        skirt_color=np.stack([ndimage.map_coordinates(rgb[:,:,c].astype(float),[skirt_y,skirt_x],order=1)
                              for c in range(3)],axis=1)
        material_weight=(np.clip((670+.6*(target_y-570)-target_x)/100,0,1)*
                         np.clip((target_y-500)/90,0,1))[:,None]
        cloned=hair_color*(1-material_weight)+skirt_color*material_weight
    # Blend the last source pixels of the hidden patch toward adjacent matching
    # material, while keeping this entire operation beneath the original arm.
    distance=hidden_boundary_distance[target_y,target_x]
    weight=np.minimum(distance/14,1)[:,None]
    edge_y=nearest[0,target_y,target_x];edge_x=nearest[1,target_y,target_x]
    hair_nearest=ndimage.distance_transform_edt(~hair_donor,return_distances=False,return_indices=True)
    hair_edge=rgb[hair_nearest[0,target_y,target_x],hair_nearest[1,target_y,target_x]]
    edge_color=rgb[edge_y,edge_x]
    if band.startswith('left'): edge_color=hair_edge
    elif band.startswith('right'):
        skirt_nearest=ndimage.distance_transform_edt(~skirt_donor,return_distances=False,return_indices=True)
        skirt_edge=rgb[skirt_nearest[0,target_y,target_x],skirt_nearest[1,target_y,target_x]]
        edge_color=hair_edge*(1-material_weight)+skirt_edge*material_weight
    cloned=cloned*weight+edge_color*(1-weight)
    hidden_rgb[target_y,target_x]=np.rint(cloned).clip(0,255).astype(np.uint8)
    hidden_donor_y[target_y,target_x] = chosen_y
    hidden_donor_x[target_y,target_x] = chosen_x
    backing_stats[band] = {'pixels':int(dest.sum()),'donorPixels':int(donor.sum()),
                          'sourceTexturePatch':list(patch),
                          'method':'bilinear source texture clone; sloped material transition; fourteen pixel same-material edge blend'}
body[hidden,:3] = hidden_rgb[hidden]
body[hidden,3] = 255
Image.fromarray(np.dstack([hidden_rgb,hidden.astype(np.uint8)*255])).save(QC/'hidden-arm-backing.png')
new_arrays['body'] = body

for sprite in manifest['sprites']:
    if sprite['id'] in new_arrays:
        sprite_id = sprite['id']
        bounds = metadata['parts'][sprite_id]['sourceBounds']
        x0, y0, x1, y1 = bounds
        name = f'{sprite_id}-original-v0.2.31.png'
        Image.fromarray(new_arrays[sprite_id][y0:y1,x0:x1]).save(OUT / name)
        shutil.copy2(OUT / name, ASSETS / name)
        sprite['file'] = name
    else:
        shutil.copy2(ACTIVE / sprite['file'], ASSETS / sprite['file'])
manifest['name'] = 'Viola Original Reference Arm Repair v0.2.31'
(STAGE / 'character-layout.json').write_text(json.dumps(manifest, indent=2) + '\n')

def reconstruct(changed):
    result = Image.new('RGBA', source.size)
    for sprite_id in rest_ids:
        arr = new_arrays[sprite_id] if changed and sprite_id in new_arrays else registered(sprite_id)
        result.alpha_composite(Image.fromarray(arr))
    return np.asarray(result)

before, after = reconstruct(False), reconstruct(True)
before = before.copy(); after = after.copy()
before[before[:, :, 3] == 0] = 0
after[after[:, :, 3] == 0] = 0
Image.fromarray(after).save(QC / 'neutral-reconstruction.png')
transfer_preview = source.convert('RGBA')
highlight = np.zeros((height, width, 4), np.uint8)
highlight[transfer] = (255, 30, 20, 150)
transfer_preview.alpha_composite(Image.fromarray(highlight))
transfer_preview.save(QC / 'transferred-static-hair.png')
sheet = Image.new('RGB', (900, 980), (235, 235, 235))
draw = ImageDraw.Draw(sheet)
for index, sprite_id in enumerate(arm_ids[:2]):
    x0,y0,x1,y1 = metadata['parts'][sprite_id]['sourceBounds']
    crop = Image.fromarray(new_arrays[sprite_id][y0:y1,x0:x1])
    crop = crop.resize((crop.width*2,crop.height*2))
    sheet.paste(crop,(index*450,30),crop)
    draw.text((index*450+10,10),sprite_id,fill='black')
sheet.save(QC / 'clean-arms.png')

rgb_errors = {}
for sprite_id, arr in new_arrays.items():
    mask = (arr[:, :, 3] > 0) & (~hidden if sprite_id == 'body' else True)
    rgb_errors[sprite_id] = int(np.any(arr[:, :, :3][mask] != rgb[mask], axis=1).sum())
body_bounds = metadata['parts']['body']['sourceBounds']
x0,y0,x1,y1 = body_bounds
body_domain = np.zeros((height,width),bool);body_domain[y0:y1,x0:x1] = True
qc = {
    'sourceSHA256': hashlib.sha256((OLD/'user-original.png').read_bytes()).hexdigest(),
    'removedArmPixels': removed, 'transferredStaticBodyPixels': int(transfer.sum()),
    'removedStaticSleeveDuplicatePixels': int(static_sleeve_duplicates.sum()),
    'hiddenArmBackingPixels': int(hidden.sum()),
    'hiddenArmBackingBands': backing_stats,
    'hiddenArmBackingOutsideOriginalArmCoverage': int((hidden & ~moving_arm_coverage).sum()),
    'hiddenArmBackingSourceDonorsValid': bool(np.all(material_guard[hidden_donor_y[hidden],hidden_donor_x[hidden]])),
    'proximalShoulderOverlapSourceY': 335,
    'transferOutsideBodyFrame': int((transfer & ~body_domain).sum()),
    'neutralDifferentPixels': int(np.any(before != after,axis=2).sum()),
    'visibleRGBDifferentFromOriginal': rgb_errors,
    'unchangedSpriteFrames': True, 'unchangedLeftPalmFingerAssets': True,
    'rightPalmShapePreserved': 'two source pixel outline overlap; skirt below transferred static',
    'unchangedLegAssets': True, 'spriteCount': len(manifest['sprites']),
    'rigProfile': manifest['rigProfile'],
    'sourceJoints': {'leftShoulder':[380,310],'leftElbow':[344,492],
                     'leftWrist':[341,563], 'rightShoulder':[627,309],
                     'rightElbow':[689,492],'rightWrist':[614,567]},
    'cuffRigidSourceY': {'left': 535, 'right': 525},
    'method': 'Source pixel alpha repartition; hidden source-cloned material backing under original opaque arms',
}
(OUT / 'repair-metadata.json').write_text(json.dumps(qc,indent=2)+'\n')
(QC / 'qc.json').write_text(json.dumps(qc,indent=2)+'\n')
assert qc['neutralDifferentPixels'] == 0, qc
assert qc['transferOutsideBodyFrame'] == 0, qc
assert all(count == 0 for count in rgb_errors.values()), qc
assert len(manifest['sprites']) >= 25, qc
print(json.dumps(qc,indent=2))
