"""Author the review-only crypt library from contour rules, never copied rooms.
No game tests. Original user map and source atlases are read-only inputs.
"""
import argparse,hashlib,json,random
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'assets/data/custom_dungeons/dungeon_mein_entwurf.json'
OUT=ROOT/'assets/data/custom_dungeons/dungeon_crypt_of_the_damned.json'
NAMES=['Vorhalle der Verdammten','Knochengalerien','Sarkophaghof','Kapelle der verlorenen Seelen','Verschlungene Katakomben','Garten der Graburnen','Reliquienarchiv','Grab der Namenlosen','Trauerhallen','Thron der Verdammten']
ROOM_PALETTES=['amber','violet','rose','amber','moss','moss','amber','moss','rose','violet']
D=[(0,-1),(1,-1),(1,0),(1,1),(0,1),(-1,1),(-1,0),(-1,-1)]
# Independent architectural graphs, not repetitions of an authored room.
PLANS=[
 ([(6,4,8,10),(6,17,15,11),(23,11,14,13),(23,29,13,9),(44,17,15,11)],[(0,1),(1,2),(2,3),(2,4)]),
 ([(8,5,14,8),(32,5,22,8),(8,31,22,8),(42,31,13,8),(25,18,14,9)],[(0,1),(0,2),(2,3),(1,3),(1,4),(4,2)]),
 ([(8,5,19,10),(37,5,18,10),(8,30,18,10),(36,30,19,10)],[(0,1),(1,3),(3,2),(2,0)]),
 ([(24,5,16,12),(24,17,16,12),(24,29,16,11),(8,17,13,11),(44,17,13,11)],[(0,1),(1,2),(3,1),(1,4)]),
 ([(8,5,12,9),(26,6,13,9),(45,6,12,9),(8,29,13,10),(28,28,13,11),(46,29,12,10)],[(0,3),(3,4),(4,1),(1,2),(2,5)]),
 ([(10,5,12,12),(37,4,16,10),(9,29,16,10),(40,29,15,11),(25,18,12,9)],[(0,1),(0,2),(2,3),(1,3),(0,4),(4,3)]),
 ([(9,6,13,31),(29,5,25,9),(30,18,24,9),(29,31,25,9)],[(0,1),(0,2),(0,3),(1,2)]),
 ([(8,5,18,10),(37,5,17,10),(9,29,17,10),(38,29,17,10),(25,17,13,12)],[(0,1),(1,3),(3,2),(2,0),(0,4),(4,3)]),
 ([(8,5,15,11),(35,5,19,10),(12,29,18,11),(40,27,14,12),(23,17,18,10)],[(0,4),(4,1),(4,2),(2,3)]),
 ([(9,8,15,12),(26,5,16,13),(43,8,13,12),(9,29,15,10),(26,27,16,13),(43,29,13,10)],[(0,1),(1,2),(0,3),(3,4),(4,5),(2,5)])]
ROLES={'north':2,'south':37,'west':21,'east':27,'outer_nw':7,'outer_ne':5,'outer_sw':36,'outer_se':34,'inner_nw':33,'inner_ne':29,'inner_sw':12,'inner_se':8}
def cell(x,y,t,solid=False,layer='floor',rotation=0,wall=False):
 a=dict(x=x,y=y,tile=t,solid=solid,layer=layer,rotation=rotation)
 if wall:a['crypt_wall']=True
 return a
def wall_role(p,F):
 x,y=p;n=(x,y-1)in F;e=(x+1,y)in F;s=(x,y+1)in F;w=(x-1,y)in F
 # Each void cell receives exactly one role. No stochastic sprite choice.
 if n and w:return 'inner_nw'
 if n and e:return 'inner_ne'
 if s and w:return 'inner_sw'
 if s and e:return 'inner_se'
 if s:return 'north'
 if n:return 'south'
 if e:return 'west'
 if w:return 'east'
 if (x+1,y+1)in F:return 'outer_nw'
 if (x-1,y+1)in F:return 'outer_ne'
 if (x+1,y-1)in F:return 'outer_sw'
 return 'outer_se'
