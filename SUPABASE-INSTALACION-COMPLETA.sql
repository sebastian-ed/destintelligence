-- DESTINTELLIGENCE V5.7 · INSTALACIÓN COMPLETA PARA SUPABASE
create extension if not exists pgcrypto;

create table if not exists public.organizations(
 id uuid primary key default gen_random_uuid(),
 name text not null,
 plan text not null default 'standard',
 created_at timestamptz not null default now()
);

create table if not exists public.destinations(
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 name text not null,
 province text,
 country text not null default 'Argentina',
 population integer,
 created_at timestamptz not null default now()
);

create table if not exists public.organization_members(
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 full_name text not null,
 email text,
 role text not null check(role in('owner','admin','analyst','field')),
 destination_id uuid references public.destinations(id) on delete set null,
 status text not null default 'active' check(status in('active','disabled','invited')),
 unique(organization_id,user_id)
);

create table if not exists public.studies(
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 destination_id uuid not null references public.destinations(id) on delete cascade,
 name text not null,
 universe_definition text not null,
 sampling_method text not null check(sampling_method in('systematic_intercept','simple_random','stratified','quota','convenience','open_link')),
 population_size integer,
 confidence_level numeric(4,3) not null default .95,
 target_margin_error numeric(4,3) not null default .05,
 target_sample_size integer not null,
 min_subgroup_n integer not null default 100,
 intercept_every integer not null default 3,
 design_notes text,
 questionnaire_config jsonb not null default '{}'::jsonb,
 status text not null default 'active',
 start_date date not null,
 end_date date not null,
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now()
);

create table if not exists public.survey_questions(
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 destination_id uuid not null references public.destinations(id) on delete cascade,
 study_id uuid not null references public.studies(id) on delete cascade,
 text text not null,
 type text not null check(type in('single','multi','yesno','scale','number','text')),
 options jsonb not null default '[]',
 required boolean not null default false,
 section text not null default 'extra' check(section in('context','journey','experience','opportunity','extra')),
 help_text text,
 active boolean not null default true,
 position integer not null,
 condition jsonb,
 created_at timestamptz not null default now()
);

create table if not exists public.visitor_records(
 id uuid primary key default gen_random_uuid(),
 client_id uuid not null unique,
 organization_id uuid not null references public.organizations(id) on delete cascade,
 destination_id uuid not null references public.destinations(id) on delete cascade,
 study_id uuid not null references public.studies(id) on delete restrict,
 visited_at timestamptz not null,
 field_point text not null,
 time_band text,
 selection_method text,

 -- screener / clasificación
 origin_country text,
 origin_province text,
 origin_city text,
 residence_area text,
 usual_commuter boolean,
 visitor_type text,

 -- perfil
 age_range text,
 gender text,
 party_type text,
 party_size integer default 1,
 children_count integer default 0,

 -- viaje
 trip_purpose text,
 first_visit boolean,
 previous_visits integer,
 overnight boolean,
 nights integer,
 accommodation text,
 motivations text[] not null default '{}',
 primary_driver text,
 alternative_destination text,
 planning_lead text,
 transport_mode text,
 info_channels text[] not null default '{}',
 primary_info_channel text,
 booking_channel text,

 -- comportamiento territorial
 activities text[] not null default '{}',
 primary_activity text,
 neighborhoods text[] not null default '{}',
 main_neighborhood text,
 missed_neighborhood text,
 missed_neighborhood_reason text,

 -- gasto por persona/día
 spend_currency text default 'USD',
 spend_accommodation numeric(14,2),
 spend_food numeric(14,2),
 spend_transport numeric(14,2),
 spend_activities numeric(14,2),
 spend_culture numeric(14,2),
 spend_shopping numeric(14,2),
 spend_other numeric(14,2),

 -- experiencia
 importance_factors text[] not null default '{}',
 satisfaction jsonb not null default '{}',
 recommend_score smallint check(recommend_score between 0 and 10),
 revisit_score smallint check(revisit_score between 0 and 10),
 overall_satisfaction smallint check(overall_satisfaction between 0 and 10),
 preferred_season text,

 -- fricciones
 problems text[] not null default '{}',
 main_problem text,
 problem_severity smallint check(problem_severity between 0 and 10),
 blocked_action boolean,
 lost_purchase boolean,

 -- demanda insatisfecha / monetización
 has_unmet_need boolean,
 unmet_category text,
 unmet_need_text text,
 unmet_reason text,
 unmet_importance smallint check(unmet_importance between 0 and 10),
 would_pay text,
 expected_solution text,
 expected_price numeric(14,2),
 expected_price_currency text,
 could_extend_stay boolean,
 stay_extension_driver text,

 -- concept test opcional
 concept_name text,
 concept_interest smallint check(concept_interest between 0 and 10),
 concept_purchase smallint check(concept_purchase between 0 and 10),

 field_observation text,
 survey_answers jsonb not null default '{}',
 latitude double precision,
 longitude double precision,
 gps_accuracy_m numeric,
 duration_seconds integer,
 created_by uuid not null references auth.users(id),
 source text not null default 'field' check(source in('field','historical','api')),
 created_at timestamptz not null default now()
);

