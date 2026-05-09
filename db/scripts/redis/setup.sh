#!/usr/bin/env bash
set -euo pipefail

REDIS_PORT="${REDIS_PORT:-6379}"

apt-get update -qq
apt-get install -y redis-server

mkdir -p /var/lib/redis /var/log/redis
chown redis:redis /var/lib/redis /var/log/redis

sysctl -w vm.overcommit_memory=1
echo 'vm.overcommit_memory = 1' > /etc/sysctl.d/99-redis.conf

cat > /etc/redis/redis.conf << EOF
bind 0.0.0.0
port ${REDIS_PORT}
dir /var/lib/redis
appendonly yes
appendfilename appendonly.aof
appendfsync everysec
requirepass ${REDIS_PASSWORD}
protected-mode yes
loglevel notice
logfile /var/log/redis/redis-server.log
EOF

systemctl enable redis-server
systemctl restart redis-server

for i in $(seq 1 30); do
  redis-cli -p "${REDIS_PORT}" -a "${REDIS_PASSWORD}" ping 2>/dev/null | grep -q PONG && break
  sleep 1
done
