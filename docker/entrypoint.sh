#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

ROOT_PASSWORD="${ROOT_PASSWORD:-}"
WEBMIN_ETC_DIR="/etc/webmin"
BIND_ETC_DIR="/etc/bind"
BIND_CACHE_DIR="/var/cache/bind"
BIND_LIB_DIR="/var/lib/bind"

mkdir -p /run/named /var/webmin "$WEBMIN_ETC_DIR" "$BIND_ETC_DIR" "$BIND_CACHE_DIR" "$BIND_LIB_DIR"

if [[ -n "$ROOT_PASSWORD" ]]; then
  echo "root:${ROOT_PASSWORD}" | chpasswd
fi

if [[ ! -f "${BIND_ETC_DIR}/named.conf" ]]; then
  log "Creating default ${BIND_ETC_DIR}/named.conf"
  cat > "${BIND_ETC_DIR}/named.conf" <<'EOF'
include "/etc/bind/named.conf.options";
include "/etc/bind/named.conf.local";
EOF
else
  log "Keeping existing ${BIND_ETC_DIR}/named.conf"
fi

if [[ ! -f "${BIND_ETC_DIR}/named.conf.options" ]]; then
  log "Creating default ${BIND_ETC_DIR}/named.conf.options"
  cat > "${BIND_ETC_DIR}/named.conf.options" <<'EOF'
options {
    directory "/var/cache/bind";
    recursion no;
    allow-query-cache { none; };
    allow-recursion { none; };
    allow-transfer { none; };
    dnssec-validation auto;
    listen-on { any; };
    listen-on-v6 { any; };
};
EOF
else
  log "Keeping existing ${BIND_ETC_DIR}/named.conf.options"
fi

if [[ ! -f "${BIND_ETC_DIR}/named.conf.local" ]]; then
  log "Creating empty ${BIND_ETC_DIR}/named.conf.local"
  touch "${BIND_ETC_DIR}/named.conf.local"
else
  log "Keeping existing ${BIND_ETC_DIR}/named.conf.local"
fi

if [[ ! -f "${WEBMIN_ETC_DIR}/.start-init" ]]; then
  cat > "${WEBMIN_ETC_DIR}/.start-init" <<'EOF'
#!/bin/sh
exec /usr/share/webmin/miniserv.pl /etc/webmin/miniserv.conf
EOF
fi

if [[ ! -f "${WEBMIN_ETC_DIR}/.stop-init" ]]; then
  cat > "${WEBMIN_ETC_DIR}/.stop-init" <<'EOF'
#!/bin/sh
if [ -f /var/webmin/miniserv.pid ]; then
  kill "$(cat /var/webmin/miniserv.pid)" 2>/dev/null || true
fi
EOF
fi

if [[ ! -f "${WEBMIN_ETC_DIR}/.reload-init" ]]; then
  cat > "${WEBMIN_ETC_DIR}/.reload-init" <<'EOF'
#!/bin/sh
if [ -f /var/webmin/miniserv.pid ]; then
  kill -HUP "$(cat /var/webmin/miniserv.pid)" 2>/dev/null || true
fi
EOF
fi

if [[ ! -f "${WEBMIN_ETC_DIR}/.restart-init" ]]; then
  cat > "${WEBMIN_ETC_DIR}/.restart-init" <<'EOF'
#!/bin/sh
if [ -f /var/webmin/miniserv.pid ]; then
  kill "$(cat /var/webmin/miniserv.pid)" 2>/dev/null || true
fi
exec /usr/share/webmin/miniserv.pl /etc/webmin/miniserv.conf
EOF
fi

if [[ ! -f "${WEBMIN_ETC_DIR}/.restart-by-force-kill-init" ]]; then
  cat > "${WEBMIN_ETC_DIR}/.restart-by-force-kill-init" <<'EOF'
#!/bin/sh
if [ -f /var/webmin/miniserv.pid ]; then
  kill -9 "$(cat /var/webmin/miniserv.pid)" 2>/dev/null || true
fi
exec /usr/share/webmin/miniserv.pl /etc/webmin/miniserv.conf
EOF
fi

chmod +x \
  "${WEBMIN_ETC_DIR}/.start-init" \
  "${WEBMIN_ETC_DIR}/.stop-init" \
  "${WEBMIN_ETC_DIR}/.reload-init" \
  "${WEBMIN_ETC_DIR}/.restart-init" \
  "${WEBMIN_ETC_DIR}/.restart-by-force-kill-init"

chown -R root:root "${BIND_ETC_DIR}" || true
chown -R bind:bind "${BIND_CACHE_DIR}" "${BIND_LIB_DIR}" /run/named /var/webmin || true

find "${BIND_ETC_DIR}" -type d -exec chmod 755 {} \; || true
find "${BIND_ETC_DIR}" -type f -exec chmod 644 {} \; || true
find "${BIND_CACHE_DIR}" -type d -exec chmod 775 {} \; || true
find "${BIND_CACHE_DIR}" -type f -exec chmod 664 {} \; || true
find "${BIND_LIB_DIR}" -type d -exec chmod 775 {} \; || true
find "${BIND_LIB_DIR}" -type f -exec chmod 664 {} \; || true

if [[ -f "${BIND_ETC_DIR}/named.conf" ]]; then
  log "Validating BIND configuration"
  named-checkconf "${BIND_ETC_DIR}/named.conf"
fi

log "Starting Webmin"
service webmin start

log "Starting named"
named -g -u bind &
wait -n
