#!/usr/bin/env bash
# Required env vars: NODE_NAME NODE_IP ETCD_CLUSTER ETCD_HOSTS
#                    PG_SCOPE PG_SUPER_PASS PG_REPL_PASS PG_VERSION ETCD_VERSION
set -euo pipefail

PG_VERSION="${PG_VERSION:-16}"
ETCD_VERSION="${ETCD_VERSION:-3.5.12}"
TIMEZONE="${TIMEZONE:-Europe/London}"

log() { echo "[$(date +%H:%M:%S)] $*"; }

# ── Time sync ─────────────────────────────────────────────────────────────────
log "Configuring timezone and NTP"
timedatectl set-timezone "${TIMEZONE}"
timedatectl set-ntp true

# ── PostgreSQL ─────────────────────────────────────────────────────────────────
log "Installing PostgreSQL ${PG_VERSION}"
apt-get update -qq
apt-get install -y curl ca-certificates postgresql-common
/usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y

apt-get install -y "postgresql-${PG_VERSION}" libpq-dev python3-pip python3-dev python3-venv

# Patroni manages the cluster; disable the default unit and wipe the auto-initialized
# data dir so Patroni controls initdb (or clones from the primary on non-seed nodes).
systemctl stop postgresql || true
systemctl disable postgresql || true
rm -rf "/var/lib/postgresql/${PG_VERSION}/main"

# ── etcd ──────────────────────────────────────────────────────────────────────
log "Installing etcd ${ETCD_VERSION}"
ETCD_TAR="etcd-v${ETCD_VERSION}-linux-amd64.tar.gz"
curl -fsSL "https://github.com/etcd-io/etcd/releases/download/v${ETCD_VERSION}/${ETCD_TAR}" \
  -o "/tmp/${ETCD_TAR}"
tar -xzf "/tmp/${ETCD_TAR}" -C /tmp
install -m 755 "/tmp/etcd-v${ETCD_VERSION}-linux-amd64/etcd"    /usr/local/bin/etcd
install -m 755 "/tmp/etcd-v${ETCD_VERSION}-linux-amd64/etcdctl" /usr/local/bin/etcdctl
rm -rf "/tmp/etcd-v${ETCD_VERSION}-linux-amd64" "/tmp/${ETCD_TAR}"

useradd --system --home /var/lib/etcd --shell /bin/false etcd 2>/dev/null || true
mkdir -p /var/lib/etcd
chown etcd:etcd /var/lib/etcd

mkdir -p /etc/etcd
cat > /etc/etcd/etcd.env << EOF
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

cat > /etc/systemd/system/etcd.service << 'UNIT'
[Unit]
Description=etcd
After=network.target

[Service]
Type=notify
User=etcd
EnvironmentFile=/etc/etcd/etcd.env
ExecStart=/usr/local/bin/etcd
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable etcd
systemctl start etcd

# ── Patroni ───────────────────────────────────────────────────────────────────
log "Installing Patroni"

apt install -y python3-pip python3-dev libpq-dev python3-venv   

python3 -m venv /opt/patroni-venv
/opt/patroni-venv/bin/pip install patroni[etcd3] psycopg2-binary
chown -R postgres:postgres /opt/patroni-venv

mkdir -p /etc/patroni
cat > /etc/patroni/patroni.yml << EOF
scope: ${PG_SCOPE}
name: ${NODE_NAME}
namespace: /db/

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
    - host replication replicator 192.168.50.0/24 scram-sha-256
    - host all all 192.168.50.0/24 scram-sha-256

postgresql:
  listen: 0.0.0.0:5432
  connect_address: ${NODE_IP}:5432
  data_dir: /var/lib/postgresql/${PG_VERSION}/main
  bin_dir: /usr/lib/postgresql/${PG_VERSION}/bin
  authentication:
    replication:
      username: replicator
      password: ${PG_REPL_PASS}
    superuser:
      username: postgres
      password: ${PG_SUPER_PASS}

tags:
  nofailover: false
  noloadbalance: false
  clonefrom: false
  nosync: false
EOF
chown postgres:postgres /etc/patroni/patroni.yml
chmod 640 /etc/patroni/patroni.yml

cat > /etc/systemd/system/patroni.service << 'UNIT'
[Unit]
Description=Patroni PostgreSQL HA
After=network.target etcd.service

[Service]
Type=simple
User=postgres
ExecStart=/opt/patroni-venv/bin/patroni /etc/patroni/patroni.yml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

chown postgres:postgres /etc/patroni/patroni.yml
chmod 640 /etc/patroni/patroni.yml
chmod 755 /etc/patroni

systemctl daemon-reload
systemctl enable patroni
systemctl start patroni

log "Patroni setup complete — ${NODE_NAME} (${NODE_IP})"
