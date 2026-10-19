#!/usr/bin/env bash
# shellcheck shell=bash
# Remote bootstrap entrypoint — public installs use proprietary release artifacts.
#
# Usage:
#   curl -fsSL https://dwiis.dedusoft.com/install.sh | bash
#   curl -fsSL https://dwiis.dedusoft.com/install.sh | bash -s -- --profile backend
#
# Bootstrap installs the dwiis CLI only. Choose a profile afterward:
#   dwiis install --profile backend
#
# Internal Git mode (Dedusoft engineers with private repo access only):
#   bash install.sh --mode git --repo git@github.com:dedusoft/dwiis.git
#
# With integrity verification (recommended):
#   curl -fsSL https://dwiis.dedusoft.com/install.sh -o install.sh
#   curl -fsSL https://dwiis.dedusoft.com/install.sh.sha256 -o install.sh.sha256
#   sha256sum -c install.sh.sha256 && bash install.sh

set -euo pipefail

DWIIS_BOOTSTRAP_VERSION="1.0.0"
DWIIS_INSTALL_ROOT="${DWIIS_INSTALL_ROOT:-/opt/dwiis}"
DWIIS_PROFILE="${DWIIS_PROFILE:-}"
DWIIS_DISTRIBUTION_MODE="${DWIIS_DISTRIBUTION_MODE:-artifact}"
DWIIS_ARTIFACT_BASE_URL="${DWIIS_ARTIFACT_BASE_URL:-https://github.com/dedusoft/dwiis-dist/releases/latest/download}"
DWIIS_DEFAULT_REPO_URL="${DWIIS_REPO_URL:-git@github.com:dedusoft/dwiis.git}"
DWIIS_DEFAULT_BRANCH="${DWIIS_REPO_BRANCH:-main}"

log() { echo "[bootstrap] $*"; }
err() { echo "[bootstrap] ERROR: $*" >&2; }

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profile) DWIIS_PROFILE="$2"; shift 2 ;;
      --mode) DWIIS_DISTRIBUTION_MODE="$2"; shift 2 ;;
      --repo) DWIIS_DEFAULT_REPO_URL="$2"; shift 2 ;;
      --branch) DWIIS_DEFAULT_BRANCH="$2"; shift 2 ;;
      --artifact-url) DWIIS_ARTIFACT_BASE_URL="$2"; shift 2 ;;
      --install-root) DWIIS_INSTALL_ROOT="$2"; shift 2 ;;
      *) err "Unknown argument: $1"; exit 1 ;;
    esac
  done
}

detect_os() {
  if [[ ! -f /etc/os-release ]]; then
    err "Cannot detect OS"
    exit 1
  fi
  # shellcheck source=/dev/null
  source /etc/os-release
  if [[ "${ID:-}" != "ubuntu" ]]; then
    err "This bootstrap supports Ubuntu LTS only (detected: ${ID:-unknown})"
    exit 1
  fi
  case "${VERSION_ID:-}" in
    22.04|24.04|26.04) ;;
    *) err "Unsupported Ubuntu version: ${VERSION_ID:-unknown}. Use 22.04, 24.04, or 26.04 LTS."; exit 1 ;;
  esac
  log "Detected Ubuntu ${VERSION_ID}"
}

check_connectivity() {
  if curl -fsSL --max-time 5 --head "${DWIIS_ARTIFACT_BASE_URL}/VERSION" >/dev/null 2>&1; then
    log "Release server connectivity: OK"
    return 0
  fi
  if curl -fsSL --max-time 5 --head "https://dwiis.dedusoft.com" >/dev/null 2>&1; then
    log "Bootstrap server connectivity: OK"
    return 0
  fi
  if [[ -d "${DWIIS_INSTALL_ROOT}/scripts" ]]; then
    log "No internet — using existing installation at ${DWIIS_INSTALL_ROOT}"
    return 0
  fi
  err "No internet and no local installation found"
  exit 1
}

install_prerequisites() {
  log "Installing prerequisites (sudo required)"
  export DEBIAN_FRONTEND=noninteractive
  sudo apt-get update -y
  sudo apt-get install -y curl ca-certificates ansible python3 tar gzip
  if [[ "${DWIIS_DISTRIBUTION_MODE}" == "git" ]]; then
    sudo apt-get install -y git
  fi
}

verify_artifact_checksum() {
  local archive="$1"
  local checksum_file="$2"
  if [[ ! -f "${checksum_file}" ]]; then
    err "Checksum file missing: ${checksum_file}"
    return 1
  fi
  local expected actual
  expected="$(awk '{print $1}' "${checksum_file}")"
  if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "${archive}" | awk '{print $1}')"
  else
    actual="$(shasum -a 256 "${archive}" | awk '{print $1}')"
  fi
  if [[ "${expected}" != "${actual}" ]]; then
    err "Release artifact checksum mismatch"
    return 1
  fi
  log "Release artifact checksum verified"
}

