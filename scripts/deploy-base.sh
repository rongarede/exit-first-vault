#!/usr/bin/env bash
set -euo pipefail

# Production deploy wrapper for ExitFirstVault on Base.
# Required env: BASE_RPC, DEPLOYER_PK, METAMORPHO_VAULT
# Optional: ETHERSCAN_API_KEY (for auto-verification on BaseScan)

: "${BASE_RPC:?BASE_RPC must be set}"
: "${DEPLOYER_PK:?DEPLOYER_PK must be set}"
: "${METAMORPHO_VAULT:?METAMORPHO_VAULT must be set (e.g. 0xBEEFE94c8aD530842bfE7d8B397938fFc1cb83b2 = Steakhouse Prime USDC)}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTRACTS_DIR="$(cd "$SCRIPT_DIR/../packages/contracts" && pwd)"

cd "$CONTRACTS_DIR"
forge script script/Deploy.s.sol \
  --rpc-url "$BASE_RPC" \
  --broadcast \
  ${ETHERSCAN_API_KEY:+--verify --etherscan-api-key "$ETHERSCAN_API_KEY"} \
  -vvv

echo ""
echo "Post-deploy checklist:"
echo "  1. Copy the deployed address from the output above"
echo "  2. Update packages/shared/src/constants/addresses.ts EXIT_FIRST_VAULT"
echo "  3. Run: pnpm build:contracts && pnpm sync-abi"
echo "  4. Commit the address update"
