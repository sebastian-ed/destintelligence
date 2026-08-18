# Destintelligence V5.6 Simple · Junín de los Andes

Aplicación de inteligencia turística para equipos municipales. La operación diaria sigue siendo simple: preparar el estudio, registrar entrevistas y revisar resultados. La metodología, la calidad de campo, el análisis y la administración quedan disponibles sin recargar la interfaz.

## Supabase ya conectado

Esta entrega ya incluye en `config.js` el proyecto indicado:

- Proyecto: `dnnlbqnppxlmstneawrw`
- URL: `https://dnnlbqnppxlmstneawrw.supabase.co`
- Clave: publishable/public key

La clave incluida es pública. **Nunca agregues la `service_role` al navegador.**

## Base de datos

Si ya ejecutaste `SUPABASE-INSTALACION-COMPLETA.sql` en la versión anterior, **no vuelvas a ejecutarlo**.

Para una instalación completamente nueva, el archivo consolidado sigue siendo:

`SUPABASE-INSTALACION-COMPLETA.sql`

## Gestión de usuarios

V5.6 permite desde la pantalla **Usuarios**:

- agregar o invitar usuarios;
- reconocer un correo que ya existe en Supabase Auth y darle acceso sin duplicarlo;
- editar nombre, correo, rol y destino;
- habilitar y deshabilitar accesos;
- eliminar usuarios;
- impedir que un administrador modifique al responsable principal;
- impedir que se elimine/deshabilite el último responsable principal;
- impedir que una persona se elimine a sí misma accidentalmente.

Estas operaciones de Auth deben ejecutarse en servidor. Por seguridad usan la Edge Function:

`supabase/functions/admin-users/index.ts`

## Activar la gestión de usuarios una sola vez

La app web ya está lista, pero la Edge Function debe publicarse en tu proyecto Supabase.

### Opción A · Supabase Dashboard

1. Entrá a tu proyecto Supabase.
2. Abrí **Edge Functions**.
3. Creá/desplegá una función llamada exactamente `admin-users`.
4. Usá el contenido de `supabase/functions/admin-users/index.ts`.
5. Desactivá la verificación JWT del gateway para esta función (`verify_jwt = false`). La propia función valida la sesión del usuario y sus permisos antes de hacer cualquier cambio.

### Opción B · Supabase CLI

Desde esta carpeta:

```bash
npx supabase login
npx supabase link --project-ref dnnlbqnppxlmstneawrw
npx supabase functions deploy admin-users --no-verify-jwt
```

También podés usar `DESPLEGAR-FUNCION-USUARIOS.ps1` en Windows.

## Recuperación de contraseña

En **Supabase → Authentication → URL Configuration** mantené:

- Site URL: `https://sebastian-ed.github.io/destintelligence/`
- Redirect URL: `https://sebastian-ed.github.io/destintelligence/`

El login incluye **¿Olvidaste tu contraseña?** y el flujo para elegir una contraseña nueva.

## Publicar en GitHub Pages

Reemplazá los archivos de la versión anterior por los de esta carpeta. Los scripts llevan versión `5.6.0` para reducir problemas de caché.
