$ErrorActionPreference = "Stop"
Write-Host "Destintelligence · activación de gestión de usuarios" -ForegroundColor Cyan
Write-Host "Se abrirá el login de Supabase si todavía no estás autenticado."
npx supabase login
npx supabase link --project-ref dnnlbqnppxlmstneawrw
npx supabase functions deploy admin-users --no-verify-jwt
Write-Host "Listo. La función admin-users quedó desplegada." -ForegroundColor Green
