#!/bin/sh
set -e

PORT="${PORT:-3000}"
PUBLIC_URL="${GBRAIN_PUBLIC_URL:-}"

echo "[gbrain-render] Starting up..."

# Init / migrate DB schema (idempotent)
if [ -n "$DATABASE_URL" ]; then
  echo "[gbrain-render] Initialising brain on Postgres..."
  gbrain init --url "$DATABASE_URL" --no-embedding || gbrain apply-migrations --yes --non-interactive || true
else
  echo "[gbrain-render] ERROR: DATABASE_URL not set"
  exit 1
fi

# Configure API keys
if [ -n "$ANTHROPIC_API_KEY" ]; then
  gbrain config set anthropic_api_key "$ANTHROPIC_API_KEY"
fi

if [ -n "$OPENAI_API_KEY" ]; then
  gbrain config set embedding_model "openai:text-embedding-3-large"
fi

# Start the HTTP MCP server
if [ -n "$PUBLIC_URL" ]; then
  echo "[gbrain-render] Serving at $PUBLIC_URL"
  exec gbrain serve --http --port "$PORT" --bind 0.0.0.0 --public-url "$PUBLIC_URL"
else
  exec gbrain serve --http --port "$PORT" --bind 0.0.0.0
fi
