-- DESTINTELLIGENCE V5.7
-- Ejecutar UNA sola vez en Supabase > SQL Editor sobre una instalación existente.
-- No elimina datos. Ajusta únicamente permisos de lectura para el rol Encuestador.

-- Encuestador: sólo puede ver su propia membresía.
-- Responsable principal / Admin / Analista: pueden ver los miembros de la organización.
drop policy if exists member_read on public.organization_members;
create policy member_read on public.organization_members for select to authenticated
using(
  organization_id in(select public.current_org_ids())
  and (
    user_id = auth.uid()
    or public.current_role(organization_id) in ('owner','admin','analyst')
  )
);

-- Encuestador: sólo puede leer las entrevistas que él mismo cargó.
-- Los roles superiores pueden analizar el conjunto completo.
drop policy if exists visitor_read on public.visitor_records;
create policy visitor_read on public.visitor_records for select to authenticated
using(
  organization_id in(select public.current_org_ids())
  and (
    public.current_role(organization_id) in ('owner','admin','analyst')
    or created_by = auth.uid()
  )
);

-- Igual criterio para rechazos / abandonos / eventos de campo.
drop policy if exists events_read on public.field_events;
create policy events_read on public.field_events for select to authenticated
using(
  organization_id in(select public.current_org_ids())
  and (
    public.current_role(organization_id) in ('owner','admin','analyst')
    or created_by = auth.uid()
  )
);

-- El dashboard privado no se expone al Encuestador.
drop policy if exists snapshots_private on public.public_snapshots;
create policy snapshots_private on public.public_snapshots for select to authenticated
using(
  organization_id in(select public.current_org_ids())
  and public.current_role(organization_id) in ('owner','admin','analyst')
);

-- Las políticas de escritura ya existentes se conservan:
-- * Encuestador puede insertar sus propias entrevistas/eventos.
-- * Analista puede gestionar estudios/preguntas/resultados.
-- * Owner/Admin administran usuarios y marca.
