#!/usr/bin/env bash
set -euo pipefail

# Generate LI.FI contractCalls calldata fixtures for D-class tests.
# Output:
#   packages/contracts/test/utils/fixtures.json  (raw quote responses)
#   packages/contracts/test/utils/fixtures.txt   (hex snippets for paste)
#
# Day 0 finding: LI.FI Diamond does NOT validate msg.sender, so the
# fromAddress baked into the quote does not need to match the CREATE2
# vault address at test time. We use a stable dummy for reproducibility.

export https_proxy="${https_proxy:-http://127.0.0.1:7897}"
export http_proxy="${http_proxy:-http://127.0.0.1:7897}"
export all_proxy="${all_proxy:-socks5://127.0.0.1:7897}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_JSON="$ROOT_DIR/packages/contracts/test/utils/fixtures.json"
OUT_TXT="$ROOT_DIR/packages/contracts/test/utils/fixtures.txt"

mkdir -p "$(dirname "$OUT_JSON")"

# Stable dummy vault address for fromAddress field — OK because Diamond
# doesn't validate sender. Keep this constant across regenerations.
DUMMY_VAULT="0x000000000000000000000000000000000000dEaD"
DUMMY_RECEIVER="0x000000000000000000000000000000000000dEaD"
USDC_BASE="0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
USDC_ARB="0xaf88d065e77c8cC2239327C5EDb3A432268e5831"
USDC_OP="0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85"

echo "[" > "$OUT_JSON"
first_entry=1

probe() {
  local name=$1 toChain=$2 toToken=$3 amount=$4
  local body
  body=$(cat <<JSON
{
  "fromChain": 8453,
  "toChain": $toChain,
  "fromToken": "$USDC_BASE",
  "toToken": "$toToken",
  "fromAmount": "$amount",
  "fromAddress": "$DUMMY_VAULT",
  "toAddress": "$DUMMY_RECEIVER",
  "contractCalls": []
}
JSON
)
  local resp
  resp=$(curl -sS -X POST 'https://li.quest/v1/quote/contractCalls' \
    -H 'Content-Type: application/json' -d "$body")
  if [ "$first_entry" -eq 0 ]; then echo "," >> "$OUT_JSON"; fi
  first_entry=0
  echo "$resp" | jq --arg name "$name" '{
    name: $name,
    tool: .tool,
    data: .transactionRequest.data,
    to: .transactionRequest.to,
    value: .transactionRequest.value,
    fromAmount: .action.fromAmount,
    selector: .transactionRequest.data[0:10]
  }' >> "$OUT_JSON"
}

probe "base_to_arb_usdc_100"   42161 "$USDC_ARB" "100000000"
probe "base_to_op_usdc_1000"   10    "$USDC_OP"  "1000000000"
probe "base_to_arb_usdc_1"     42161 "$USDC_ARB" "1000000"

echo "]" >> "$OUT_JSON"

# Produce hex snippets for paste into LifiFixture.sol
echo "# LI.FI fixture hex snippets (paste into LifiFixture.sol)" > "$OUT_TXT"
echo "# Generated $(date -u +%Y-%m-%dT%H:%M:%SZ) at fork-time latest Base block" >> "$OUT_TXT"
jq -r '.[] | "// " + .name + " (" + .tool + ", selector=" + .selector + ")\n// to=" + .to + "\n// fromAmount=" + .fromAmount + "\n" + .data + "\n"' "$OUT_JSON" >> "$OUT_TXT"

echo "Wrote $OUT_JSON"
echo "Wrote $OUT_TXT"
