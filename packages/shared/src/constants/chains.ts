export const CHAIN_IDS = {
  ETHEREUM: 1,
  OPTIMISM: 10,
  POLYGON: 137,
  BASE: 8453,
  ARBITRUM: 42161,
} as const

export type ChainId = (typeof CHAIN_IDS)[keyof typeof CHAIN_IDS]

export const SOURCE_CHAIN: ChainId = CHAIN_IDS.BASE

export const SUPPORTED_DEST_CHAINS: readonly ChainId[] = [
  CHAIN_IDS.ARBITRUM,
  CHAIN_IDS.OPTIMISM,
  CHAIN_IDS.ETHEREUM,
  CHAIN_IDS.POLYGON,
] as const
