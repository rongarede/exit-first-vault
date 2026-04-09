#!/usr/bin/env bash
set -euo pipefail

# Sync compiled ABI from packages/contracts/out → packages/shared/src/abi
# Run after every `forge build` that changes the vault contract.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

CONTRACT_OUT="$ROOT_DIR/packages/contracts/out/ExitFirstVault.sol/ExitFirstVault.json"
SHARED_ABI="$ROOT_DIR/packages/shared/src/abi/vault.json"

if [ ! -f "$CONTRACT_OUT" ]; then
  echo "ERROR: $CONTRACT_OUT not found. Run 'pnpm build:contracts' first." >&2
  exit 1
fi

mkdir -p "$(dirname "$SHARED_ABI")"
jq '.abi' "$CONTRACT_OUT" > "$SHARED_ABI"
echo "Synced ABI: $CONTRACT_OUT → $SHARED_ABI"
