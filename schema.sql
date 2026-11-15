-- شغّل هذا الملف كاملاً في Supabase → SQL Editor

create table profiles(
  id uuid primary key references auth.users on delete cascade,
  name text not null,
  age int not null check (age between 18 and 99),
  gender text not null,
  bio text default '',
  photos text[] default '{}',
  created_at timestamptz default now());
alter table profiles enable row level security;
create policy "read profiles" on profiles for select to authenticated using (true);
create policy "insert own"   on profiles for insert to authenticated with check (id = auth.uid());
create policy "update own"   on profiles for update to authenticated using (id = auth.uid());

create table queue(user_id uuid primary key references auth.users on delete cascade, created_at timestamptz default now());
alter table queue enable row level security;  -- بدون سياسات: الوصول عبر الدوال فقط

create table chats(
  id uuid primary key default gen_random_uuid(),
  a uuid not null references auth.users, b uuid not null references auth.users,
  ended boolean default false, created_at timestamptz default now());
alter table chats enable row level security;
create policy "members read" on chats for select to authenticated using (auth.uid() in (a,b));

create table messages(
  id uuid primary key default gen_random_uuid(),
  chat_id uuid not null references chats on delete cascade,
  sender uuid not null references auth.users,
  kind text not null check (kind in ('text','image','voice','video')),
  body text, path text, viewed_at timestamptz,
  created_at timestamptz default now());
alter table messages enable row level security;
create policy "members read" on messages for select to authenticated
  using (exists(select 1 from chats c where c.id=chat_id and auth.uid() in (c.a,c.b)));
create policy "members send" on messages for insert to authenticated
  with check (sender=auth.uid() and exists(select 1 from chats c where c.id=chat_id and not c.ended and auth.uid() in (c.a,c.b)));

create table reports(
  id uuid primary key default gen_random_uuid(),
  reporter uuid not null references auth.users, reported uuid not null references auth.users,
  chat_id uuid references chats on delete set null, reason text,
  created_at timestamptz default now());
alter table reports enable row level security;
create policy "file report" on reports for insert to authenticated with check (reporter=auth.uid());
-- القراءة من لوحة Supabase فقط (Table Editor)

-- ========== المطابقة العشوائية ==========
create or replace function find_match() returns uuid
language plpgsql security definer set search_path=public as $$
declare me uuid := auth.uid(); other uuid; cid uuid;
begin
  select id into cid from chats where not ended and me in (a,b) limit 1;
  if cid is not null then return cid; end if;
  delete from queue where created_at < now() - interval '30 seconds';
  select q.user_id into other from queue q
   where q.user_id <> me
     and not exists(select 1 from reports r where (r.reporter=me and r.reported=q.user_id) or (r.reporter=q.user_id and r.reported=me))
   order by random() limit 1 for update skip locked;
  if other is null then
    insert into queue(user_id) values (me) on conflict (user_id) do update set created_at = now();
    return null;
  end if;
  delete from queue where user_id in (me, other);
  insert into chats(a,b) values (other, me) returning id into cid;
  return cid;
end $$;

create or replace function cancel_search() returns void
language sql security definer set search_path=public as $$ delete from queue where user_id=auth.uid() $$;

create or replace function leave_chat(cid uuid) returns void
language sql security definer set search_path=public as $$
  update chats set ended=true where id=cid and auth.uid() in (a,b) $$;

create or replace function mark_viewed(mid uuid) returns void
language sql security definer set search_path=public as $$
  update messages m set viewed_at=now()
   where m.id=mid and m.sender<>auth.uid() and m.kind='video'
     and exists(select 1 from chats c where c.id=m.chat_id and auth.uid() in (c.a,c.b)) $$;

-- ========== التخزين ==========
insert into storage.buckets(id,name,public) values ('media','media',true),('temp','temp',false) on conflict do nothing;

create policy "upload own folder" on storage.objects for insert to authenticated
  with check (bucket_id in ('media','temp') and (storage.foldername(name))[1]=auth.uid()::text);
create policy "delete own files" on storage.objects for delete to authenticated
  using (bucket_id in ('media','temp') and (storage.foldername(name))[1]=auth.uid()::text);
-- الفيديو المؤقت: يُقرأ فقط قبل أن يُشاهد
create policy "temp video once" on storage.objects for select to authenticated
  using (bucket_id='temp' and ((storage.foldername(name))[1]=auth.uid()::text or exists(
    select 1 from messages m join chats c on c.id=m.chat_id
    where m.path=storage.objects.name and m.viewed_at is null and auth.uid() in (c.a,c.b))));

-- ========== الوقت الحقيقي ==========
alter publication supabase_realtime add table messages, chats;
