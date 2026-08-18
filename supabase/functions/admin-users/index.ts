import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-supabase-api-version",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (value: unknown, status = 200) =>
  new Response(JSON.stringify(value), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

const validRoles = new Set(["owner", "admin", "analyst", "field"]);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Método no permitido" }, 405);

  try {
    const authHeader = req.headers.get("Authorization") || "";
    const token = authHeader.replace(/^Bearer\s+/i, "").trim();
    if (!token) return json({ error: "Sesión no válida" }, 401);

    const url = Deno.env.get("SUPABASE_URL");
    const anon = Deno.env.get("SUPABASE_ANON_KEY");
    const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!url || !anon || !service) return json({ error: "Faltan variables del servidor" }, 500);

    const caller = createClient(url, anon, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const admin = createClient(url, service, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: userData, error: userError } = await caller.auth.getUser(token);
    const user = userData?.user;
    if (userError || !user) return json({ error: "Sesión vencida o inválida" }, 401);

    const body = await req.json().catch(() => ({}));
    const organizationId = String(body.organization_id || "");
    if (!organizationId) return json({ error: "Falta la organización" }, 400);

    const { data: callerMember, error: memberError } = await admin
      .from("organization_members")
      .select("id,user_id,role,status")
      .eq("organization_id", organizationId)
      .eq("user_id", user.id)
      .eq("status", "active")
      .maybeSingle();

    if (memberError) return json({ error: memberError.message }, 400);
    if (!callerMember || !["owner", "admin"].includes(callerMember.role)) {
      return json({ error: "No tenés permiso para gestionar usuarios" }, 403);
    }

    const requireOwnerForOwnerRole = (_role: string) => {
      // Owner y Admin son gestores. Cualquiera de los dos puede asignar roles.
      // La continuidad se controla por cantidad de gestores activos, no por exigir un owner permanente.
    };

    const getTarget = async (userId: string) => {
      const { data, error } = await admin
        .from("organization_members")
        .select("*")
        .eq("organization_id", organizationId)
        .eq("user_id", userId)
        .maybeSingle();
      if (error) throw new Error(error.message);
      if (!data) throw new Error("Usuario no encontrado en esta organización");
      if (callerMember.role === "admin" && data.role === "owner") {
        throw new Error("Un administrador no puede modificar al responsable principal");
      }
      return data;
    };

    const ensureManagerContinuity = async (target: any, nextRole?: string, nextStatus?: string, deleting = false) => {
      const managerRoles = new Set(["owner", "admin"]);
      const isManagerNow = managerRoles.has(target.role) && target.status === "active";
      const nextIsManager = !deleting && managerRoles.has(nextRole || target.role) && (nextStatus || target.status) === "active";
      if (!isManagerNow || nextIsManager) return;
      const { data, error } = await admin
        .from("organization_members")
        .select("user_id,role,status")
        .eq("organization_id", organizationId)
        .eq("status", "active")
        .in("role", ["owner", "admin"])
        .neq("user_id", target.user_id);
      if (error) throw new Error(error.message);
      if (!data?.length) throw new Error("Debe quedar al menos un Responsable principal o Administrador activo en la organización");
    };

    if (body.action === "invite") {
      const email = String(body.email || "").trim().toLowerCase();
      const fullName = String(body.full_name || "").trim();
      const role = String(body.role || "field");
      const destinationId = body.destination_id || null;
      if (!email || !fullName) return json({ error: "Completá nombre y correo" }, 400);
      if (!validRoles.has(role)) return json({ error: "Rol inválido" }, 400);
      requireOwnerForOwnerRole(role);

      let authUser: any = null;
      for (let page = 1; page <= 10 && !authUser; page++) {
        const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 1000 });
        if (error) throw new Error(error.message);
        authUser = data.users.find((u) => (u.email || "").toLowerCase() === email) || null;
        if (data.users.length < 1000) break;
      }

      if (!authUser) {
        const { data, error } = await admin.auth.admin.inviteUserByEmail(email, {
          data: { full_name: fullName },
        });
        if (error) throw new Error(error.message);
        authUser = data.user;
      } else {
        await admin.auth.admin.updateUserById(authUser.id, {
          user_metadata: { ...(authUser.user_metadata || {}), full_name: fullName },
        });
      }

      const { data: membership, error: membershipError } = await admin
        .from("organization_members")
        .upsert(
          {
            organization_id: organizationId,
            user_id: authUser.id,
            full_name: fullName,
            email,
            role,
            destination_id: destinationId,
            status: "active",
          },
          { onConflict: "organization_id,user_id" },
        )
        .select()
        .single();
      if (membershipError) throw new Error(membershipError.message);
      return json({ membership, existing_auth_user: !!authUser.last_sign_in_at });
    }

    if (body.action === "update") {
      const userId = String(body.user_id || "");
      const target = await getTarget(userId);
      const email = String(body.email || target.email || "").trim().toLowerCase();
      const fullName = String(body.full_name || target.full_name || "").trim();
      const role = String(body.role || target.role);
      const destinationId = body.destination_id || null;
      if (!validRoles.has(role)) return json({ error: "Rol inválido" }, 400);
      requireOwnerForOwnerRole(role);
      await ensureManagerContinuity(target, role, target.status, false);

      const authChanges: Record<string, unknown> = {
        user_metadata: { full_name: fullName },
      };
      if (email && email !== target.email) authChanges.email = email;
      const { error: authError } = await admin.auth.admin.updateUserById(userId, authChanges);
      if (authError) throw new Error(authError.message);

      const { data: membership, error } = await admin
        .from("organization_members")
        .update({ full_name: fullName, email, role, destination_id: destinationId })
        .eq("organization_id", organizationId)
        .eq("user_id", userId)
        .select()
        .single();
      if (error) throw new Error(error.message);
      return json({ membership });
    }

    if (body.action === "set_status") {
      const userId = String(body.user_id || "");
      const status = body.status === "active" ? "active" : "disabled";
      if (userId === user.id) return json({ error: "No podés deshabilitar tu propio usuario" }, 400);
      const target = await getTarget(userId);
      await ensureManagerContinuity(target, target.role, status, false);
      const { data: membership, error } = await admin
        .from("organization_members")
        .update({ status })
        .eq("organization_id", organizationId)
        .eq("user_id", userId)
        .select()
        .single();
      if (error) throw new Error(error.message);
      return json({ membership });
    }

    if (body.action === "delete") {
      const userId = String(body.user_id || "");
      if (userId === user.id) return json({ error: "No podés eliminar tu propio usuario" }, 400);
      const target = await getTarget(userId);
      await ensureManagerContinuity(target, undefined, undefined, true);

      const { error: deleteMembershipError } = await admin
        .from("organization_members")
        .delete()
        .eq("organization_id", organizationId)
        .eq("user_id", userId);
      if (deleteMembershipError) throw new Error(deleteMembershipError.message);

      // Si no pertenece a otra organización, se desactiva también su cuenta Auth mediante soft delete.
      // Así se conserva la trazabilidad de registros históricos que referencian su UUID.
      const { count: otherMemberships } = await admin
        .from("organization_members")
        .select("id", { count: "exact", head: true })
        .eq("user_id", userId);
      let authDeleted = false;
      let authWarning: string | null = null;
      if (!otherMemberships) {
        const { error: authDeleteError } = await admin.auth.admin.deleteUser(userId, true);
        if (authDeleteError) authWarning = authDeleteError.message;
        else authDeleted = true;
      }
      return json({ ok: true, auth_deleted: authDeleted, warning: authWarning });
    }

    return json({ error: "Acción desconocida" }, 400);
  } catch (error) {
    console.error(error);
    return json({ error: error instanceof Error ? error.message : String(error) }, 400);
  }
});
