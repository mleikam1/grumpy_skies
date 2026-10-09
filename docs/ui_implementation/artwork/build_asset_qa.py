"""Create comparison sheets and metadata only; never modifies runtime artwork."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import hashlib, json, shutil
ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
REF = Path('/Users/MattLeikam/Downloads/daymaker_exact_ui/references')
ASSET = ROOT/'assets/approved_v1'
FONT = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf', 18)
SMALL = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf', 14)
ROWS = [
 ('personas/karen_portrait.png','characters/light_karen_portrait_context.png','Karen',160,220,'01a1225d-f955-77e3-ad55-1c67bd85a339/exec-d9aa1117-bc84-4d2c-867a-1bb592a8732b.png'),
 ('personas/frat_bro_portrait.png','characters/light_frat_bro_avatar.png','Frat Bro',66,88,'01a12278-8cdc-72e2-a6e9-dd23b17c6079/exec-c2061035-876a-4c4c-83c2-7173b55cf69c.png'),
 ('personas/politician_portrait.png','characters/light_politician_avatar.png','Politician',66,88,'01a12278-8cdc-72e2-a6e9-dd23b17c6079/exec-b1860732-a766-42fc-a022-e693f3cf4ea2.png'),
 ('personas/grandpa_portrait.png','characters/light_grandpa_portrait_context.png','Grandpa',160,220,'01a1225d-f955-77e3-ad55-1c67bd85a339/exec-ac2392cc-4f63-4ed5-9d1d-d6f80612dafa.png'),
 ('personas/two_year_old_portrait.png','characters/light_two_year_old_avatar.png','2-Year-Old',66,88,'01a12278-8cdc-72e2-a6e9-dd23b17c6079/exec-de4147ba-6bc2-48f3-a6e7-20f945eecb98.png'),
 ('weather/sun_grumpy_cloud.png','artwork/light_weather_hero.png','Today hero',200,200,'01a12278-8cdc-72e2-a6e9-dd23b17c6079/exec-d08a10aa-9b89-4c4b-a048-64e0a98c931e.png'),
 ('weather/sunglasses_cloud.png','artwork/light_fun_cloud.png','Sunglasses cloud',190,190,'01a12278-8cdc-72e2-a6e9-dd23b17c6079/exec-0d4b77c2-5aaa-4881-ad36-5eac757124b1.png'),
 ('weather/sun_sunglasses.png','artwork/light_sun_template.png','Sun template',90,90,'01a12278-8cdc-72e2-a6e9-dd23b17c6079/exec-f96300b3-b5e4-47fd-9b81-6f5fda644b05.png'),
 ('weather/coffee_cloud.png','artwork/light_coffee_cloud_template.png','Coffee cloud',90,90,'01a12278-8cdc-72e2-a6e9-dd23b17c6079/exec-2a289a21-346b-4d7b-97c4-ebd16a03bb57.png'),
 ('weather/storm_cloud.png','artwork/light_storm_cloud_template.png','Storm cloud',90,90,'01a12278-8cdc-72e2-a6e9-dd23b17c6079/exec-81ddf2f6-0675-4ee1-bb58-de601a9506ac.png'),
 ('memes/beach_sun_background.png','components/light_fun_featured_meme.png','Beach background',350,117,'01a12278-8cdc-72e2-a6e9-dd23b17c6079/exec-20fb5ea1-6d67-4e2b-b56f-e847bca78436.png'),
]
(OUT/'references').mkdir(exist_ok=True)
metadata=[]
for path,ref,label,w,h,source in ROWS:
 shutil.copy2(REF/ref,OUT/'references'/Path(ref).name)
 im=Image.open(ASSET/path)
 alpha=im.getchannel('A') if im.mode=='RGBA' else None
 metadata.append(dict(path='assets/approved_v1/'+path,classification='reconstructed',tool='builtin image_gen',source_generated_image='~/.codex/generated_images/'+source,reference=ref,width=im.width,height=im.height,mode=im.mode,alpha_range=alpha.getextrema() if alpha else None,sha256=hashlib.sha256((ASSET/path).read_bytes()).hexdigest(),intended_max_logical_slot=[160,220] if path.startswith('personas/') else [w,h],status='review_required_alpha_edges' if alpha else 'textless_reconstruction'))
(OUT/'asset_metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
def put(canvas, image, box, upscale=True):
 x,y,w,h=box
 img=image.convert('RGBA').copy()
 ratio=min(w/img.width,h/img.height)
 if not upscale:ratio=min(1,ratio)
 img=img.resize((round(img.width*ratio),round(img.height*ratio)),Image.Resampling.LANCZOS)
 canvas.alpha_composite(img,(x+(w-img.width)//2,y+(h-img.height)//2))
def sheet(rows,name):
 rowh=310
 im=Image.new('RGBA',(1140,70+rowh*len(rows)), '#f2f3f6')
 d=ImageDraw.Draw(im)
 for x,t in [(20,'Approved crop (native)'),(255,'Crop enlarged for comparison'),(520,'Reconstruction / light'),(830,'Reconstruction / dark')]:d.text((x,20),t,font=SMALL,fill='#142344')
 for i,(path,ref,label,w,h,source) in enumerate(rows):
  y=70+i*rowh
  d.text((20,y),label,font=FONT,fill='#142344')
  src=Image.open(REF/ref)
  d.text((20,y+25),f'{src.width} x {src.height} source',font=SMALL,fill='#506080')
  put(im,src,(20,y+55,210,230),False)
  put(im,src,(255,y+50,210,230))
  for x,bg in [(500,'#fff0f6'),(820,'#142344')]:
   d.rounded_rectangle((x,y+40,x+290,y+292),16,fill=bg)
   put(im,Image.open(ASSET/path),(x+15,y+45,260,238))
 im.convert('RGB').save(OUT/name)
sheet(ROWS[:5],'character_comparisons.png')
sheet(ROWS[5:],'weather_comparisons.png')
# At 1 PNG pixel per logical pixel, these sizes expose practical slot appearance.
im=Image.new('RGBA',(1020,870),'#eef2f7');d=ImageDraw.Draw(im)
d.text((20,18),'Runtime-size artwork checks (1 px = 1 logical px; images are not app screenshots)',font=FONT,fill='#142344')
for i,(path,ref,label,w,h,source) in enumerate(ROWS[:10]):
 x=15+(i%5)*200;y=60+(i//5)*390
 d.text((x,y),label,font=FONT,fill='#142344')
 slotw=min(w,180);sloth=min(h,150)
 for j,bg in enumerate(['#fff0f6','#142344']):
  sy=y+35+j*165
  d.rounded_rectangle((x,sy,x+185,sy+155),12,fill=bg)
  put(im,Image.open(ASSET/path),(x+(185-slotw)//2,sy+(155-sloth)//2,slotw,sloth))
im.convert('RGB').save(OUT/'runtime_slot_checks.png')
print('Created comparison sheets and asset_metadata.json')
