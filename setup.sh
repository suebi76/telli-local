#!/usr/bin/env bash
# =============================================================
# Telli Local Setup - Bash-Skript (Linux / macOS)
#
# Richtet eine vollstaendige lokale Telli-Instanz ein.
# Fuehre das Skript im Verzeichnis deploy/local aus:
#   bash setup.sh
# =============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ---------------------------------------------------------------------------
# Farb-Hilfsfunktionen
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'  # No Color

log_header() { echo -e "\n${CYAN}$(printf '=%.0s' {1..60})${NC}\n${CYAN}  $1${NC}\n${CYAN}$(printf '=%.0s' {1..60})${NC}\n"; }
log_step()   { echo -e "${YELLOW}[SCHRITT] $1${NC}"; }
log_ok()     { echo -e "${GREEN}[OK] $1${NC}"; }
log_info()   { echo -e "$1"; }
log_warn()   { echo -e "${YELLOW}[WARNUNG] $1${NC}"; }
log_err()    { echo -e "${RED}[FEHLER] $1${NC}"; }

# ---------------------------------------------------------------------------
# Zufaelliger Hex-String
# ---------------------------------------------------------------------------
random_hex() {
    local bytes="${1:-32}"
    if command -v openssl &>/dev/null; then
        openssl rand -hex "$bytes"
    else
        # Fallback fuer Systeme ohne openssl
        head -c "$bytes" /dev/urandom | xxd -p | tr -d '\n' | head -c $((bytes * 2))
    fi
}

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
log_header "Telli Lokales Setup"
log_info "Arbeitsverzeichnis: $SCRIPT_DIR"
log_info ""
log_info "Dieses Skript richtet eine vollstaendige lokale Telli-Instanz ein."
log_info "Du benoeligst einen API-Schluessel eines LLM-Providers."

# ---------------------------------------------------------------------------
# 1. Docker pruefen
# ---------------------------------------------------------------------------
log_header "Docker pruefen"

if ! command -v docker &>/dev/null; then
    log_err "Docker ist nicht installiert oder nicht im PATH."
    log_info "Installiere Docker Desktop von: https://www.docker.com/products/docker-desktop"
    exit 1
fi
log_ok "Docker gefunden: $(docker --version)"

if ! docker info &>/dev/null; then
    log_err "Docker laeuft nicht. Starte Docker Desktop und versuche es erneut."
    exit 1
fi
log_ok "Docker laeuft."

if ! docker compose version &>/dev/null; then
    log_err "Docker Compose nicht gefunden. Stelle sicher, dass Docker Desktop aktuell ist."
    exit 1
fi
log_ok "Docker Compose verfuegbar."

# ---------------------------------------------------------------------------
# 2. Bestehende .env pruefen
# ---------------------------------------------------------------------------
ENV_FILE="$SCRIPT_DIR/.env"
EXISTING_SETUP=false

if [ -f "$ENV_FILE" ]; then
    EXISTING_SETUP=true
    log_warn "Eine .env-Datei existiert bereits."
    echo ""
    read -rp "Moechtest du die bestehende Konfiguration [r]einitialisieren oder [b]eibehalten? [b/r]: " choice
    if [ "$choice" = "r" ]; then
        log_step "Stoppe bestehende Dienste..."
        docker compose -f "$SCRIPT_DIR/docker-compose.yml" down 2>/dev/null || true
        rm -f "$ENV_FILE"
        log_ok "Alte Konfiguration entfernt."
        EXISTING_SETUP=false
    else
        log_info "Bestehende Konfiguration wird beibehalten."
    fi
fi

