#Requires -Version 5.1
<#
.SYNOPSIS
    Telli Local Setup - Windows PowerShell Setup-Skript

.DESCRIPTION
    Richtet eine vollstaendige lokale Telli-Instanz mit Docker Compose ein.
    Erstellt die .env-Datei, startet alle Dienste und wartet auf Bereitschaft.

.NOTES
    Voraussetzungen:
    - Windows 10/11
    - Docker Desktop (laeuft und ist gestartet)
    - Internetverbindung (fuer Docker Images)
    - API-Schluessel eines LLM-Providers (z.B. IONOS, OpenAI)
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Farb-Hilfsfunktionen
# ---------------------------------------------------------------------------
function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([string]$Text)
    Write-Host "[SCHRITT] $Text" -ForegroundColor Yellow
}

function Write-OK {
    param([string]$Text)
    Write-Host "[OK] $Text" -ForegroundColor Green
}

function Write-Info {
    param([string]$Text)
    Write-Host "[INFO] $Text" -ForegroundColor White
}

function Write-Warn {
    param([string]$Text)
    Write-Host "[WARNUNG] $Text" -ForegroundColor DarkYellow
}

function Write-Err {
    param([string]$Text)
    Write-Host "[FEHLER] $Text" -ForegroundColor Red
}

# ---------------------------------------------------------------------------
# Generiere zufaelligen Hex-String
# ---------------------------------------------------------------------------
function New-RandomHex {
    param([int]$Bytes = 32)
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $buffer = New-Object byte[] $Bytes
    $rng.GetBytes($buffer)
    $rng.Dispose()
    return ([System.BitConverter]::ToString($buffer) -replace '-', '').ToLower()
}

# ---------------------------------------------------------------------------
# Skriptverzeichnis bestimmen
# ---------------------------------------------------------------------------
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
Write-Header "Telli Lokales Setup"
Write-Info "Arbeitsverzeichnis: $ScriptDir"
Write-Host ""
Write-Info "Dieses Skript richtet eine vollstaendige lokale Telli-Instanz ein."
Write-Info "Du benoeligst einen API-Schluessel eines LLM-Providers."
Write-Host ""

# ---------------------------------------------------------------------------
# 1. Docker pruefen
# ---------------------------------------------------------------------------
Write-Step "Pruefe Docker..."

try {
    $dockerVersion = docker --version 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Docker nicht gefunden" }
    Write-OK "Docker gefunden: $dockerVersion"
} catch {
    Write-Err "Docker ist nicht installiert oder nicht im PATH."
    Write-Info "Installiere Docker Desktop von: https://www.docker.com/products/docker-desktop"
    exit 1
}

try {
    docker info 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Docker laeuft nicht" }
    Write-OK "Docker Desktop laeuft."
} catch {
    Write-Err "Docker Desktop ist nicht gestartet."
    Write-Info "Starte Docker Desktop und versuche es erneut."
    exit 1
}

# ---------------------------------------------------------------------------
# 2. Bestehende .env pruefen
# ---------------------------------------------------------------------------
$envFile = Join-Path $ScriptDir ".env"
$skipNewSetup = $false

if (Test-Path $envFile) {
    Write-Warn "Eine .env-Datei existiert bereits."
    Write-Host ""
    $choice = Read-Host "Moechtest du die bestehende Konfiguration (r)einitialisieren oder (b)eibehalten? [b/r]"
    if ($choice -eq 'r') {
        Write-Step "Stoppe bestehende Dienste..."
        docker compose -f "$ScriptDir/docker-compose.yml" down 2>&1 | Out-Null
        Remove-Item $envFile -Force
        Write-OK "Alte Konfiguration entfernt."
    } else {
        Write-Info "Bestehende Konfiguration wird beibehalten."
        Write-Info "Starte Dienste mit bestehender .env..."
        $skipNewSetup = $true
    }
}

