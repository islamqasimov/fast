# F.A.S.T. - one-shot VM setup
#
# Run on a fresh Ubuntu 22.04 or 24.04 VM. Install Docker, clone the repo,
# kick off the installer. Designed for the capstone demo rig.
#
# Usage (from the VM, as a non-root user with sudo):
#   curl -L https://raw.githubusercontent.com/<team>/fast/dev/setup-vm.sh | bash
# or after cloning:
#   ./setup-vm.sh
#
# This script is idempotent. Re-running is a no-op.

set -euo pipefail

log() { printf '[setup-vm] %s\n' "$*" >&2; }

FAST_REPO="${FAST_REPO:-https://github.com/<team>/fast.git}"
FAST_BRANCH="${FAST_BRANCH:-dev}"
FAST_HOME="${FAST_HOME:-$HOME/fast}"

# ---------------------------------------------------------------------------
# 1. Install Docker if missing
# ---------------------------------------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
  log "installing Docker Engine..."
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "${USER}"
  log "Docker installed. You may need to log out and back in for the docker group to apply."
  log "Re-run this script after logging back in."
  exit 0
fi

if ! docker compose version >/dev/null 2>&1; then
  log "ERROR: docker compose v2 not available. Install the docker-compose-plugin."
  exit 1
fi

# ---------------------------------------------------------------------------
# 2. Clone the repo
# ---------------------------------------------------------------------------
if [[ ! -d "${FAST_HOME}" ]]; then
  log "cloning ${FAST_REPO} (branch ${FAST_BRANCH}) into ${FAST_HOME}"
  git clone --branch "${FAST_BRANCH}" "${FAST_REPO}" "${FAST_HOME}"
else
  log "repo already present at ${FAST_HOME}; pulling latest"
  (cd "${FAST_HOME}" && git pull --ff-only)
fi

cd "${FAST_HOME}"

# ---------------------------------------------------------------------------
# 3. Run the installer
# ---------------------------------------------------------------------------
log "running install.sh (non-interactive, cron enabled)"
sudo ./install.sh --mode unattended --yes

# ---------------------------------------------------------------------------
# 4. Verify
# ---------------------------------------------------------------------------
log "running bin/fast status"
bin/fast status

log "next steps:"
log "  - open https://<vm-ip> in a browser (use --expose-dashboard flag if needed)"
log "  - run bin/fast demo to validate the four simulations"
log "  - inspect the T.A.L.O.N. dashboard at http://127.0.0.1:9516 (run with --expose-talon-dashboard)"
