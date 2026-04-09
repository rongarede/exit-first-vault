"use client"
import { useEffect, useState } from "react"
import { getStatus, type StatusResponse } from "@lifi/sdk"

export function BridgeStatus({ txHash }: { txHash: string }) {
  const [status, setStatus] = useState<StatusResponse | null>(null)

  useEffect(() => {
    if (!txHash) return
    let cancelled = false

    async function poll() {
      try {
        const result = await getStatus({ txHash })
        if (!cancelled) setStatus(result)
      } catch (e) {
        console.error("status poll error", e)
      }
    }

    poll()
    const interval = setInterval(poll, 5000)
    return () => {
      cancelled = true
      clearInterval(interval)
    }
  }, [txHash])

  if (!status) return <p className="text-sm opacity-60">Polling bridge status...</p>

  return (
    <div className="text-sm space-y-1">
      <p>
        Status: <strong>{status.status}</strong>
      </p>
      {status.substatus && <p>Sub: {status.substatus}</p>}
      {status.status === "DONE" && <p className="text-green-500">Bridge complete!</p>}
      {status.status === "FAILED" && (
        <p className="text-red-500">
          Failed. See <a href="/recover">recover page</a>.
        </p>
      )}
    </div>
  )
}