if (-not $skipNewSetup) {
    # -------------------------------------------------------------------------
    # 3. LLM Provider Konfiguration
    # -------------------------------------------------------------------------
    Write-Header "LLM Provider Konfiguration"
    Write-Info "Telli benoetigt einen OpenAI-kompatiblen API-Schluessel."
    Write-Host ""
    Write-Host "Verfuegbare Provider:" -ForegroundColor White
    Write-Host "  [1] IONOS AI Model Hub (empfohlen - deutsches Rechenzentrum, DSGVO-konform)"
    Write-Host "      Registrierung: https://cloud.ionos.de/ai"
    Write-Host "  [2] OpenAI (GPT-4, etc.)"
    Write-Host "      Registrierung: https://platform.openai.com"
    Write-Host "  [3] Eigener OpenAI-kompatibler Provider"
    Write-Host ""

    $providerChoice = Read-Host "Provider auswaehlen [1-3, Standard: 1]"
    if ([string]::IsNullOrWhiteSpace($providerChoice)) { $providerChoice = "1" }

    switch ($providerChoice) {
        "1" {
            $llmBaseUrl = "https://openai.ionos.de/openai"
            Write-Info "Provider: IONOS AI Model Hub"
            Write-Info "Erstelle deinen API-Schluessel unter: https://cloud.ionos.de/ai"
        }
        "2" {
            $llmBaseUrl = "https://api.openai.com/v1"
            Write-Info "Provider: OpenAI"
        }
        "3" {
            $llmBaseUrl = Read-Host "Base URL deines Providers (z.B. https://mein-provider.de/v1)"
            Write-Info "Provider: Benutzerdefiniert ($llmBaseUrl)"
        }
        default {
            $llmBaseUrl = "https://openai.ionos.de/openai"
            Write-Info "Ungueltige Auswahl, verwende IONOS als Standard."
        }
    }

    Write-Host ""
    $llmApiKey = ""
    while ([string]::IsNullOrWhiteSpace($llmApiKey)) {
        $llmApiKey = Read-Host "API-Schluessel eingeben"
        if ([string]::IsNullOrWhiteSpace($llmApiKey)) {
            Write-Warn "Der API-Schluessel darf nicht leer sein."
        }
    }
    Write-OK "API-Schluessel eingetragen."

    # -------------------------------------------------------------------------
    # 4. Sicherheitsschluessel generieren
    # -------------------------------------------------------------------------
    Write-Header "Sicherheitsschluessel generieren"

    Write-Step "Generiere AUTH_SECRET (64 Zeichen)..."
    $authSecret = New-RandomHex -Bytes 32  # 32 bytes = 64 hex chars
    Write-OK "AUTH_SECRET generiert."

    Write-Step "Generiere ENCRYPTION_KEY (32 Zeichen)..."
    $encryptionKey = New-RandomHex -Bytes 16  # 16 bytes = 32 hex chars
    Write-OK "ENCRYPTION_KEY generiert."

    # -------------------------------------------------------------------------
    # 5. .env schreiben
    # -------------------------------------------------------------------------
    Write-Step "Schreibe .env-Datei..."

    $envContent = @"
# ============================================================
# Telli Local Setup - Generiert von setup.ps1
# $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# ============================================================

# LLM Provider
LLM_API_KEY=$llmApiKey
LLM_BASE_URL=$llmBaseUrl

# Sicherheitsschluessel (automatisch generiert)
AUTH_SECRET=$authSecret
ENCRYPTION_KEY=$encryptionKey

# Datenbankpasswort (Standard wird verwendet wenn leer)
DB_PASSWORD=
"@

    $envContent | Out-File -FilePath $envFile -Encoding UTF8 -NoNewline
    Write-OK ".env-Datei erstellt."
}

# ---------------------------------------------------------------------------
# 6. Docker Images herunterladen
# ---------------------------------------------------------------------------
Write-Header "Docker Images herunterladen"
Write-Info "Dies kann beim ersten Start mehrere Minuten dauern..."
Write-Host ""

Write-Step "Lade telli-dialog Image..."
docker pull ghcr.io/fwu-de/telli-dialog:latest
if ($LASTEXITCODE -ne 0) { Write-Warn "Konnte telli-dialog Image nicht laden." }

Write-Step "Lade telli-api Image..."
docker pull ghcr.io/fwu-de/telli-api:latest
if ($LASTEXITCODE -ne 0) { Write-Warn "Konnte telli-api Image nicht laden." }

Write-Step "Lade telli-admin Image..."
docker pull ghcr.io/fwu-de/telli-admin:latest
if ($LASTEXITCODE -ne 0) { Write-Warn "Konnte telli-admin Image nicht laden." }

# ---------------------------------------------------------------------------
# 7. Infrastruktur starten
# ---------------------------------------------------------------------------
Write-Header "Infrastruktur starten"

Write-Step "Starte Infrastruktur-Dienste (postgres, valkey, keycloak, rabbitmq)..."
docker compose -f "$ScriptDir/docker-compose.yml" up -d `
    postgres valkey rabbitmq fix-keycloak-volume-ownership keycloak

if ($LASTEXITCODE -ne 0) {
    Write-Err "Fehler beim Starten der Infrastruktur-Dienste."
    exit 1
}
Write-OK "Infrastruktur gestartet."

Write-Step "Warte auf PostgreSQL..."
$maxWait = 60
$waited = 0
do {
    Start-Sleep -Seconds 2
    $waited += 2
    $health = docker compose -f "$ScriptDir/docker-compose.yml" ps --format json 2>$null |
              ConvertFrom-Json 2>$null |
              Where-Object { $_.Service -eq 'postgres' } |
              Select-Object -ExpandProperty Health -ErrorAction SilentlyContinue
    Write-Host "  Warte auf PostgreSQL (${waited}s)..." -NoNewline
    Write-Host "`r" -NoNewline
} while ($health -ne 'healthy' -and $waited -lt $maxWait)

