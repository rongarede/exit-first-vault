import "./globals.css"
import type { ReactNode } from "react"

export const metadata = {
  title: "Exit-First Vault",
  description: "One-signature cross-chain exit from Morpho yield.",
}

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
