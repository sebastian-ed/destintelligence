-- DESTINTELLIGENCE V5.5 · REPARACIÓN DE ACCESO DEL PRIMER USUARIO
--
-- CUÁNDO USAR ESTE ARCHIVO
-- Si podés iniciar sesión pero la app informa:
-- "El usuario no tiene una organización activa".
--
-- QUÉ HACE
-- 1. Crea una función segura de inicialización.
-- 2. NO borra usuarios ni datos.
-- 3. Si todavía no existe ningún miembro activo, el próximo usuario autenticado
--    que ingrese a Destintelligence se convierte en Owner de la instalación.
-- 4. Si la organización ya tiene miembros activos, NO otorga permisos automáticamente.
--
-- PASOS
-- A) Pegá TODO este archivo en Supabase > SQL Editor > Run.
-- B) Cerrá sesión en Destintelligence.
-- C) Volvé a ingresar con tu usuario.



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



-- Reparación inmediata cuando el proyecto tiene un único usuario de Authentication.
do $repair_single_user$
declare
  v_user_count integer;
  v_member_count integer;
  v_uid uuid;
  v_email text;
  v_name text;
  v_org uuid;
  v_dest uuid;
  v_study uuid;
begin
  select count(*) into v_user_count from auth.users;
  select count(*) into v_member_count from public.organization_members where status='active';

  if v_member_count = 0 and v_user_count = 1 then
    select id, email,
           coalesce(nullif(raw_user_meta_data->>'full_name',''), split_part(email,'@',1), email, 'Administrador')
      into v_uid, v_email, v_name
      from auth.users
     limit 1;

    select id into v_org from public.organizations
     where name='Municipalidad de Junín de los Andes'
     order by created_at asc limit 1;
    if v_org is null then
      insert into public.organizations(name,plan)
      values('Municipalidad de Junín de los Andes','standard') returning id into v_org;
    end if;

    select id into v_dest from public.destinations
     where organization_id=v_org and name='Junín de los Andes'
     order by created_at asc limit 1;
    if v_dest is null then
      insert into public.destinations(organization_id,name,province,country)
      values(v_org,'Junín de los Andes','Neuquén','Argentina') returning id into v_dest;
    end if;

    insert into public.organization_members(organization_id,user_id,full_name,email,role,destination_id,status)
    values(v_org,v_uid,v_name,v_email,'owner',v_dest,'active')
    on conflict(organization_id,user_id) do update set
      full_name=excluded.full_name,email=excluded.email,role='owner',destination_id=excluded.destination_id,status='active';

    insert into public.destination_branding(destination_id,organization_id,institution_name,primary_color,footer)
    values(v_dest,v_org,'Secretaría de Turismo · Junín de los Andes','#315d4d','Junín de los Andes · Neuquén · Argentina')
    on conflict(destination_id) do update set organization_id=excluded.organization_id,institution_name=excluded.institution_name,updated_at=now();

    select id into v_study from public.studies
     where organization_id=v_org and destination_id=v_dest
     order by created_at asc limit 1;
    if v_study is null then
      insert into public.studies(
        organization_id,destination_id,name,universe_definition,sampling_method,
        confidence_level,target_margin_error,target_sample_size,min_subgroup_n,
        intercept_every,design_notes,status,start_date,end_date,created_by
      ) values(
        v_org,v_dest,'Estudio de demanda turística · Junín de los Andes',
        'Visitantes de Junín de los Andes durante el período de relevamiento.',
        'systematic_intercept',0.95,0.05,400,80,3,
        'Configuración inicial sugerida por Destintelligence. Puede editarse desde la aplicación.',
        'active',current_date,(current_date + interval '1 year')::date,v_uid
      ) returning id into v_study;
    end if;

    raise notice 'DESTINTELLIGENCE: usuario % vinculado como Owner.', v_email;
  elsif v_member_count > 0 then
    raise notice 'DESTINTELLIGENCE: ya existe al menos un miembro activo. No se modificaron permisos.';
  else
    raise notice 'DESTINTELLIGENCE: hay % usuarios Auth. La V5.5 hará el autoalta del primer usuario que ingrese si todavía no existen miembros activos.', v_user_count;
  end if;
end
$repair_single_user$;

-- Diagnóstico opcional. Después de ejecutar, podés mirar estos resultados.
select
  (select count(*) from auth.users) as usuarios_auth,
  (select count(*) from public.organizations) as organizaciones,
  (select count(*) from public.organization_members where status='active') as miembros_activos,
  (select count(*) from public.destinations) as destinos;
