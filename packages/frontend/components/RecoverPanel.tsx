"use client"
import { useAccount, useReadContract } from "wagmi"
import { erc20Abi } from "viem"
import { USDC_BASE } from "@/lib/vault"

export function RecoverPanel() {
  const { address } = useAccount()

  const { data: usdcOnBase } = useReadContract({
    address: USDC_BASE,
    abi: erc20Abi,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
  })

  return (
    <div className="max-w-lg mx-auto p-6 space-y-4">
      <h2 className="text-2xl font-bold">Recover stranded funds</h2>
      <p className="text-sm opacity-70">
        If a cross-chain withdrawal failed on the destination chain, LI.FI refunds
        USDC to your Base address. Your shares were already burned — the refund
        here is the equivalent value.
      </p>
      {address && (
        <div className="border rounded p-4">
          <p className="text-sm opacity-60">USDC on Base</p>
          <p className="text-xl">{usdcOnBase != null ? String(usdcOnBase) : "—"}</p>
        </div>
      )}
      <p className="text-xs opacity-50">
        This is an expected outcome when bridge destinations fail. No vault bug.
      </p>
    </div>
  )
}
