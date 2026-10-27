"""Slice generated4-column,8-row animation atlases into64 native PNG frames.
This is asset import, not a game/test runner. Source alpha and originals survive.
"""
import argparse,json,shutil
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'assets/crypt/living'

def render_preview(frames):
 manifest=json.loads((BASE/'living_manifest.json').read_text(encoding='utf-8'))
 # A compact art preview, deliberately separate from any gameplay claim.
 gifs=[]
 for frame in range(4):
  contact=Image.new('RGB',(640,432),(14,9,23));draw=ImageDraw.Draw(contact)
  for index,entry in enumerate(manifest['animations']):
   sprite=Image.open(frames/f'living_{index:03}_f{frame}.png').convert('RGBA')
   sprite=sprite.resize((80,80),Image.Resampling.NEAREST)
   x=(index%8)*80;y=(index//8)*216+16
   contact.paste(sprite,(x,y),sprite)
   label=entry['name'];words=label.split();line='';dy=y+90
   for word in words:
    if len(line+' '+word)>13:
     draw.text((x+3,dy),line,fill=(210,195,224));line=word;dy+=14
    else:line=(line+' '+word).strip()
   draw.text((x+3,dy),line,fill=(210,195,224))
  gifs.append(contact)
 gifs[0].save(BASE/'living_preview.gif',save_all=True,append_images=gifs[1:],duration=180,loop=0,disposal=2)
 gifs[0].save(BASE/'living_preview.png')

def main(paths):
 source=BASE/'source';frames=BASE/'frames';source.mkdir(parents=True,exist_ok=True);frames.mkdir(parents=True,exist_ok=True)
 manifest=json.loads((BASE/'living_manifest.json').read_text(encoding='utf-8'))
 for sheet_index,path in enumerate(paths):
  target=source/f'living_sheet_{"a" if sheet_index==0 else "b"}.png'
  shutil.copyfile(path,target)
  sheet=Image.open(target).convert('RGBA')
  for row in range(8):
   index=sheet_index*8+row
   for frame in range(4):
    box=(round(frame*sheet.width/4),round(row*sheet.height/8),round((frame+1)*sheet.width/4),round((row+1)*sheet.height/8))
    image=sheet.crop(box).resize((64,64),Image.Resampling.NEAREST)
    image.save(frames/f'living_{index:03}_f{frame}.png')
 render_preview(frames)
 print(json.dumps({'animations':16,'frames':64,'frame_size':64,'output':str(frames),'sources':[str(p)for p in paths]}))
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('sheet_a',nargs='?');parser.add_argument('sheet_b',nargs='?');parser.add_argument('--preview-frames');args=parser.parse_args()
 if args.preview_frames:render_preview(Path(args.preview_frames))
 elif args.sheet_a and args.sheet_b:main([args.sheet_a,args.sheet_b])
 else:parser.error('Two source sheets or --preview-frames required')
