create extension if not exists pgcrypto;

create table if not exists public.schools (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  city text,
  territory text,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.teachers (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null unique references auth.users (id) on delete cascade,
  full_name text,
  email text,
  school_id uuid references public.schools (id) on delete set null,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.classes (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools (id) on delete cascade,
  teacher_id uuid not null references public.teachers (id) on delete cascade,
  grade text not null,
  class_name text not null,
  school_year text not null,
  student_count integer,
  weekly_lessons text,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.talp_sessions (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes (id) on delete cascade,
  teacher_id uuid not null references public.teachers (id) on delete cascade,
  inducer_term text not null,
  status text not null default 'draft' check (status in ('draft', 'open', 'closed')),
  qr_token text not null unique default encode(gen_random_bytes(12), 'hex'),
  created_at timestamptz not null default timezone('utc', now()),
  closed_at timestamptz
);

create table if not exists public.talp_responses (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.talp_sessions (id) on delete cascade,
  evoked_words text[] not null,
  desired_learning text,
  rarely_in_classes text,
  barriers text,
  created_at timestamptz not null default timezone('utc', now()),
  constraint talp_responses_evoked_words_size check (coalesce(array_length(evoked_words, 1), 0) = 5)
);

create index if not exists idx_schools_created_by on public.schools (created_by);
create index if not exists idx_teachers_auth_user_id on public.teachers (auth_user_id);
create index if not exists idx_classes_teacher_id on public.classes (teacher_id);
create index if not exists idx_talp_sessions_teacher_id on public.talp_sessions (teacher_id);
create index if not exists idx_talp_sessions_class_id on public.talp_sessions (class_id);
create index if not exists idx_talp_sessions_qr_token on public.talp_sessions (qr_token);
create index if not exists idx_talp_responses_session_id on public.talp_responses (session_id);

create or replace function public.get_my_teacher_id()
returns uuid
language sql
stable
as $$
  select id
  from public.teachers
  where auth_user_id = auth.uid()
  limit 1;
$$;

create or replace function public.get_public_talp_session(p_token text)
returns table (
  session_id uuid,
  inducer_term text,
  status text,
  school_name text,
  grade text,
  class_name text
)
language sql
security definer
set search_path = public
as $$
  select
    ts.id as session_id,
    ts.inducer_term,
    ts.status,
    s.name as school_name,
    c.grade,
    c.class_name
  from public.talp_sessions ts
  join public.classes c on c.id = ts.class_id
  join public.schools s on s.id = c.school_id
  where ts.qr_token = p_token
  limit 1;
$$;

create or replace function public.submit_talp_response(
  p_token text,
  p_evoked_words text[],
  p_desired_learning text default null,
  p_rarely_in_classes text default null,
  p_barriers text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session_id uuid;
  v_response_id uuid;
begin
  if coalesce(array_length(p_evoked_words, 1), 0) <> 5 then
    raise exception 'A resposta TALP precisa conter exatamente 5 palavras.';
  end if;

  select id
    into v_session_id
  from public.talp_sessions
  where qr_token = p_token
    and status = 'open'
  limit 1;

  if v_session_id is null then
    raise exception 'Sessao TALP inexistente ou fechada.';
  end if;

  insert into public.talp_responses (
    session_id,
    evoked_words,
    desired_learning,
    rarely_in_classes,
    barriers
  )
  values (
    v_session_id,
    p_evoked_words,
    nullif(trim(p_desired_learning), ''),
    nullif(trim(p_rarely_in_classes), ''),
    nullif(trim(p_barriers), '')
  )
  returning id into v_response_id;

  return v_response_id;
end;
$$;

grant execute on function public.get_public_talp_session(text) to anon, authenticated;
grant execute on function public.submit_talp_response(text, text[], text, text, text) to anon, authenticated;

alter table public.schools enable row level security;
alter table public.teachers enable row level security;
alter table public.classes enable row level security;
alter table public.talp_sessions enable row level security;
alter table public.talp_responses enable row level security;

drop policy if exists "teachers_select_own" on public.teachers;
create policy "teachers_select_own"
on public.teachers
for select
to authenticated
using (auth.uid() = auth_user_id);

drop policy if exists "teachers_insert_own" on public.teachers;
create policy "teachers_insert_own"
on public.teachers
for insert
to authenticated
with check (auth.uid() = auth_user_id);

drop policy if exists "teachers_update_own" on public.teachers;
create policy "teachers_update_own"
on public.teachers
for update
to authenticated
using (auth.uid() = auth_user_id)
with check (auth.uid() = auth_user_id);

drop policy if exists "schools_select_owned" on public.schools;
create policy "schools_select_owned"
on public.schools
for select
to authenticated
using (
  created_by = auth.uid()
  or exists (
    select 1
    from public.classes c
    join public.teachers t on t.id = c.teacher_id
    where c.school_id = schools.id
      and t.auth_user_id = auth.uid()
  )
);

drop policy if exists "schools_insert_owned" on public.schools;
create policy "schools_insert_owned"
on public.schools
for insert
to authenticated
with check (created_by = auth.uid());

drop policy if exists "schools_update_owned" on public.schools;
create policy "schools_update_owned"
on public.schools
for update
to authenticated
using (created_by = auth.uid())
with check (created_by = auth.uid());

drop policy if exists "classes_select_teacher" on public.classes;
create policy "classes_select_teacher"
on public.classes
for select
to authenticated
using (
  exists (
    select 1
    from public.teachers t
    where t.id = classes.teacher_id
      and t.auth_user_id = auth.uid()
  )
);

drop policy if exists "classes_insert_teacher" on public.classes;
create policy "classes_insert_teacher"
on public.classes
for insert
to authenticated
with check (
  exists (
    select 1
    from public.teachers t
    where t.id = classes.teacher_id
      and t.auth_user_id = auth.uid()
  )
);

drop policy if exists "classes_update_teacher" on public.classes;
create policy "classes_update_teacher"
on public.classes
for update
to authenticated
using (
  exists (
    select 1
    from public.teachers t
    where t.id = classes.teacher_id
      and t.auth_user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.teachers t
    where t.id = classes.teacher_id
      and t.auth_user_id = auth.uid()
  )
);

drop policy if exists "talp_sessions_select_teacher" on public.talp_sessions;
create policy "talp_sessions_select_teacher"
on public.talp_sessions
for select
to authenticated
using (
  exists (
    select 1
    from public.teachers t
    where t.id = talp_sessions.teacher_id
      and t.auth_user_id = auth.uid()
  )
);

drop policy if exists "talp_sessions_insert_teacher" on public.talp_sessions;
create policy "talp_sessions_insert_teacher"
on public.talp_sessions
for insert
to authenticated
with check (
  exists (
    select 1
    from public.teachers t
    where t.id = talp_sessions.teacher_id
      and t.auth_user_id = auth.uid()
  )
);

drop policy if exists "talp_sessions_update_teacher" on public.talp_sessions;
create policy "talp_sessions_update_teacher"
on public.talp_sessions
for update
to authenticated
using (
  exists (
    select 1
    from public.teachers t
    where t.id = talp_sessions.teacher_id
      and t.auth_user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.teachers t
    where t.id = talp_sessions.teacher_id
      and t.auth_user_id = auth.uid()
  )
);

drop policy if exists "talp_responses_select_teacher" on public.talp_responses;
create policy "talp_responses_select_teacher"
on public.talp_responses
for select
to authenticated
using (
  exists (
    select 1
    from public.talp_sessions ts
    join public.teachers t on t.id = ts.teacher_id
    where ts.id = talp_responses.session_id
      and t.auth_user_id = auth.uid()
  )
);
