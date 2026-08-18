-- DESTINTELLIGENCE V5.8 · INSTALACIÓN COMPLETA PARA SUPABASE
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


-- ============================================================================
-- CAPA V5.8 · GESTIÓN Y AUDITORÍA
-- ============================================================================
-- DESTINTELLIGENCE V5.8 · GESTIÓN, AUDITORÍA Y BACKUPS
-- Capa V5.8 integrada en la instalación completa.
-- En una instalación nueva, este bloque se ejecuta como parte de este único archivo; no requiere migraciones separadas.

create table if not exists public.audit_logs(
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null,
 destination_id uuid,
 study_id uuid,
 actor_user_id uuid,
 actor_email text,
 entity_type text not null,
 entity_id text,
 action text not null,
 reason text,
 before_data jsonb,
 after_data jsonb,
 metadata jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now()
);

alter table public.studies add column if not exists updated_at timestamptz;
alter table public.studies add column if not exists updated_by uuid;
alter table public.studies add column if not exists last_edit_reason text;
alter table public.studies add column if not exists archived_at timestamptz;

alter table public.visitor_records add column if not exists updated_at timestamptz;
alter table public.visitor_records add column if not exists updated_by uuid;
alter table public.visitor_records add column if not exists last_edit_reason text;

alter table public.survey_questions add column if not exists updated_at timestamptz;
alter table public.survey_questions add column if not exists updated_by uuid;
alter table public.survey_questions add column if not exists last_edit_reason text;

create index if not exists idx_audit_org_date on public.audit_logs(organization_id,created_at desc);
create index if not exists idx_audit_entity on public.audit_logs(entity_type,entity_id,created_at desc);
create index if not exists idx_audit_study on public.audit_logs(study_id,created_at desc);

alter table public.audit_logs enable row level security;

drop policy if exists audit_read on public.audit_logs;
create policy audit_read on public.audit_logs for select to authenticated
using(
 organization_id in(select public.current_org_ids())
 and public.current_role(organization_id) in ('owner','admin','analyst')
);

-- La escritura de auditoría se hace mediante funciones controladas, no directamente desde el navegador.
drop policy if exists audit_insert on public.audit_logs;

create or replace function public.record_audit_event(
 p_organization_id uuid,
 p_destination_id uuid,
 p_study_id uuid,
 p_entity_type text,
 p_entity_id text,
 p_action text,
 p_reason text default null,
 p_before_data jsonb default null,
 p_after_data jsonb default null,
 p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
 v_uid uuid := auth.uid();
 v_id uuid;
 v_email text;
begin
 if v_uid is null then raise exception 'Sesión no válida'; end if;
 if not exists(select 1 from public.organization_members where organization_id=p_organization_id and user_id=v_uid and status='active') then
  raise exception 'No pertenecés a esta organización';
 end if;
 select email into v_email from auth.users where id=v_uid;
 insert into public.audit_logs(
  organization_id,destination_id,study_id,actor_user_id,actor_email,
  entity_type,entity_id,action,reason,before_data,after_data,metadata
 ) values(
  p_organization_id,p_destination_id,p_study_id,v_uid,v_email,
  p_entity_type,p_entity_id,p_action,nullif(btrim(coalesce(p_reason,'')),''),p_before_data,p_after_data,coalesce(p_metadata,'{}'::jsonb)
 ) returning id into v_id;
 return v_id;
end $$;

revoke all on function public.record_audit_event(uuid,uuid,uuid,text,text,text,text,jsonb,jsonb,jsonb) from public;
grant execute on function public.record_audit_event(uuid,uuid,uuid,text,text,text,text,jsonb,jsonb,jsonb) to authenticated;

create or replace function public.audit_destintelligence_change()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare
 v_old jsonb := case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) else null end;
 v_new jsonb := case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) else null end;
 v_source jsonb := coalesce(v_new,v_old);
 v_org uuid := nullif(v_source->>'organization_id','')::uuid;
 v_dest uuid := nullif(v_source->>'destination_id','')::uuid;
 v_study uuid := case when tg_table_name='studies' then nullif(v_source->>'id','')::uuid else nullif(v_source->>'study_id','')::uuid end;
 v_reason text := coalesce(nullif(coalesce(v_new->>'last_edit_reason',''),''),nullif(current_setting('destintelligence.audit_reason',true),''));
 v_email text;
 v_action text := lower(tg_op);
begin
 if tg_op='UPDATE' and tg_argv[0]='study' then
  if coalesce(old.status,'') <> coalesce(new.status,'') and new.status='archived' then v_action:='archive';
  elsif coalesce(old.status,'')='archived' and coalesce(new.status,'')<>'archived' then v_action:='restore';
  end if;
 end if;
 if auth.uid() is not null then select email into v_email from auth.users where id=auth.uid(); end if;
 insert into public.audit_logs(
  organization_id,destination_id,study_id,actor_user_id,actor_email,
  entity_type,entity_id,action,reason,before_data,after_data
 ) values(
  v_org,v_dest,v_study,auth.uid(),v_email,
  tg_argv[0],v_source->>'id',v_action,v_reason,v_old,v_new
 );
 return case when tg_op='DELETE' then old else new end;
