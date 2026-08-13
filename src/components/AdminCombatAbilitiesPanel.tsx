import { AdminAutoBattleBannedAttacksPanel } from './AdminAutoBattleBannedAttacksPanel'
import { AdminAutoBattleAbilityRulesPanel } from './AdminAutoBattleAbilityRulesPanel'

// Section admin "Capacités de combat" : bans et effets spéciaux des capacités.
// Ils vivaient dans la section Combat JcE, alors qu'ils s'appliquent AUSSI au
// Combat JcJ (voir PvpPopup, qui lit useAutoBattleBannedAttacks et
// useAutoBattleAbilityRules) — d'où cette section dédiée, commune aux deux
// modes, pour ne plus laisser croire que ces réglages ne concernent que le JcE.
export function AdminCombatAbilitiesPanel() {
  return (
    <div className="flex flex-col gap-4">
      <AdminAutoBattleBannedAttacksPanel />
      <AdminAutoBattleAbilityRulesPanel />
    </div>
  )
}
