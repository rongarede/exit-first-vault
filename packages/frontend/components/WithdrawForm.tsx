"use client"
import { useState } from "react"
import { useAccount, useReadContract, useWriteContract } from "wagmi"
import { VAULT_ABI, VAULT_ADDRESS } from "@/lib/vault"
import { requestExitQuote } from "@/lib/lifi"
import { CHAIN_IDS, USDC_ADDRESS, type ChainId } from "@exit-first/shared"
import type { Address } from "viem"
import { BridgeStatus } from "./BridgeStatus"

type DestChainId = typeof CHAIN_IDS.ARBITRUM
  | typeof CHAIN_IDS.OPTIMISM
  | typeof CHAIN_IDS.POLYGON
  | typeof CHAIN_IDS.ETHEREUM

export function WithdrawForm() {
  const { address } = useAccount()
  const [shares, setShares] = useState("")
  const [destChainId, setDestChainId] = useState<DestChainId>(CHAIN_IDS.ARBITRUM)
  const [quoting, setQuoting] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const { writeContract, data: txHash } = useWriteContract()

  const { data: sharesBalance } = useReadContract({
    address: VAULT_ADDRESS,
    abi: VAULT_ABI,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
  })

  const { data: previewAssets } = useReadContract({
    address: VAULT_ADDRESS,
    abi: VAULT_ABI,
    functionName: "previewRedeem",
    args: shares ? [BigInt(shares)] : undefined,
  })

  async function handleWithdraw() {
    if (!address || !shares || previewAssets == null) return
    setError(null)
    setQuoting(true)

    try {
      const fromAmount = previewAssets as bigint
      const quote = await requestExitQuote({
        fromVaultAddress: VAULT_ADDRESS as Address,
        fromAmount,
        destChainId,
        destToken: USDC_ADDRESS[destChainId as ChainId],
        destReceiver: address,
      })

      // 0.5% slippage on the source-chain redeem
      const minAssetsOut = (fromAmount * 995n) / 1000n

      writeContract({
        address: VAULT_ADDRESS,
        abi: VAULT_ABI,
        functionName: "redeemAndBridge",
        args: [BigInt(shares), minAssetsOut, address, quote.lifiCallData],
      })
    } catch (e) {
      setError(e instanceof Error ? e.message : "quote failed")
    } finally {
      setQuoting(false)
    }
  }

  return (
    <div className="max-w-md mx-auto p-6 space-y-4">
      <h2 className="text-2xl font-bold">Withdraw to any chain</h2>
      <p className="text-sm opacity-70">
        Your shares: {sharesBalance != null ? String(sharesBalance) : "—"}
      </p>

      <input
        type="text"
        value={shares}
        onChange={(e) => setShares(e.target.value)}
        placeholder="Shares to burn"
        className="w-full border rounded px-3 py-2"
      />

      <select
        value={destChainId}
        onChange={(e) => setDestChainId(Number(e.target.value) as DestChainId)}
        className="w-full border rounded px-3 py-2"
      >
        <option value={CHAIN_IDS.ARBITRUM}>Arbitrum</option>
        <option value={CHAIN_IDS.OPTIMISM}>Optimism</option>
        <option value={CHAIN_IDS.POLYGON}>Polygon</option>
        <option value={CHAIN_IDS.ETHEREUM}>Ethereum</option>
      </select>

      <button
        onClick={handleWithdraw}
        disabled={!address || !shares || quoting}
        className="w-full bg-black text-white rounded py-2"
      >
        {quoting ? "Getting quote..." : "Withdraw (1 signature)"}
      </button>

      {error && <p className="text-red-500 text-sm">{error}</p>}
      {previewAssets != null && (
        <p className="text-xs opacity-60">
          Will redeem ~{String(previewAssets)} USDC from MetaMorpho
        </p>
      )}
      {txHash && <BridgeStatus txHash={txHash} />}
    </div>
  )
}
