#!/usr/bin/env bash
# F.A.S.T. host firewall - T1.3 final.
#
# Enforces "only the talon container has outbound access" at the iptables
# level. Idempotent: removes any prior fast_* chains before recreating them.
#
# Run only as root. install.sh sources this after the secrets step.

set -euo pipefail

install_firewall_rules() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: firewall rules require root; rerun install.sh with sudo." >&2
    return 1
  fi

  # Resolve the talon container's IP via docker inspect. If the container is
  # not running yet, skip and warn - the next install.sh run will pick it up.
  local talon_ip
  talon_ip="$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' fast-talon 2>/dev/null || true)"
  if [[ -z "${talon_ip}" ]]; then
    echo "WARN: talon container not up yet; firewall rules set on next install." >&2
    return 0
  fi

  # Drop existing fast_* chains if present.
  iptables -nL FAST_OUTBOUND >/dev/null 2>&1 && iptables -F FAST_OUTBOUND
  iptables -nL FAST_OUTBOUND >/dev/null 2>&1 || iptables -N FAST_OUTBOUND

  # Allow outbound from the talon container only.
  iptables -A FAST_OUTBOUND -s "${talon_ip}/32" -j ACCEPT
  # Drop everything else from the fast_net subnet.
  iptables -A FAST_OUTBOUND -s 172.20.0.0/16 -j DROP

  # Insert at the top of FORWARD so the rule wins.
  iptables -C FORWARD -j FAST_OUTBOUND 2>/dev/null || iptables -I FORWARD 1 -j FAST_OUTBOUND
}
