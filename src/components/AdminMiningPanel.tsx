import { AdminMiningEconomyPanel } from './AdminMiningEconomyPanel'
import { AdminMiningProceduralPanel } from './AdminMiningProceduralPanel'
import { AdminMiningCustomGridsPanel } from './AdminMiningCustomGridsPanel'

export function AdminMiningPanel() {
  return (
    <div className="flex flex-col gap-4">
      <AdminMiningEconomyPanel />
      <AdminMiningProceduralPanel />
      <AdminMiningCustomGridsPanel />
    </div>
  )
}
