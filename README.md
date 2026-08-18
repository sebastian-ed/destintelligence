# Destintelligence V5.7 · Junín de los Andes

Versión enfocada en facilidad de uso, gestión de usuarios y separación real de permisos.

## Roles

- **Responsable principal:** acceso total.
- **Administrador:** acceso total operativo y gestión de usuarios.
- **Analista:** estudios, cuestionarios, calidad, resultados, oportunidades, segmentos, importación, informes y publicación. No administra usuarios ni marca.
- **Encuestador:** Inicio + Registrar entrevista. No accede a resultados ni administración. En Supabase sólo puede leer las entrevistas/eventos que él mismo cargó.

## Gestión de usuarios

La pantalla Usuarios permite crear/invitar, editar, cambiar rol, habilitar/deshabilitar y eliminar accesos.

V5.7 permite pasar un Responsable principal a Administrador. La regla de seguridad ya no exige conservar un Owner: exige que quede al menos un **Responsable principal o Administrador activo**.

Las operaciones Auth se realizan con la Edge Function `admin-users`; la `service_role` nunca se expone en el navegador.

## Actualizar una instalación V5.6 existente

1. Reemplazar en GitHub los archivos de la app por los de V5.7.
2. Ejecutar **ACTUALIZAR-PERMISOS-V5.7.sql** una sola vez en Supabase > SQL Editor.
3. Volver a desplegar la Edge Function:

```powershell
npx supabase login
npx supabase link --project-ref dnnlbqnppxlmstneawrw
npx supabase functions deploy admin-users --no-verify-jwt
```

También se incluye `DESPLEGAR-FUNCION-USUARIOS.ps1`.

## Instalación nueva

Ejecutar únicamente `SUPABASE-INSTALACION-COMPLETA.sql` y desplegar `admin-users`.

## Supabase configurado

`config.js` ya contiene la URL y publishable key pública del proyecto proporcionado para esta instalación.
