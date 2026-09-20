"""Operator-only public-feed worker. Never import into the website.
Required: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in the CI secret store.
Use --dry-run to validate feeds without any database mutation.
"""
import csv,hashlib,json,os,sys,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'app'))
import sources,tagger

def csv_rows(name):
 with (ROOT/'data'/name).open(encoding='utf-8',newline='') as f:return list(csv.DictReader(f))
def collect():
 skills=[{'slug':r['slug'],'name':r['skill']} for r in csv_rows('skill_taxonomy.csv')]
 index=tagger.build_skill_index(skills,csv_rows('skill_aliases.csv'));required={}
 for r in csv_rows('career_skills.csv'):required.setdefault(r['career_slug'],[]).append({'skill_slug':r['skill_slug'],'weight':int(r['weight'])})
 posts=[]
 for cls in sources.DEFAULT_ADAPTERS:
  adapter=cls()
  if adapter.name=='sample':continue
  try: fetched=adapter.fetch()
  except Exception as exc:
   print(adapter.name+': '+type(exc).__name__);continue
  for p in fetched:
   tags=tagger.tag_skills(p['title'],p.get('description'),index)
   if not tags:continue
   p['external_id']=str(p['external_id']);p['slug']='feed-'+hashlib.sha256((p['source']+':'+p['external_id']).encode()).hexdigest()[:24]
   p['skill_tags']=[{'slug':s,'weight':w} for s,w in tags.items()];p['career_tags']=list(tagger.infer_careers(tags,required));posts.append(p)
  print(adapter.name+': '+str(len(fetched))+' fetched')
 return posts
if __name__=='__main__':
 posts=collect()
 if not posts:raise SystemExit('No listings fetched. Existing data was not changed.')
 if '--dry-run' in sys.argv:print(str(len(posts))+' tagged listings ready; no writes.');raise SystemExit(0)
 url=os.environ['SUPABASE_URL'];key=os.environ['SUPABASE_SERVICE_ROLE_KEY']
 if not url.startswith('https://'):raise SystemExit('HTTPS required')
 req=urllib.request.Request(url+'/rest/v1/rpc/sync_feed_opportunities',data=json.dumps({'postings':posts}).encode(),headers={'apikey':key,'Authorization':'Bearer '+key,'Content-Type':'application/json'},method='POST')
 try:
  with urllib.request.urlopen(req,timeout=60) as response:print('Synchronized listings:',json.load(response))
 except Exception as exc:raise SystemExit('Feed sync failed: '+type(exc).__name__)