def build_floor(recipe,rng):
 F=set();rectangles=[]
 for index,r in enumerate(recipe['chambers']):
  x,y,w,h=map(int,r)
  # Entrances are fixed; room lengths vary within their reserved architectural envelope.
  if index>=2:w+=rng.randrange(2);h+=rng.randrange(2)
  rectangles.append((x,y,w,h))
  F.update((xx,yy)for yy in range(y,y+h)for xx in range(x,x+w))
 def passage(a,b):
  if a[1]==b[1]:F.update((x,y)for x in range(min(a[0],b[0]),max(a[0],b[0])+1)for y in range(a[1]-2,a[1]+3))
  else:F.update((x,y)for y in range(min(a[1],b[1]),max(a[1],b[1])+1)for x in range(a[0]-2,a[0]+3))
 for a,b in recipe['links']:
  ra=rectangles[a];rb=rectangles[b];aa=(ra[0]+ra[2]//2,ra[1]+ra[3]//2);bb=(rb[0]+rb[2]//2,rb[1]+rb[3]//2)
  elbow=(bb[0],aa[1]) if rng.randrange(2)else(aa[0],bb[1])
  passage(aa,elbow);passage(elbow,bb)
 return F,rectangles

def make_room(i,seed=42026):
 rng=random.Random(seed+i*1301);rooms,links=PLANS[i];palette=ROOM_PALETTES[i]
 # Side entry/exit chambers connect to graph nodes0/last. They are not copied art motifs.
 chambers=[(3,17,11,11),(50,17,11,11)]+rooms
 links=[(a+2,b+2)for a,b in links]+[(0,2),(1,len(chambers)-1)]
 recipe=dict(chambers=chambers,links=links)
 F,rects=build_floor(recipe,rng)
 border={(x+dx,y+dy)for x,y in F for dx,dy in D if(x+dx,y+dy)not in F}
 tiles=[]
 for x,y in sorted(F,key=lambda p:(p[1],p[0])):
  # Same floor family as the user; retain a restrained grain rather than new colors.
  tile=f'{palette}_011' if rng.randrange(30)==0 else f'{palette}_017'
  tiles.append(cell(x,y,tile))
 for x,y in sorted(border,key=lambda p:(p[1],p[0])):
  role=wall_role((x,y),F);tiles.append(cell(x,y,f'{palette}_{ROLES[role]:03}',True,'structure',wall=True))
 players=[[240,656],[304,656],[240,720],[304,720]]
 if i==0:players=[[272,240],[336,240],[272,304],[336,304]]
 enemies=[[1728,640],[1792,640],[1856,704],[1728,768],[1792,768]]
 reward=[304,720];stairs=[1792,736]
 fires=[[(x+w//2)*32,(y+2)*32]for x,y,w,h in rects[2:]][:12]
 reserved=players+enemies+fires+[reward,stairs,[176,720],[1872,720]]
 anchors=[]
 for x,y,w,h in rects[2:]:
  for px,py in [(x+3,y+4),(x+w-4,y+h-4)]:
   center=[px*32+16,py*32+16]
   if(px,py)not in F or any((center[0]-p[0])**2+(center[1]-p[1])**2<112**2 for p in reserved):continue
   if any(abs(px-a[0])+abs(py-a[1])<4 for a in anchors):continue
   anchors.append((px,py))
 # Theme dressing is applied by scripts/dress_crypt_samples.gd after this geometry bake.
 t=dict(id=f'crypt_{i+1:02}',title=f'CRYPT OF THE DAMNED · {NAMES[i]}',boss=i==9,layout_mode='freeform',world_size=[2048,1408],play_bounds=[0,0,2048,1408],theme=palette,accent_color='8b79a6',render_style='classic_quiet',decoration_enabled=False,obstacles_tiles=[],painted_tiles=tiles,player_spawns=players,enemy_spawns=enemies,brazier_spawns=fires,reward_spawn=reward,authored_doors=[dict(x=5,y=22,side='west',tile='items_002',rotation=0),dict(x=58,y=22,side='east',tile='items_002',rotation=0)],crypt_recipe=recipe,crypt_profile=True,crypt_entrance=i==0,encounter=dict(min_enemies=5+i//3,max_enemies=7+i//3,spawn_min_distance=288,enemy_spacing=80),crypt_ambience=dict(fog_opacity=.16,fog_speed=5.0))
 if i==0:
  # Only this northern threshold uses the original broken masonry graphic.
  for a in tiles:
   if a['x']==8 and a['y']==3 and a['layer']=='structure':a['tile']=f'{palette}_045'
 if i==9:
  t['stairs_spawn']=stairs;t['stairs_art']=dict(tile=f'{palette}_000',rotation=0);t['encounter']['boss_enemies']=3
 return t

def render_preview(config):
 if config.get('render_style')=='classic_quiet':
  print('CLASSIC_QUIET: use the Godot editor/game renderer for current art; legacy colored preview generation skipped.')
  return
 props=ROOT/'assets/crypt/props'
 manifest=json.loads((ROOT/'assets/crypt/living/living_manifest.json').read_text(encoding='utf-8'))
 dimensions={a['id']:a['draw_size'][0]for a in manifest['animations']}
 # Static design view only. Actual gameplay uses full-size frames and contact shadows.
 sheet=Image.new('RGB',(1280,1690),(8,6,15));draw=ImageDraw.Draw(sheet)
 for i,t in enumerate(config['templates']):
  im=Image.new('RGBA',(2048,1408),(8,6,15,255))
  for c in t['painted_tiles']:
   crypt=c['tile'].startswith('crypt_');living=c['tile'].startswith('living_');x=int(c['x'])*32;y=int(c['y'])*32
   path=ROOT/f"assets/crypt/living/frames/{c['tile']}_f0.png" if living else props/f"{c['tile']}.png" if crypt else ROOT/f"assets/tilesets/cells32/{c['tile']}.png"
   cache=ROOT/f".godot/art_preview/props/{c['tile']}.png" if crypt else ROOT/f".godot/art_preview/living/{c['tile']}_f0.png"
   if (crypt or living) and cache.exists():path=cache
   a=Image.open(path).convert('RGBA')
   size=dimensions.get(c['tile'],64) if living else a.width if crypt else 32
   a=a.resize((size,size),Image.Resampling.NEAREST)
   im.alpha_composite(a,(x+16-size//2,y+32-size))
  if i==0:im.crop((96,64,800,576)).save(ROOT/'assets/crypt/crypt_style_detail.png')
  im.thumbnail((620,300),Image.Resampling.NEAREST);ox=i%2*640+10;oy=i//2*338+30;sheet.paste(im,(ox,oy));draw.text((ox,oy-22),f'{i+1:02} {NAMES[i]}',(191,175,210))
 sheet.save(ROOT/'assets/crypt/crypt_layout_overview.png')

def build(atlas=None):
 props=ROOT/'assets/crypt/props';source=ROOT/'assets/crypt/source';props.mkdir(parents=True,exist_ok=True);source.mkdir(parents=True,exist_ok=True)
 if atlas:
  target=source/'crypt_furnishings_atlas.png';target.write_bytes(Path(atlas).read_bytes());im=Image.open(target).convert('RGBA');w,h=im.width//4,im.height//4
  for i in range(16):im.crop((i%4*w,i//4*h,(i%4+1)*w,(i//4+1)*h)).resize((64,64),Image.Resampling.NEAREST).save(props/f'crypt_{i:03}.png')
 style=dict(source_room='room_001',source_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),wall_roles={k:f'violet_{v:03}'for k,v in ROLES.items()},floor_tiles=['violet_017','violet_011'])
 config=dict(schema_version=1,generator_version=4,tile_size=32,world_size=[896,480],play_bounds=[32,48,832,400],max_actor_radius=24,campaign_room_count=10,campaign_title='Crypt of the Damned',render_style='classic_quiet',decoration_enabled=False,crypt_procedural=True,crypt_style_source=style,crypt_decoration_catalog=json.loads((ROOT/'assets/data/crypt_decoration_catalog.json').read_text(encoding='utf-8'))['themes'],templates=[make_room(i)for i in range(10)])
 OUT.write_text(json.dumps(config,ensure_ascii=False,separators=(',',':'))+'\n',encoding='utf-8')
 render_preview(config)
 print(json.dumps(dict(bytes=OUT.stat().st_size,source_sha256=style['source_sha256'],maps=10,method='independent chamber graphs + deterministic complete8-neighbour contour')))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--atlas');p.add_argument('--preview-only',action='store_true');args=p.parse_args()
 if args.preview_only:render_preview(json.loads(OUT.read_text(encoding='utf-8')))
 else:build(args.atlas)
