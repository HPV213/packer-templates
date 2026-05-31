#!/usr/bin/env bash
# Local CI testing with act (nektos/act)
# Usage: ./local-ci.sh <os-name> [act-options]
# Example: ./local-ci.sh debian-13
#          ./local-ci.sh ubuntu-24.04 --verbose

set -euo pipefail

SECRETS_FILE=".secrets"
WORKFLOWS_DIR=".github/workflows"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <os-name> [act-options]"
  echo ""
  echo "Available OS:"
  ls "${WORKFLOWS_DIR}"/*.yml 2>/dev/null | grep -v packer.yml | grep -v validate | xargs -I{} basename {} .yml | sort
  exit 1
fi

OS_NAME="$1"
shift

WORKFLOW="${WORKFLOWS_DIR}/${OS_NAME}.yml"
if [ ! -f "${WORKFLOW}" ]; then
  echo "ERROR: Workflow not found: ${WORKFLOW}"
  exit 1
fi

if [ ! -f "${SECRETS_FILE}" ]; then
  echo "ERROR: ${SECRETS_FILE} not found. Copy .secrets.example and fill in values:"
  echo "  cp .secrets.example .secrets"
  exit 1
fi

echo "Running local CI: ${OS_NAME}"
echo "Workflow: ${WORKFLOW}"
echo ""

ARCH_FLAG=""
if [ "$(uname -m)" = "arm64" ]; then
  ARCH_FLAG="--container-architecture linux/amd64"
fi

act workflow_dispatch \
  -W "${WORKFLOW}" \
  --secret-file "${SECRETS_FILE}" \
  ${ARCH_FLAG} \
  "$@"
