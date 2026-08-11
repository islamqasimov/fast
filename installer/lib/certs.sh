#!/usr/bin/env bash
# F.A.S.T. Wazuh TLS cert generation - T1.2.
#
# Generates self-signed certs at install time so the OpenSearch Security
# plugin in wazuh-indexer and the wazuh-dashboard can initialise their TLS
# layers. Without these files, both containers crash on boot with
# ENOENT / AccessControlException on /etc/wazuh-*/certs/*.pem.
#
# Idempotent: re-running with certs already present is a no-op unless the
# caller passes --force.
#
# Files generated under ${CERTS_DIR}/:
#   root-ca.pem, root-ca.key           - self-signed CA (10-year validity)
#   indexer.pem, indexer-key.pem       - CN=wazuh-indexer
#   dashboard.pem, dashboard-key.pem   - CN=wazuh-dashboard
#   admin.pem, admin-key.pem           - CN=admin (indexer superuser)
#
# Plaintext cert material. Certs/, secrets/, var/, logs/, etc/fast.env
# are gitignored; these certs go under etc/certs/ which is also gitignored.

set -euo pipefail

CERTS_DIR_DEFAULT="${FAST_ROOT:-/home/fast}/etc/certs"

usage() {
  cat <<EOF
Usage: source installer/lib/certs.sh; generate_wazuh_certs [CERTS_DIR] [--force]
EOF
}

# Generate one signed cert from the CA. Args: name, CN
_gen_signed_cert() {
  local name="$1" cn="$2"
  local key="${CERTS_DIR}/${name}-key.pem"
  local csr="${CERTS_DIR}/${name}.csr"
  local ext="${CERTS_DIR}/${name}.ext"
  local crt="${CERTS_DIR}/${name}.pem"

  openssl req -newkey rsa:2048 -nodes \
    -keyout "${key}" \
    -out "${csr}" \
    -subj "/CN=${cn}/O=F.A.S.T./OU=Demo" >/dev/null 2>&1

  cat > "${ext}" <<EOF
subjectAltName=DNS:${cn},DNS:localhost,IP:127.0.0.1
EOF

  openssl x509 -req -in "${csr}" \
    -CA "${CERTS_DIR}/root-ca.pem" \
    -CAkey "${CERTS_DIR}/root-ca.key" \
    -CAcreateserial \
    -out "${crt}" \
    -days 3650 -sha256 \
    -extfile "${ext}" >/dev/null 2>&1

  chmod 600 "${key}"
  chmod 644 "${crt}"
  rm -f "${csr}" "${ext}" "${CERTS_DIR}/root-ca.srl"
}

# Public entry point. Generates certs if missing (or always if --force).
generate_wazuh_certs() {
  local force=false
  local certs_dir="${CERTS_DIR_DEFAULT}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force) force=true; shift ;;
      --help|-h) usage; return 0 ;;
      -*) echo "ERROR: unknown argument: $1" >&2; return 64 ;;
      *) certs_dir="$1"; shift ;;
    esac
  done

  CERTS_DIR="${certs_dir}"

  # Idempotency: if all expected files exist and --force not passed, skip.
  if [[ "${force}" != "true" ]] && \
     [[ -s "${CERTS_DIR}/root-ca.pem" ]] && \
     [[ -s "${CERTS_DIR}/root-ca.key" ]] && \
     [[ -s "${CERTS_DIR}/indexer.pem" ]] && \
     [[ -s "${CERTS_DIR}/indexer-key.pem" ]] && \
     [[ -s "${CERTS_DIR}/dashboard.pem" ]] && \
     [[ -s "${CERTS_DIR}/dashboard-key.pem" ]] && \
     [[ -s "${CERTS_DIR}/admin.pem" ]] && \
     [[ -s "${CERTS_DIR}/admin-key.pem" ]]; then
    return 0
  fi

  command -v openssl >/dev/null || {
    echo "ERROR: openssl not found. Install openssl before running install.sh." >&2
    return 1
  }

  mkdir -p "${CERTS_DIR}"
  chmod 700 "${CERTS_DIR}"

  # Root CA (self-signed, 10-year validity)
  openssl req -x509 -newkey rsa:2048 -days 3650 -nodes \
    -keyout "${CERTS_DIR}/root-ca.key" \
    -out "${CERTS_DIR}/root-ca.pem" \
    -subj "/CN=F.A.S.T. Root CA/O=F.A.S.T./OU=Demo" >/dev/null 2>&1
  chmod 600 "${CERTS_DIR}/root-ca.key"
  chmod 644 "${CERTS_DIR}/root-ca.pem"

  _gen_signed_cert indexer wazuh-indexer
  _gen_signed_cert dashboard wazuh-dashboard
  _gen_signed_cert admin admin
}
