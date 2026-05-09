#!/usr/bin/env bash
# Required env vars: PG_IP_1 PG_IP_2 PG_IP_3
#                    HAPROXY_PG_PRIMARY_PORT HAPROXY_PG_REPLICA_PORT HAPROXY_STATS_PORT
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

EOF

systemctl enable haproxy
systemctl restart haproxy

log "HAProxy setup complete"
