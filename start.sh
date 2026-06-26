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

OUTCLASS_CODE_SOURCE_ID="${OUTCLASS_CODE_SOURCE_ID:-gstack-code-gies-outclass-b6f4b0}"
OUTCLASS_CODE_DIR="${OUTCLASS_CODE_DIR:-/root/.gbrain/clones/$OUTCLASS_CODE_SOURCE_ID}"
OUTCLASS_CODE_REPO_SSH="${OUTCLASS_CODE_REPO_SSH:-git@github.com:Outclass-Education-Technologies/Outclass.git}"

if [ -n "$OUTCLASS_CODE_DEPLOY_KEY" ]; then
  echo "[gbrain] Preparing Outclass code source clone..."
  mkdir -p /root/.ssh "$(dirname "$OUTCLASS_CODE_DIR")"
  printf '%s\n' "$OUTCLASS_CODE_DEPLOY_KEY" > /root/.ssh/outclass_code_deploy_key
  chmod 600 /root/.ssh/outclass_code_deploy_key
  ssh-keyscan github.com > /root/.ssh/known_hosts 2>/dev/null || true
  export GIT_SSH_COMMAND="ssh -i /root/.ssh/outclass_code_deploy_key -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes"

  if [ -d "$OUTCLASS_CODE_DIR/.git" ]; then
    git -C "$OUTCLASS_CODE_DIR" fetch --depth=1 origin main 2>&1 || true
    git -C "$OUTCLASS_CODE_DIR" reset --hard origin/main 2>&1 || true
  else
    rm -rf "$OUTCLASS_CODE_DIR"
    git clone --depth=1 "$OUTCLASS_CODE_REPO_SSH" "$OUTCLASS_CODE_DIR" 2>&1 || true
  fi

  if [ -d "$OUTCLASS_CODE_DIR/.git" ]; then
    gbrain sources add "$OUTCLASS_CODE_SOURCE_ID" \
      --path "$OUTCLASS_CODE_DIR" \
      --name "Outclass code" \
      --federated 2>&1 || true
  else
    echo "[gbrain] WARN: Outclass code source clone unavailable; skipping source registration"
  fi
else
  echo "[gbrain] OUTCLASS_CODE_DEPLOY_KEY not set; skipping Outclass code source clone"
fi

# Auth credentials are managed explicitly with `gbrain auth` / OAuth.
# Do not mint or list tokens during deploy: token material can land in logs,
# and repeated deploys leave duplicate active legacy tokens.

# TOKEN_TTL: 1 year in seconds (31536000) — tokens last ~1yr, no manual rotation needed
TOKEN_TTL="${GBRAIN_TOKEN_TTL:-31536000}"

echo "[gbrain] Starting HTTP MCP server on port $PORT (token TTL: ${TOKEN_TTL}s)..."
if [ -n "$PUBLIC_URL" ]; then
  exec gbrain serve --http --port "$PORT" --bind 0.0.0.0 --public-url "$PUBLIC_URL" --token-ttl "$TOKEN_TTL"
else
  exec gbrain serve --http --port "$PORT" --bind 0.0.0.0 --token-ttl "$TOKEN_TTL"
fi
