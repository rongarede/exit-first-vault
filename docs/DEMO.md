# Demo Script (for video recording)

## Setup
- Wallet with 100 USDC on Base
- Empty wallet on Arbitrum
- Screen recorder ready
- Browser dev-tools closed (clean shot)

## Narration
> "DeFi already solved one-click deposit into yield vaults. Jumper, Enso, Coinbase
> — they all let you go from any chain into Morpho. But when you want *out*, you're
> on your own: switch chains, redeem, approve, bridge, swap. Five transactions.
>
> We built the opposite. Exit-First Vault."

## Shots

1. **Landing page.** Read tagline: "Jumper 帮你进来。我们帮你出去。" 3 seconds.
2. **Deposit flow.** Click Deposit. Connect wallet. Enter `100`. Click Deposit.
   Sign approve + deposit. Show efUSDC shares in wallet.
3. **Cut to Jumper (or Enso).** Their Morpho deposit flow is beautiful — that's
   the state of the art. Open their withdraw flow: notice it takes you to a
   multi-step manual process (switch chain, redeem, approve, bridge, swap).
4. **Return to our /withdraw page.** Paste shares balance. Select "Arbitrum USDC".
   Click "Withdraw (1 signature)". Sign ONE transaction.
5. **Show BridgeStatus polling.** Status transitions PENDING → DONE over ~30 seconds.
   Cut to Arbitrum wallet — USDC arrives.
6. **Landing page closing.** "One vault. One signature. Any chain."

## Key numbers to cite
- **1 signature** (vs 3-5 for the manual path)
- **Immutable contract** (no owner, no upgrade, no fee)
- **13 pinned LI.FI facet selectors** covering Across, StargateV2, CCTP
- **Any destination chain LI.FI supports** (20+)
- **Steakhouse Prime USDC** on Base (~$468M TVL) as the yield source

## Fallback: if bridge fails mid-recording
Show the /recover page. "LI.FI refunds failed bridges to your source address.
Your shares are burned — the refund is the equivalent value. This is an
expected outcome, not a vault bug."
