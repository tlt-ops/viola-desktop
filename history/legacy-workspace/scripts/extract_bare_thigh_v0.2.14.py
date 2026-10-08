"""Map the reference's exposed thigh texture onto only the existing upper thighs.

Retains original alpha, leg contours, atlas dimensions, knees, calves and feet.
The integrated candidate only receives the two versioned leg file references.
"""
from pathlib import Path
import json
import shutil
import numpy as np
from PIL import Image, ImageFilter, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Assets/Source"
OUT = ROOT / "build/previews-v0.2.14-integrated"
reference = np.asarray(Image.open(SOURCE / "reference-seating.png").convert("RGBA"))

# The boundaries below stay inside the visible skin, excluding ivory drape and
# dark stocking edges. They follow the source's narrow curved skin opening.
source_y = np.array([581, 590, 605, 620, 640, 656, 670, 677])
source_left = np.array([767, 779, 792, 800, 812, 822, 831, 836])
source_right = np.array([777, 789, 806, 823, 837, 845, 845, 841])

def skin_sample(u, v):
    sy = np.clip(581 + np.clip(v, 0, 1) * 96, 581, 677)
    left = np.interp(sy, source_y, source_left)
    right = np.interp(sy, source_y, source_right)
    sx = left + np.clip(u, 0, 1) * (right - left)
    x0 = np.floor(sx).astype(int); y0 = np.floor(sy).astype(int)
    fx = (sx - x0)[..., None]; fy = (sy - y0)[..., None]
    return ((reference[y0,x0,:3]*(1-fx) + reference[y0,x0+1,:3]*fx)*(1-fy) +
            (reference[y0+1,x0,:3]*(1-fx) + reference[y0+1,x0+1,:3]*fx)*fy)

def save_atlas(source_name, result_name, side):
    image = Image.open(SOURCE / source_name).convert("RGBA")
    original = np.array(image)
    result = original.copy()
    h,w = original.shape[:2]; yy,xx = np.mgrid[:h,:w]
    alpha = Image.fromarray(original[:,:,3])
    inside = np.asarray(alpha.filter(ImageFilter.MinFilter(5))) / 255.0
    if side == "front":
        # A short upper-thigh opening: 190 source rows, around 54 canvas points.
        u = np.clip((xx-847)/192,0,1)
        cuff = 245 - 26 * (2*u-1)**2
        v = np.clip((yy-52)/np.maximum(1,cuff-52),0,1)
        amount = np.clip((cuff-yy)/2,0,1)
        amount *= (xx>=830)&(xx<=1050)&(yy>=42)&(yy<247)
    else:
        # Retain the bent knee. Skin is confined to the hip-end 18 percent of
        # the diagonal thigh, with a curved cuff perpendicular to its axis.
        dx,dy = 570.0,285.0
        length = np.hypot(dx,dy)
        along = ((xx-345)*dx+(yy-330)*dy)/(length*length)
        lateral = ((xx-345)*(-dy)+(yy-330)*dx)/length
        u = np.clip((lateral+72)/155,0,1)
        cuff = 0.80 + 0.026*(2*u-1)**2
        v = np.clip((1-along)/np.maximum(0.01,1-cuff),0,1)
        amount = np.clip((along-cuff)*length/2,0,1)
        amount *= (xx>690)&(yy>435)&(yy<745)
    # Preserve the original fine dark outline; only interior RGB is replaced.
    amount *= inside
    mapped = skin_sample(u,v)
    mixed = original[:,:,:3]*(1-amount[...,None])+mapped*amount[...,None]
    result[:,:,:3] = np.rint(mixed).astype(np.uint8)
    Image.fromarray(result).save(SOURCE/result_name)
    shutil.copy2(SOURCE/result_name,ROOT/"Sources/ViolaDesktop/Resources/Characters/Viola"/result_name)
    target_assets = OUT/"character-assets"
    target_assets.mkdir(parents=True,exist_ok=True)
    shutil.copy2(SOURCE/result_name,target_assets/result_name)
    changed = np.any(result != original,axis=2)
    ys,xs = np.where(changed)
    return {"source":source_name,"output":result_name,"changedPixels":int(changed.sum()),
            "changedBounds":[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)],
            "alphaUnchanged":bool(np.array_equal(result[:,:,3],original[:,:,3]))}

evidence = [save_atlas("legs-slender-v0.2.8.png","legs-bare-thigh-v0.2.14.png","front"),
            save_atlas("leg-right-seated-v0.2.12.png","leg-right-seated-bare-thigh-v0.2.14.png","back")]
layout_file = OUT/"character-layout.json"
layout = json.loads(layout_file.read_text())
for sprite in layout["sprites"]:
    if sprite["id"] in ["leg_front","leg_front_thigh"]:
        sprite["file"] = "legs-bare-thigh-v0.2.14.png"
    elif sprite["id"] in ["leg_back","leg_back_thigh"]:
        sprite["file"] = "leg-right-seated-bare-thigh-v0.2.14.png"
layout_file.write_text(json.dumps(layout,ensure_ascii=False,indent=2)+"\n")
(OUT/"bare-thigh-evidence.json").write_text(json.dumps(evidence,indent=2)+"\n")

# Pixel previews are reviewable source transformations, not native UI evidence.
preview = Image.new("RGBA",(1250,700),(40,43,49,255))
for x,name,crop,size in [(20,"legs-slender-v0.2.8.png",(819,42,1079,395),(260,353)),
                         (310,"legs-bare-thigh-v0.2.14.png",(819,42,1079,395),(260,353)),
                         (600,"leg-right-seated-v0.2.12.png",(350,280,915,740),(282,230)),
                         (910,"leg-right-seated-bare-thigh-v0.2.14.png",(350,280,915,740),(282,230))]:
    tile=Image.open(SOURCE/name).crop(crop).resize(size,Image.Resampling.LANCZOS)
    preview.alpha_composite(tile,(x,40))
    ImageDraw.Draw(preview).text((x,15),name,fill="white")
ref=Image.open(SOURCE/"reference-seating.png").crop((740,565,875,690)).resize((270,250))
preview.alpha_composite(ref,(20,420));ImageDraw.Draw(preview).text((20,400),"original exposed thigh / cuff",fill="white")
preview.save(OUT/"bare-thigh-source-comparison.png")
print(json.dumps(evidence,indent=2))
