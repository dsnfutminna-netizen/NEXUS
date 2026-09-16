begin;
select set_config('request.jwt.claim.sub',gen_random_uuid()::text,true);
select set_config('request.jwt.claims',json_build_object('sub',current_setting('request.jwt.claim.sub'),'email','right@example.invalid','role','authenticated')::text,true);
insert into auth.users(id,email) values(current_setting('request.jwt.claim.sub')::uuid,'right@example.invalid');
set local role authenticated;
do $$ begin
 begin
  insert into profiles(id,email,full_name) values(auth.uid(),'wrong@example.invalid','Fixture');
  raise exception 'Impersonation allowed';
 exception when insufficient_privilege then null; end;
 insert into profiles(id,email,full_name) values(auth.uid(),'right@example.invalid','Fixture');
 begin
  insert into events(student_id,event_type) values(auth.uid(),'no_consent');
  raise exception 'Nonconsenting analytics allowed';
 exception when insufficient_privilege then null; end;
 update profiles set data_consent=true where id=auth.uid();
 insert into events(student_id,event_type) values(auth.uid(),'consented');
end $$;
reset role;
select 'PASS: email identity enforced and consent gates analytics' as result;
rollback;