if ($waited -ge $maxWait) {
    Write-Warn "PostgreSQL hat nicht rechtzeitig geantwortet. Fahre trotzdem fort..."
} else {
    Write-OK "PostgreSQL ist bereit."
}

# ---------------------------------------------------------------------------
# 8. Datenbank-Seeder ausfuehren
# ---------------------------------------------------------------------------
Write-Header "Datenbank initialisieren"

Write-Step "Baue Seeder-Image..."
docker compose -f "$ScriptDir/docker-compose.yml" build db-seeder
if ($LASTEXITCODE -ne 0) {
    Write-Err "Fehler beim Bauen des Seeder-Images."
    exit 1
}

Write-Step "Fuehre Datenbank-Seeder aus..."
docker compose -f "$ScriptDir/docker-compose.yml" run --rm db-seeder
if ($LASTEXITCODE -ne 0) {
    Write-Err "Fehler beim Initialisieren der Datenbank."
    Write-Info "Logs anzeigen: docker compose -f $ScriptDir/docker-compose.yml logs db-seeder"
    exit 1
}
Write-OK "Datenbank initialisiert."

# ---------------------------------------------------------------------------
# 9. Applikationen starten
# ---------------------------------------------------------------------------
Write-Header "Telli Applikationen starten"

Write-Step "Starte telli-api..."
docker compose -f "$ScriptDir/docker-compose.yml" up -d telli-api
if ($LASTEXITCODE -ne 0) { Write-Warn "Fehler beim Starten von telli-api." }

Write-Step "Starte telli-dialog und telli-admin..."
docker compose -f "$ScriptDir/docker-compose.yml" up -d telli-dialog telli-admin
if ($LASTEXITCODE -ne 0) { Write-Warn "Fehler beim Starten der Applikationen." }

# ---------------------------------------------------------------------------
# 10. Auf Bereitschaft warten
# ---------------------------------------------------------------------------
Write-Header "Warte auf Bereitschaft"

Write-Info "Warte bis alle Dienste bereit sind (bis zu 2 Minuten)..."
$services = @(
    @{ Name = "telli-dialog"; Url = "http://localhost:3000"; Port = 3000 },
    @{ Name = "telli-admin";  Url = "http://localhost:3001"; Port = 3001 },
    @{ Name = "telli-api";    Url = "http://localhost:3002"; Port = 3002 }
)

foreach ($svc in $services) {
    Write-Step "Warte auf $($svc.Name) ($($svc.Url))..."
    $maxAttempts = 30
    $ready = $false
    for ($i = 1; $i -le $maxAttempts; $i++) {
        try {
            $response = Invoke-WebRequest -Uri $svc.Url -TimeoutSec 3 -UseBasicParsing -ErrorAction Stop
            if ($response.StatusCode -lt 500) {
                $ready = $true
                break
            }
        } catch {
            # Not ready yet
        }
        Start-Sleep -Seconds 3
        Write-Host "  Versuch $i/$maxAttempts..." -NoNewline
        Write-Host "`r" -NoNewline
    }
    if ($ready) {
        Write-OK "$($svc.Name) ist bereit."
    } else {
        Write-Warn "$($svc.Name) hat nicht rechtzeitig geantwortet. Pruefe die Logs."
    }
}

# ---------------------------------------------------------------------------
# 11. Erfolg
# ---------------------------------------------------------------------------
Write-Header "Setup abgeschlossen!"

Write-Host ""
Write-Host "Telli ist jetzt verfuegbar unter:" -ForegroundColor Green
Write-Host ""
Write-Host "  Chat-App (Dialog):  " -NoNewline; Write-Host "http://localhost:3000" -ForegroundColor Cyan
Write-Host "  Admin-Panel:        " -NoNewline; Write-Host "http://localhost:3001" -ForegroundColor Cyan
Write-Host "  API:                " -NoNewline; Write-Host "http://localhost:3002" -ForegroundColor Cyan
Write-Host "  Keycloak Admin:     " -NoNewline; Write-Host "http://localhost:8080  (admin / admin)" -ForegroundColor Cyan
Write-Host "  RabbitMQ Mgmt:      " -NoNewline; Write-Host "http://localhost:15672 (user / password)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Naechste Schritte:" -ForegroundColor Yellow
Write-Host "  1. Oeffne http://localhost:8080/admin"
Write-Host "  2. Melde dich mit admin / admin an"
Write-Host "  3. Wechsle zum Realm 'telli-local'"
Write-Host "  4. Lege Benutzer unter Users -> Add User an"
Write-Host "  5. Oeffne http://localhost:3000 und melde dich an"
Write-Host ""
Write-Host "Telli stoppen:" -ForegroundColor Yellow
Write-Host "  docker compose -f `"$ScriptDir\docker-compose.yml`" down"
Write-Host ""
Write-Host "Logs anzeigen:" -ForegroundColor Yellow
Write-Host "  docker compose -f `"$ScriptDir\docker-compose.yml`" logs -f"
Write-Host ""
