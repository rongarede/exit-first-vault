import { http, createConfig } from "wagmi"
import { arbitrum, base, mainnet, optimism, polygon } from "wagmi/chains"
import { injected, walletConnect } from "wagmi/connectors"

const projectId = process.env.NEXT_PUBLIC_WC_PROJECT_ID ?? ""

export const wagmiConfig = createConfig({
  chains: [base, arbitrum, optimism, mainnet, polygon],
  connectors: [
    injected(),
    ...(projectId ? [walletConnect({ projectId })] : []),
  ],
  transports: {
    [base.id]: http(),
    [arbitrum.id]: http(),
    [optimism.id]: http(),
    [mainnet.id]: http(),
    [polygon.id]: http(),
  },
})