create table if not exists public.field_events(
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 destination_id uuid not null references public.destinations(id) on delete cascade,
 study_id uuid not null references public.studies(id) on delete cascade,
 outcome text not null check(outcome in('refused','abandoned','not_eligible')),
 field_point text not null,
 time_band text,
 created_by uuid not null references auth.users(id),
 event_at timestamptz not null default now()
);

create table if not exists public.coverage_targets(
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 destination_id uuid not null references public.destinations(id) on delete cascade,
 study_id uuid not null references public.studies(id) on delete cascade,
 field_point text not null,
 time_band text not null default 'all_day',
 target_n integer not null check(target_n > 0),
 created_at timestamptz not null default now()
);

create table if not exists public.destination_branding(
 destination_id uuid primary key references public.destinations(id) on delete cascade,
 organization_id uuid not null references public.organizations(id) on delete cascade,
 institution_name text not null,
 primary_color text not null default '#315d4d',
 footer text,
 logo_url text,
 updated_at timestamptz not null default now()
);

create table if not exists public.public_snapshots(
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete cascade,
 destination_id uuid not null references public.destinations(id) on delete cascade,
 study_id uuid references public.studies(id) on delete set null,
 slug text not null unique,
 published boolean not null default false,
 payload jsonb not null,
 updated_at timestamptz not null default now()
);

create or replace function public.current_org_ids()
returns setof uuid language sql stable security definer set search_path=public
as $$ select organization_id from public.organization_members where user_id=auth.uid() and status='active' $$;

create or replace function public.current_role(target_org uuid)
returns text language sql stable security definer set search_path=public
as $$ select role from public.organization_members where user_id=auth.uid() and organization_id=target_org and status='active' limit 1 $$;


