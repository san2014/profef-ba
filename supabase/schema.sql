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

create table if not exists public.teacher_evaluations (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null references public.teachers (id) on delete cascade,
  status text not null default 'draft' check (status in ('draft', 'completed')),
  title text,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.thematic_axes (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null unique,
  sort_order integer not null unique,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.axis_skills (
  id uuid primary key default gen_random_uuid(),
  axis_id uuid not null references public.thematic_axes (id) on delete cascade,
  description text not null,
  sort_order integer not null,
  created_at timestamptz not null default timezone('utc', now()),
  unique (axis_id, sort_order)
);

create table if not exists public.competencies (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  label text not null,
  description text not null,
  sort_order integer not null unique,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.competency_skills (
  id uuid primary key default gen_random_uuid(),
  competency_id uuid not null references public.competencies (id) on delete cascade,
  code text not null,
  description text not null,
  sort_order integer not null,
  created_at timestamptz not null default timezone('utc', now()),
  unique (competency_id, sort_order)
);

create index if not exists idx_schools_created_by on public.schools (created_by);
create index if not exists idx_teachers_auth_user_id on public.teachers (auth_user_id);
create index if not exists idx_classes_teacher_id on public.classes (teacher_id);
create index if not exists idx_talp_sessions_teacher_id on public.talp_sessions (teacher_id);
create index if not exists idx_talp_sessions_class_id on public.talp_sessions (class_id);
create index if not exists idx_talp_sessions_qr_token on public.talp_sessions (qr_token);
create index if not exists idx_talp_responses_session_id on public.talp_responses (session_id);
create index if not exists idx_teacher_evaluations_teacher_id on public.teacher_evaluations (teacher_id);
create index if not exists idx_axis_skills_axis_id on public.axis_skills (axis_id);
create index if not exists idx_thematic_axes_sort_order on public.thematic_axes (sort_order);
create index if not exists idx_competencies_sort_order on public.competencies (sort_order);
create index if not exists idx_competency_skills_competency_id on public.competency_skills (competency_id);

insert into public.thematic_axes (slug, name, sort_order)
values
  ('ginastica_exercicio_saude', 'Ginástica, Exercício e Saúde', 1),
  ('lutas_dancas', 'Lutas e Danças', 2),
  ('jogos_esportes', 'Jogos e Esportes', 3),
  ('esporte_adaptado', 'Esporte e Esporte Adaptado', 4),
  ('cultura_digital_praticas_alternativas', 'Cultura Digital e Práticas Alternativas', 5),
  ('esportes_radicais', 'Esportes Radicais', 6)
on conflict (slug) do update
set
  name = excluded.name,
  sort_order = excluded.sort_order;

insert into public.axis_skills (axis_id, description, sort_order)
select axis.id, skill.description, skill.sort_order
from public.thematic_axes axis
join (
  values
    ('ginastica_exercicio_saude', 'Ginástica geral e suas possibilidades na comunidade local.', 1),
    ('ginastica_exercicio_saude', 'Valências físicas.', 2),
    ('ginastica_exercicio_saude', 'Elementos e fundamentos da ginástica.', 3),
    ('ginastica_exercicio_saude', 'Tipos e realidades de ginástica.', 4),
    ('ginastica_exercicio_saude', 'Exercício físico e lazer.', 5),
    ('ginastica_exercicio_saude', 'Cuidados e benefícios do exercício físico.', 6),
    ('ginastica_exercicio_saude', 'Exercício físico e doenças hipocinéticas.', 7),
    ('lutas_dancas', 'Princípios, possibilidades e especificidades das artes marciais e dos esportes de combate.', 1),
    ('lutas_dancas', 'Lutas de origem indígena e capoeiras.', 2),
    ('lutas_dancas', 'Esportivização das lutas.', 3),
    ('lutas_dancas', 'Realidades e possibilidades das danças e expressões rítmicas na comunidade local.', 4),
    ('lutas_dancas', 'Tipos e características das danças.', 5),
    ('jogos_esportes', 'Jogos populares e cultura local.', 1),
    ('jogos_esportes', 'Origem das diversas modalidades esportivas e jogos presentes na comunidade local.', 2),
    ('jogos_esportes', 'Discriminações e preconceitos no âmbito esportivo.', 3),
    ('jogos_esportes', 'Jogos, esportes e lazer.', 4),
    ('jogos_esportes', 'Diversidade, características e classificação dos esportes.', 5),
    ('esporte_adaptado', 'Esportes adaptados.', 1),
    ('esporte_adaptado', 'Possibilidades e realidades esportivas da comunidade local.', 2),
    ('esporte_adaptado', 'Práticas esportivas no tempo livre.', 3),
    ('esporte_adaptado', 'Discriminação e violência no esporte.', 4),
    ('esporte_adaptado', 'Lesões na prática esportiva.', 5),
    ('esporte_adaptado', 'Esporte espetáculo e de alto rendimento.', 6),
    ('cultura_digital_praticas_alternativas', 'Práticas corporais com interação ou apropriação de tecnologias digitais.', 1),
    ('cultura_digital_praticas_alternativas', 'Jogos e esportes em games.', 2),
    ('cultura_digital_praticas_alternativas', 'Práticas corporais alternativas.', 3),
    ('cultura_digital_praticas_alternativas', 'Bem-estar e qualidade de vida.', 4),
    ('cultura_digital_praticas_alternativas', 'Estilo de vida ativo com tecnologias digitais.', 5),
    ('esportes_radicais', 'Esportes radicais urbanos.', 1),
    ('esportes_radicais', 'Práticas corporais de aventura na natureza.', 2),
    ('esportes_radicais', 'Primeiros socorros e prevenção de acidentes.', 3),
    ('esportes_radicais', 'Consciência corporal e postural.', 4),
    ('esportes_radicais', 'Esporte e estilo de vida.', 5)
) as skill(axis_slug, description, sort_order)
  on skill.axis_slug = axis.slug
on conflict (axis_id, sort_order) do update
set description = excluded.description;

insert into public.competencies (code, label, description, sort_order)
values
  (
    'Competência 1',
    'Valorizar conhecimentos historicamente construídos',
    'Valorizar e utilizar os conhecimentos historicamente construídos sobre o mundo físico, social, cultural e digital para entender e explicar a realidade, continuar aprendendo e colaborar para a construção de uma sociedade justa, democrática e inclusiva.',
    1
  ),
  (
    'Competência 2',
    'Exercitar a curiosidade intelectual',
    'Exercitar a curiosidade intelectual e recorrer à abordagem própria das ciências, incluindo a investigação, a reflexão, a análise crítica, a imaginação e a criatividade, para investigar causas, elaborar e testar hipóteses, formular e resolver problemas e criar soluções (inclusive tecnológicas) com base nos conhecimentos das diferentes áreas.',
    2
  ),
  (
    'Competência 5',
    'Compreender e criar tecnologias digitais',
    'Compreender, utilizar e criar tecnologias digitais de informação e comunicação de forma crítica, significativa, reflexiva e ética nas diversas práticas sociais (incluindo as escolares) para se comunicar, acessar e disseminar informações, produzir conhecimentos, resolver problemas e exercer protagonismo e autoria na vida pessoal e coletiva.',
    3
  ),
  (
    'Competência 7',
    'Argumentar com base em fatos, dados e informações confiáveis',
    'Argumentar com base em fatos, dados e informações confiáveis, para formular, negociar e defender ideias, pontos de vista e decisões comuns que respeitem e promovam os direitos humanos, a consciência socioambiental e o consumo responsável em âmbito local, regional e global, com posicionamento ético em relação ao cuidado de si mesmo, dos outros e do planeta.',
    4
  )
on conflict (code) do update
set
  label = excluded.label,
  description = excluded.description,
  sort_order = excluded.sort_order;

insert into public.competency_skills (competency_id, code, description, sort_order)
select c.id, skill.code, skill.description, skill.sort_order
from public.competencies c
join (
  values
    ('Competência 1', 'EM13LGG101', 'Compreender e analisar processos de produção e circulação de discursos, nas diferentes linguagens, para fazer escolhas fundamentadas em função de interesses pessoais e coletivos.', 1),
    ('Competência 1', 'EM13LGG102', 'Analisar visões de mundo, conflitos de interesse, preconceitos e ideologias presentes nos discursos veiculados nas diferentes mídias como forma de ampliar suas possibilidades de explicação e interpretação crítica da realidade.', 2),
    ('Competência 1', 'EM12EF01BA', 'Ampliar experimentações, interpretações e apropriações das manifestações da cultura corporal estabelecendo relações com a sociedade atual, a vida cotidiana, os equipamentos/espaços de lazer e o universo de possibilidades das práticas corporais existentes na realidade local.', 3),
    ('Competência 1', 'EM12EF02BA', 'Propiciar e consolidar oportunidades de uso e de reflexão acerca da leitura da gestualidade na comunidade local, reconhecendo as possibilidades e significados das práticas corporais conectadas às compreensões das circunstâncias sociais e ao posicionamento inclusivo e colaborativo.', 4),
    ('Competência 1', 'EM12EFBA03', 'Ampliar e aprofundar compreensões de conceitos e processos contemporâneos da virtualização e das representações das práticas corporais reconhecendo sua diversidade de possibilidade, experimentação, apropriação e reflexão.', 5),
    ('Competência 1', 'EM12EFBA04', 'Proporcionar oportunidades de vivências que contribuam para a consolidação e a ampliação de compreensões acerca das construções subjetivas da gestualidade desconstruindo preconceitos e aprofundando os processos de autoconhecimento e de reelaboração crítica das práticas corporais na construção de uma sociedade menos desigual.', 6),
    ('Competência 2', 'EM13LGG201', 'Utilizar as diversas linguagens (artísticas, corporais e verbais) em diferentes contextos, valorizando-as como fenômeno social, cultural, histórico, variável, heterogêneo e sensível aos contextos de uso.', 1),
    ('Competência 2', 'EM13LGG202', 'Analisar interesses, relações de poder e perspectivas de mundo nos discursos das diversas práticas de linguagem (artísticas, corporais e verbais), para compreender o modo como circulam, constituem-se e (re)produzem significação e ideologias.', 2),
    ('Competência 2', 'EM13LGG204', 'Dialogar e produzir entendimento mútuo, nas diversas linguagens (artísticas, corporais e verbais), com vistas ao interesse comum pautado em princípios e valores de equidade assentados na democracia e nos direitos humanos.', 3),
    ('Competência 2', 'EM12EF01BA', 'Ampliar experimentações, interpretações e apropriações das manifestações da cultura corporal estabelecendo relações com a sociedade atual, a vida cotidiana, os equipamentos/espaços de lazer e o universo de possibilidades das práticas corporais existentes na realidade local.', 4),
    ('Competência 2', 'EM12EF02BA', 'Propiciar e consolidar oportunidades de uso e de reflexão acerca da leitura da gestualidade na comunidade local, reconhecendo as possibilidades e significados das práticas corporais conectadas às compreensões das circunstâncias sociais e ao posicionamento inclusivo e colaborativo.', 5),
    ('Competência 2', 'EM12EFBA03', 'Ampliar e aprofundar compreensões de conceitos e processos contemporâneos da virtualização e das representações das práticas corporais reconhecendo sua diversidade de possibilidade, experimentação, apropriação e reflexão.', 6),
    ('Competência 2', 'EM12EFBA04', 'Proporcionar oportunidades de vivências que contribuam para a consolidação e a ampliação de compreensões acerca das construções subjetivas da gestualidade desconstruindo preconceitos e aprofundando os processos de autoconhecimento e de reelaboração crítica das práticas corporais na construção de uma sociedade menos desigual.', 7),
    ('Competência 5', 'EM13LGG502', 'Analisar criticamente preconceitos, estereótipos e relações de poder presentes nas práticas corporais, adotando posicionamento contrário a qualquer manifestação de injustiça e desrespeito a direitos humanos e valores democráticos.', 1),
    ('Competência 5', 'EM13LGG503', 'Vivenciar práticas corporais e significá-las em seu projeto de vida como forma de autoconhecimento, autocuidado com o corpo e com a saúde, socialização e entretenimento.', 2),
    ('Competência 5', 'EM12EF01BA', 'Ampliar experimentações, interpretações e apropriações das manifestações da cultura corporal estabelecendo relações com a sociedade atual, a vida cotidiana, os equipamentos/espaços de lazer e o universo de possibilidades das práticas corporais existentes na realidade local.', 3),
    ('Competência 5', 'EM12EF02BA', 'Propiciar e consolidar oportunidades de uso e de reflexão acerca da leitura da gestualidade na comunidade local, reconhecendo as possibilidades e significados das práticas corporais conectadas às compreensões das circunstâncias sociais e ao posicionamento inclusivo e colaborativo.', 4),
    ('Competência 5', 'EM12EFBA03', 'Ampliar e aprofundar compreensões de conceitos e processos contemporâneos da virtualização e das representações das práticas corporais reconhecendo sua diversidade de possibilidade, experimentação, apropriação e reflexão.', 5),
    ('Competência 5', 'EM12EFBA04', 'Proporcionar oportunidades de vivências que contribuam para a consolidação e a ampliação de compreensões acerca das construções subjetivas da gestualidade desconstruindo preconceitos e aprofundando os processos de autoconhecimento e de reelaboração crítica das práticas corporais na construção de uma sociedade menos desigual.', 6),
    ('Competência 7', 'EM13LGG701', 'Explorar tecnologias digitais da informação e comunicação (TDIC), compreendendo seus princípios e funcionalidades, e mobilizá-las de modo ético, responsável e adequado a práticas de linguagem em diferentes contextos.', 1),
    ('Competência 7', 'EM13LGG704', 'Apropriar-se criticamente de processos de pesquisa e busca de informação, por meio de ferramentas e dos novos formatos de produção e distribuição do conhecimento na cultura de rede.', 2),
    ('Competência 7', 'EM12EF01BA', 'Ampliar experimentações, interpretações e apropriações das manifestações da cultura corporal estabelecendo relações com a sociedade atual, a vida cotidiana, os equipamentos/espaços de lazer e o universo de possibilidades das práticas corporais existentes na realidade local.', 3),
    ('Competência 7', 'EM12EF02BA', 'Propiciar e consolidar oportunidades de uso e de reflexão acerca da leitura da gestualidade na comunidade local, reconhecendo as possibilidades e significados das práticas corporais conectadas às compreensões das circunstâncias sociais e ao posicionamento inclusivo e colaborativo.', 4),
    ('Competência 7', 'EM12EFBA03', 'Ampliar e aprofundar compreensões de conceitos e processos contemporâneos da virtualização e das representações das práticas corporais reconhecendo sua diversidade de possibilidade, experimentação, apropriação e reflexão.', 5),
    ('Competência 7', 'EM12EFBA04', 'Proporcionar oportunidades de vivências que contribuam para a consolidação e a ampliação de compreensões acerca das construções subjetivas da gestualidade desconstruindo preconceitos e aprofundando os processos de autoconhecimento e de reelaboração crítica das práticas corporais na construção de uma sociedade menos desigual.', 6)
) as skill(competency_code, code, description, sort_order)
  on skill.competency_code = c.code
on conflict (competency_id, sort_order) do update
set
  code = excluded.code,
  description = excluded.description;

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

create or replace function public.list_thematic_axes_with_skills()
returns table (
  axis_id uuid,
  axis_slug text,
  axis_name text,
  axis_sort_order integer,
  skills jsonb
)
language sql
stable
security definer
set search_path = public
as $$
  select
    ta.id as axis_id,
    ta.slug as axis_slug,
    ta.name as axis_name,
    ta.sort_order as axis_sort_order,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', sk.id,
          'description', sk.description,
          'sort_order', sk.sort_order
        )
        order by sk.sort_order
      ) filter (where sk.id is not null),
      '[]'::jsonb
    ) as skills
  from public.thematic_axes ta
  left join public.axis_skills sk on sk.axis_id = ta.id
  group by ta.id, ta.slug, ta.name, ta.sort_order
  order by ta.sort_order;
