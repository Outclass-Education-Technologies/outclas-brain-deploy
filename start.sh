#!/bin/sh
set -e
export PATH="/root/.bun/bin:$PATH"

echo "[gbrain] version: $(gbrain --version)"

PORT="${PORT:-8080}"
PUBLIC_URL="${GBRAIN_PUBLIC_URL:-}"

if [ -z "$DATABASE_URL" ]; then
  echo "[gbrain] ERROR: DATABASE_URL not set"; exit 1
fi

echo "[gbrain] Initialising brain on Postgres..."
gbrain init --url "$DATABASE_URL" --embedding-model voyage:voyage-3-large 2>&1

echo "[gbrain] Configuring API keys..."
gbrain config set anthropic_api_key "$ANTHROPIC_API_KEY" 2>&1 || true

# Auto-create named auth tokens (idempotent — skips if name exists)
echo "[gbrain] Creating auth tokens..."
gbrain auth create "vlad" 2>&1 || true
gbrain auth create "openclaw" 2>&1 || true
echo "[gbrain] Token list:"
gbrain auth list 2>&1 || true

# TOKEN_TTL: 1 year in seconds (31536000) — tokens last ~1yr, no manual rotation needed
TOKEN_TTL="${GBRAIN_TOKEN_TTL:-31536000}"

echo "[gbrain] Starting HTTP MCP server on port $PORT (token TTL: ${TOKEN_TTL}s)..."
if [ -n "$PUBLIC_URL" ]; then
  exec gbrain serve --http --port "$PORT" --bind 0.0.0.0 --public-url "$PUBLIC_URL" --token-ttl "$TOKEN_TTL"
else
  exec gbrain serve --http --port "$PORT" --bind 0.0.0.0 --token-ttl "$TOKEN_TTL"
fi
