#!/usr/bin/env bash
# Sets up keepalived (floating VIP) + HAProxy (API load balancer) on a control-plane node.
# HAProxy only binds to the VIP address, so it never conflicts with kube-apiserver on port 6443.
# keepalived's notify script starts haproxy only on the MASTER node.
set -euo pipefail

: "${VIP:?VIP required}"
: "${NODE_IP:?NODE_IP required}"
: "${PRIORITY:?PRIORITY required}"
: "${CP1_IP:?CP1_IP required}"
: "${CP2_IP:?CP2_IP required}"
: "${CP3_IP:?CP3_IP required}"

INTERFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '/dev/{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}' | head -1)
VRRP_STATE=$([ "${PRIORITY}" -eq 101 ] && echo "MASTER" || echo "BACKUP")

echo "==> Installing HAProxy and keepalived..."
apt-get install -y -qq haproxy keepalived

echo "==> Configuring HAProxy (binds only to VIP ${VIP})..."
cat > /etc/haproxy/haproxy.cfg <<EOF
global
    log /dev/log local0
    maxconn 2048

defaults
    mode    tcp
    log     global
    option  tcplog
    timeout connect 5s
    timeout client  30s
    timeout server  30s

frontend k8s-apiserver
    bind ${VIP}:6443
    default_backend k8s-controlplane

backend k8s-controlplane
    option  tcp-check
    balance roundrobin
    server  cp-1 ${CP1_IP}:6443 check fall 3 rise 2
    server  cp-2 ${CP2_IP}:6443 check fall 3 rise 2
    server  cp-3 ${CP3_IP}:6443 check fall 3 rise 2
EOF

# Prevent haproxy from auto-starting; keepalived controls it via notify script.
systemctl disable haproxy 2>/dev/null || true
systemctl stop haproxy 2>/dev/null || true

echo "==> Writing keepalived notify script..."
cat > /etc/keepalived/notify.sh <<'NOTIFY'
#!/bin/bash
# $3 = MASTER | BACKUP | FAULT
case "$3" in
  MASTER) systemctl start  haproxy ;;
  BACKUP) systemctl stop   haproxy 2>/dev/null || true ;;
  FAULT)  systemctl stop   haproxy 2>/dev/null || true ;;
esac
NOTIFY
chmod +x /etc/keepalived/notify.sh

echo "==> Writing keepalived config (state=${VRRP_STATE}, priority=${PRIORITY})..."
cat > /etc/keepalived/keepalived.conf <<EOF
global_defs {
    router_id k8s_lb
    script_user root
    enable_script_security
}

vrrp_instance VI_1 {
    state               ${VRRP_STATE}
    interface           ${INTERFACE}
    virtual_router_id   51
    priority            ${PRIORITY}
    advert_int          1

    unicast_src_ip      ${NODE_IP}
    unicast_peer {
EOF

for PEER in "${CP1_IP}" "${CP2_IP}" "${CP3_IP}"; do
    [ "${PEER}" != "${NODE_IP}" ] && echo "        ${PEER}" >> /etc/keepalived/keepalived.conf
done

cat >> /etc/keepalived/keepalived.conf <<EOF
    }

    authentication {
        auth_type PASS
        auth_pass k8s_vrrp_2024
    }

    virtual_ipaddress {
        ${VIP}
    }

    notify /etc/keepalived/notify.sh
}
EOF

systemctl enable keepalived
systemctl restart keepalived

echo "==> keepalived started. Waiting 4 s for VIP election..."
sleep 4

if ip addr show | grep -q "${VIP}"; then
    echo "==> This node holds the VIP — HAProxy should be starting."
else
    echo "==> This node is a BACKUP — HAProxy intentionally not running."
fi

echo "==> HAProxy + keepalived setup complete."
