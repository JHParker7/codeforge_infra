#!/usr/bin/env bash
# Phase 1: Install a minimal NixOS base onto the blank disk via nixos-anywhere.
# Required env vars: NODE_NAME NODE_IP CIDR_PREFIX GATEWAY DNS_SERVER
#                    NIXOS_VERSION SSH_PUBLIC_KEY SSH_PRIVATE_KEY INSTALLER_IP
# Requires on the Terraform host: nixos-anywhere, nix (with flakes enabled)
set -euo pipefail

log() { echo "[$(date +%H:%M:%S)] $*"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="$(mktemp -d)"
KEY_FILE="$(mktemp)"
chmod 600 "${KEY_FILE}"
printf '%s' "${SSH_PRIVATE_KEY}" > "${KEY_FILE}"
trap 'rm -rf "${WORK_DIR}" "${KEY_FILE}"' EXIT

log "Installing NixOS on ${NODE_NAME} — installer: ${INSTALLER_IP}, static: ${NODE_IP}"

# ── Per-node configuration.nix ────────────────────────────────────────────────
cat > "${WORK_DIR}/configuration.nix" << EOF
{ ... }:
{
  imports = [ ./disko.nix ];

  networking = {
    hostName       = "${NODE_NAME}";
    useDHCP        = false;
    nameservers    = [ "${DNS_SERVER}" ];
    defaultGateway = "${GATEWAY}";
    interfaces.eth0.ipv4.addresses = [{
      address      = "${NODE_IP}";
      prefixLength = ${CIDR_PREFIX};
    }];
  };

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin        = "no";
      PasswordAuthentication = false;
    };
  };

  users.users.nixos = {
    isNormalUser = true;
    extraGroups  = [ "wheel" ];
    openssh.authorizedKeys.keys = [ "${SSH_PUBLIC_KEY}" ];
  };

  security.sudo.wheelNeedsPassword = false;

  services.qemuGuest.enable = true;

  system.stateVersion = "${NIXOS_VERSION}";
}
EOF

# ── Flake wrapper ─────────────────────────────────────────────────────────────
cat > "${WORK_DIR}/flake.nix" << EOF
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-${NIXOS_VERSION}";
    disko       = { url = "github:nix-community/disko"; inputs.nixpkgs.follows = "nixpkgs"; };
  };
  outputs = { self, nixpkgs, disko }: {
    nixosConfigurations.node = nixpkgs.lib.nixosSystem {
      system  = "x86_64-linux";
      modules = [ disko.nixosModules.disko ./disko.nix ./configuration.nix ];
    };
  };
}
EOF

cp "${SCRIPT_DIR}/disko.nix" "${WORK_DIR}/"

# ── Install ───────────────────────────────────────────────────────────────────
nixos-anywhere \
  --flake "${WORK_DIR}#node" \
  --ssh-private-key "${KEY_FILE}" \
  nixos@"${INSTALLER_IP}"

log "Waiting for ${NODE_NAME} to come up on ${NODE_IP}"

until ssh \
  -o StrictHostKeyChecking=no \
  -o ConnectTimeout=5 \
  -i "${KEY_FILE}" \
  nixos@"${NODE_IP}" true 2>/dev/null; do
  sleep 10
done

log "NixOS is up on ${NODE_NAME} (${NODE_IP})"