# ---------------------------------------------------------------------------
# 3. LLM Provider konfigurieren (nur bei Ersteinrichtung)
# ---------------------------------------------------------------------------
if [ "$EXISTING_SETUP" = "false" ]; then
    log_header "LLM Provider Konfiguration"
    log_info "Telli benoetigt einen OpenAI-kompatiblen API-Schluessel."
    echo ""
    echo "Verfuegbare Provider:"
    echo "  [1] IONOS AI Model Hub (empfohlen - deutsches Rechenzentrum, DSGVO-konform)"
    echo "      https://cloud.ionos.de/ai"
    echo "  [2] OpenAI (GPT-4, etc.)"
    echo "      https://platform.openai.com"
    echo "  [3] Eigener OpenAI-kompatibler Provider"
    echo ""

    read -rp "Provider auswaehlen [1-3, Standard: 1]: " provider_choice
    provider_choice="${provider_choice:-1}"

    case "$provider_choice" in
        1)
            LLM_BASE_URL="https://openai.ionos.de/openai"
            log_info "Provider: IONOS AI Model Hub"
            ;;
        2)
            LLM_BASE_URL="https://api.openai.com/v1"
            log_info "Provider: OpenAI"
            ;;
        3)
            read -rp "Base URL deines Providers (z.B. https://mein-provider.de/v1): " LLM_BASE_URL
            log_info "Provider: Benutzerdefiniert ($LLM_BASE_URL)"
            ;;
        *)
            LLM_BASE_URL="https://openai.ionos.de/openai"
            log_warn "Ungueltige Auswahl, verwende IONOS als Standard."
            ;;
    esac

    echo ""
    LLM_API_KEY=""
    while [ -z "$LLM_API_KEY" ]; do
        read -rp "API-Schluessel eingeben: " LLM_API_KEY
        if [ -z "$LLM_API_KEY" ]; then
            log_warn "Der API-Schluessel darf nicht leer sein."
        fi
    done
    log_ok "API-Schluessel eingetragen."

    # -------------------------------------------------------------------------
    # 4. Sicherheitsschluessel generieren
    # -------------------------------------------------------------------------
    log_header "Sicherheitsschluessel generieren"

    log_step "Generiere AUTH_SECRET (64 Zeichen)..."
    AUTH_SECRET=$(random_hex 32)
    log_ok "AUTH_SECRET generiert."

    log_step "Generiere ENCRYPTION_KEY (32 Zeichen)..."
    ENCRYPTION_KEY=$(random_hex 16)
    log_ok "ENCRYPTION_KEY generiert."

    # -------------------------------------------------------------------------
    # 5. .env schreiben
    # -------------------------------------------------------------------------
    log_step "Schreibe .env-Datei..."
    cat > "$ENV_FILE" <<EOF
# ============================================================
# Telli Local Setup - Generiert von setup.sh
# $(date '+%Y-%m-%d %H:%M:%S')
# ============================================================

# LLM Provider
LLM_API_KEY=${LLM_API_KEY}
LLM_BASE_URL=${LLM_BASE_URL}

# Sicherheitsschluessel (automatisch generiert)
AUTH_SECRET=${AUTH_SECRET}
ENCRYPTION_KEY=${ENCRYPTION_KEY}

# Datenbankpasswort (Standard wird verwendet wenn leer)
DB_PASSWORD=
EOF
    log_ok ".env-Datei erstellt."
fi

# ---------------------------------------------------------------------------
# 6. Docker Images herunterladen
# ---------------------------------------------------------------------------
log_header "Docker Images herunterladen"
log_info "Dies kann beim ersten Start mehrere Minuten dauern..."

for image in \
    "ghcr.io/fwu-de/telli-dialog:latest" \
    "ghcr.io/fwu-de/telli-api:latest" \
    "ghcr.io/fwu-de/telli-admin:latest"; do
    log_step "Lade $image..."
    docker pull "$image" || log_warn "Konnte $image nicht laden."
done

# ---------------------------------------------------------------------------
# 7. Infrastruktur starten
# ---------------------------------------------------------------------------
log_header "Infrastruktur starten"

log_step "Starte Infrastruktur-Dienste..."
docker compose -f "$SCRIPT_DIR/docker-compose.yml" up -d \
    postgres valkey rabbitmq fix-keycloak-volume-ownership keycloak
