#!/usr/bin/env bash
# F.A.S.T. cron install - T4.3.
#
# Idempotent: rewrites /etc/cron.d/talon on every install. Never duplicates.

set -euo pipefail

install_talon_cron() {
  local fast_root="$1"
  local env_file="${fast_root}/etc/fast.env"
  local hour minute
  hour="$(grep -E '^TALON_CRON_HOUR=' "${env_file}" | cut -d= -f2 | tr -d '\r')"
  minute="$(grep -E '^TALON_CRON_MINUTE=' "${env_file}" | cut -d= -f2 | tr -d '\r')"
  # Jitter window: ±15 minutes. The exact minute is randomised at install time
  # and pinned by writing the literal minute into the cron file.
  local jitter_minute
  jitter_minute=$(( (RANDOM % 31) - 15 ))
  local actual_minute=$(( (10#${minute} + jitter_minute + 60) % 60 ))

  local cron_file="/etc/cron.d/talon"
  local user="${SUDO_USER:-${USER:-root}}"

  # Compose the cron entry. `nice -n 10` keeps the daily run from
  # contending with foreground work.
  cat > "${cron_file}" <<EOF
# F.A.S.T. - T.A.L.O.N. daily IOC pipeline (installed by installer/install.sh).
# Do not edit by hand; rerun install.sh to regenerate.
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
${actual_minute} ${hour} * * * ${user} cd ${fast_root} && ${hour}>=0 TALON_MODE=online ./bin/fast run-talon >> /var/log/talon-cron.log 2>&1
EOF
  chmod 644 "${cron_file}"
  # cron.d files must not be group/other writable.
  chown root:root "${cron_file}"
}

remove_talon_cron() {
  rm -f /etc/cron.d/talon
}
