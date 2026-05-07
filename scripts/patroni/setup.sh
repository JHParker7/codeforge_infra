#!/usr/bin/env bash
# Required env vars: NODE_NAME NODE_IP ETCD_CLUSTER ETCD_HOSTS
#                    PG_SCOPE PG_SUPER_PASS PG_REPL_PASS PG_VERSION ETCD_VERSION
set -euo pipefail

PG_VERSION="${PG_VERSION:-16}"
ETCD_VERSION="${ETCD_VERSION:-3.5.12}"

log() { echo "[$(date +%H:%M:%S)] $*"; }

# ── System prep ───────────────────────────────────────────────────────────────
log "Preparing system"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl gnupg2 lsb-release python3-pip python3-dev libpq-dev

# ── etcd ──────────────────────────────────────────────────────────────────────
log "Installing etcd ${ETCD_VERSION}"
curl -sL "https://github.com/etcd-io/etcd/releases/download/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-amd64.tar.gz" \
  | tar -xz -C /tmp
install -m 755 /tmp/etcd-v${ETCD_VERSION}-linux-amd64/etcd    /usr/local/bin/etcd
install -m 755 /tmp/etcd-v${ETCD_VERSION}-linux-amd64/etcdctl /usr/local/bin/etcdctl
rm -rf /tmp/etcd-v${ETCD_VERSION}-linux-amd64

id etcd &>/dev/null || useradd -r -s /sbin/nologin etcd
mkdir -p /var/lib/etcd
chown etcd:etcd /var/lib/etcd
chmod 700 /var/lib/etcd

cat > /etc/default/etcd <<EOF
ETCD_NAME="${NODE_NAME}"
ETCD_DATA_DIR="/var/lib/etcd"
ETCD_LISTEN_PEER_URLS="http://${NODE_IP}:2380"
ETCD_LISTEN_CLIENT_URLS="http://${NODE_IP}:2379,http://127.0.0.1:2379"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://${NODE_IP}:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://${NODE_IP}:2379"
ETCD_INITIAL_CLUSTER="${ETCD_CLUSTER}"
ETCD_INITIAL_CLUSTER_TOKEN="pg-etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE="new"
EOF

cat > /etc/systemd/system/etcd.service <<'SVC'
[Unit]
Description=etcd key-value store
After=network-online.target
Wants=network-online.target

[Service]
User=etcd
Type=notify
EnvironmentFile=/etc/default/etcd
ExecStart=/usr/local/bin/etcd
Restart=on-failure
RestartSec=5s
LimitNOFILE=40000

[Install]
WantedBy=multi-user.target
SVC

systemctl daemon-reload
systemctl enable etcd
systemctl start etcd
log "etcd started"

# ── PostgreSQL ────────────────────────────────────────────────────────────────
log "Installing PostgreSQL ${PG_VERSION}"
curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
  | gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg
echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" \
  > /etc/apt/sources.list.d/pgdg.list
apt-get update -qq
apt-get install -y -qq "postgresql-${PG_VERSION}" "postgresql-contrib-${PG_VERSION}"

# Patroni owns the cluster lifecycle; disable the default service
systemctl stop postgresql || true
systemctl disable postgresql || true

# ── Patroni ───────────────────────────────────────────────────────────────────
log "Installing Patroni"
pip3 install -q "patroni[etcd3]" "psycopg2-binary"

mkdir -p /etc/patroni
PATRONI_DATA="/var/lib/postgresql/${PG_VERSION}/patroni"
mkdir -p "${PATRONI_DATA}"
chown -R postgres:postgres /etc/patroni "${PATRONI_DATA}"

cat > /etc/patroni/config.yaml <<EOF
scope: ${PG_SCOPE}
name: ${NODE_NAME}

restapi:
  listen: ${NODE_IP}:8008
  connect_address: ${NODE_IP}:8008

etcd3:
  hosts: ${ETCD_HOSTS}

bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576
    postgresql:
      use_pg_rewind: true
      parameters:
        wal_level: replica
        hot_standby: "on"
        max_wal_senders: 10
        max_replication_slots: 10
  initdb:
    - encoding: UTF8
    - data-checksums
  pg_hba:
    - host replication replicator 0.0.0.0/0 scram-sha-256
    - host all all 0.0.0.0/0 scram-sha-256

postgresql:
  listen: 0.0.0.0:5432
  connect_address: ${NODE_IP}:5432
  data_dir: ${PATRONI_DATA}
  bin_dir: /usr/lib/postgresql/${PG_VERSION}/bin
  pgpass: /tmp/pgpass0
  authentication:
    replication:
      username: replicator
      password: "${PG_REPL_PASS}"
    superuser:
      username: postgres
      password: "${PG_SUPER_PASS}"

tags:
  nofailover: false
  noloadbalance: false
  clonefrom: false
  nosync: false
EOF

chown postgres:postgres /etc/patroni/config.yaml
chmod 600 /etc/patroni/config.yaml

PATRONI_BIN="$(which patroni)"

cat > /etc/systemd/system/patroni.service <<EOF
[Unit]
Description=Patroni HA PostgreSQL
After=network-online.target etcd.service
Wants=network-online.target

[Service]
Type=simple
User=postgres
Group=postgres
ExecStart=${PATRONI_BIN} /etc/patroni/config.yaml
KillMode=process
TimeoutSec=30
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable patroni
systemctl start patroni

log "Patroni setup complete — ${NODE_NAME} (${NODE_IP})"
