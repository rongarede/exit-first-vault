import type { Address } from "viem"

/**
 * LI.FI Diamond on Base. Verified 2026-04-09 via Day 0 probe
 * (`probe/day0-results.md`). This is a stable EIP-2535 proxy address
 * maintained by LI.FI; see spec §11 for the trust assumption.
 */
export const LIFI_DIAMOND_BASE: Address = "0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE"

/**
 * Selected MetaMorpho USDC vault on Base. TBD at Task 4 — see spec §12 for
 * curator selection criteria. Current placeholder is the sentinel zero
 * address; tests that depend on a real curator vault must override via
 * `METAMORPHO_VAULT` env var until this is filled in.
 */
export const METAMORPHO_USDC_BASE: Address = "0x0000000000000000000000000000000000000000"

/**
 * Deployed ExitFirstVault address. Filled after Task 14 deploy script runs
 * against Base mainnet.
 */
export const EXIT_FIRST_VAULT: Address = "0x0000000000000000000000000000000000000000"
