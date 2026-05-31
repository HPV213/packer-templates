#!/usr/bin/env bash
# Local CI testing with act (nektos/act)
# Usage: ./local-ci.sh <os-name> [act-options]
# Example: ./local-ci.sh debian-13
#          ./local-ci.sh debian-13 --skip-build  (validate only)

set -eo pipefail

SECRETS_FILE=".secrets"
WORKFLOWS_DIR=".github/workflows"
LOCAL_WORKFLOW="${WORKFLOWS_DIR}/local-ci-test.yml"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <os-name> [--skip-build] [act-options]"
  echo ""
  echo "Options:"
  echo "  --skip-build    Validate only, skip Proxmox build"
  echo ""
  echo "Available OS:"
  ls "${WORKFLOWS_DIR}"/*.yml 2>/dev/null | grep -v packer.yml | grep -v validate | grep -v local-ci | xargs -I{} basename {} .yml | sort
  exit 1
fi

OS_NAME="$1"
shift

SKIP_BUILD=false
ACT_EXTRA_ARGS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --skip-build)
      SKIP_BUILD=true
      shift
      ;;
    *)
      ACT_EXTRA_ARGS+=("$1")
      shift
      ;;
  esac
done

if [ ! -f "${LOCAL_WORKFLOW}" ]; then
  echo "ERROR: Workflow not found: ${LOCAL_WORKFLOW}"
  exit 1
fi

# Auto-detect Docker socket (Colima on macOS)
if [ -z "${DOCKER_HOST:-}" ]; then
  COLIMA_SOCK="$HOME/.colima/default/docker.sock"
  if [ -S "$COLIMA_SOCK" ]; then
    export DOCKER_HOST="unix://${COLIMA_SOCK}"
  fi
fi

if [ "${SKIP_BUILD}" = true ]; then
  echo "Running local CI (validate only): ${OS_NAME}"
  act workflow_dispatch \
    -W "${LOCAL_WORKFLOW}" \
    --input "name=${OS_NAME}" \
    --input "skip-build=true" \
    $(test -f "${SECRETS_FILE}" && echo "--secret-file ${SECRETS_FILE}" || echo "") \
    "${ACT_EXTRA_ARGS[@]}"
else
  if [ ! -f "${SECRETS_FILE}" ]; then
    echo "ERROR: ${SECRETS_FILE} not found. Copy .secrets.example and fill in values:"
    echo "  cp .secrets.example .secrets"
    exit 1
  fi

  echo "Running local CI (full): ${OS_NAME}"
  act workflow_dispatch \
    -W "${LOCAL_WORKFLOW}" \
    --input "name=${OS_NAME}" \
    --input "skip-build=false" \
    --secret-file "${SECRETS_FILE}" \
    "${ACT_EXTRA_ARGS[@]}"
fi
