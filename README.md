# Destintelligence V5.4 Simple · Junín de los Andes

Aplicación de inteligencia turística orientada a equipos municipales. La interfaz prioriza tres tareas: crear/preparar un estudio, registrar entrevistas y ver resultados. La metodología, los controles de calidad, la edición del cuestionario, la importación histórica, la segmentación y los hallazgos automáticos siguen disponibles sin recargar la operación diaria.

## Probar la demo

1. Abrí `index.html`.
2. Tocá **Abrir demo Junín de los Andes**.
3. La demo usa datos ficticios y no necesita Supabase.

También podés abrir directamente `DEMO-DESTINTELLIGENCE-JUNIN-DE-LOS-ANDES.html`.

## Instalación nueva en Supabase — un solo SQL

No uses migraciones antiguas. Esta versión incluye únicamente:

`SUPABASE-INSTALACION-COMPLETA.sql`

Ese archivo ya contiene el esquema final de Destintelligence V5.4, incluidas las variables agregadas en V5.2.

### Paso 1 · Crear el primer usuario

En tu proyecto de Supabase, creá un único usuario inicial en Authentication. Ese usuario será el administrador/owner inicial.

### Paso 2 · Ejecutar el único SQL

Abrí SQL Editor, copiá todo el contenido de `SUPABASE-INSTALACION-COMPLETA.sql` y ejecutalo.

Si existe un solo usuario en Authentication, el SQL lo detecta automáticamente y crea/configura:

- organización: Municipalidad de Junín de los Andes;
- destino: Junín de los Andes · Neuquén;
- membresía del primer usuario como `owner`;
- marca institucional inicial;
- estudio inicial de demanda turística listo para comenzar;
- todas las tablas, índices, políticas RLS y bucket de branding.

Si el proyecto ya tiene más de un usuario, el propio SQL explica dónde indicar el email del administrador.

### Paso 3 · Conectar la web

Editá solamente `config.js` y reemplazá:

```js
SUPABASE_URL: "https://TU-PROYECTO.supabase.co",
SUPABASE_ANON_KEY: "TU-ANON-KEY"
```

No necesitás editar `app.js` ni `public.js`: ambos leen la misma configuración.

### Paso 4 · Publicar la app

Subí la carpeta a tu hosting/GitHub Pages. `index.html` es la aplicación principal y `public.html` es el dashboard público.

## Usuarios adicionales

La pantalla Usuarios utiliza la Edge Function incluida en:

`supabase/functions/admin-users/index.ts`

La base y el primer administrador funcionan sin desplegar esta función. Solo necesitás desplegarla cuando quieras crear/invitar usuarios desde la propia aplicación.

## Archivos que ya no necesitás

Esta instalación nueva NO requiere:

- `supabase-v3.sql`
- `supabase-v4.sql`
- migraciones V3 → V4
- migraciones V4.1 → V4.2
- migraciones V4.2 → V4.3
- migración V5.1 → V5.2

Todo quedó consolidado en `SUPABASE-INSTALACION-COMPLETA.sql`.


## V5.4 · conexión y recuperación de contraseña

`index.html` y `public.html` cargan `config.js` automáticamente antes de iniciar Supabase. En versiones anteriores el archivo existía pero no era incluido por la página, por lo que la app podía mostrar el aviso de configuración aun con credenciales correctas.

Para GitHub Pages, después de publicar la app, configurá en Supabase **Authentication → URL Configuration**:

- **Site URL:** `https://TU-USUARIO.github.io/TU-REPOSITORIO/`
- **Redirect URLs:** agregá exactamente la misma URL.

En este proyecto, si el repositorio se llama `destintelligence`, el formato será `https://TU-USUARIO.github.io/destintelligence/`.

La recuperación funciona así: el usuario toca **¿Olvidaste tu contraseña?**, escribe su correo, Supabase envía el email, el enlace vuelve a la app y Destintelligence muestra el formulario para elegir una nueva contraseña.
