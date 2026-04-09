import { EXIT_FIRST_VAULT, USDC_ADDRESS, CHAIN_IDS } from "@exit-first/shared"
import vaultAbi from "@exit-first/shared/src/abi/vault.json"
import { parseUnits } from "viem"

export const USDC_BASE = USDC_ADDRESS[CHAIN_IDS.BASE]
export const VAULT_ADDRESS = EXIT_FIRST_VAULT
export const VAULT_ABI = vaultAbi

export function parseUsdc(value: string): bigint {
  return parseUnits(value, 6)
}
