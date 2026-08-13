import { AdminAutoBattleEconomyPanel } from './AdminAutoBattleEconomyPanel'
import { AdminAutoBattleVariantsPanel } from './AdminAutoBattleVariantsPanel'

// Section admin "Combat JcE" : uniquement les réglages généraux et les
// parcours (variantes). Les bans de capacités et leurs effets spéciaux sont
// partagés avec le Combat JcJ et vivent donc dans leur propre section
// (AdminCombatAbilitiesPanel).
export function AdminAutoBattlePanel() {
  return (
    <div className="flex flex-col gap-4">
      <AdminAutoBattleEconomyPanel />
      <AdminAutoBattleVariantsPanel />
    </div>
  )
}
