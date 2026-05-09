#!/usr/bin/env bash
# Required env vars: PG_IP_1 PG_IP_2 PG_IP_3 REDIS_PORT REDIS_PASSWORD
#                    HAPROXY_PG_PRIMARY_PORT HAPROXY_PG_REPLICA_PORT
#                    HAPROXY_REDIS_PORT HAPROXY_STATS_PORT
set -euo pipefail

log() { echo "[$(date +%H:%M:%S)] $*"; }

log "Installing HAProxy"
apt-get install -y haproxy

cat > /etc/haproxy/haproxy.cfg << EOF
global
    maxconn 1000
    log /dev/log local0

defaults
    log global
    mode tcp
    retries 2
    timeout client 30m
    timeout connect 4s
    timeout server 30m
    timeout check 5s

# ── Stats ──────────────────────────────────────────────────────────────────────
listen stats
    mode http
    bind *:${HAPROXY_STATS_PORT}
    stats enable
    stats uri /
    stats refresh 10s

# ── PostgreSQL primary (read-write) ───────────────────────────────────────────
frontend pg_primary
    bind *:${HAPROXY_PG_PRIMARY_PORT}
    default_backend pg_primary_backend

backend pg_primary_backend
    option httpchk GET /primary
    http-check expect status 200
    default-server inter 3s fall 3 rise 2 on-marked-down shutdown-sessions
    server pg-1 ${PG_IP_1}:5432 maxconn 100 check port 8008
    server pg-2 ${PG_IP_2}:5432 maxconn 100 check port 8008
    server pg-3 ${PG_IP_3}:5432 maxconn 100 check port 8008

# ── PostgreSQL replicas (read-only) ───────────────────────────────────────────
frontend pg_replicas
    bind *:${HAPROXY_PG_REPLICA_PORT}
    default_backend pg_replica_backend

backend pg_replica_backend
    balance roundrobin
    option httpchk GET /replica
    http-check expect status 200
    default-server inter 3s fall 3 rise 2 on-marked-down shutdown-sessions
    server pg-1 ${PG_IP_1}:5432 maxconn 100 check port 8008
    server pg-2 ${PG_IP_2}:5432 maxconn 100 check port 8008
    server pg-3 ${PG_IP_3}:5432 maxconn 100 check port 8008

# ── Redis ─────────────────────────────────────────────────────────────────────
frontend redis
    bind *:${HAPROXY_REDIS_PORT}
    default_backend redis_backend

backend redis_backend
    balance roundrobin
    option tcp-check
    tcp-check connect
    tcp-check send AUTH\ ${REDIS_PASSWORD}\r\n
    tcp-check expect string +OK
    tcp-check send PING\r\n
    tcp-check expect string +PONG
    tcp-check send QUIT\r\n
    tcp-check expect string +OK
    default-server inter 3s fall 3 rise 2
    server redis-1 ${PG_IP_1}:${REDIS_PORT} check
    server redis-2 ${PG_IP_2}:${REDIS_PORT} check
    server redis-3 ${PG_IP_3}:${REDIS_PORT} check
EOF

systemctl enable haproxy
systemctl restart haproxy

log "HAProxy setup complete"