-- ============================================================================
-- AUTOALTA SEGURA DEL PRIMER RESPONSABLE
-- ============================================================================
-- Esta función se usa sólo cuando todavía NO existe ningún miembro activo.
-- El primer usuario autenticado que ingresa queda asociado como owner.
-- Una vez inicializada la organización, la función ya no otorga acceso a otros usuarios.
create or replace function public.ensure_destintelligence_initial_owner()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_email text;
  v_full_name text;
  v_org_id uuid;
  v_destination_id uuid;
  v_study_id uuid;
  v_active_members integer;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'reason', 'not_authenticated');
  end if;

  if exists (
    select 1 from public.organization_members
    where user_id = v_uid and status = 'active'
  ) then
    return jsonb_build_object('ok', true, 'reason', 'already_member');
  end if;

  select count(*) into v_active_members
  from public.organization_members
  where status = 'active';

  -- Seguridad: sólo se auto-inicializa una instalación que todavía no tiene dueño.
  if v_active_members > 0 then
    return jsonb_build_object('ok', false, 'reason', 'organization_already_initialized');
  end if;

  select email,
         coalesce(nullif(raw_user_meta_data->>'full_name',''), split_part(email,'@',1), email, 'Administrador')
    into v_email, v_full_name
    from auth.users
   where id = v_uid;

  if v_email is null then
    return jsonb_build_object('ok', false, 'reason', 'auth_user_not_found');
  end if;

  select id into v_org_id
    from public.organizations
   where name = 'Municipalidad de Junín de los Andes'
   order by created_at asc
   limit 1;

  if v_org_id is null then
    insert into public.organizations(name, plan)
    values('Municipalidad de Junín de los Andes', 'standard')
    returning id into v_org_id;
  end if;

  select id into v_destination_id
    from public.destinations
   where organization_id = v_org_id
     and name = 'Junín de los Andes'
   order by created_at asc
   limit 1;

  if v_destination_id is null then
    insert into public.destinations(organization_id, name, province, country)
    values(v_org_id, 'Junín de los Andes', 'Neuquén', 'Argentina')
    returning id into v_destination_id;
  end if;

  insert into public.organization_members(
    organization_id, user_id, full_name, email, role, destination_id, status
  ) values(
    v_org_id, v_uid, v_full_name, v_email, 'owner', v_destination_id, 'active'
  )
  on conflict(organization_id, user_id) do update set
    full_name = excluded.full_name,
    email = excluded.email,
    role = 'owner',
    destination_id = excluded.destination_id,
    status = 'active';

  insert into public.destination_branding(
    destination_id, organization_id, institution_name, primary_color, footer
  ) values(
    v_destination_id, v_org_id,
    'Secretaría de Turismo · Junín de los Andes',
    '#315d4d',
    'Junín de los Andes · Neuquén · Argentina'
  )
  on conflict(destination_id) do update set
    organization_id = excluded.organization_id,
    institution_name = excluded.institution_name,
    updated_at = now();

  select id into v_study_id
    from public.studies
   where organization_id = v_org_id
     and destination_id = v_destination_id
   order by created_at asc
   limit 1;

  if v_study_id is null then
    insert into public.studies(
      organization_id, destination_id, name, universe_definition,
      sampling_method, confidence_level, target_margin_error,
      target_sample_size, min_subgroup_n, intercept_every,
      design_notes, status, start_date, end_date, created_by
    ) values(
      v_org_id, v_destination_id,
      'Estudio de demanda turística · Junín de los Andes',
      'Visitantes de Junín de los Andes durante el período de relevamiento.',
      'systematic_intercept', 0.95, 0.05,
      400, 80, 3,
      'Configuración inicial sugerida por Destintelligence. Puede editarse desde la aplicación.',
      'active', current_date, (current_date + interval '1 year')::date, v_uid
    ) returning id into v_study_id;
  end if;

  return jsonb_build_object(
    'ok', true,
    'reason', 'bootstrapped',
    'organization_id', v_org_id,
    'destination_id', v_destination_id,
    'study_id', v_study_id
  );
end;
$$;

revoke all on function public.ensure_destintelligence_initial_owner() from public;
grant execute on function public.ensure_destintelligence_initial_owner() to authenticated;

alter table public.organizations enable row level security;
alter table public.destinations enable row level security;
alter table public.organization_members enable row level security;
alter table public.studies enable row level security;
alter table public.survey_questions enable row level security;
alter table public.visitor_records enable row level security;
alter table public.field_events enable row level security;
alter table public.coverage_targets enable row level security;
alter table public.destination_branding enable row level security;
alter table public.public_snapshots enable row level security;

drop policy if exists org_read on public.organizations;
create policy org_read on public.organizations for select to authenticated using(id in(select public.current_org_ids()));
drop policy if exists dest_read on public.destinations;
create policy dest_read on public.destinations for select to authenticated using(organization_id in(select public.current_org_ids()));
drop policy if exists member_read on public.organization_members;
create policy member_read on public.organization_members for select to authenticated
using(
  organization_id in(select public.current_org_ids())
  and (
    user_id = auth.uid()
    or public.current_role(organization_id) in ('owner','admin','analyst')
  )
);
drop policy if exists studies_read on public.studies;
create policy studies_read on public.studies for select to authenticated using(organization_id in(select public.current_org_ids()));
drop policy if exists q_read on public.survey_questions;
create policy q_read on public.survey_questions for select to authenticated using(organization_id in(select public.current_org_ids()));
drop policy if exists visitor_read on public.visitor_records;
create policy visitor_read on public.visitor_records for select to authenticated
using(
  organization_id in(select public.current_org_ids())
  and (
    public.current_role(organization_id) in ('owner','admin','analyst')
    or created_by = auth.uid()
  )
);
drop policy if exists events_read on public.field_events;
create policy events_read on public.field_events for select to authenticated
using(
  organization_id in(select public.current_org_ids())
  and (
    public.current_role(organization_id) in ('owner','admin','analyst')
    or created_by = auth.uid()
  )
);
drop policy if exists coverage_read on public.coverage_targets;
create policy coverage_read on public.coverage_targets for select to authenticated using(organization_id in(select public.current_org_ids()));
drop policy if exists brand_read on public.destination_branding;
create policy brand_read on public.destination_branding for select to authenticated using(organization_id in(select public.current_org_ids()));