install_platform_from_artifact() {
  local tmp archive version
  tmp="$(mktemp -d)"
  archive="${tmp}/dwiis-latest.tar.gz"

  log "Downloading DWIIS release from ${DWIIS_ARTIFACT_BASE_URL}"
  curl -fsSL "${DWIIS_ARTIFACT_BASE_URL}/dwiis-latest.tar.gz.sha256" -o "${tmp}/dwiis-latest.tar.gz.sha256"
  curl -fsSL "${DWIIS_ARTIFACT_BASE_URL}/dwiis-latest.tar.gz" -o "${archive}"
  verify_artifact_checksum "${archive}" "${tmp}/dwiis-latest.tar.gz.sha256"

  version="$(curl -fsSL "${DWIIS_ARTIFACT_BASE_URL}/VERSION" 2>/dev/null || echo unknown)"
  log "Installing DWIIS version ${version}"

  if [[ -d "${DWIIS_INSTALL_ROOT}" ]]; then
    sudo mv "${DWIIS_INSTALL_ROOT}" "${DWIIS_INSTALL_ROOT}.bak.$(date +%s)" 2>/dev/null || true
  fi
  sudo mkdir -p /opt
  sudo tar xzf "${archive}" -C /opt
  rm -rf "${tmp}"

  if [[ ! -d "${DWIIS_INSTALL_ROOT}/scripts" ]]; then
    err "Invalid release archive — expected ${DWIIS_INSTALL_ROOT}/scripts"
    exit 1
  fi
  log "Platform extracted to ${DWIIS_INSTALL_ROOT}"
}

install_platform_from_git() {
  if ! command -v git >/dev/null 2>&1; then
    err "git is required for --mode git"
    exit 1
  fi

  if [[ -d "${DWIIS_INSTALL_ROOT}/.git" ]]; then
    log "Updating existing platform at ${DWIIS_INSTALL_ROOT}"
    sudo git -C "${DWIIS_INSTALL_ROOT}" fetch --all --prune
    sudo git -C "${DWIIS_INSTALL_ROOT}" checkout "${DWIIS_DEFAULT_BRANCH}"
    sudo git -C "${DWIIS_INSTALL_ROOT}" pull --ff-only origin "${DWIIS_DEFAULT_BRANCH}" || true
  elif [[ -d "${DWIIS_INSTALL_ROOT}/scripts/install.sh" ]]; then
    log "Using existing platform copy at ${DWIIS_INSTALL_ROOT}"
  else
    log "Cloning private platform repository to ${DWIIS_INSTALL_ROOT}"
    sudo mkdir -p "$(dirname "${DWIIS_INSTALL_ROOT}")"
    sudo git clone -b "${DWIIS_DEFAULT_BRANCH}" "${DWIIS_DEFAULT_REPO_URL}" "${DWIIS_INSTALL_ROOT}"
  fi
}

install_platform_config() {
  sudo mkdir -p /etc/dwiis /var/log/dwiis /var/lib/dwiis

  if [[ "${DWIIS_DISTRIBUTION_MODE}" == "artifact" ]]; then
    if [[ -f "${DWIIS_INSTALL_ROOT}/configs/platform.env.public" ]]; then
      sudo cp "${DWIIS_INSTALL_ROOT}/configs/platform.env.public" /etc/dwiis/platform.env
    fi
  elif [[ ! -f /etc/dwiis/platform.env ]] && [[ -f "${DWIIS_INSTALL_ROOT}/configs/platform.env" ]]; then
    sudo cp "${DWIIS_INSTALL_ROOT}/configs/platform.env" /etc/dwiis/platform.env
  fi
}

install_cli() {
  log "Installing dwiis CLI"
  sudo install -m 755 "${DWIIS_INSTALL_ROOT}/scripts/dwiis" /usr/local/bin/dwiis
}

print_next_steps() {
  local version
  version="$(cat "${DWIIS_INSTALL_ROOT}/VERSION" 2>/dev/null || echo unknown)"
  cat <<EOF

[bootstrap] DWIIS v${version} installed successfully.

Next steps — pick a profile and provision your workstation:

  dwiis install --profile minimal    # Base tooling only
  dwiis install --profile frontend   # Frontend stack
  dwiis install --profile backend    # Backend stack + databases
  dwiis install --profile devops     # DevOps / cloud tooling
  dwiis install --profile full       # Everything

Other commands:

  dwiis verify                       # Check installation
  dwiis status                       # View install state
  dwiis self-update                  # Update platform manually

Each 'dwiis install' checks for the latest release before provisioning.

EOF
}

run_provisioning() {
  log "Starting provisioning (profile=${DWIIS_PROFILE}, mode=${DWIIS_DISTRIBUTION_MODE})"
  sudo \
    SUDO_USER="${SUDO_USER:-${USER}}" \
    DWIIS_REPO_ROOT="${DWIIS_INSTALL_ROOT}" \
    DWIIS_INSTALL_ROOT="${DWIIS_INSTALL_ROOT}" \
    DWIIS_PROFILE="${DWIIS_PROFILE}" \
    DWIIS_DISTRIBUTION_MODE="${DWIIS_DISTRIBUTION_MODE}" \
    DWIIS_ARTIFACT_BASE_URL="${DWIIS_ARTIFACT_BASE_URL}" \
    bash "${DWIIS_INSTALL_ROOT}/scripts/install.sh" --profile "${DWIIS_PROFILE}"
}

main() {
  parse_args "$@"
  detect_os
  check_connectivity
  install_prerequisites

  case "${DWIIS_DISTRIBUTION_MODE}" in
    artifact) install_platform_from_artifact ;;
    git) install_platform_from_git ;;
    *) err "Unknown distribution mode: ${DWIIS_DISTRIBUTION_MODE} (use artifact or git)"; exit 1 ;;
  esac

  install_platform_config
  install_cli

  if [[ -n "${DWIIS_PROFILE}" ]]; then
    run_provisioning
    log "Bootstrap complete. Run 'dwiis verify' to confirm."
  else
    print_next_steps
  fi
}

main "$@"