log_ok "Infrastruktur gestartet."

log_step "Warte auf PostgreSQL (bis zu 60 Sekunden)..."
max_wait=60
waited=0
until docker compose -f "$SCRIPT_DIR/docker-compose.yml" \
    exec postgres pg_isready -U telli -d telli_dialog_db &>/dev/null; do
    sleep 2
    waited=$((waited + 2))
    echo -n "."
    if [ $waited -ge $max_wait ]; then
        echo ""
        log_warn "PostgreSQL hat nicht rechtzeitig geantwortet. Fahre trotzdem fort..."
        break
    fi
done
echo ""
[ $waited -lt $max_wait ] && log_ok "PostgreSQL ist bereit." || true

# ---------------------------------------------------------------------------
# 8. Datenbank-Seeder
# ---------------------------------------------------------------------------
log_header "Datenbank initialisieren"

log_step "Baue Seeder-Image..."
docker compose -f "$SCRIPT_DIR/docker-compose.yml" build db-seeder

log_step "Fuehre Datenbank-Seeder aus..."
docker compose -f "$SCRIPT_DIR/docker-compose.yml" run --rm db-seeder
log_ok "Datenbank initialisiert."

# ---------------------------------------------------------------------------
# 9. Applikationen starten
# ---------------------------------------------------------------------------
log_header "Telli Applikationen starten"

log_step "Starte alle Applikationen..."
docker compose -f "$SCRIPT_DIR/docker-compose.yml" up -d \
    telli-api telli-dialog telli-admin
log_ok "Applikationen gestartet."

# ---------------------------------------------------------------------------
# 10. Auf Bereitschaft warten
# ---------------------------------------------------------------------------
log_header "Warte auf Bereitschaft"

wait_for_service() {
    local name="$1"
    local url="$2"
    local max_attempts=30
    log_step "Warte auf $name ($url)..."
    for i in $(seq 1 $max_attempts); do
        if curl -sf --max-time 3 "$url" &>/dev/null; then
            log_ok "$name ist bereit."
            return 0
        fi
        echo -n "."
        sleep 3
    done
    echo ""
    log_warn "$name hat nicht rechtzeitig geantwortet. Pruefe die Logs."
}

wait_for_service "telli-dialog" "http://localhost:3000"
wait_for_service "telli-admin"  "http://localhost:3001"
wait_for_service "telli-api"    "http://localhost:3002"

# ---------------------------------------------------------------------------
# 11. Erfolg
# ---------------------------------------------------------------------------
log_header "Setup abgeschlossen!"

echo -e "${GREEN}Telli ist jetzt verfuegbar unter:${NC}"
echo ""
echo -e "  Chat-App (Dialog):  ${CYAN}http://localhost:3000${NC}"
echo -e "  Admin-Panel:        ${CYAN}http://localhost:3001${NC}"
echo -e "  API:                ${CYAN}http://localhost:3002${NC}"
echo -e "  Keycloak Admin:     ${CYAN}http://localhost:8080  (admin / admin)${NC}"
echo -e "  RabbitMQ Mgmt:      ${CYAN}http://localhost:15672 (user / password)${NC}"
echo ""
echo -e "${YELLOW}Naechste Schritte:${NC}"
echo "  1. Oeffne http://localhost:8080/admin"
echo "  2. Melde dich mit admin / admin an"
echo "  3. Wechsle zum Realm 'telli-local'"
echo "  4. Lege Benutzer unter Users -> Add User an"
echo "  5. Oeffne http://localhost:3000 und melde dich an"
echo ""
echo -e "${YELLOW}Telli stoppen:${NC}"
echo "  docker compose -f \"$SCRIPT_DIR/docker-compose.yml\" down"
echo ""
echo -e "${YELLOW}Logs anzeigen:${NC}"
echo "  docker compose -f \"$SCRIPT_DIR/docker-compose.yml\" logs -f"
echo ""
