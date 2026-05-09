CONTROL_PLANE_IP=(
    "192.168.50.138"
    "192.168.50.159"
    "192.168.50.150"
    )
WORKER_IP=(
    "192.168.50.124"
    "192.168.50.170"
    "192.168.50.115"
    )
YOUR_ENDPOINT=k8.jhparker.uk
CLUSTER_NAME=codeforge

talosctl gen secrets -o secrets.yaml
talosctl gen config --with-secrets secrets.yaml $CLUSTER_NAME https://$YOUR_ENDPOINT:6443

for ip in "${CONTROL_PLANE_IP[@]}"; do
  echo "=== Applying configuration to node $ip ==="
  talosctl apply-config --insecure \
    --nodes $ip \
    --file controlplane.yaml
  echo "Configuration applied to $ip"
  echo ""
done

for ip in "${WORKER_IP[@]}"; do
  echo "=== Applying configuration to node $ip ==="
  talosctl apply-config --insecure \
    --nodes $ip \
    --file worker.yaml
  echo "Configuration applied to $ip"
  echo ""
done

talosctl config merge ./talosconfig

mkdir -p ~/.talos
cp ./talosconfig ~/.talos/config
export TALOSCONFIG=~/.talos/config

talosctl config endpoint $CONTROL_PLANE_IP[0] $CONTROL_PLANE_IP[1] $CONTROL_PLANE_IP[2]

for ip in "${CONTROL_PLANE_IP[@]}"; do
    talosctl bootstrap --nodes $ip
done

talosctl kubeconfig --nodes $CONTROL_PLANE_IP[0]
talosctl kubeconfig alternative-kubeconfig --nodes $CONTROL_PLANE_IP[0]
export KUBECONFIG=./alternative-kubeconfig

kubectl get nodes