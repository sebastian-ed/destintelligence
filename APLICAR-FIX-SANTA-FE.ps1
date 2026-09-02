param(
  [Parameter(Mandatory=$false)]
  [string]$ProjectPath = "."
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path $ProjectPath).Path

Write-Host "Destintelligence - Fix Santa Fe" -ForegroundColor Cyan
Write-Host "Proyecto: $root"

# Archivos de texto donde sí es seguro aplicar correcciones.
$extensions = @(".html",".js",".sql",".md",".txt")
$files = Get-ChildItem -Path $root -Recurse -File |
  Where-Object { $extensions -contains $_.Extension.ToLowerInvariant() }

# Sustituciones explícitas: no se reemplaza 'Neuquén' de forma global,
# porque puede ser una provincia válida de origen de visitantes.
$replacements = [ordered]@{
  "Municipalidad de Junín de los Andes" = "Municipalidad de Santa Fe"
  "Secretaría de Turismo · Junín de los Andes" = "Secretaría de Turismo · Santa Fe"
  "Junín de los Andes · Neuquén · Argentina" = "Santa Fe · Santa Fe · Argentina"
  "Residente de Junín de los Andes" = "Residente de Santa Fe"
  "Argentina, fuera de Neuquén" = "Argentina, fuera de Santa Fe"
  "Neuquén, fuera de Junín de los Andes" = "Provincia de Santa Fe, fuera de la ciudad de Santa Fe"
  "Junín de los Andes" = "Santa Fe"
  "Demo Junín" = "Demo Santa Fe"
  "Abrir demo Junín" = "Abrir demo Santa Fe"
  "study-junin" = "study-santa-fe"
  "junin-andes" = "santa-fe"
  "demo_junin" = "demo_santa_fe"
}

$changed = New-Object System.Collections.Generic.List[string]

foreach ($file in $files) {
  $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
  $original = $content

  foreach ($pair in $replacements.GetEnumerator()) {
    $content = $content.Replace($pair.Key, $pair.Value)
  }

  # Ajustes puntuales del SQL de instalación: sólo el bootstrap.
  if ($file.Name -eq "SUPABASE-INSTALACION-COMPLETA.sql") {
    $content = $content.Replace("v_province text := 'Neuquén';", "v_province text := 'Santa Fe';")
    $content = $content.Replace("values(v_org_id, 'Santa Fe', 'Neuquén', 'Argentina')", "values(v_org_id, 'Santa Fe', 'Santa Fe', 'Argentina')")
    $content = $content.Replace("CONFIGURACIÓN INICIAL DE JUNÍN DE LOS ANDES", "CONFIGURACIÓN INICIAL DE SANTA FE")
    $content = $content.Replace("turismo@junindelosandes.gov.ar", "turismo@municipio.gob.ar")
  }

  if ($content -ne $original) {
    Set-Content -LiteralPath $file.FullName -Value $content -Encoding UTF8 -NoNewline
    $changed.Add($file.FullName.Substring($root.Length).TrimStart("\"))
  }
}

# Copiar la migración de producción junto al proyecto, si viene en la misma carpeta del script.
$migrationSource = Join-Path $PSScriptRoot "MIGRAR-PRODUCCION-A-SANTA-FE.sql"
if (Test-Path $migrationSource) {
  Copy-Item $migrationSource (Join-Path $root "MIGRAR-PRODUCCION-A-SANTA-FE.sql") -Force
}

# Limpieza conservadora: sólo basura histórica identificada en el repositorio.
$obsolete = @(
  "DEMO-DESTINTELLIGENCE-JUNIN-DE-LOS-ANDES.html",
  "destintelligence.rar",
  "ACTUALIZAR-DESDE-V5.7.txt",
  "ACTUALIZAR-GESTION-AUDITORIA-V5.8.sql",
  "ACTUALIZAR-PERMISOS-V5.7.sql",
  "CAMBIOS-LICENCIA-V5.8.1.txt",
  "DESPLEGAR-GESTION-USUARIOS.txt",
  "REPARAR-ACCESO-USUARIO.sql"
)

$removed = New-Object System.Collections.Generic.List[string]
foreach ($name in $obsolete) {
  $target = Join-Path $root $name
  if (Test-Path $target) {
    Remove-Item -LiteralPath $target -Force
    $removed.Add($name)
  }
}

# Verificación: no debería quedar Junín de los Andes en archivos activos.
$remaining = Get-ChildItem -Path $root -Recurse -File |
  Where-Object { $extensions -contains $_.Extension.ToLowerInvariant() } |
  Select-String -Pattern "Junín de los Andes|junin-andes|study-junin|demo_junin" -SimpleMatch:$false

Write-Host ""
Write-Host "Archivos modificados: $($changed.Count)" -ForegroundColor Green
$changed | ForEach-Object { Write-Host "  MOD  $_" }

Write-Host ""
Write-Host "Archivos obsoletos eliminados: $($removed.Count)" -ForegroundColor Green
$removed | ForEach-Object { Write-Host "  DEL  $_" }

if ($remaining) {
  Write-Host ""
  Write-Host "ATENCION: quedaron referencias a Junín para revisión:" -ForegroundColor Yellow
  $remaining | ForEach-Object { Write-Host "  $($_.Path):$($_.LineNumber)  $($_.Line.Trim())" }
} else {
  Write-Host ""
  Write-Host "OK: no quedaron referencias activas a Junín de los Andes." -ForegroundColor Green
}

# Genera ZIP limpio al lado del proyecto.
$parent = Split-Path $root -Parent
$name = Split-Path $root -Leaf
$zip = Join-Path $parent ($name + "-SANTA-FE-LIMPIO.zip")
if (Test-Path $zip) { Remove-Item $zip -Force }

Compress-Archive -Path (Join-Path $root "*") -DestinationPath $zip -CompressionLevel Optimal

Write-Host ""
Write-Host "ZIP generado:" -ForegroundColor Cyan
Write-Host $zip
Write-Host ""
Write-Host "IMPORTANTE: para corregir PRODUCCION también ejecutá MIGRAR-PRODUCCION-A-SANTA-FE.sql en Supabase > SQL Editor." -ForegroundColor Yellow
