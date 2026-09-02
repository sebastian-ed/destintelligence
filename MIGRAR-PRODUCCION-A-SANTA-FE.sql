-- DESTINTELLIGENCE · MIGRACIÓN DE PRODUCCIÓN A SANTA FE
-- Fecha: 2026-09-01
-- Objetivo:
--   1) Renombrar el destino existente Junín de los Andes -> Santa Fe sin cambiar UUID/FKs.
--   2) Corregir branding, estudio y preguntas que todavía muestran Junín.
--   3) Evitar que el auto-bootstrap vuelva a crear Junín.
--   4) No borrar entrevistas ni datos históricos.
--
-- Ejecutar UNA VEZ en Supabase > SQL Editor sobre la base de PRODUCCIÓN.

begin;

-- 1. Destino y organización existentes.
update public.destinations
set
  name = 'Santa Fe',
  province = 'Santa Fe',
  country = 'Argentina'
where lower(trim(name)) = lower('Junín de los Andes');

update public.organizations
set name = 'Municipalidad de Santa Fe'
where lower(trim(name)) = lower('Municipalidad de Junín de los Andes');

-- 2. Branding visible.
update public.destination_branding b
set
  institution_name = case
    when coalesce(b.institution_name,'') ilike '%Junín de los Andes%'
      then replace(b.institution_name, 'Junín de los Andes', 'Santa Fe')
    else b.institution_name
  end,
  footer = case
    when coalesce(b.footer,'') ilike '%Junín de los Andes%'
      then 'Santa Fe · Santa Fe · Argentina'
    else b.footer
  end,
  updated_at = now()
where b.destination_id in (
  select d.id
  from public.destinations d
  where lower(trim(d.name)) = lower('Santa Fe')
    and lower(coalesce(d.province,'')) = lower('Santa Fe')
);

-- 3. Textos persistidos en estudios y preguntas.
update public.studies s
set
  name = replace(s.name, 'Junín de los Andes', 'Santa Fe'),
  universe_definition = replace(s.universe_definition, 'Junín de los Andes', 'Santa Fe'),
  design_notes = case
    when s.design_notes is null then null
    else replace(s.design_notes, 'Junín de los Andes', 'Santa Fe')
  end
where s.destination_id in (
  select d.id from public.destinations d
  where lower(trim(d.name)) = lower('Santa Fe')
    and lower(coalesce(d.province,'')) = lower('Santa Fe')
);

update public.survey_questions q
set
  text = replace(q.text, 'Junín de los Andes', 'Santa Fe'),
  help_text = case
    when q.help_text is null then null
    else replace(q.help_text, 'Junín de los Andes', 'Santa Fe')
  end
where q.destination_id in (
  select d.id from public.destinations d
  where lower(trim(d.name)) = lower('Santa Fe')
    and lower(coalesce(d.province,'')) = lower('Santa Fe')
);

-- 4. Si existe un dashboard público viejo con texto de Junín, lo despublica.
--    No se borra: se puede regenerar desde la app con los datos ya corregidos.
update public.public_snapshots p
set published = false, updated_at = now()
where p.destination_id in (
  select d.id from public.destinations d
  where lower(trim(d.name)) = lower('Santa Fe')
    and lower(coalesce(d.province,'')) = lower('Santa Fe')
)
and p.payload::text ilike '%Junín de los Andes%';

-- 5. Corrige el auto-bootstrap persistido en la base.
--    Mantiene exactamente la misma lógica de seguridad; sólo cambia el destino inicial.
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
   where name = 'Municipalidad de Santa Fe'
   order by created_at asc
   limit 1;

  if v_org_id is null then
    insert into public.organizations(name, plan)
    values('Municipalidad de Santa Fe', 'standard')
    returning id into v_org_id;
  end if;

  select id into v_destination_id
    from public.destinations
   where organization_id = v_org_id
     and name = 'Santa Fe'
   order by created_at asc
   limit 1;

  if v_destination_id is null then
    insert into public.destinations(organization_id, name, province, country)
    values(v_org_id, 'Santa Fe', 'Santa Fe', 'Argentina')
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
    'Secretaría de Turismo · Santa Fe',
    '#315d4d',
    'Santa Fe · Santa Fe · Argentina'
  )
  on conflict(destination_id) do update set
    organization_id = excluded.organization_id,
    institution_name = excluded.institution_name,
    footer = excluded.footer,
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
      'Estudio de demanda turística · Santa Fe',
      'Visitantes de Santa Fe durante el período de relevamiento.',
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

commit;

-- VERIFICACIÓN
select id, organization_id, name, province, country
from public.destinations
order by created_at;

select d.name as destino, b.institution_name, b.footer
from public.destinations d
left join public.destination_branding b on b.destination_id = d.id
order by d.created_at;
