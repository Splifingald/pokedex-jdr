import type { ReactNode } from 'react'

// Grille 2 colonnes de cartes de stats (PV DE BASE / DÉGÂTS BASE)
export function StatGrid({ children }: { children: ReactNode }) {
  return <div className="grid grid-cols-2 gap-2">{children}</div>
}
