# Exit-First Vault

ERC-4626 Morpho wrapper on Base. One-signature cross-chain exit via LI.FI Diamond.

**Tagline:** Jumper 帮你进来。我们帮你出去。

## Why

Jumper, Enso, Coinbase × Morpho OnchainKit all nailed "one-click deposit into
yield vaults." None of them solved the exit. We did.

`redeemAndBridge(shares, minAssetsOut, receiver, lifiCallData)` burns vault
shares, withdraws underlying USDC from the backing MetaMorpho vault, and
atomically invokes LI.FI Diamond to bridge the proceeds to any supported
chain — all in one source-chain signature.

## Architecture

- **`ExitFirstVault.sol`** — immutable ERC-4626 wrapper over a MetaMorpho USDC vault
- **Backing vault:** Steakhouse Prime USDC on Base (~$468M TVL)
- **Bridge router:** LI.FI Diamond (`0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE`)
- **Selector whitelist:** 13 selectors pinned at construction covering Across,
  StargateV2, and CCTP (CircleBridge) facets
- Zero fee, no owner, no upgrade, no pause

## Trust assumptions

- LI.FI Diamond is an EIP-2535 proxy governed by LI.FI DAO. We inherit its
  trust model. The selector whitelist limits the blast radius to bridge-related
  facets observed during the Day 0 probe.
- The underlying MetaMorpho vault is operated by a curator with a track
  record. Default = Steakhouse Prime USDC, addresses in
  `packages/shared/src/constants/addresses.ts`.
- OZ 5.0 `ERC4626` provides virtual-shares defense against first-depositor
  inflation attacks (verified in `Inflation.t.sol`).

## Repository layout

```
.
├── packages/
│   ├── contracts/          # Foundry — ExitFirstVault + tests
│   ├── frontend/           # Next.js 14 App Router + wagmi v2 + @lifi/sdk
│   └── shared/             # pure TS constants, types, synced ABI
├── probe/                  # Day 0 LI.FI validation probe (separate git repo)
├── scripts/
│   ├── deploy-base.sh
│   ├── generate-lifi-fixtures.sh
│   └── sync-abi.sh
└── docs/DEMO.md
```

## Run locally

```bash
pnpm install
pnpm build:contracts
pnpm sync-abi
BASE_RPC=https://mainnet.base.org pnpm test:contracts
pnpm dev:frontend
```

## Test coverage

14 tests across 6 suites:

| Suite                      | Tests | Class | Focus                                    |
|----------------------------|-------|-------|------------------------------------------|
| Accounting.t.sol           | 5     | A     | ERC-4626 invariants, fuzz round-trip     |
| Inflation.t.sol            | 1     | B     | First-depositor donation attack          |
| MetaMorphoFailure.t.sol    | 2     | C     | MetaMorpho revert + share price drop     |
| RedeemAndBridge.t.sol      | 3     | D     | Empty/disallowed calldata + happy path   |
| ReentrancyAttack.t.sol     | 1     | D     | Reentrancy via LI.FI callback            |
| CallDataGriefing.t.sol     | 2     | D     | Fuzz griefing + broken whitelisted call  |

Happy-path test exercises the real LI.FI Diamond on a Base mainnet fork —
deposits 1.1 USDC, bridges 1 USDC Base→Arbitrum via Across facet, verifies
zero residual state in the vault.

## Deployed addresses

See `packages/shared/src/constants/addresses.ts`. Fill `EXIT_FIRST_VAULT`
after running `scripts/deploy-base.sh`.

## Spec

Design document: `docs/superpowers/specs/2026-04-09-exit-first-vault-design.md`
(path relative to the parent monorepo workspace).

## Day 0 validation

Before any production code was written, we ran a LI.FI contract-caller probe
to answer three blocking questions:

1. Does `/v1/quote/contractCalls` accept a contract address as `fromAddress`? → **YES**
2. Does a contract calling `Diamond.call(data)` on Base fork succeed? → **YES**
3. What are the dust / residual allowance values after the call? → **0 / 0** on Across path

Results in `probe/day0-results.md`. All three checks were GO — the
differentiating entry is viable.
