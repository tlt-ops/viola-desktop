"""Separate the user's latest original seated legs and skin, without texture mapping."""
from pathlib import Path
import json
import shutil
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path('/var/folders/9s/ypsb7ly90zq0kbp0nqrcr5tw0000gn/T/codex-clipboard-c0e42639-0d12-420d-9fb3-a0ec746c49ae.png')
RETAINED = ROOT/'Assets/Source/reference-perfect-seated-v0.2.15.png'
if SOURCE.exists(): shutil.copy2(SOURCE,RETAINED)
image = Image.open(RETAINED).convert('RGBA')
assert image.size == (1312,1199)
original = np.asarray(image)
output = ROOT/'build/original-seated-legs-v0.2.15'
output.mkdir(parents=True,exist_ok=True)

outlines = {
 'back': [(371,598),(397,592),(424,590),(426,598),(415,610),(402,631),(389,658),
          (380,684),(373,711),(369,735),(366,755),(370,773),(370,793),(371,808),
          (368,825),(354,850),(343,876),(329,908),(326,927),(328,943),(332,954),
          (329,970),(322,985),(316,995),(315,1017),(312,1043),(311,1064),(306,1080),
          (296,1099),(282,1111),(269,1117),(255,1117),(241,1111),(227,1098),
          (216,1081),(211,1069),(214,1054),(220,1038),(227,1019),(235,998),
          (244,975),(248,954),(249,936),(256,918),(262,895),(265,871),(269,845),
          (272,821),(275,794),(281,768),(286,744),(292,721),(300,700),(308,679),
          (316,658),(324,635),(332,612),(346,598)],
 'front': [(659,613),(662,604),(670,592),(681,584),(696,578),(711,578),
           (729,584),(743,596),(751,611),(755,627),(754,641),(748,651),
           (759,669),(774,695),(786,724),(794,755),(799,789),(800,824),
           (800,861),(800,897),(803,921),(813,944),(820,962),(821,979),
           (817,1002),(817,1021),(817,1041),(820,1062),(816,1080),(805,1096),
           (790,1107),(772,1116),(755,1122),(740,1125),(732,1120),(725,1112),
           (722,1099),(720,1083),(720,1067),(723,1048),(727,1029),(731,1010),
           (734,989),(733,972),(734,953),(734,938),(730,921),(724,902),(719,883),
           (713,864),(705,841),(697,819),(686,793),(677,768),(671,745),
           (668,721),(666,697),(662,675),(659,654),(658,634)],
 'skin': [(710,572),(725,572),(740,578),(751,586),(758,596),(763,606),(774,618),
          (784,631),(795,645),(805,656),(804,666),(797,673),(785,675),(773,674),
          (761,670),(750,665),(738,655),(748,645),(752,630),(748,613),(741,598),
          (730,586),(718,578)]
}

# The back leg's visible exterior is already separated by source alpha. Its
# interior boundary follows the purple hair occlusion instead of filling it in.
# Correct the exterior trace to source positions; no invisible anatomy is drawn.
outlines['back'] = [(373,598),(393,592),(427,590),(425,597),(414,614),(402,637),
 (389,664),(379,691),(374,717),(370,741),(367,758),(372,773),(371,798),(371,815),
 (363,834),(351,861),(339,889),(328,915),(327,934),(334,951),(334,962),(329,976),
 (317,992),(315,1014),(312,1043),(312,1068),(306,1084),(295,1100),(282,1112),
 (268,1118),(253,1118),(242,1113),(231,1101),(218,1083),(211,1069),
 (216,1047),(223,1026),(232,1004),(240,981),(248,957),(249,939),(257,921),
 (263,901),(267,879),(271,855),(274,831),(277,806),(282,780),(288,754),
 (294,729),(302,706),(311,682),(319,660),(327,637),(338,615),(352,599)]

# Read directly from source contours: full image positions remain unchanged.
metadata = {'source':str(RETAINED.relative_to(ROOT)),'canvas':[1312,1199],
 'layoutCrop':[240,560,1072,630],'layoutRect':[128.83399209486166,80,646.1660079051383,375],
 'parts':{}}
combined = Image.new('RGBA',image.size)
for key,polygon in outlines.items():
 mask = Image.new('L',(image.width*4,image.height*4));d=ImageDraw.Draw(mask)
 d.polygon([(x*4,y*4) for x,y in polygon],fill=255)
 mask=mask.resize(image.size,Image.Resampling.LANCZOS)
 rgba=original.copy()
 rgba[:,:,3]=np.rint(original[:,:,3].astype(float)*np.asarray(mask)/255).astype(np.uint8)
 filename=f'leg-reference-perfect-{key}-v0.2.15.png' if key!='skin' else 'thigh-reference-perfect-skin-v0.2.15.png'
 result=Image.fromarray(rgba)
 result.save(ROOT/'Assets/Source'/filename);result.save(output/filename)
 mask.save(output/f'{key}-mask.png');combined.alpha_composite(result)
 metadata['parts'][key]={'file':filename,'sourceOutline':polygon,'alphaBounds':result.getbbox(),
                        'RGBUnchanged':bool(np.array_equal(rgba[:,:,:3],original[:,:,:3]))}

metadata['parts']['back']['contacts']={'hip':[410,592],'knee':[353,774],'ankle':[318,965],'foot':[278,1090]}
metadata['parts']['front']['contacts']={'hip':[769,617],'knee':[705,609],'ankle':[780,969],'foot':[755,1098]}
metadata['parts']['skin']['contacts']={'hip':[747,580],'stockingCuff':[783,672]}
for part in metadata['parts'].values():
 part['canvasContacts']={k:[128.83399209486166+(v[0]-240)/1072*646.1660079051383,
                             80+(1190-v[1])/630*375] for k,v in part['contacts'].items()}
(output/'source-coordinates.json').write_text(json.dumps(metadata,indent=2)+'\n')
background=Image.new('RGBA',image.size,(35,37,44,255));background.alpha_composite(combined)
background.crop((200,555,870,1145)).save(output/'isolated-original-legs.png')
print(output)
