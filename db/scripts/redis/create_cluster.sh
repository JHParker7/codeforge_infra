#!/usr/bin/env bash
set -euo pipefail

# REDIS_NODES: space-separated list of "ip:port" for all cluster members
# REDIS_PASSWORD: cluster password

# Idempotent: skip if a cluster is already formed
FIRST_NODE=$(echo "$REDIS_NODES" | awk '{print $1}')
CLUSTER_INFO=$(redis-cli -h "${FIRST_NODE%%:*}" -p "${FIRST_NODE##*:}" -a "$REDIS_PASSWORD" \
  cluster info 2>/dev/null || true)

if echo "$CLUSTER_INFO" | grep -q "cluster_state:ok"; then
  echo "Redis cluster already formed, skipping create."
  exit 0
fi

redis-cli --cluster create $REDIS_NODES \
  --cluster-replicas 0 \
  -a "$REDIS_PASSWORD" \
  --cluster-yes
