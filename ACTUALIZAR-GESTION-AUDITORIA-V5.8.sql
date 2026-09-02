-- DESTINTELLIGENCE V5.8 · GESTIÓN, AUDITORÍA Y BACKUPS
-- Ejecutar UNA sola vez en Supabase > SQL Editor sobre una instalación V5.7 existente.
-- No elimina datos existentes. Agrega trazabilidad, edición controlada y eliminación segura.

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
