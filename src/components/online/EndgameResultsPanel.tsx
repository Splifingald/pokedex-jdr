import { useState, useMemo } from 'react'
import type { Item, Player, Pokemon } from '../../types'
import type { EndgameEntry, ItemGrant } from '../../lib/endgame'
import { totalKoEnemyHp } from '../../lib/endgame'
import { getMilestones, getMaxXp } from '../../lib/xpBonuses'
import { getStatusInfo } from '../../lib/status'
import { PANEL_LG, CARD } from '../../lib/panelStyles'
import { BUTTON_STYLE } from '../../lib/buttonStyles'
import { HpGauge } from '../HpGauge'
import { XpGauge } from '../XpGauge'
import { NumberInput } from '../NumberInput'
import { ItemSearchInput } from '../ItemSearchInput'
import { CloseIcon } from '../icons/CloseIcon'

interface Props {
  entries: EndgameEntry[]
  players: Player[]
  itemsList: Item[]
  pokemonByName: Map<string, Pokemon>
  saving: boolean
  onValidate: (xpByPokemon: Map<number, number>, grants: ItemGrant[]) => void
  onCancel: () => void
}

// Bilan du MJ : ce que les ennemis ont coûté, ce que les alliés ont vécu, et la
// distribution des récompenses. Valider écrit réellement l'XP sur les Pokémon
// et les objets dans les sacs.
export function EndgameResultsPanel({
  entries, players, itemsList, pokemonByName, saving, onValidate, onCancel,
}: Props) {
  const enemies = useMemo(() => entries.filter((e) => !e.isAlly), [entries])
  const allies = useMemo(() => entries.filter((e) => e.isAlly && e.owned), [entries])
  const koHp = useMemo(() => totalKoEnemyHp(entries), [entries])

  const [xpByPokemon, setXpByPokemon] = useState<Map<number, number>>(
    () => new Map(allies.filter((a) => a.owned).map((a) => [a.playerPokemonId as number, a.owned!.xp]))
  )
  const [grants, setGrants] = useState<ItemGrant[]>([])

  const participants = useMemo(() => {
    const ids = new Set(allies.map((a) => a.ownerPlayerId).filter((id): id is number => id != null))
    return players.filter((p) => ids.has(p.id))
  }, [allies, players])

  const setXp = (id: number, value: number) => setXpByPokemon((prev) => new Map(prev).set(id, Math.max(0, value)))
  const patchGrant = (i: number, patch: Partial<ItemGrant>) =>
    setGrants((prev) => prev.map((g, j) => (j === i ? { ...g, ...patch } : g)))

  return (
    <div className="fixed inset-0 z-[60] flex items-center justify-center bg-black/80 p-4">
      <div className={`${PANEL_LG} w-full max-w-3xl max-h-[90vh] overflow-y-auto p-6 text-ink flex flex-col gap-5`}>
        <div className="flex items-center justify-between gap-2">
          <h3 className="text-ink text-lg">Bilan du combat</h3>
          <button onClick={onCancel} aria-label="Fermer" className="w-8 h-8 rounded-full border-2 border-ink bg-cream flex items-center justify-center shrink-0">
            <CloseIcon className="w-4 h-4" />
          </button>
        </div>

        <div className={`${CARD} px-4 py-3 text-center`}>
          <p className="text-ink-muted-2 text-xs">PV totaux des ennemis mis K.O.</p>
          <p className="text-ink text-3xl font-bold">{koHp}</p>
          <p className="text-ink-muted-2 text-[0.65rem] mt-1">Basé sur leurs PV max — sert à calculer l'XP à distribuer.</p>
        </div>

        <div>
          <p className="text-ink-muted-2 text-sm mb-2">Ennemis ({enemies.length})</p>
          {enemies.length === 0 ? (
            <p className="text-ink-muted-2 text-xs italic">Aucun ennemi n'est passé sur le plateau.</p>
          ) : (
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
              {enemies.map((e) => (
                <div key={e.key} className={`${CARD} p-2 flex items-center gap-2`}>
                  <span className="w-9 h-9 shrink-0 flex items-center justify-center">
                    {e.species?.image_miniature && (
                      <img
                        src={e.species.image_miniature}
                        alt=""
                        className={`pixelated w-full h-full object-contain ${e.isKo ? 'grayscale opacity-60' : ''}`}
                      />
                    )}
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block text-ink text-xs font-bold truncate">{e.displayName}</span>
                    <span className={`block text-[0.65rem] font-bold ${e.isKo ? 'text-hp-red' : 'text-ink-muted'}`}>
                      {e.isKo ? `K.O. · ${e.maxHp} PV` : `${e.hp} / ${e.maxHp} PV`}
                    </span>
                  </span>
                </div>
              ))}
            </div>
          )}
        </div>

        <div>
          <p className="text-ink-muted-2 text-sm mb-2">Alliés ({allies.length})</p>
          {allies.length === 0 ? (
            <p className="text-ink-muted-2 text-xs italic">Aucun Pokémon de joueur n'a participé.</p>
          ) : (
            <div className="flex flex-col gap-2">
              {allies.map((a) => {
                const species = a.species ?? pokemonByName.get(a.nom)
                const maxXp = getMaxXp(species)
                const status = getStatusInfo(a.owned?.status ?? 'aucun')
                const owner = players.find((p) => p.id === a.ownerPlayerId)
                return (
                  <div key={a.key} className={`${CARD} p-2.5 flex flex-col gap-2`}>
                    <div className="flex items-center gap-2">
                      <span className="w-9 h-9 shrink-0 flex items-center justify-center">
                        {species?.image_miniature && (
                          <img src={species.image_miniature} alt="" className={`pixelated w-full h-full object-contain ${a.isKo ? 'grayscale opacity-60' : ''}`} />
                        )}
                      </span>
                      <span className="min-w-0 flex-1">
                        <span className="block text-ink text-sm font-bold truncate">{a.displayName}</span>
                        <span className="block text-ink-muted-2 text-[0.65rem] truncate">
                          {owner?.name ?? '?'}
                          {a.owned?.status && a.owned.status !== 'aucun' ? ` · ${status.label}` : ''}
                        </span>
                      </span>
                      <span className="w-28 shrink-0">
                        <HpGauge current={a.hp} max={a.maxHp} showValue compact />
                      </span>
                    </div>
                    {maxXp != null && a.playerPokemonId != null && (
                      <XpGauge
                        xp={xpByPokemon.get(a.playerPokemonId) ?? a.owned?.xp ?? 0}
                        max={maxXp}
                        milestones={getMilestones(species)}
                        onXpChange={(v) => setXp(a.playerPokemonId as number, v)}
                      />
                    )}
                  </div>
                )
              })}
            </div>
          )}
        </div>

        <div>
          <p className="text-ink-muted-2 text-sm mb-2">Objets à remettre</p>
          <div className="flex flex-col gap-2">
            {grants.map((g, i) => (
              <div key={i} className={`${CARD} p-2 flex items-center gap-2 flex-wrap`}>
                <span className="flex-1 min-w-40">
                  {g.item_nom ? (
                    <span className="flex items-center gap-2">
                      <span className="flex-1 text-ink text-sm truncate">{g.item_nom}</span>
                      <button
                        onClick={() => patchGrant(i, { item_nom: '' })}
                        className={`px-2 py-0.5 rounded text-xs font-bold ${BUTTON_STYLE.gray}`}
                      >
                        Changer
                      </button>
                    </span>
                  ) : (
                    <ItemSearchInput options={itemsList} onSelect={(item) => patchGrant(i, { item_nom: item.nom })} />
                  )}
                </span>
                <NumberInput
                  value={g.quantity}
                  onCommit={(v) => patchGrant(i, { quantity: Math.max(1, v) })}
                  min={1}
                  className="w-14 bg-white border-2 border-ink rounded px-1 py-1 text-ink text-sm text-center outline-none"
                />
                <select
                  value={g.playerId ?? ''}
                  onChange={(e) => patchGrant(i, { playerId: e.target.value === '' ? null : Number(e.target.value) })}
                  className="bg-white border-2 border-ink rounded px-2 py-1 text-ink text-sm outline-none"
                >
                  <option value="">Tous les participants</option>
                  {participants.map((p) => (
                    <option key={p.id} value={p.id}>{p.name}</option>
                  ))}
                </select>
                <button
                  onClick={() => setGrants((prev) => prev.filter((_, j) => j !== i))}
                  aria-label="Retirer cette ligne"
                  className={`px-2 py-1 rounded text-xs font-bold ${BUTTON_STYLE.gray}`}
                >
                  <CloseIcon className="w-3 h-3" />
                </button>
              </div>
            ))}
          </div>
          <button
            onClick={() => setGrants((prev) => [...prev, { item_nom: '', quantity: 1, playerId: null }])}
            className={`mt-2 px-3 py-1.5 rounded text-xs font-bold ${BUTTON_STYLE.blue}`}
          >
            + Ajouter un objet
          </button>
          {participants.length === 0 && (
            <p className="text-ink-muted-2 text-xs italic mt-2">
              Aucun joueur n'a participé : les objets destinés à « tous les participants » ne seront remis à personne.
            </p>
          )}
        </div>

        <button
          onClick={() => onValidate(xpByPokemon, grants.filter((g) => g.item_nom && g.quantity > 0))}
          disabled={saving}
          className={`py-3 rounded text-sm font-bold ${BUTTON_STYLE.green} disabled:opacity-60`}
        >
          {saving ? 'Attribution…' : 'Valider et distribuer'}
        </button>
        <p className="text-ink-muted-2 text-xs text-center -mt-3">
          L'XP et les objets sont réellement attribués, puis chaque joueur voit son récapitulatif.
        </p>
      </div>
    </div>
  )
}
