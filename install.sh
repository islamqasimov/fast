#!/usr/bin/env bash
# F.A.S.T. installer - T1.2.5 / T4.3 cron support.
#
# Usage:
#   ./install.sh --mode interactive          # default
#   ./install.sh --mode unattended --yes
#   ./install.sh --mode unattended --no-cron
#
# Idempotent: re-running without flag changes is a no-op.
# See ../knowledge.md §4 for the contract.

set -euo pipefail

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
FAST_ROOT="$(cd "$(dirname "$0")" && pwd)"
SECRETS_DIR="${FAST_ROOT}/secrets"
LOGS_DIR="${FAST_ROOT}/logs"
LOG_FILE="${LOGS_DIR}/installer.log"
LIB_DIR="${FAST_ROOT}/installer/lib"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
MODE="interactive"
ASSUME_YES=false
INSTALL_CRON=true
EXPOSE_DASHBOARD=false
TALON_UI_PASSWORD_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="${2:-}"; shift 2 ;;
    --mode=*)
      MODE="${1#*=}"; shift ;;
    --yes|-y)
      ASSUME_YES=true; shift ;;
    --no-cron)
      INSTALL_CRON=false; shift ;;
    --expose-dashboard)
      EXPOSE_DASHBOARD=true; shift ;;
    --talon-ui-password)
      TALON_UI_PASSWORD_OVERRIDE="${2:-}"; shift 2 ;;
    --help|-h)
      sed -n '2,11p' "$0"; exit 0 ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      exit 64
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
mkdir -p "${LOGS_DIR}"
log() {
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '[%s] %s\n' "${ts}" "$*" | tee -a "${LOG_FILE}" >&2
}

die() {
  log "FATAL: $*"
  exit 1
}

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------
command -v docker >/dev/null || die "docker not found. Install Docker Engine 24.x first."
command -v git    >/dev/null || die "git not found."
command -v openssl >/dev/null || die "openssl not found."
docker compose version >/dev/null 2>&1 || die "docker compose v2 not available. Install the docker-compose-plugin."

log "pre-flight OK (mode=${MODE}, cron=${INSTALL_CRON})"

# ---------------------------------------------------------------------------
# Step 1 - secrets (T1.3)
# ---------------------------------------------------------------------------
# shellcheck source=installer/lib/secrets.sh
source "${LIB_DIR}/secrets.sh"

generate_all_secrets "${SECRETS_DIR}" "${TALON_UI_PASSWORD_OVERRIDE}"
log "secrets present and policy-validated"

# ---------------------------------------------------------------------------
# Step 2 - .env file (T1.2.3)
# ---------------------------------------------------------------------------
if [[ ! -f "${FAST_ROOT}/etc/fast.env" ]]; then
  cp "${FAST_ROOT}/etc/fast.env.example" "${FAST_ROOT}/etc/fast.env"
  log "copied etc/fast.env.example -> etc/fast.env"
fi

# ---------------------------------------------------------------------------
# Step 2a - populate plaintext password vars in etc/fast.env (T1.2.3, T1.3)
# Wazuh's manager and dashboard entrypoints do not support _FILE suffix for
# INDEXER_PASSWORD / DASHBOARD_PASSWORD / API_PASSWORD - they only read
# plaintext env vars. We copy the values from secrets/*.password into
# etc/fast.env after generation so compose --env-file can interpolate them.
# etc/fast.env is gitignored and mode 0600; the plaintext never enters git.
# ---------------------------------------------------------------------------
_env_set() {
  local key="$1" file="$2" env_file="${FAST_ROOT}/etc/fast.env"
  local val
  val="$(cat "${file}")"
  # Replace the value if the key exists, otherwise append.
  if grep -q -E "^${key}=" "${env_file}"; then
    # In-place edit using sed with a unique delimiter (password may contain /).
    sed -i.bak -E "s|^${key}=.*$|${key}=${val}|" "${env_file}"
    rm -f "${env_file}.bak"
  else
    printf '%s=%s\n' "${key}" "${val}" >> "${env_file}"
  fi
}
_env_set WAZUH_INDEXER_PASSWORD  "${SECRETS_DIR}/wazuh_indexer_password"
_env_set WAZUH_DASHBOARD_PASSWORD "${SECRETS_DIR}/wazuh_admin_password"
_env_set WAZUH_API_PASSWORD       "${SECRETS_DIR}/wazuh_api_password"
chmod 600 "${FAST_ROOT}/etc/fast.env"
log "populated plaintext password vars in etc/fast.env (mode 0600)"

# ---------------------------------------------------------------------------
# Step 2b - Wazuh TLS certs (T1.2.7)
# The OpenSearch Security plugin in wazuh-indexer and the wazuh-dashboard
# both require /etc/wazuh-*/certs/*.pem files at boot, even with
# DISABLE_SECURITY_PLUGIN=true. Generate them once here so compose up has
# them mounted. Idempotent: re-runs are no-ops.
# ---------------------------------------------------------------------------
# shellcheck source=installer/lib/certs.sh
source "${LIB_DIR}/certs.sh"
generate_wazuh_certs "${FAST_ROOT}/etc/certs"
log "wazuh TLS certs present at etc/certs/"

# ---------------------------------------------------------------------------
# Step 3 - cron entry (T4.3)
# ---------------------------------------------------------------------------
if [[ "${INSTALL_CRON}" == "true" ]]; then
  # shellcheck source=installer/lib/cron.sh
  source "${LIB_DIR}/cron.sh"
  install_talon_cron "${FAST_ROOT}"
  log "cron entry installed at /etc/cron.d/talon"
else
  log "cron install skipped (--no-cron)"
fi

# ---------------------------------------------------------------------------
# Step 4 - host firewall (T1.3 final). Talon is the only container with
# outbound access; iptables rules enforce this. Idempotent.
# ---------------------------------------------------------------------------
# shellcheck source=installer/lib/firewall.sh
source "${LIB_DIR}/firewall.sh"
install_firewall_rules
log "host firewall rules installed (talon-only outbound)"

# ---------------------------------------------------------------------------
# Step 5 - pull images and start the stack (T1.2.6).
# Bails out non-zero on failure; the partial rollback is in installer/lib/rollback.sh.
# ---------------------------------------------------------------------------
log "starting docker compose stack..."
docker compose -f "${FAST_ROOT}/compose/docker-compose.yml" \
  --env-file "${FAST_ROOT}/etc/fast.env" \
  up -d --remove-orphans

log "FAST install complete"
log "next: run bin/fast status to verify health"
