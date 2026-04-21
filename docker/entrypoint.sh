#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${ROOT_PASSWORD:-}" ]]; then
  echo "root:${ROOT_PASSWORD}" | chpasswd
fi

mkdir -p /run/named /var/webmin

mkdir -p /run/named /var/webmin /etc/bind

cat > /etc/bind/named.conf <<'EOF'
include "/etc/bind/named.conf.options";
include "/etc/bind/named.conf.local";
EOF

cat > /etc/bind/named.conf.options <<'EOF'
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

touch /etc/bind/named.conf.local

cat > /etc/webmin/.start-init <<'EOF'
#!/bin/sh
exec /usr/share/webmin/miniserv.pl /etc/webmin/miniserv.conf
EOF

cat > /etc/webmin/.stop-init <<'EOF'
#!/bin/sh
if [ -f /var/webmin/miniserv.pid ]; then
  kill "$(cat /var/webmin/miniserv.pid)" 2>/dev/null || true
fi
EOF

cat > /etc/webmin/.reload-init <<'EOF'
#!/bin/sh
if [ -f /var/webmin/miniserv.pid ]; then
  kill -HUP "$(cat /var/webmin/miniserv.pid)" 2>/dev/null || true
fi
EOF

cat > /etc/webmin/.restart-init <<'EOF'
#!/bin/sh
if [ -f /var/webmin/miniserv.pid ]; then
  kill "$(cat /var/webmin/miniserv.pid)" 2>/dev/null || true
fi
exec /usr/share/webmin/miniserv.pl /etc/webmin/miniserv.conf
EOF

cat > /etc/webmin/.restart-by-force-kill-init <<'EOF'
#!/bin/sh
if [ -f /var/webmin/miniserv.pid ]; then
  kill -9 "$(cat /var/webmin/miniserv.pid)" 2>/dev/null || true
fi
exec /usr/share/webmin/miniserv.pl /etc/webmin/miniserv.conf
EOF

chmod +x /etc/webmin/.start-init /etc/webmin/.stop-init /etc/webmin/.reload-init /etc/webmin/.restart-init /etc/webmin/.restart-by-force-kill-init

service webmin start

named -g -u bind &
wait -n
