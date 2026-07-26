import type { ReactNode } from 'react'
import { CARD } from '../lib/panelStyles'

interface Props {
  icon: ReactNode
  value: ReactNode
  title: string
  /** Signale une info admin uniquement (ex : chances de capture) */
  adminOnly?: boolean
}

export function StatCell({ icon, value, title, adminOnly = false }: Props) {
  return (
    <div
      title={title}
      className={`${CARD} p-2 text-center ${adminOnly ? 'border-dashed border-[3px] border-yellow-700/60' : ''}`}
    >
      <div className="flex items-center justify-center text-lg leading-none mb-0.5">{icon}</div>
      <div className="text-base text-ink">{value}</div>
    </div>
  )
}
