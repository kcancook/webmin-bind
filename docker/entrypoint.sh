#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

ROOT_PASSWORD="${ROOT_PASSWORD:-}"
ROOT_PASSWORD_FILE="${ROOT_PASSWORD_FILE:-}"
WEBMIN_ETC_DIR="/etc/webmin"
BIND_ETC_DIR="/etc/bind"
BIND_CACHE_DIR="/var/cache/bind"
BIND_LIB_DIR="/var/lib/bind"

mkdir -p /run/named /var/webmin "$WEBMIN_ETC_DIR" "$BIND_ETC_DIR" "$BIND_CACHE_DIR" "$BIND_LIB_DIR"

if [[ -n "${ROOT_PASSWORD_FILE}" && -f "${ROOT_PASSWORD_FILE}" ]]; then
  ROOT_PASSWORD="$(tr -d '\r\n' < "${ROOT_PASSWORD_FILE}")"
fi

if [[ -n "$ROOT_PASSWORD" ]]; then
  log "Setting system root password"
  echo "root:${ROOT_PASSWORD}" | chpasswd || true

  if [[ -x /usr/share/webmin/changepass.pl ]]; then
    log "Setting Webmin root password"
    /usr/share/webmin/changepass.pl /etc/webmin root "${ROOT_PASSWORD}" || true
  fi
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

if [[ ! -f "${BIND_ETC_DIR}/rndc.key" ]]; then
  log "Creating RNDC key"
  rndc-confgen -a -c "${BIND_ETC_DIR}/rndc.key"
else
  log "Keeping existing ${BIND_ETC_DIR}/rndc.key"
fi

chown root:bind "${BIND_ETC_DIR}/rndc.key" 2>/dev/null || true
chmod 640 "${BIND_ETC_DIR}/rndc.key" 2>/dev/null || true

if ! grep -q '^include "/etc/bind/rndc.key";' "${BIND_ETC_DIR}/named.conf"; then
  log "Adding rndc.key include to ${BIND_ETC_DIR}/named.conf"
  tmpfile="$(mktemp)"
  {
    echo 'include "/etc/bind/rndc.key";'
    cat "${BIND_ETC_DIR}/named.conf"
  } > "${tmpfile}"
  cat "${tmpfile}" > "${BIND_ETC_DIR}/named.conf"
  rm -f "${tmpfile}"
else
  log "named.conf already includes rndc.key"
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
chown root:bind "${BIND_ETC_DIR}/rndc.key" 2>/dev/null || true

find "${BIND_ETC_DIR}" -type d -exec chmod 755 {} \; || true
find "${BIND_ETC_DIR}" -type f ! -name 'rndc.key' -exec chmod 644 {} \; || true
find "${BIND_CACHE_DIR}" -type d -exec chmod 775 {} \; || true
find "${BIND_CACHE_DIR}" -type f -exec chmod 664 {} \; || true
find "${BIND_LIB_DIR}" -type d -exec chmod 775 {} \; || true
find "${BIND_LIB_DIR}" -type f -exec chmod 664 {} \; || true
chmod 640 "${BIND_ETC_DIR}/rndc.key" 2>/dev/null || true

if [[ -f "${BIND_ETC_DIR}/named.conf" ]]; then
  log "Validating BIND configuration"
  named-checkconf "${BIND_ETC_DIR}/named.conf"
fi

if [[ -f /var/webmin/miniserv.pid ]]; then
  oldpid="$(cat /var/webmin/miniserv.pid 2>/dev/null || true)"
  if [[ -n "${oldpid}" ]] && kill -0 "${oldpid}" 2>/dev/null; then
    log "Removing stale Webmin PID file for PID ${oldpid}"
  else
    log "Removing old Webmin PID file"
  fi
  rm -f /var/webmin/miniserv.pid
fi

log "Starting Webmin"
(/usr/share/webmin/miniserv.pl /etc/webmin/miniserv.conf &) 

log "Starting named"
exec named -g -u bind
