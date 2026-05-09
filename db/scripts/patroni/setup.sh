#!/usr/bin/env bash
# Required env vars: NODE_NAME NODE_IP ETCD_CLUSTER ETCD_HOSTS
#                    PG_SCOPE PG_SUPER_PASS PG_REPL_PASS PG_VERSION ETCD_VERSION
set -euo pipefail

PG_VERSION="${PG_VERSION:-16}"

log() { echo "[$(date +%H:%M:%S)] $*"; }

# ── Write NixOS patroni module ─────────────────────────────────────────────────
log "Writing NixOS configuration for ${NODE_NAME} (${NODE_IP})"

cat > /etc/nixos/patroni-node.nix << EOF
{ pkgs, ... }:
{
  services.etcd = {
    enable                   = true;
    name                     = "${NODE_NAME}";
    dataDir                  = "/var/lib/etcd";
    listenPeerUrls           = "http://${NODE_IP}:2380";
    listenClientUrls         = "http://${NODE_IP}:2379,http://127.0.0.1:2379";
    initialAdvertisePeerUrls = "http://${NODE_IP}:2380";
    advertiseClientUrls      = "http://${NODE_IP}:2379";
    initialCluster           = "${ETCD_CLUSTER}";
    initialClusterToken      = "pg-etcd-cluster";
    initialClusterState      = "new";
  };

  services.patroni = {
    enable            = true;
    scope             = "${PG_SCOPE}";
    name              = "${NODE_NAME}";
    nodeIp            = "${NODE_IP}";
    postgresqlPackage = pkgs."postgresql_${PG_VERSION}";

    settings = {
      restapi = {
        listen          = "${NODE_IP}:8008";
        connect_address = "${NODE_IP}:8008";
      };

      etcd3.hosts = "${ETCD_HOSTS}";

      bootstrap = {
        dcs = {
          ttl                     = 30;
          loop_wait               = 10;
          retry_timeout           = 10;
          maximum_lag_on_failover = 1048576;
          postgresql = {
            use_pg_rewind = true;
            parameters = {
              wal_level             = "replica";
              hot_standby           = "on";
              max_wal_senders       = 10;
              max_replication_slots = 10;
            };
          };
        };
        initdb = [ { encoding = "UTF8"; } "data-checksums" ];
        pg_hba = [
          "host replication replicator 0.0.0.0/0 scram-sha-256"
          "host all all 0.0.0.0/0 scram-sha-256"
        ];
      };

      postgresql = {
        listen          = "0.0.0.0:5432";
        connect_address = "${NODE_IP}:5432";
        authentication = {
          replication = {
            username = "replicator";
            password = "${PG_REPL_PASS}";
          };
          superuser = {
            username = "postgres";
            password = "${PG_SUPER_PASS}";
          };
        };
      };

      tags = {
        nofailover    = false;
        noloadbalance = false;
        clonefrom     = false;
        nosync        = false;
      };
    };
  };
}
EOF

# ── Add module to NixOS imports if not already present ────────────────────────
if ! grep -q "patroni-node.nix" /etc/nixos/configuration.nix; then
  sed -i 's|imports = \[|imports = [\n    ./patroni-node.nix|' /etc/nixos/configuration.nix
fi

# ── Apply configuration ────────────────────────────────────────────────────────
log "Applying NixOS configuration"
nixos-rebuild switch

log "Patroni setup complete — ${NODE_NAME} (${NODE_IP})"
