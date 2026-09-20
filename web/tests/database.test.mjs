import { PGlite } from "@electric-sql/pglite";
import { readFileSync, readdirSync } from "node:fs";
import { test } from "node:test";
import assert from "node:assert/strict";
test("Postgres migrations enforce isolation, identity, consent, feedback and admin permissions", async () => {
  const db = new PGlite();
  await db.exec(
    `create role anon;create role authenticated;create role service_role bypassrls;create schema auth;create table auth.users(id uuid primary key,email text);create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;create function auth.jwt() returns jsonb language sql stable as $$ select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb $$;grant usage on schema public,auth to anon,authenticated,service_role;create function public.rls_auto_enable() returns void language sql as $$ select $$;`,
  );
  for (const filename of readdirSync("../supabase/migrations")
    .filter((f) => f.endsWith(".sql"))
    .sort()) {
    const sql = readFileSync(
      "../supabase/migrations/" + filename,
      "utf8",
    ).replace(/create extension if not exists pgcrypto;[^\n]*/i, "");
    await db.exec(sql);
  }
  for (const path of ["../db/test_rls.sql", "../db/test_identity_consent.sql"])
    await db.exec(readFileSync(path, "utf8"));
  await db.exec(
    `begin;select set_config('test.student',gen_random_uuid()::text,true),set_config('test.other',gen_random_uuid()::text,true),set_config('test.admin',gen_random_uuid()::text,true);insert into auth.users(id,email) values(current_setting('test.student')::uuid,'a@example.test'),(current_setting('test.other')::uuid,'b@example.test'),(current_setting('test.admin')::uuid,'admin@example.test');insert into profiles(id,email,full_name,role) values(current_setting('test.student')::uuid,'a@example.test','A','student'),(current_setting('test.other')::uuid,'b@example.test','B','student'),(current_setting('test.admin')::uuid,'admin@example.test','Admin','admin');select set_config('request.jwt.claim.sub',current_setting('test.student'),true);set local role authenticated;insert into feedback_requests(student_id,category,body) values(auth.uid(),'problem','Test feedback body');do $$ begin if (select count(*) from feedback_requests)<>1 then raise exception 'Own feedback not visible';end if;update feedback_requests set status='resolved';if found then raise exception 'Student changed status';end if;begin insert into feedback_notes(feedback_id,author_id,body) select id,auth.uid(),'Secret note' from feedback_requests;raise exception 'Student wrote note';exception when insufficient_privilege then null;end;begin perform sync_feed_opportunities('[]');raise exception 'Student ran ingestion';exception when insufficient_privilege then null;end;end $$;reset role;select set_config('request.jwt.claim.sub',current_setting('test.other'),true);set local role authenticated;do $$ begin if exists(select 1 from feedback_requests) then raise exception 'Other student read feedback';end if;end $$;reset role;select set_config('request.jwt.claim.sub',current_setting('test.admin'),true);set local role authenticated;do $$ begin if (select count(*) from feedback_requests)<>1 then raise exception 'Admin cannot read feedback';end if;end $$;update feedback_requests set status='reviewing';insert into feedback_notes(feedback_id,author_id,body) select id,auth.uid(),'Reviewing issue' from feedback_requests;reset role;select set_config('request.jwt.claim.sub',current_setting('test.student'),true);set local role authenticated;do $$ begin if exists(select 1 from feedback_notes) then raise exception 'Private notes exposed';end if;if (select status from feedback_requests limit 1)<>'reviewing' then raise exception 'Review status missing';end if;end $$;reset role;rollback;`,
  );
  const result = await db.query("select count(*)::int as n from profiles");
  assert.equal(result.rows[0].n, 0);
  await db.close();
});
