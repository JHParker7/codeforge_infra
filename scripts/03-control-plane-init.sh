#!/usr/bin/env bash
# Initialises the first control-plane node and writes join scripts to /tmp/.
# Runs only on cp-1.
set -euo pipefail

: "${VIP:?}"
: "${TOKEN:?}"
: "${CERT_KEY:?}"
: "${POD_CIDR:=192.168.0.0/16}"
: "${SERVICE_CIDR:=10.96.0.0/12}"
: "${CALICO_VERSION:=3.29.0}"

NODE_IP=$(hostname -I | awk '{print $1}')

echo "==> Running kubeadm init (endpoint=${VIP}:6443, node-ip=${NODE_IP})..."
kubeadm init \
  --control-plane-endpoint "${VIP}:6443" \
  --pod-network-cidr       "${POD_CIDR}" \
  --service-cidr           "${SERVICE_CIDR}" \
  --token                  "${TOKEN}" \
  --certificate-key        "${CERT_KEY}" \
  --upload-certs \
  --apiserver-advertise-address "${NODE_IP}" \
  --cri-socket unix:///var/run/containerd/containerd.sock \
  --node-name "$(hostname -s)" \
  2>&1 | tee /var/log/kubeadm-init.log

echo "==> Setting up kubectl for ubuntu user..."
mkdir -p /home/ubuntu/.kube
cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config

echo "==> Installing Calico ${CALICO_VERSION}..."
KUBECONFIG=/etc/kubernetes/admin.conf \
kubectl apply -f \
  "https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VERSION}/manifests/calico.yaml"

echo "==> Waiting for API server to accept connections..."
for i in $(seq 1 30); do
  KUBECONFIG=/etc/kubernetes/admin.conf kubectl get nodes &>/dev/null && break
  echo "  attempt $i/30 — sleeping 10s..."
  sleep 10
done

echo "==> Extracting CA cert hash..."
CA_HASH=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt \
  | openssl rsa -pubin -outform der 2>/dev/null \
  | openssl dgst -sha256 -hex \
  | awk '{print $2}')

echo "==> Writing /tmp/cp-join.sh..."
cat > /tmp/cp-join.sh <<EOF
#!/usr/bin/env bash
set -euo pipefail
kubeadm join ${VIP}:6443 \\
  --token                          ${TOKEN} \\
  --discovery-token-ca-cert-hash   sha256:${CA_HASH} \\
  --control-plane \\
  --certificate-key                ${CERT_KEY} \\
  --cri-socket unix:///var/run/containerd/containerd.sock \\
  --node-name "\$(hostname -s)"
mkdir -p /home/ubuntu/.kube
cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config
EOF

echo "==> Writing /tmp/worker-join.sh..."
cat > /tmp/worker-join.sh <<EOF
#!/usr/bin/env bash
set -euo pipefail
kubeadm join ${VIP}:6443 \\
  --token                        ${TOKEN} \\
  --discovery-token-ca-cert-hash sha256:${CA_HASH} \\
  --cri-socket unix:///var/run/containerd/containerd.sock \\
  --node-name "\$(hostname -s)"
EOF

chmod +x /tmp/cp-join.sh /tmp/worker-join.sh

echo "==> Control-plane init complete. CA hash: sha256:${CA_HASH}"
