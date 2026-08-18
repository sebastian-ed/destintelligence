# Destintelligence V5.8 · Gestión, auditoría y backups

Aplicación de inteligencia turística para equipos municipales. Mantiene la operación diaria simple, pero agrega una capa institucional de gestión: estudios, entrevistas, trazabilidad, exportaciones y respaldos.

## Supabase ya conectado

`config.js` ya contiene el proyecto solicitado:

- Project ref: `dnnlbqnppxlmstneawrw`
- URL: `https://dnnlbqnppxlmstneawrw.supabase.co`
- Publishable key configurada

La publishable key es pública y puede estar en el frontend. **Nunca coloques la `service_role` en GitHub, `config.js` ni ningún archivo del navegador.**

## Si ya tenés V5.7 funcionando

No reinstales la base.

1. En **Supabase → SQL Editor**, ejecutá una vez `ACTUALIZAR-GESTION-AUDITORIA-V5.8.sql`.
2. Volvé a desplegar `admin-users` para que la administración de usuarios también escriba en el historial.
3. Reemplazá en GitHub los archivos anteriores por esta versión.
4. Esperá el deploy de GitHub Pages y hacé `Ctrl + F5`.

## Si instalás desde cero

Ejecutá solamente:

`SUPABASE-INSTALACION-COMPLETA.sql`

No hace falta ejecutar migraciones anteriores.

## Gestión de datos

### Entrevistas / cuestionarios cargados

Responsable principal, Administrador y Analista pueden:

- abrir una entrevista individual;
- editarla indicando obligatoriamente el motivo;
- seleccionar una, varias, una página o todos los resultados filtrados;
- exportar la selección en CSV, Excel o PDF;
- eliminar definitivamente una selección mediante motivo + palabra `ELIMINAR`.

El Encuestador dispone de **Mis entrevistas** y puede abrir y corregir únicamente registros creados por él. Toda corrección exige motivo y deja trazabilidad.

### Estudios

Responsable principal, Administrador y Analista pueden:

- editar metodología, nombre, período y parámetros;
- archivar y reactivar;
- ver sus entrevistas;
- descargar un respaldo del estudio;
- seleccionar varios estudios;
- eliminar definitivamente con confirmación fuerte.

Archivar conserva todos los datos y es la opción recomendada cuando termina una temporada.

### Preguntas

La gestión de cuestionario mantiene editar, reordenar, duplicar, ocultar/restaurar y agrega eliminación definitiva de preguntas personalizadas. Los cambios quedan auditados.

### Historial

Registra, entre otros:

- usuario;
- correo;
- fecha y hora;
- acción;
- entidad afectada;
- motivo;
- información anterior y posterior.

Incluye entrevistas, estudios, preguntas, usuarios, cobertura, eventos de campo, marca, publicaciones, exportaciones y backups.

### Backups

**Backup completo** descarga un JSON con la información de la organización: estudios, preguntas, entrevistas, eventos, cobertura, usuarios, marca, publicaciones e historial.

Recomendación: hacer un backup al cerrar una temporada y antes de cualquier eliminación masiva.

## Edge Function de usuarios

La gestión de Supabase Auth se realiza mediante:

`supabase/functions/admin-users/index.ts`

Para desplegarla desde una terminal en esta carpeta:

```bash
npx supabase login
npx supabase link --project-ref dnnlbqnppxlmstneawrw
npx supabase functions deploy admin-users --no-verify-jwt
```

También está `DESPLEGAR-FUNCION-USUARIOS.ps1` para Windows.

## Recuperación de contraseña

En **Supabase → Authentication → URL Configuration** usá:

- Site URL: `https://sebastian-ed.github.io/destintelligence/`
- Redirect URL: `https://sebastian-ed.github.io/destintelligence/`

## Exportaciones

- **CSV:** preparado para abrir correctamente en Excel con configuración regional que usa `;` como separador.
- **Excel:** hoja de entrevistas + hoja de información del exportable.
- **PDF:** ficha detallada para una entrevista y documento tabular paginado para múltiples entrevistas.
- **JSON:** estudios y backups completos.

Las librerías de Excel/PDF se cargan desde CDN; si no estuvieran disponibles, la app conserva alternativas de exportación cuando es posible.
