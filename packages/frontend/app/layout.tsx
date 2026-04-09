import "./globals.css"
import type { ReactNode } from "react"
import { Providers } from "./providers"

export const metadata = {
  title: "Exit-First Vault",
  description: "One-signature cross-chain exit from Morpho yield.",
}

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body>
        <Providers>{children}</Providers>
      </body>
    </html>
  )
}
