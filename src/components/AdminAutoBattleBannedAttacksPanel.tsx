import { useMemo } from 'react'
import type { Attack } from '../types'
import { useAutoBattleBannedAttacks } from '../hooks/useAutoBattleBannedAttacks'
import { useAttacks } from '../hooks/useAttacks'
import { MoveSearchInput } from './MoveSearchInput'
import { TypeBadge } from './TypeBadge'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { PIXEL_BORDER_SM } from '../lib/panelStyles'
import { CloseIcon } from './icons/CloseIcon'

// Liste de capacités bannies du Combat Auto (trop puissantes pour ce mode) —
// gérée librement par l'admin, exclut la capacité à la fois du choix du
// joueur et de celui de l'adversaire (voir src/lib/autoBattle.ts et le RPC
// autobattle_resolve_battle).
export function AdminAutoBattleBannedAttacksPanel() {
  const { bannedAttacks, bannedNames, loading: bannedLoading, banAttack, unbanAttack } = useAutoBattleBannedAttacks()
  const { attacks, loading: attacksLoading } = useAttacks()

  const attacksByName = useMemo(() => {
    const map = new Map<string, Attack>()
    for (const a of attacks) map.set(a.nom, a)
    return map
  }, [attacks])

  const selectableAttacks = useMemo(
    () => attacks.filter((a) => !bannedNames.has(a.nom)),
    [attacks, bannedNames]
  )

  if (bannedLoading || attacksLoading) {
    return (
      <div className="bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
        <p className="text-ink-muted-2 text-sm">Chargement…</p>
      </div>
    )
  }

  return (
    <div className="bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
      <div className="flex items-center gap-2 mb-5">
        <span className="text-2xl">🚫</span>
        <h3 className="text-[#a3841a] text-lg font-bold">Capacités bannies</h3>
      </div>
      <p className="text-ink-muted-2 text-sm mb-3">
        Ces capacités ne peuvent être choisies ni par les joueurs, ni configurées comme capacité d'un opposant (trop puissantes pour ce mode de jeu).
      </p>

      <MoveSearchInput options={selectableAttacks} disabled={false} showDamage onSelect={(a) => banAttack(a.nom)} />

      <div className="flex flex-col gap-2 mt-4">
        {bannedAttacks.length === 0 ? (
          <p className="text-ink-muted-2 text-sm italic">Aucune capacité bannie pour l'instant.</p>
        ) : (
          bannedAttacks.map((row) => {
            const attack = attacksByName.get(row.attack_nom)
            return (
              <div key={row.attack_nom} className={`flex items-center gap-2 px-3 py-2 rounded ${PIXEL_BORDER_SM} bg-cream-secondary`}>
                <TypeBadge type={attack?.type ?? '?'} small />
                <span className="text-ink text-sm font-bold flex-1 truncate">{row.attack_nom}</span>
                <button onClick={() => unbanAttack(row.attack_nom)} className={`text-xs px-2 py-1 rounded ${BUTTON_STYLE.gray}`}>
                  <CloseIcon className="w-3 h-3" />
                </button>
              </div>
            )
          })
        )}
      </div>
    </div>
  )
}
