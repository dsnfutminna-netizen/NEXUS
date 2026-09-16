-- Transaction-only fixtures: no test accounts or student data survive this test.
begin;
select set_config('nexus.test_a',gen_random_uuid()::text,true),set_config('nexus.test_b',gen_random_uuid()::text,true);
insert into auth.users(id,email) values
(current_setting('nexus.test_a')::uuid,'rls-a@example.invalid'),
(current_setting('nexus.test_b')::uuid,'rls-b@example.invalid');
insert into profiles(id,full_name,email,target_career_id) values
(current_setting('nexus.test_a')::uuid,'RLS A','rls-a@example.invalid',(select id from careers limit 1)),
(current_setting('nexus.test_b')::uuid,'RLS B','rls-b@example.invalid',(select id from careers limit 1));
select set_config('request.jwt.claim.sub',current_setting('nexus.test_a'),true);
set local role authenticated;
do $$ declare n integer; sid bigint; begin
 if (select count(*) from profiles) <> 1 then raise exception 'Profile isolation failed'; end if;
 if exists(select 1 from v_skill_gaps where student_id<>auth.uid()) then raise exception 'View isolation failed'; end if;
 update profiles set full_name='forbidden' where id=current_setting('nexus.test_b')::uuid;
 get diagnostics n=row_count;
 if n<>0 then raise exception 'Cross-user update allowed'; end if;
 begin
  update profiles set role='admin' where id=auth.uid();
  raise exception 'Role escalation allowed';
 exception when insufficient_privilege then null; end;
 sid:=(select id from skills order by id limit 1);
 perform save_my_skills(jsonb_build_array(jsonb_build_object('skill_id',sid,'rank',2)));
 if (select proficiency_rank from student_skills where student_id=auth.uid() and skill_id=sid)<>2 then raise exception 'Skill save failed'; end if;
 begin
  perform save_my_skills(jsonb_build_array(jsonb_build_object('skill_id',sid,'rank',3),jsonb_build_object('skill_id',sid,'rank',9)));
  raise exception 'Invalid rank accepted';
 exception when raise_exception then
  if SQLERRM<>'Invalid proficiency' then raise; end if;
 end;
 if (select proficiency_rank from student_skills where student_id=auth.uid() and skill_id=sid)<>2 then raise exception 'Partial skill save'; end if;
 begin
  insert into student_skills(student_id,skill_id,proficiency_rank) values(current_setting('nexus.test_b')::uuid,sid,1);
  raise exception 'Cross-user insert allowed';
 exception when insufficient_privilege then null; end;
 perform save_my_interests(array[(select id from industries order by id limit 1)]);
 insert into feedback(student_id,clarity_before,clarity_after,nps,comment) values(auth.uid(),2,4,8,'Transactional test');
 insert into saved_opportunities(student_id,opportunity_id) select auth.uid(),id from opportunities limit 1;
 if (select count(*) from saved_opportunities)<>1 then raise exception 'Save failed'; end if;
end $$;
reset role;
select set_config('request.jwt.claim.sub',current_setting('nexus.test_b'),true);
set local role authenticated;
do $$ begin
 if exists(select 1 from student_skills) or exists(select 1 from feedback) or exists(select 1 from saved_opportunities) or exists(select 1 from student_interests) then raise exception 'Private data leaked to user B'; end if;
 if (select count(*) from profiles)<>1 then raise exception 'User B profile isolation failed'; end if;
end $$;
reset role;
set local role anon;
do $$ begin
 begin
  perform * from profiles;
  raise exception 'Anonymous profile access allowed';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
select 'PASS: isolation, role protection, atomic skills, interests, saved opportunities, feedback, anonymous denial' as result;
rollback;
