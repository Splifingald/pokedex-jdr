import { AdminAutoBattleEconomyPanel } from './AdminAutoBattleEconomyPanel'
import { AdminAutoBattleBannedAttacksPanel } from './AdminAutoBattleBannedAttacksPanel'
import { AdminAutoBattleAbilityRulesPanel } from './AdminAutoBattleAbilityRulesPanel'
import { AdminAutoBattleVariantsPanel } from './AdminAutoBattleVariantsPanel'

export function AdminAutoBattlePanel() {
  return (
    <div className="flex flex-col gap-4">
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-4 items-start">
        <AdminAutoBattleEconomyPanel />
        <AdminAutoBattleBannedAttacksPanel />
      </div>
      <AdminAutoBattleVariantsPanel />
      <AdminAutoBattleAbilityRulesPanel />
    </div>
  )
}
