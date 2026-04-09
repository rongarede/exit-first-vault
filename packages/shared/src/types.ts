import type { ChainId } from "./constants/chains"
import type { Address } from "viem"

export type DestChainOption = {
  chainId: ChainId
  label: string
  usdc: Address
}

export type WithdrawQuoteRequest = {
  shares: bigint
  destChainId: ChainId
  destToken: Address
  receiver: Address
  slippageBps: number
}
