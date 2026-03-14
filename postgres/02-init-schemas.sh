#!/bin/bash
# =============================================================
# Telli Database Schema Initialization
# Runs after 01-create-databases.sql to apply full schemas
# =============================================================
set -e

MIGRATIONS_DIR="/docker-entrypoint-initdb.d/migrations"

echo "==> Applying Dialog DB schema (telli_dialog_db)..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "telli_dialog_db" \
  -f "$MIGRATIONS_DIR/dialog-schema.sql"
echo "==> Dialog DB schema applied successfully."

echo "==> Applying API DB schema (telli_api_db)..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "telli_api_db" \
  -f "$MIGRATIONS_DIR/api-schema.sql"
echo "==> API DB schema applied successfully."

echo "==> All database schemas initialized."
