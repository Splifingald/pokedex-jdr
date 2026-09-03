import { useState } from 'react'
import type { Player, Pokemon, OnlineTileColor } from '../../types'
import { ONLINE_TILE_COLORS } from '../../types'
import { TILE_COLOR_CSS, TILE_COLOR_LABEL } from '../../lib/onlineBoard'
import { BUTTON_STYLE } from '../../lib/buttonStyles'
import { CARD, PIXEL_BORDER_SM } from '../../lib/panelStyles'
import { PlayerSearchInput } from '../PlayerSearchInput'
import { PokemonSearchInput } from '../PokemonSearchInput'
import { NumberInput } from '../NumberInput'

/** Outil du clic GAUCHE. Le clic droit, lui, rend toujours une case
 *  inaccessible, quel que soit l'outil — et déplacer un jeton reste possible
 *  dans tous les cas. */
export type AdminTool = 'ping' | 'paint'

/** Sélection de la palette : une teinte, le noir « Bloquée » qui rend la case
 *  inaccessible, ou la gomme (null) qui enlève l'un comme l'autre. */
export type PaintChoice = OnlineTileColor | 'blocked' | null

interface Props {
  players: Player[]
  /** Le MJ peut incarner PLUSIEURS personnages : leurs équipes s'ajoutent à la
   *  suite dans la barre latérale. */
  incarnated: Player[]
  onIncarnate: (player: Player) => void
  onRelease: (playerId: number) => void
  /** Camp de chaque personnage incarné : les PNJ sont ennemis par défaut, mais
   *  le MJ peut en jouer certains du côté allié. */
  isAlly: (playerId: number) => boolean
  onToggleAlly: (playerId: number) => void
  pokemonCatalog: Pokemon[]
  onPlaceFreeSpecies: (species: Pokemon, maxHp: number, damage: number, label: string) => void
  tool: AdminTool
  onToolChange: (tool: AdminTool) => void
  paintColor: PaintChoice
  onPaintColorChange: (color: PaintChoice) => void
  onReset: () => void
}

const TOOL_LABEL: Record<AdminTool, string> = {
  ping: '📍 Pointer',
  paint: '🎨 Colorier',
}

