#!/usr/bin/env bash
# F.A.S.T. secret generation - T1.3.1.
#
# Generates passwords that meet the policy:
#   - length >= 20
#   - contains at least 3 of: lower / upper / digit / symbol
# Rejects any password that fails the check.
#
# Plaintext never lives in etc/fast.env. References are by file path.

set -euo pipefail

# Lowercase, uppercase, digit, symbol, length 20-32.
_password_meets_policy() {
  local pwd="$1"
  [[ "${#pwd}" -ge 20 ]] || return 1
  local classes=0
  [[ "${pwd}" =~ [a-z] ]] && classes=$((classes + 1))
  [[ "${pwd}" =~ [A-Z] ]] && classes=$((classes + 1))
  [[ "${pwd}" =~ [0-9] ]] && classes=$((classes + 1))
  [[ "${pwd}" =~ [^a-zA-Z0-9] ]] && classes=$((classes + 1))
  [[ "${classes}" -ge 3 ]] || return 1
  return 0
}

# Generate a password, retry if it fails policy.
_generate_password() {
  local attempts=0
  local pwd
  while [[ "${attempts}" -lt 5 ]]; do
    pwd="$(openssl rand -base64 24)"
    if _password_meets_policy "${pwd}"; then
      printf '%s' "${pwd}"
      return 0
    fi
    attempts=$((attempts + 1))
  done
  echo "ERROR: could not generate a policy-valid password after 5 attempts" >&2
  return 1
}

# Generate a single secret file if missing or empty.
_write_secret_if_missing() {
  local secrets_dir="$1"
  local name="$2"
  local file="${secrets_dir}/${name}"
  if [[ -s "${file}" ]]; then
    # File exists and is non-empty. Re-validate.
    local existing
    existing="$(cat "${file}")"
    if _password_meets_policy "${existing}"; then
      return 0
    fi
    echo "ERROR: existing secret ${name} fails policy. Refusing to overwrite." >&2
    return 1
  fi
  mkdir -p "${secrets_dir}"
  chmod 700 "${secrets_dir}"
  _generate_password > "${file}"
  chmod 600 "${file}"
}

# Public entry point. Required secrets for week 1.
generate_all_secrets() {
  local secrets_dir="$1"
  local talon_ui_override="${2:-}"

  _write_secret_if_missing "${secrets_dir}" "wazuh_indexer_password"
  _write_secret_if_missing "${secrets_dir}" "wazuh_admin_password"
  _write_secret_if_missing "${secrets_dir}" "wazuh_api_password"
  _write_secret_if_missing "${secrets_dir}" "talon_api_token"

  if [[ -n "${talon_ui_override}" ]]; then
    printf '%s' "${talon_ui_override}" > "${secrets_dir}/talon_ui_password"
    chmod 600 "${secrets_dir}/talon_ui_password"
  else
    _write_secret_if_missing "${secrets_dir}" "talon_ui_password"
  fi
}