drop policy if exists studies_write on public.studies;
create policy studies_write on public.studies for all to authenticated
using(organization_id in(select public.current_org_ids()) and public.current_role(organization_id) in('owner','admin','analyst'))
with check(organization_id in(select public.current_org_ids()) and public.current_role(organization_id) in('owner','admin','analyst'));

drop policy if exists q_write on public.survey_questions;
create policy q_write on public.survey_questions for all to authenticated
using(organization_id in(select public.current_org_ids()) and public.current_role(organization_id) in('owner','admin','analyst'))
with check(organization_id in(select public.current_org_ids()) and public.current_role(organization_id) in('owner','admin','analyst'));

drop policy if exists visitor_insert on public.visitor_records;
create policy visitor_insert on public.visitor_records for insert to authenticated
with check(organization_id in(select public.current_org_ids()) and created_by=auth.uid());

drop policy if exists event_insert on public.field_events;
create policy event_insert on public.field_events for insert to authenticated
with check(organization_id in(select public.current_org_ids()) and created_by=auth.uid());

drop policy if exists coverage_write on public.coverage_targets;
create policy coverage_write on public.coverage_targets for all to authenticated
using(organization_id in(select public.current_org_ids()) and public.current_role(organization_id) in('owner','admin','analyst'))
with check(organization_id in(select public.current_org_ids()) and public.current_role(organization_id) in('owner','admin','analyst'));

drop policy if exists brand_write on public.destination_branding;
create policy brand_write on public.destination_branding for all to authenticated
using(organization_id in(select public.current_org_ids()) and public.current_role(organization_id) in('owner','admin'))
with check(organization_id in(select public.current_org_ids()) and public.current_role(organization_id) in('owner','admin'));

drop policy if exists snapshots_private on public.public_snapshots;
create policy snapshots_private on public.public_snapshots for select to authenticated
using(
  organization_id in(select public.current_org_ids())
  and public.current_role(organization_id) in ('owner','admin','analyst')
);
drop policy if exists snapshots_write on public.public_snapshots;
create policy snapshots_write on public.public_snapshots for all to authenticated
using(organization_id in(select public.current_org_ids()) and public.current_role(organization_id) in('owner','admin','analyst'))
with check(organization_id in(select public.current_org_ids()) and public.current_role(organization_id) in('owner','admin','analyst'));
drop policy if exists snapshots_public on public.public_snapshots;
create policy snapshots_public on public.public_snapshots for select to anon using(published=true);

insert into storage.buckets(id,name,public) values('branding','branding',true) on conflict(id) do nothing;
drop policy if exists "branding insert authenticated" on storage.objects;
create policy "branding insert authenticated" on storage.objects for insert to authenticated with check(bucket_id='branding');
drop policy if exists "branding public read" on storage.objects;
create policy "branding public read" on storage.objects for select to public using(bucket_id='branding');

create index if not exists idx_dest_org on public.destinations(organization_id);
create index if not exists idx_members_org_user on public.organization_members(organization_id,user_id);
create index if not exists idx_studies_org_dest on public.studies(organization_id,destination_id);
create index if not exists idx_visitors_study_date on public.visitor_records(organization_id,destination_id,study_id,visited_at);
create index if not exists idx_visitors_type on public.visitor_records(study_id,visitor_type);
create index if not exists idx_visitors_unmet on public.visitor_records(study_id,has_unmet_need,unmet_category);
create index if not exists idx_events_study_date on public.field_events(study_id,event_at);
create index if not exists idx_coverage_study on public.coverage_targets(study_id,field_point,time_band);


-- ============================================================================
-- CONFIGURACIÓN INICIAL DE JUNÍN DE LOS ANDES
-- ============================================================================
-- FLUJO MÁS SIMPLE:
-- 1) Creá UN primer usuario en Supabase > Authentication > Users.
-- 2) Ejecutá TODO este archivo en SQL Editor.
-- 3) Si existe un solo usuario, se lo configura automáticamente como OWNER.
--
-- Solo si tu proyecto ya tiene MÁS DE UN usuario, escribí abajo el correo del
-- administrador en v_admin_email. Si hay uno solo, dejalo en NULL.

