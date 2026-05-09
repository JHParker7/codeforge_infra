# codeforge-infra

Terraform for the Codeforge homelab, targeting a 3-node Proxmox cluster (`hades`, `zeus`, `poseidon`).

## Layout

```
.
├── k8/   — Talos Kubernetes cluster (3 control planes + 3 workers)
└── db/   — Database layer (Patroni/PostgreSQL + Redis Cluster + HAProxy)
```

Each directory is an independent Terraform root with its own state.

---

## k8

Six Talos VMs spread across Proxmox nodes: `k8s-cp-{1,2,3}` and `k8s-worker-{1,2,3}`.

The Talos image is built via the Talos image factory with the `qemu-guest-agent` extension so Proxmox can report VM IPs.

### State

HTTP backend at `http://localhost:8081/state/codeforge_infra`.  
Set `TF_HTTP_USERNAME` and `TF_HTTP_PASSWORD` before running.

### Variables (`k8/variables.tf`)

| Variable | Default | Description |
|---|---|---|
| `proxmox_nodes` | `["pve"]` | Proxmox nodes to spread VMs across |
| `vm_id_base` | `200` | Starting VM ID; CPs get `base+0..2`, workers `base+3..5` |
| `talos_version` | `1.13.0` | Talos release |
| `datastore` | `local-lvm` | Proxmox datastore for disks |
| `iso_datastore` | `local` | Proxmox datastore for the Talos ISO |
| `network_bridge` | `vmbr0` | Proxmox network bridge |
| `cp_cores` / `cp_memory_gb` / `cp_disk_gb` | `2` / `4` / `50` | Control plane sizing |
| `worker_cores` / `worker_memory_gb` / `worker_disk_gb` | `8` / `8` / `100` | Worker sizing |

### Deploy

```bash
cd k8
terraform init
terraform apply
```

---

## db

Three Ubuntu VMs (`pg-1`, `pg-2`, `pg-3`) cloned from a cloud-init template, each running:

- **etcd** — distributed lock manager for Patroni
- **PostgreSQL 18** managed by **Patroni** — single primary with streaming replication
- **Redis 7** in cluster mode — 3 primaries, no replicas
- **HAProxy** — single endpoint routing for both PostgreSQL and Redis

### State

HTTP backend at `http://localhost:8081/state/codeforge_db`.  
Set `TF_HTTP_USERNAME` and `TF_HTTP_PASSWORD` before running.

### Ports

| Port | Service |
|---|---|
| `5432` | PostgreSQL (direct) |
| `8008` | Patroni REST API |
| `6379` | Redis (direct) |
| `5000` | HAProxy → PostgreSQL primary (read-write) |
| `5001` | HAProxy → PostgreSQL replicas (read-only, round-robin) |
| `6380` | HAProxy → Redis cluster (round-robin) |
| `7000` | HAProxy stats (`http://<ip>:7000/`) |

Connect applications to any node on ports `5000`/`5001`/`6380` — HAProxy health-checks backends and routes correctly regardless of which node holds the primary role.

### Provisioning phases

1. **VM creation** — Proxmox clones the Ubuntu template and applies cloud-init (static IP, SSH key, hostname)
2. **Patroni setup** (`scripts/patroni/setup.sh`) — installs etcd, PostgreSQL, and Patroni; configures and starts all three services
3. **Redis setup** (`scripts/redis/setup.sh`) — installs Redis in cluster mode; configures per-node with announce IP
4. **Redis cluster init** (`scripts/redis/create_cluster.sh`) — runs once from `pg-1` to form the cluster (idempotent)
5. **HAProxy setup** (`scripts/haproxy/setup.sh`) — installs HAProxy and writes config pointing at all three nodes

### Prerequisites

- Ubuntu cloud-init template present on Proxmox (set `pg_template_vm_id` and `pg_template_proxmox_node`)
- SSH key with access to the template's default user

### Variables (`db/patroni_variables.tf`, `db/redis_variables.tf`, `db/haproxy_variables.tf`)

| Variable | Default | Description |
|---|---|---|
| `pg_template_vm_id` | — | VM ID of the Ubuntu cloud-init template |
| `pg_template_proxmox_node` | — | Proxmox node hosting the template |
| `pg_ips` | — | Static IPs for the 3 VMs |
| `pg_network_gateway` | — | Default gateway |
| `pg_dns_server` | `8.8.8.8` | DNS server |
| `pg_username` | `ubuntu` | SSH user on provisioned VMs |
| `pg_ssh_public_key` | `""` | SSH public key injected via cloud-init |
| `pg_ssh_private_key_path` | `~/.ssh/id_rsa` | Local path used for provisioning |
| `pg_version` | `16` | PostgreSQL major version |
| `pg_cluster_name` | `postgres` | Patroni scope name |
| `pg_superuser_password` | — | PostgreSQL superuser password |
| `pg_replication_password` | — | Patroni replication user password |
| `etcd_version` | `3.5.12` | etcd release |
| `timezone` | `Europe/London` | VM timezone |
| `redis_password` | — | Redis `requirepass` / `masterauth` |
| `redis_port` | `6379` | Redis client port |
| `haproxy_pg_primary_port` | `5000` | HAProxy primary frontend port |
| `haproxy_pg_replica_port` | `5001` | HAProxy replica frontend port |
| `haproxy_redis_port` | `6380` | HAProxy Redis frontend port |
| `haproxy_stats_port` | `7000` | HAProxy stats page port |

### Deploy

```bash
cd db
terraform init
terraform apply
```

### Check cluster health

```bash
# Patroni — expect one master and two replica
for ip in 192.168.50.191 192.168.50.192 192.168.50.193; do
  role=$(curl -s http://$ip:8008 | python3 -c "import sys,json; print(json.load(sys.stdin)['role'])" 2>/dev/null || echo unreachable)
  echo "$ip: $role"
done

# Redis cluster
redis-cli -h 192.168.50.191 -p 6379 -a <password> cluster info | grep cluster_state
```
