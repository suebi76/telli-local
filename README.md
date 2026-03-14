# Telli – Lokale Installation

Diese Anleitung beschreibt, wie du eine vollständige **Telli**-Instanz lokal auf deinem Windows-Rechner mit Docker Compose betreiben kannst, **ohne den Quellcode** herunterzuladen.

---

## Was ist Telli?

[Telli](https://github.com/FWU-DE/telli-dialog) ist eine datenschutzkonforme KI-Assistenzplattform für Schulen und Bildungseinrichtungen, entwickelt vom FWU (Fachinstitut für audiovisuelle Medien). Telli ermöglicht:

- **KI-gestützte Chats** für Lehrkräfte und Schüler
- **Lernszenarien** und geteilte Chats im Unterricht
- **Eigene KI-Personas** (Characters) für pädagogische Zwecke
- **Bundesland-basierte Konfiguration** mit individuellen Budgets und Funktionen
- **OpenAI-kompatible LLM-Provider** hinter einer einheitlichen API

---

## Systemvoraussetzungen

| Anforderung | Mindest | Empfohlen |
|---|---|---|
| Betriebssystem | Windows 10 (64-bit) | Windows 11 |
| RAM | 4 GB verfügbar | 8 GB verfügbar |
| Festplatte | 10 GB frei | 20 GB frei |
| Software | [Docker Desktop](https://www.docker.com/products/docker-desktop) | Docker Desktop aktuell |
| Netzwerk | Internetverbindung | stabil |

**Wichtig:** Docker Desktop muss gestartet und betriebsbereit sein, bevor du das Setup ausführst.

---

## Schnellstart (3 Schritte)

### Schritt 1: Dateien herunterladen

Lade den Inhalt dieses Verzeichnisses (`deploy/local/`) herunter oder klone das Repository:

```bash
git clone https://github.com/FWU-DE/telli-dialog.git
cd telli-dialog/deploy/local
```

Alternativ kannst du nur die nötigen Dateien direkt aus GitHub herunterladen.

### Schritt 2: Setup ausführen

**Windows (empfohlen):**
```powershell
.\setup.ps1
```

**Linux / macOS:**
```bash
bash setup.sh
```

Das Skript führt dich durch die Konfiguration und startet alle Dienste automatisch.

### Schritt 3: Benutzer anlegen und loslegen

1. Öffne **Keycloak** unter [http://localhost:8080/admin](http://localhost:8080/admin)
2. Anmelden mit `admin` / `admin`
3. Realm `telli-local` auswählen (links oben)
4. **Users** → **Add user** → Benutzer anlegen
5. Tab **Credentials** → Passwort setzen (Temporary: off)
6. Öffne **Telli** unter [http://localhost:3000](http://localhost:3000)

---

## Manuelle Konfiguration (ohne Setup-Skript)

Falls du das Setup-Skript nicht verwenden möchtest:

### 1. .env-Datei erstellen

```bash
cp .env.example .env
```

Bearbeite `.env` und passe folgende Werte an:

```env
# Dein LLM-API-Schlüssel (Pflichtfeld)
LLM_API_KEY=sk-dein-api-schluessel

# Base URL des Providers (OpenAI-kompatibel)
# OpenAI:  https://api.openai.com/v1
# Gemini:  https://generativelanguage.googleapis.com/v1beta/openai/
LLM_BASE_URL=https://api.openai.com/v1

# Name des zusätzlichen Modells (Gemini 2.5 Flash/Pro sind bereits eingerichtet)
LLM_CHAT_MODEL=gpt-4o-mini

# Zufällige Sicherheitsschlüssel (Pflichtfelder)
# Linux/Mac: openssl rand -hex 32
AUTH_SECRET=<zufaelliger-64-zeichen-string>
# Linux/Mac: openssl rand -hex 16
ENCRYPTION_KEY=<zufaelliger-32-zeichen-string>
```

### 2. Datenbank initialisieren und Dienste starten

```bash
docker compose up -d postgres valkey rabbitmq keycloak fix-keycloak-volume-ownership
docker compose run --rm db-seeder
docker compose up -d telli-api telli-dialog telli-admin
```

---

## Dienste und Ports

| Dienst | URL | Beschreibung |
|---|---|---|
| **Telli Dialog** | http://localhost:3000 | Haupt-Chat-App für Nutzer |
| **Telli Admin** | http://localhost:3001 | Administrations-Panel |
| **Telli API** | http://localhost:3002 | LLM-Proxy-API |
| **Keycloak** | http://localhost:8080 | Identity Provider (SSO) |
| **RabbitMQ Mgmt.** | http://localhost:15672 | Message Broker (user/password) |
| **PostgreSQL** | localhost:5432 | Datenbank (intern) |
| **Valkey** | localhost:6379 | Cache (intern) |

### Interne Zugangsdaten (nur lokal)

| Dienst | Benutzername | Passwort |
|---|---|---|
| Keycloak Admin | `admin` | `admin` |
| RabbitMQ | `user` | `password` |
| PostgreSQL | `telli` | `telli-local-1234` (Standard) |

---

## Architektur

```
┌─────────────────────────────────────────────────────┐
│                   Browser / Client                   │
└──────┬──────────────┬──────────────┬────────────────┘
       │ :3000        │ :3001        │ :8080
       ▼              ▼              ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────────┐
│ telli-dialog │ │ telli-admin  │ │    Keycloak       │
│  (Next.js)   │ │  (Next.js)   │ │ (Identity Prov.) │
└──────┬───────┘ └──────┬───────┘ └──────────────────┘
       │                │
       │ :3002          │
       ▼                │
┌──────────────┐        │
│  telli-api   │        │
│ (LLM Proxy)  │        │
└──────┬───────┘        │
       │                │
       ▼                ▼
┌──────────────────────────────┐ ┌────────────┐
│         PostgreSQL           │ │   Valkey   │
│  telli_dialog_db             │ │  (Cache)   │
│  telli_api_db                │ └────────────┘
└──────────────────────────────┘
```

### LLM-Modelle

Gemini 2.5 Flash und Gemini 2.5 Pro werden automatisch vorkonfiguriert. Das beim Setup angegebene Modell (`LLM_CHAT_MODEL`) wird ebenfalls eingerichtet, sofern es nicht bereits in der Liste ist. Weitere Modelle können über das **Admin-Panel** unter http://localhost:3001 hinzugefügt werden.

| Modell | Typ |
|---|---|
| gemini-2.5-flash | Text/Chat |
| gemini-2.5-pro | Text/Chat |
| *(dein LLM_CHAT_MODEL)* | Text/Chat |

---

## Benutzer anlegen (Keycloak)

### Schritt-für-Schritt Anleitung

1. Öffne [http://localhost:8080/admin](http://localhost:8080/admin)
2. Anmelde-Daten: `admin` / `admin`
3. **Realm auswählen:** Klicke oben links auf das Realm-Dropdown und wähle **`telli-local`**

   > Falls kein `telli-local` Realm vorhanden ist, warte einige Sekunden und lade die Seite neu. Keycloak importiert den Realm beim Start.

4. **Benutzer erstellen:**
   - Links im Menü: **Users** → **Add user**
   - Pflichtfeld: **Username**
   - Optional: First name, Last name, Email
   - **Create** klicken

5. **Passwort setzen:**
   - Reiter **Credentials** öffnen
   - **Set password** klicken
   - Passwort eingeben
   - **Temporary: OFF** setzen (sonst muss der Nutzer es beim ersten Login ändern)
   - **Save** klicken

6. Öffne [http://localhost:3000](http://localhost:3000) und melde dich an.

### Nutzer-Rollen

Telli unterscheidet zwischen:
- **Lehrkräfte:** Höheres Token-Budget, Zugriff auf alle Features
- **Schüler:** Reduziertes Budget, eingeschränkte Features

Die Rollen werden über Keycloak-Attribute gesteuert. Im lokalen Setup haben alle Nutzer standardmäßig Lehrkraft-Rechte.

---

## Konfiguration

### LLM-Provider wechseln

Passe in `.env` an:

```env
LLM_API_KEY=sk-dein-neuer-schluessel
LLM_BASE_URL=https://api.dein-provider.de/v1
LLM_CHAT_MODEL=modellname
```

Nach Änderung:
```bash
docker compose restart db-seeder  # aktualisiert API-Schlüssel in DB
docker compose restart telli-api telli-dialog
```

### Datenbank-Passwort ändern

Passe in `.env` an:
```env
DB_PASSWORD=mein-sicheres-passwort
```

> **Achtung:** Nach einer Änderung musst du die Datenbank-Volumes löschen, da PostgreSQL das Passwort nur beim ersten Start setzt:
> ```bash
> docker compose down -v  # LÖSCHT ALLE DATEN!
> docker compose up -d
> ```

### Crawl4AI (optionaler Web-Crawler für RAG)

Um die Funktion zur Webseiten-Einbindung (RAG) zu aktivieren, entkommentiere in `docker-compose.yml` den `crawl4ai`-Service:

```yaml
# crawl4ai:
#   image: unclecode/crawl4ai:0.8.0
#   ...
```

Ändere zu:
```yaml
crawl4ai:
  image: unclecode/crawl4ai:0.8.0
  ...
```

**Anforderung:** 2 GB zusätzlicher RAM.

---

## Updates

### Neue Version installieren

```bash
# Neue Images herunterladen
docker compose pull

# Dienste neu starten
docker compose up -d
```

### Zurücksetzen (alle Daten löschen)

```bash
# Alle Dienste stoppen und Volumes löschen
docker compose down -v

# Neu aufsetzen
.\setup.ps1   # Windows
bash setup.sh  # Linux/Mac
```

---

## Fehlerbehebung

### Dienst startet nicht

```bash
# Logs eines bestimmten Dienstes anzeigen
docker compose logs -f telli-dialog
docker compose logs -f telli-api
docker compose logs -f db-seeder
docker compose logs -f postgres
```

### PostgreSQL startet nicht

```bash
# Status prüfen
docker compose ps

# Logs anzeigen
docker compose logs postgres

# Falls Volume-Fehler: Volume löschen (DATEN GEHEN VERLOREN!)
docker compose down -v
docker compose up -d postgres
```

### Keycloak zeigt falschen Realm

Warte 30-60 Sekunden nach dem Start. Keycloak importiert den Realm beim ersten Start.
Lade die Seite neu oder prüfe die Logs:
```bash
docker compose logs keycloak
```

### "Cannot connect to API"

Stelle sicher, dass `telli-api` läuft:
```bash
docker compose ps
curl http://localhost:3002/health
```

### Datenbank-Seeder schlägt fehl

```bash
# Seeder-Logs anzeigen
docker compose logs db-seeder

# Seeder manuell erneut ausführen
docker compose run --rm db-seeder
```

### Port ist bereits belegt

```bash
# Prüfen, welcher Prozess Port 3000 belegt
netstat -aon | findstr :3000

# Oder anderen Port in docker-compose.yml konfigurieren:
# ports:
#   - "3100:3000"  # Host:Container
```

### Docker Images können nicht geladen werden

Stelle sicher, dass du bei `ghcr.io` angemeldet bist, falls die Images privat sind:
```bash
docker login ghcr.io
```

Für öffentliche Images ist keine Anmeldung erforderlich.

---

## Datenschutz und Sicherheit

### Lokale Nutzung

Diese Konfiguration ist **ausschließlich für lokale Entwicklung und Tests** gedacht. Sie enthält:

- **Feste Standardpasswörter** (Keycloak, RabbitMQ, PostgreSQL)
- **Nicht gehärtete Dienste** (keine TLS-Verschlüsselung)
- **Einen festen lokalen API-Schlüssel** (`sk-local.telli-local-secret-not-for-production`)

**Betreibe diese Konfiguration NIEMALS öffentlich im Internet.**

### Deine Daten

- **API-Schlüssel:** Dein LLM-Provider-Schlüssel wird in der lokalen PostgreSQL-Datenbank gespeichert.
- **Chats:** Alle Konversationen bleiben lokal auf deinem Rechner.
- **Keine Telemetrie:** Diese Konfiguration sendet keine Nutzungsdaten.
- **LLM-Anfragen:** Deine Nachrichten werden an den konfigurierten LLM-Provider gesendet. Prüfe deren Datenschutzbestimmungen.

---

## Verzeichnisstruktur

```
deploy/local/
├── docker-compose.yml          # Hauptkonfiguration aller Dienste
├── .env.example                # Vorlage für Umgebungsvariablen
├── .env                        # Deine Konfiguration (nicht commiten!)
├── .gitignore
├── setup.ps1                   # Windows-Setup-Skript
├── setup.sh                    # Linux/Mac-Setup-Skript
├── README.md                   # Diese Anleitung
├── postgres/
│   ├── 01-create-databases.sql # Erstellt telli_api_db
│   ├── 02-init-schemas.sh      # Führt Schema-Migrationen aus
│   └── migrations/
│       ├── dialog-schema.sql   # Vollständiges Dialog-DB-Schema
│       └── api-schema.sql      # Vollständiges API-DB-Schema
└── seed/
    ├── Dockerfile              # Seeder-Container
    ├── package.json
    └── seed.js                 # Datenbank-Seeding-Skript
```

---

## Support und Weiterentwicklung

- **GitHub Repository:** https://github.com/FWU-DE/telli-dialog
- **Issues melden:** https://github.com/FWU-DE/telli-dialog/issues

---

*Telli wird entwickelt vom FWU – Institut für Bildung im Digitalzeitalter.*
