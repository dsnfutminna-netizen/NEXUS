"""Fetch public feeds and generate operator-only SQL. Never reads student data.
Run: python scripts/refresh_cloud_opportunities.py
Review release-private/opportunities.sql, then run it in Supabase SQL Editor.
"""
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'app'))
import sources
import tagger
from build_cloud_seed import rows,quote,lookup

def main():
    skills=[dict(slug=r['slug'],name=r['skill']) for r in rows('skill_taxonomy')]
    index=tagger.build_skill_index(skills,rows('skill_aliases'))
    required={}
    for r in rows('career_skills'):
        required.setdefault(r['career_slug'],[]).append(dict(skill_slug=r['skill_slug'],weight=int(r['weight'])))
    out=['begin;']; count=0
    for cls in sources.DEFAULT_ADAPTERS:
        adapter=cls()
        if adapter.name=='sample': continue
        try: postings=adapter.fetch()
        except Exception as exc:
            print(f'{adapter.name}: {type(exc).__name__}');continue
        for p in postings:
            tags=tagger.tag_skills(p['title'],p.get('description'),index)
            if not tags: continue
            slug='feed-'+hashlib.sha256((p['source']+':'+str(p['external_id'])).encode()).hexdigest()[:24]
            p.update(slug=slug,is_active='true',is_remote='true' if p.get('is_remote') else 'false',fetched_at=datetime.now(timezone.utc).isoformat())
            p['tags']=json.dumps(p.get('tags',[]))
            cols=['slug','source','external_id','title','organization','description','url','category','is_remote','location','posted_at','deadline','tags','fetched_at','is_active']
            vals=','.join(quote(p.get(k)) for k in cols)
            updates=','.join(f'{k}=excluded.{k}' for k in cols if k!='slug')
            out.append(f'insert into opportunities ({",".join(cols)}) values ({vals}) on conflict(slug) do update set {updates};')
            oid=lookup('opportunities','slug',slug)
            for table in ['opportunity_skills','opportunity_careers']:
                out.append(f'delete from {table} where opportunity_id={oid};')
            for skill,weight in tags.items():
                out.append(f'insert into opportunity_skills(opportunity_id,skill_id,weight) values({oid},{lookup("skills","slug",skill)},{int(weight)});')
            for career in tagger.infer_careers(tags,required):
                out.append(f'insert into opportunity_careers(opportunity_id,career_id) values({oid},{lookup("careers","slug",career)});')
            count+=1
        print(f'{adapter.name}: fetched {len(postings)}')
    out.append('commit;')
    folder=ROOT/'release-private';folder.mkdir(exist_ok=True)
    (folder/'opportunities.sql').write_text('\n'.join(out),encoding='utf-8')
    print(f'Prepared {count} tagged listings in release-private/opportunities.sql')
    if count==0: raise SystemExit('No live data fetched; no SQL should be applied.')

if __name__=='__main__': main()