end $$;

-- Estudios: registrar cambios y archivado. La eliminación definitiva se registra en su RPC específica.
drop trigger if exists trg_audit_studies_update on public.studies;
create trigger trg_audit_studies_update after insert or update on public.studies
for each row execute function public.audit_destintelligence_change('study');

-- Preguntas: cualquier alta/cambio/baja queda en historial.
drop trigger if exists trg_audit_questions on public.survey_questions;
create trigger trg_audit_questions after insert or update or delete on public.survey_questions
for each row execute function public.audit_destintelligence_change('question');

-- Entrevistas: las correcciones quedan registradas con usuario, hora, antes/después y motivo.
drop trigger if exists trg_audit_visitors_update on public.visitor_records;
create trigger trg_audit_visitors_update after insert or update on public.visitor_records
for each row execute function public.audit_destintelligence_change('interview');

-- Permitir correcciones. El Encuestador sólo puede corregir entrevistas propias y debe enviar motivo.
drop policy if exists visitor_update on public.visitor_records;
create policy visitor_update on public.visitor_records for update to authenticated
using(
 organization_id in(select public.current_org_ids())
 and (
  public.current_role(organization_id) in ('owner','admin','analyst')
  or created_by=auth.uid()
 )
)
with check(
 organization_id in(select public.current_org_ids())
 and (
  public.current_role(organization_id) in ('owner','admin','analyst')
  or (
   created_by=auth.uid()
   and updated_by=auth.uid()
   and nullif(btrim(coalesce(last_edit_reason,'')),'') is not null
  )
 )
);

-- Evitar DELETE directo de estudios/preguntas desde el cliente. Se usan RPC con confirmación fuerte.
drop policy if exists studies_write on public.studies;
drop policy if exists studies_insert on public.studies;
drop policy if exists studies_update on public.studies;
create policy studies_insert on public.studies for insert to authenticated
with check(organization_id in(select public.current_org_ids()) and public.current_role(organization_id) in('owner','admin','analyst'));
create policy studies_update on public.studies for update to authenticated
using(organization_id in(select public.current_org_ids()) and public.current_role(organization_id) in('owner','admin','analyst'))
with check(organization_id in(select public.current_org_ids()) and public.current_role(organization_id) in('owner','admin','analyst'));

drop policy if exists q_write on public.survey_questions;
drop policy if exists q_insert on public.survey_questions;
drop policy if exists q_update on public.survey_questions;
create policy q_insert on public.survey_questions for insert to authenticated
with check(organization_id in(select public.current_org_ids()) and public.current_role(organization_id) in('owner','admin','analyst'));
create policy q_update on public.survey_questions for update to authenticated
using(organization_id in(select public.current_org_ids()) and public.current_role(organization_id) in('owner','admin','analyst'))
with check(organization_id in(select public.current_org_ids()) and public.current_role(organization_id) in('owner','admin','analyst'));

create or replace function public.hard_delete_interviews(
 p_ids uuid[],
 p_reason text,
 p_confirmation text
)
returns integer
language plpgsql
security definer
set search_path=public
as $$
declare
 v_uid uuid:=auth.uid();
 v_org uuid;
 v_dest uuid;
 v_study uuid;
 v_count integer;
 v_email text;
 v_role text;
begin
 if p_confirmation <> 'ELIMINAR' then raise exception 'Confirmación incorrecta'; end if;
 if nullif(btrim(coalesce(p_reason,'')),'') is null then raise exception 'Debés indicar el motivo'; end if;
 if coalesce(array_length(p_ids,1),0)=0 then raise exception 'No seleccionaste entrevistas'; end if;
 select organization_id,destination_id,study_id into v_org,v_dest,v_study from public.visitor_records where id=any(p_ids) limit 1;
 if v_org is null then return 0; end if;
 v_role:=public.current_role(v_org);
 if v_role not in ('owner','admin','analyst') then raise exception 'No tenés permiso para eliminar entrevistas'; end if;
 select email into v_email from auth.users where id=v_uid;
 select count(*) into v_count from public.visitor_records where id=any(p_ids) and organization_id=v_org;
 -- Guardar una fotografía de cada entrevista antes de borrarla.
 insert into public.audit_logs(organization_id,destination_id,study_id,actor_user_id,actor_email,entity_type,entity_id,action,reason,before_data,metadata)
 select r.organization_id,r.destination_id,r.study_id,v_uid,v_email,'interview',r.id::text,'delete',p_reason,to_jsonb(r),jsonb_build_object('bulk',true)
 from public.visitor_records r where r.id=any(p_ids) and r.organization_id=v_org;
 insert into public.audit_logs(organization_id,destination_id,study_id,actor_user_id,actor_email,entity_type,entity_id,action,reason,before_data,metadata)
 values(v_org,v_dest,v_study,v_uid,v_email,'interview',null,'delete_bulk',p_reason,null,jsonb_build_object('count',v_count,'ids',to_jsonb(p_ids)));
 delete from public.visitor_records where id=any(p_ids) and organization_id=v_org;
 return v_count;
end $$;

