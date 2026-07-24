import type { ReactNode } from 'react'
import { CARD } from '../lib/panelStyles'

interface Props {
  label: string
  value: ReactNode
}

export function StatCell({ label, value }: Props) {
  return (
    <div className={`${CARD} p-2 text-center`}>
      <div className="text-[10px] text-ink-muted-2">{label}</div>
      <div className="text-base text-ink">{value}</div>
    </div>
  )
}