do $destintelligence_bootstrap$
declare
  v_admin_email text := null; -- Ej.: 'turismo@junindelosandes.gov.ar' solo si hay varios usuarios.
  v_organization_name text := 'Municipalidad de Junín de los Andes';
  v_destination_name text := 'Junín de los Andes';
  v_province text := 'Neuquén';
  v_country text := 'Argentina';
  v_user_id uuid;
  v_user_email text;
  v_org_id uuid;
  v_destination_id uuid;
  v_study_id uuid;
  v_full_name text;
  v_user_count integer;
begin
  select count(*) into v_user_count from auth.users;

  if v_admin_email is not null and btrim(v_admin_email) <> '' then
    select id, email,
           coalesce(nullif(raw_user_meta_data->>'full_name',''), split_part(email,'@',1), email)
      into v_user_id, v_user_email, v_full_name
      from auth.users
     where lower(email) = lower(v_admin_email)
     order by created_at asc
     limit 1;
  elsif v_user_count = 1 then
    select id, email,
           coalesce(nullif(raw_user_meta_data->>'full_name',''), split_part(email,'@',1), email)
      into v_user_id, v_user_email, v_full_name
      from auth.users
     order by created_at asc
     limit 1;
  end if;

  if v_user_id is null then
    if v_user_count = 0 then
      raise notice 'DESTINTELLIGENCE: base creada. Falta crear el primer usuario en Authentication. Después volvé a ejecutar este mismo SQL.';
    else
      raise notice 'DESTINTELLIGENCE: hay % usuarios en Authentication. Indicá el correo correcto en v_admin_email y volvé a ejecutar este SQL.', v_user_count;
    end if;
  else
    select id into v_org_id
      from public.organizations
     where name = v_organization_name
     order by created_at asc
     limit 1;

    if v_org_id is null then
      insert into public.organizations(name, plan)
      values(v_organization_name, 'standard')
      returning id into v_org_id;
    end if;

    select id into v_destination_id
      from public.destinations
     where organization_id = v_org_id
       and name = v_destination_name
     order by created_at asc
     limit 1;

    if v_destination_id is null then
      insert into public.destinations(organization_id, name, province, country)
      values(v_org_id, v_destination_name, v_province, v_country)
      returning id into v_destination_id;
    end if;

    insert into public.organization_members(
      organization_id, user_id, full_name, email, role, destination_id, status
    ) values(
      v_org_id, v_user_id, coalesce(v_full_name, v_user_email, 'Administrador'), v_user_email,
      'owner', v_destination_id, 'active'
    )
    on conflict(organization_id, user_id) do update set
      full_name = excluded.full_name,
      email = excluded.email,
      role = 'owner',
      destination_id = excluded.destination_id,
      status = 'active';

    insert into public.destination_branding(
      destination_id, organization_id, institution_name, primary_color, footer
    ) values(
      v_destination_id, v_org_id,
      'Secretaría de Turismo · Junín de los Andes',
      '#315d4d',
      'Junín de los Andes · Neuquén · Argentina'
    )
    on conflict(destination_id) do update set
      organization_id = excluded.organization_id,
      institution_name = excluded.institution_name,
      updated_at = now();

    -- Deja un estudio inicial listo para empezar. Si ya existe uno, no duplica.
    select id into v_study_id
      from public.studies
     where organization_id = v_org_id
       and destination_id = v_destination_id
     order by created_at asc
     limit 1;

    if v_study_id is null then
      insert into public.studies(
        organization_id, destination_id, name, universe_definition,
        sampling_method, confidence_level, target_margin_error,
        target_sample_size, min_subgroup_n, intercept_every,
        design_notes, status, start_date, end_date, created_by
      ) values(
        v_org_id, v_destination_id,
        'Estudio de demanda turística · Junín de los Andes',
        'Visitantes de Junín de los Andes durante el período de relevamiento.',
        'systematic_intercept', 0.95, 0.05,
        400, 80, 3,
        'Configuración inicial sugerida por Destintelligence. Puede editarse desde la aplicación.',
        'active', current_date, (current_date + interval '1 year')::date, v_user_id
      ) returning id into v_study_id;
    end if;

    raise notice 'DESTINTELLIGENCE listo. Administrador: %, destino: %, estudio inicial creado/configurado.', v_user_email, v_destination_name;
  end if;
end
$destintelligence_bootstrap$;

-- Verificación rápida: al finalizar deberías ver estas tablas en public:
-- organizations, destinations, organization_members, studies, survey_questions,
-- visitor_records, field_events, coverage_targets, destination_branding,
-- public_snapshots.