export function AdminBattleControls({
  players, incarnated, onIncarnate, onRelease, isAlly, onToggleAlly, pokemonCatalog, onPlaceFreeSpecies,
  tool, onToolChange, paintColor, onPaintColorChange, onReset,
}: Props) {
  const [freeSpecies, setFreeSpecies] = useState<Pokemon | null>(null)
  const [freeMaxHp, setFreeMaxHp] = useState(0)
  const [freeDamage, setFreeDamage] = useState(0)
  const [freeLabel, setFreeLabel] = useState('')

  const pickSpecies = (p: Pokemon) => {
    setFreeSpecies(p)
    setFreeMaxHp(p.pv_base ?? 0)
    setFreeDamage(p.degats_base ?? 0)
  }

  const place = () => {
    if (!freeSpecies) return
    onPlaceFreeSpecies(freeSpecies, freeMaxHp, freeDamage, freeLabel.trim())
    setFreeSpecies(null)
    setFreeLabel('')
  }

  return (
    <div className="flex flex-col gap-3">
      <div>
        <p className="text-ink-muted-2 text-xs mb-1">Incarner des personnages</p>
        <div className="flex flex-col gap-1.5 mb-2">
          {incarnated.map((c) => {
            const ally = isAlly(c.id)
            return (
              <div key={c.id} className={`flex items-center gap-2 px-2 py-1.5 rounded ${PIXEL_BORDER_SM} bg-cream-secondary`}>
                <span
                  className="w-4 h-4 rounded-full border-2 border-ink shrink-0"
                  style={{ backgroundColor: c.color }}
                />
                <span className="flex-1 text-ink text-sm truncate">{c.name}</span>
                <button
                  onClick={() => onToggleAlly(c.id)}
                  title={ally ? 'Compte comme allié dans le bilan' : 'Compte comme ennemi dans le bilan'}
                  className={`px-2 py-0.5 rounded text-xs font-bold ${ally ? BUTTON_STYLE.green : BUTTON_STYLE.red}`}
                >
                  {ally ? 'Allié' : 'Ennemi'}
                </button>
                <button onClick={() => onRelease(c.id)} className={`px-2 py-0.5 rounded text-xs font-bold ${BUTTON_STYLE.gray}`}>
                  Retirer
                </button>
              </div>
            )
          })}
        </div>
        {/* La recherche reste disponible : on en incarne autant qu'on veut. */}
        <PlayerSearchInput
          options={players.filter((p) => !incarnated.some((c) => c.id === p.id))}
          onSelect={onIncarnate}
          placeholder="Rechercher un personnage…"
        />
      </div>

      <div className={`${CARD} p-2.5 flex flex-col gap-2`}>
        <p className="text-ink-muted-2 text-xs">Poser une espèce libre (personnage inconnu)</p>
        {freeSpecies ? (
          <>
            <div className="flex items-center gap-2">
              {freeSpecies.image_miniature && (
                <img src={freeSpecies.image_miniature} alt="" className="pixelated w-8 h-8 object-contain" />
              )}
              <span className="flex-1 text-ink text-sm font-bold truncate">{freeSpecies.nom}</span>
              <button onClick={() => setFreeSpecies(null)} className={`px-2 py-0.5 rounded text-xs font-bold ${BUTTON_STYLE.gray}`}>
                ✕
              </button>
            </div>
            <input
              value={freeLabel}
              onChange={(e) => setFreeLabel(e.target.value)}
              placeholder="Nom affiché (facultatif)"
              className="bg-white border-2 border-ink rounded px-2 py-1 text-ink text-sm outline-none"
            />
            <div className="flex items-center gap-2">
              <label className="text-ink-muted-2 text-xs w-14 shrink-0">PV max</label>
              <NumberInput
                value={freeMaxHp}
                onCommit={setFreeMaxHp}
                className="w-16 bg-white border-2 border-ink rounded px-1 py-0.5 text-ink text-sm text-center outline-none"
              />
              <label className="text-ink-muted-2 text-xs w-14 shrink-0">Dégâts</label>
              <NumberInput
                value={freeDamage}
                onCommit={setFreeDamage}
                className="w-16 bg-white border-2 border-ink rounded px-1 py-0.5 text-ink text-sm text-center outline-none"
              />
            </div>
            <button onClick={place} className={`py-1.5 rounded text-sm font-bold ${BUTTON_STYLE.green}`}>
              Choisir une case…
            </button>
          </>
        ) : (
          <PokemonSearchInput options={pokemonCatalog} onSelect={pickSpecies} placeholder="Rechercher une espèce…" />
        )}
      </div>

      <div>
        <p className="text-ink-muted-2 text-xs mb-1">Clic gauche (le déplacement des jetons reste actif)</p>
        <div className="grid grid-cols-2 gap-1.5">
          {(Object.keys(TOOL_LABEL) as AdminTool[]).map((t) => (
            <button
              key={t}
              onClick={() => onToolChange(t)}
              className={`py-1.5 rounded text-xs font-bold ${tool === t ? BUTTON_STYLE.yellow : BUTTON_STYLE.gray}`}
            >
              {TOOL_LABEL[t]}
            </button>
          ))}
        </div>
      </div>

      {tool === 'paint' && (
        <div>
          <p className="text-ink-muted-2 text-xs mb-1">Couleur — glisser pour peindre plusieurs cases</p>
          <div className="flex flex-wrap gap-1.5">
            <button
              onClick={() => onPaintColorChange('blocked')}
              title="Bloquée — case inaccessible aux Pokémon"
              className={`w-8 h-8 rounded border-2 border-ink bg-black ${paintColor === 'blocked' ? 'ring-[3px] ring-shell' : ''}`}
            />
            {ONLINE_TILE_COLORS.map((c) => (
              <button
                key={c}
                onClick={() => onPaintColorChange(c)}
                title={`${TILE_COLOR_LABEL[c]} — simple repère, ne bloque pas`}
                className={`w-8 h-8 rounded border-2 border-ink ${paintColor === c ? 'ring-[3px] ring-shell' : ''}`}
                style={{ backgroundColor: TILE_COLOR_CSS[c] }}
              />
            ))}
            <button
              onClick={() => onPaintColorChange(null)}
              title="Gomme"
              className={`w-8 h-8 rounded border-2 border-ink bg-cream text-ink text-sm ${paintColor === null ? 'ring-[3px] ring-shell' : ''}`}
            >
              ⌫
            </button>
          </div>
        </div>
      )}

      <button onClick={onReset} className={`py-1.5 rounded text-sm font-bold ${BUTTON_STYLE.red}`}>
        Réinitialiser le plateau
      </button>
    </div>
  )
}