revoke all on function public.hard_delete_interviews(uuid[],text,text) from public;
grant execute on function public.hard_delete_interviews(uuid[],text,text) to authenticated;

create or replace function public.hard_delete_question(
 p_id uuid,
 p_reason text,
 p_confirmation text
)
returns boolean
language plpgsql
security definer
set search_path=public
as $$
declare
 v_q public.survey_questions%rowtype;
 v_role text;
begin
 if p_confirmation <> 'ELIMINAR' then raise exception 'Confirmación incorrecta'; end if;
 if nullif(btrim(coalesce(p_reason,'')),'') is null then raise exception 'Debés indicar el motivo'; end if;
 select * into v_q from public.survey_questions where id=p_id;
 if not found then return false; end if;
 v_role:=public.current_role(v_q.organization_id);
 if v_role not in ('owner','admin','analyst') then raise exception 'No tenés permiso'; end if;
 perform set_config('destintelligence.audit_reason',coalesce(p_reason,''),true);
 delete from public.survey_questions where id=p_id;
 return true;
end $$;

revoke all on function public.hard_delete_question(uuid,text,text) from public;
grant execute on function public.hard_delete_question(uuid,text,text) to authenticated;

create or replace function public.hard_delete_studies(
 p_ids uuid[],
 p_reason text,
 p_confirmation text
)
returns integer
language plpgsql
security definer
set search_path=public
as $$
declare
 v_uid uuid:=auth.uid();
 v_org uuid;
 v_dest uuid;
 v_count integer;
 v_interviews integer;
 v_email text;
 v_role text;
begin
 if p_confirmation <> 'ELIMINAR' then raise exception 'Confirmación incorrecta'; end if;
 if nullif(btrim(coalesce(p_reason,'')),'') is null then raise exception 'Debés indicar el motivo'; end if;
 if coalesce(array_length(p_ids,1),0)=0 then raise exception 'No seleccionaste estudios'; end if;
 select organization_id,destination_id into v_org,v_dest from public.studies where id=any(p_ids) limit 1;
 if v_org is null then return 0; end if;
 v_role:=public.current_role(v_org);
 if v_role not in ('owner','admin','analyst') then raise exception 'No tenés permiso para eliminar estudios'; end if;
 select email into v_email from auth.users where id=v_uid;
 perform set_config('destintelligence.audit_reason',p_reason,true);
 select count(*) into v_count from public.studies where id=any(p_ids) and organization_id=v_org;
 select count(*) into v_interviews from public.visitor_records where study_id=any(p_ids) and organization_id=v_org;
 -- Guardar cada estudio antes de eliminarlo para que el historial sobreviva al borrado.
 insert into public.audit_logs(organization_id,destination_id,study_id,actor_user_id,actor_email,entity_type,entity_id,action,reason,before_data,metadata)
 select s.organization_id,s.destination_id,s.id,v_uid,v_email,'study',s.id::text,'delete',p_reason,to_jsonb(s),jsonb_build_object('bulk',true,'interview_count',(select count(*) from public.visitor_records r where r.study_id=s.id))
 from public.studies s where s.id=any(p_ids) and s.organization_id=v_org;
 insert into public.audit_logs(organization_id,destination_id,actor_user_id,actor_email,entity_type,action,reason,metadata)
 values(v_org,v_dest,v_uid,v_email,'study','delete_bulk',p_reason,jsonb_build_object('study_count',v_count,'interview_count',v_interviews,'ids',to_jsonb(p_ids)));

 delete from public.visitor_records where study_id=any(p_ids) and organization_id=v_org;
 delete from public.field_events where study_id=any(p_ids) and organization_id=v_org;
 delete from public.coverage_targets where study_id=any(p_ids) and organization_id=v_org;
 delete from public.public_snapshots where study_id=any(p_ids) and organization_id=v_org;
 delete from public.survey_questions where study_id=any(p_ids) and organization_id=v_org;
 delete from public.studies where id=any(p_ids) and organization_id=v_org;
 return v_count;
end $$;

revoke all on function public.hard_delete_studies(uuid[],text,text) from public;
grant execute on function public.hard_delete_studies(uuid[],text,text) to authenticated;

-- Mantener audit_logs aunque se elimine un estudio/usuario: deliberadamente no tiene FKs a esas entidades.



-- Movimientos operativos adicionales: también quedan trazados.
drop trigger if exists trg_audit_field_events on public.field_events;
create trigger trg_audit_field_events after insert or update or delete on public.field_events
for each row execute function public.audit_destintelligence_change('field_event');

drop trigger if exists trg_audit_coverage on public.coverage_targets;
create trigger trg_audit_coverage after insert or update or delete on public.coverage_targets
for each row execute function public.audit_destintelligence_change('coverage');

drop trigger if exists trg_audit_branding on public.destination_branding;
create trigger trg_audit_branding after insert or update or delete on public.destination_branding
for each row execute function public.audit_destintelligence_change('branding');

drop trigger if exists trg_audit_public_snapshots on public.public_snapshots;
create trigger trg_audit_public_snapshots after insert or update or delete on public.public_snapshots
for each row execute function public.audit_destintelligence_change('snapshot');
