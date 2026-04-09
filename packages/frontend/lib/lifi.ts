import { createConfig, getContractCallsQuote, ChainId } from "@lifi/sdk"
import type { Address } from "viem"

createConfig({
  integrator: "exit-first-vault",
})

export type ExitQuoteParams = {
  fromVaultAddress: Address
  fromAmount: bigint
  destChainId: number
  destToken: Address
  destReceiver: Address
}

/**
 * Requests a LI.FI contract-calls quote for bridging USDC out of our vault.
 * The resulting `transactionRequest.data` is what gets passed as
 * `lifiCallData` to `vault.redeemAndBridge`.
 */
export async function requestExitQuote(params: ExitQuoteParams) {
  const quote = await getContractCallsQuote({
    fromChain: ChainId.BAS,
    toChain: params.destChainId,
    fromToken: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913", // USDC Base
    toToken: params.destToken,
    fromAmount: params.fromAmount.toString(),
    fromAddress: params.fromVaultAddress,
    // LI.FI delivers bridged funds to `toFallbackAddress` when contractCalls
    // is empty. That is exactly what we want: send the destination USDC to
    // the user's wallet on the destination chain.
    toFallbackAddress: params.destReceiver,
    contractCalls: [],
  })

  if (!quote?.transactionRequest?.data) {
    throw new Error("LI.FI returned no calldata")
  }

  return {
    lifiCallData: quote.transactionRequest.data as `0x${string}`,
    estimate: quote.estimate,
    tool: quote.tool,
  }
}