$$;

create or replace function public.list_competencies_with_skills()
returns table (
  competency_id uuid,
  code text,
  label text,
  description text,
  skills jsonb
)
language sql
stable
security definer
set search_path = public
as $$
  select
    c.id as competency_id,
    c.code,
    c.label,
    c.description,
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', sk.id,
          'code', sk.code,
          'description', sk.description,
          'sort_order', sk.sort_order
        )
        order by sk.sort_order
      ) filter (where sk.id is not null),
      '[]'::jsonb
    ) as skills
  from public.competencies c
  left join public.competency_skills sk on sk.competency_id = c.id
  group by c.id, c.code, c.label, c.description, c.sort_order
  order by c.sort_order;
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
grant execute on function public.list_thematic_axes_with_skills() to authenticated;
grant execute on function public.list_competencies_with_skills() to authenticated;

alter table public.schools enable row level security;
alter table public.teachers enable row level security;
alter table public.classes enable row level security;
alter table public.talp_sessions enable row level security;
alter table public.talp_responses enable row level security;
alter table public.teacher_evaluations enable row level security;
alter table public.thematic_axes enable row level security;
alter table public.axis_skills enable row level security;
alter table public.competencies enable row level security;
alter table public.competency_skills enable row level security;

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

drop policy if exists "teacher_evaluations_select_teacher" on public.teacher_evaluations;
create policy "teacher_evaluations_select_teacher"
on public.teacher_evaluations
for select
to authenticated
using (
  exists (
    select 1
    from public.teachers t
    where t.id = teacher_evaluations.teacher_id
      and t.auth_user_id = auth.uid()
  )
);

