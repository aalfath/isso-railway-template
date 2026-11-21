#!/bin/sh
# Writes Isso's config from environment variables and starts gunicorn.
# Secrets are written as ${VAR} references: Isso's config parser expands
# environment variables itself, so they never land on disk.
set -eu

PORT="${PORT:-8080}"
ISSO_DB_PATH="${ISSO_DB_PATH:-/db/comments.db}"
ISSO_ADMIN_ENABLED="${ISSO_ADMIN_ENABLED:-true}"
CFG="${ISSO_SETTINGS_FILE:-/tmp/isso-railway.cfg}"

mkdir -p "$(dirname "$ISSO_DB_PATH")"

# Websites allowed to embed comments: ISSO_HOST (comma or space separated),
# plus Isso's own public URL so the /demo/ page works.
hosts=$(printf '%s' "${ISSO_HOST:-}" | tr ', ' '\n\n' | sed '/^$/d')
if [ -n "${ISSO_PUBLIC_ENDPOINT:-}" ]; then
  ISSO_PUBLIC_ENDPOINT="${ISSO_PUBLIC_ENDPOINT%/}"
  export ISSO_PUBLIC_ENDPOINT
  hosts=$(printf '%s\n%s\n' "$hosts" "$ISSO_PUBLIC_ENDPOINT" | sed '/^$/d' | awk '!seen[$0]++')
fi
if [ -z "${ISSO_HOST:-}" ]; then
  echo "isso-railway: ISSO_HOST is empty, so only Isso's own demo page can show comments." >&2
  echo "isso-railway: set ISSO_HOST to your website URL (for example https://blog.example.com)." >&2
fi
if [ -z "$hosts" ]; then
  echo "isso-railway: set ISSO_HOST (your website URL) or ISSO_PUBLIC_ENDPOINT (Isso's own URL)" >&2
  exit 1
fi
for h in $hosts; do
  case "$h" in
    http://*|https://*) ;;
    *) echo "isso-railway: ISSO_HOST entry '$h' must start with http:// or https://" >&2; exit 1 ;;
  esac
done

case "$ISSO_ADMIN_ENABLED" in
  true|True|1|yes|on)
    if [ -z "${ISSO_ADMIN_PASSWORD:-}" ] || [ "${ISSO_ADMIN_PASSWORD}" = "please_choose_a_strong_password" ]; then
      echo "isso-railway: the admin page is on, so ISSO_ADMIN_PASSWORD must be set to a strong password" >&2
      exit 1
    fi
    if [ "${#ISSO_ADMIN_PASSWORD}" -lt 12 ]; then
      echo "isso-railway: ISSO_ADMIN_PASSWORD must be at least 12 characters" >&2
      exit 1
    fi
    ;;
esac
if [ -z "${ISSO_HASH_SALT:-}" ]; then
  echo "isso-railway: ISSO_HASH_SALT must be set (a random string)" >&2
  exit 1
fi

notify=stdout
if [ -n "${ISSO_SMTP_HOST:-}" ]; then
  notify=smtp
fi

{
  echo "[general]"
  echo "dbpath = $ISSO_DB_PATH"
  echo "name = ${ISSO_NAME:-}"
  echo "host ="
  printf '%s\n' "$hosts" | sed 's/^/    /'
  echo "max-age = ${ISSO_MAX_AGE:-15m}"
  echo "notify = $notify"
  echo "reply-notifications = ${ISSO_REPLY_NOTIFICATIONS:-false}"
  echo "log-file ="
  echo "gravatar = ${ISSO_GRAVATAR:-false}"
  echo "latest-enabled = ${ISSO_LATEST_ENABLED:-false}"
  echo
  echo "[admin]"
  echo "enabled = $ISSO_ADMIN_ENABLED"
  echo 'password = ${ISSO_ADMIN_PASSWORD}'
  echo
  echo "[moderation]"
  echo "enabled = ${ISSO_MODERATION:-false}"
  echo "approve-if-email-previously-approved = ${ISSO_APPROVE_IF_EMAIL_PREVIOUSLY_APPROVED:-false}"
  echo "purge-after = ${ISSO_PURGE_AFTER:-30d}"
  echo
  echo "[server]"
  echo "listen = http://0.0.0.0:$PORT"
  echo "public-endpoint = ${ISSO_PUBLIC_ENDPOINT:-}"
  echo "reload = false"
  echo "profile = false"
  echo "trusted-proxies ="
  echo "samesite = ${ISSO_SAMESITE:-}"
  echo
  echo "[smtp]"
  echo "username = ${ISSO_SMTP_USERNAME:-}"
  echo 'password = ${ISSO_SMTP_PASSWORD}'
  echo "host = ${ISSO_SMTP_HOST:-localhost}"
  echo "port = ${ISSO_SMTP_PORT:-587}"
  echo "security = ${ISSO_SMTP_SECURITY:-starttls}"
  echo "to = ${ISSO_SMTP_TO:-}"
  echo "from = ${ISSO_SMTP_FROM:-}"
  echo "timeout = 10"
  echo
  echo "[guard]"
  echo "enabled = ${ISSO_GUARD_ENABLED:-true}"
  echo "ratelimit = ${ISSO_GUARD_RATELIMIT:-2}"
  echo "direct-reply = ${ISSO_GUARD_DIRECT_REPLY:-3}"
  echo "reply-to-self = ${ISSO_GUARD_REPLY_TO_SELF:-false}"
  echo "require-author = ${ISSO_REQUIRE_AUTHOR:-false}"
  echo "require-email = ${ISSO_REQUIRE_EMAIL:-false}"
  echo
  echo "[hash]"
  echo 'salt = ${ISSO_HASH_SALT}'
  echo "algorithm = pbkdf2"
  echo
  echo "[rss]"
  echo "base = ${ISSO_RSS_BASE:-}"
  echo "limit = 100"
} > "$CFG"

# Unset optional secrets must still expand to an empty string, not "${VAR}".
export ISSO_SMTP_PASSWORD="${ISSO_SMTP_PASSWORD:-}"
export ISSO_SETTINGS="$CFG"

echo "isso-railway: database $ISSO_DB_PATH, websites: $(printf '%s ' $hosts)"
cd /isso
exec /isso/bin/gunicorn \
  -b "[::]:$PORT" \
  -w "${WEB_CONCURRENCY:-2}" \
  --preload \
  --worker-tmp-dir /dev/shm \
  --access-logfile - \
  --forwarded-allow-ips '*' \
  railway_wsgi:application
