import Link from "next/link"

export default function LandingPage() {
  return (
    <main className="min-h-screen">
      <section className="max-w-3xl mx-auto px-6 py-20">
        <h1 className="text-5xl font-bold tracking-tight">Exit-First Vault</h1>
        <p className="mt-6 text-xl opacity-80">
          Jumper 帮你进来。我们帮你出去。
        </p>
        <p className="mt-4 opacity-70">
          A Morpho yield vault on Base with a one-signature cross-chain exit.
          Any frontend (Jumper, Enso, OnchainKit) can deposit into us. Only we
          let you withdraw straight back to your home chain.
        </p>

        <div className="mt-10 flex gap-4">
          <Link href="/deposit" className="px-6 py-3 bg-black text-white rounded">
            Deposit
          </Link>
          <Link href="/withdraw" className="px-6 py-3 border rounded">
            Withdraw (1 sig)
          </Link>
        </div>

        <div className="mt-16 grid grid-cols-1 md:grid-cols-3 gap-6 text-sm">
          <div>
            <h3 className="font-bold">Immutable</h3>
            <p className="opacity-70">No owner, no upgrade, no fee. Just math.</p>
          </div>
          <div>
            <h3 className="font-bold">Morpho-powered</h3>
            <p className="opacity-70">Yields from a curated MetaMorpho vault.</p>
          </div>
          <div>
            <h3 className="font-bold">LI.FI native</h3>
            <p className="opacity-70">Exit to any chain, any asset, one signature.</p>
          </div>
        </div>
      </section>
    </main>
  )
}