drop policy if exists "teacher_evaluations_insert_teacher" on public.teacher_evaluations;
create policy "teacher_evaluations_insert_teacher"
on public.teacher_evaluations
for insert
to authenticated
with check (
  exists (
    select 1
    from public.teachers t
    where t.id = teacher_evaluations.teacher_id
      and t.auth_user_id = auth.uid()
  )
);

drop policy if exists "teacher_evaluations_update_teacher" on public.teacher_evaluations;
create policy "teacher_evaluations_update_teacher"
on public.teacher_evaluations
for update
to authenticated
using (
  exists (
    select 1
    from public.teachers t
    where t.id = teacher_evaluations.teacher_id
      and t.auth_user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.teachers t
    where t.id = teacher_evaluations.teacher_id
      and t.auth_user_id = auth.uid()
  )
);

drop policy if exists "teacher_evaluations_delete_teacher" on public.teacher_evaluations;
create policy "teacher_evaluations_delete_teacher"
on public.teacher_evaluations
for delete
to authenticated
using (
  exists (
    select 1
    from public.teachers t
    where t.id = teacher_evaluations.teacher_id
      and t.auth_user_id = auth.uid()
  )
);

drop policy if exists "thematic_axes_select_authenticated" on public.thematic_axes;
create policy "thematic_axes_select_authenticated"
on public.thematic_axes
for select
to authenticated
using (true);

drop policy if exists "axis_skills_select_authenticated" on public.axis_skills;
create policy "axis_skills_select_authenticated"
on public.axis_skills
for select
to authenticated
using (true);

drop policy if exists "competencies_select_authenticated" on public.competencies;
create policy "competencies_select_authenticated"
on public.competencies
for select
to authenticated
using (true);

drop policy if exists "competency_skills_select_authenticated" on public.competency_skills;
create policy "competency_skills_select_authenticated"
on public.competency_skills
for select
to authenticated
using (true);
