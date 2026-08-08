import { AdminAutoBattleEconomyPanel } from './AdminAutoBattleEconomyPanel'
import { AdminAutoBattleVariantsPanel } from './AdminAutoBattleVariantsPanel'

export function AdminAutoBattlePanel() {
  return (
    <div className="flex flex-col gap-4">
      <AdminAutoBattleEconomyPanel />
      <AdminAutoBattleVariantsPanel />
    </div>
  )
}
