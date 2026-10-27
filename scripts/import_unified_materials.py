from pathlib import Path
from PIL import Image
import argparse,shutil,json
r=Path.cwd();b=r/'assets/crypt/unified';(b/'source').mkdir(parents=True,exist_ok=True);(b/'materials').mkdir(parents=True,exist_ok=True)
parser=argparse.ArgumentParser();parser.add_argument('atlas');src=Path(parser.parse_args().atlas)
target=b/'source/crypt_material_atlas.png'
if src.resolve()!=target.resolve():shutil.copyfile(src,target)
sheet=Image.open(target).convert('RGBA')
for i in range(16):
 x=i%4;y=i//4
 box=(round(x*sheet.width/4),round(y*sheet.height/4),round((x+1)*sheet.width/4),round((y+1)*sheet.height/4))
 sheet.crop(box).resize((32,32),Image.Resampling.NEAREST).save(b/f'materials/material_{i:03}.png')
print(json.dumps({'materials':16,'native_size':32,'output':str(b/'materials')}))
