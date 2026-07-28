import { useMemo } from 'react'
import type { Pokemon } from '../types'
import { useDisplayState } from '../hooks/useDisplayState'
import { useBackgrounds } from '../hooks/useBackgrounds'
import { useDisplayAssets } from '../hooks/useDisplayAssets'
import { usePokemon } from '../hooks/usePokemon'
import { useItems } from '../hooks/useItems'
import { resolveDisplayState } from '../lib/resolveDisplayState'
import { DisplayCanvas } from './display/DisplayCanvas'
import { PokemonSearchInput } from './PokemonSearchInput'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { PANEL, PIXEL_BORDER_SM } from '../lib/panelStyles'
import { PixelIcon } from './icons/PixelIcon'
import { DISPLAY_ICON } from '../lib/icons'

const MAX_FIGURES = 4

export function AdminDisplayPanel() {
  const { state, loading, updateDisplayState } = useDisplayState()
  const { backgrounds } = useBackgrounds()
  const { assets: displayAssets, npcs } = useDisplayAssets()
  const { pokemon } = usePokemon()
  const { items } = useItems()

  const preview = useMemo(
    () => resolveDisplayState(state, backgrounds, displayAssets, pokemon, items),
    [state, backgrounds, displayAssets, pokemon, items]
  )

  const availableNpcs = npcs.filter((n) => !state.npc_ids.includes(n.id))

  const moveInArray = (ids: number[], index: number, direction: -1 | 1) => {
    const target = index + direction
    if (target < 0 || target >= ids.length) return ids
    const next = [...ids]
    ;[next[index], next[target]] = [next[target], next[index]]
    return next
  }

  const addNpc = (id: number) => {
    if (state.npc_ids.includes(id) || state.npc_ids.length >= MAX_FIGURES) return
    updateDisplayState({ npc_ids: [...state.npc_ids, id] })
  }
  const removeNpc = (id: number) => {
    updateDisplayState({ npc_ids: state.npc_ids.filter((x) => x !== id) })
  }
  const moveNpc = (index: number, direction: -1 | 1) => {
    updateDisplayState({ npc_ids: moveInArray(state.npc_ids, index, direction) })
  }

  const addPokemon = (p: Pokemon) => {
    if (state.pokemon_ids.includes(p.id) || state.pokemon_ids.length >= MAX_FIGURES) return
    updateDisplayState({ pokemon_ids: [...state.pokemon_ids, p.id] })
  }
  const removePokemon = (id: number) => {
    updateDisplayState({ pokemon_ids: state.pokemon_ids.filter((x) => x !== id) })
  }
  const movePokemon = (index: number, direction: -1 | 1) => {
    updateDisplayState({ pokemon_ids: moveInArray(state.pokemon_ids, index, direction) })
  }

  if (loading) {
    return <p className="text-ink-muted-2 text-sm">Chargement…</p>
  }

  return (
    <div className={`${PANEL} max-w-3xl w-full p-6`}>
      <div className="flex items-center justify-between gap-2 mb-5">
        <div className="flex items-center gap-2">
          <PixelIcon src={DISPLAY_ICON} size={24} />
          <h3 className="text-ink text-lg font-bold">Affichage</h3>
        </div>
        <button
          onClick={() => window.open('/display', '_blank')}
          className={`px-3 py-1.5 rounded text-sm font-bold ${BUTTON_STYLE.blue}`}
        >
          Ouvrir l'affichage ↗
        </button>
      </div>

      <div className="mb-5 w-full max-w-lg aspect-video border-4 border-ink rounded-[var(--radius-pixel)] overflow-hidden shadow-[var(--shadow-pixel)]">
        <DisplayCanvas
          backgroundUrl={preview.backgroundUrl}
          npcs={preview.npcs}
          pokemons={preview.pokemons}
          item={preview.item}
          className="w-full h-full"
        />
      </div>

      <div className="flex flex-col gap-5">
        <div>
          <label className="text-ink-muted-2 text-sm block mb-1">Fond d'écran</label>
          <select
            value={state.background_id ?? ''}
            onChange={(e) => updateDisplayState({ background_id: e.target.value ? Number(e.target.value) : null })}
            className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
          >
            <option value="">— Aucun —</option>
            {backgrounds.map((b) => (
              <option key={b.id} value={b.id}>{b.nom}</option>
            ))}
          </select>
        </div>

        <div>
          <p className="text-ink-muted-2 text-sm mb-2">
            PNJ affichés ({state.npc_ids.length}/{MAX_FIGURES})
          </p>
          <div className="flex flex-col gap-1.5 mb-2">
            {state.npc_ids.length === 0 ? (
              <p className="text-ink-muted-2 text-xs italic">Aucun PNJ affiché.</p>
            ) : (
              state.npc_ids.map((id, index) => {
                const npc = displayAssets.find((a) => a.id === id)
                if (!npc) return null
                return (
                  <div key={id} className={`flex items-center gap-2 px-3 py-2 rounded ${PIXEL_BORDER_SM} bg-cream-secondary`}>
                    <div className="w-6 h-6 shrink-0 flex items-center justify-center">
                      {npc.image_url && <img src={npc.image_url} alt="" className="w-full h-full object-contain" />}
                    </div>
                    <span className="flex-1 text-ink text-sm truncate">{npc.nom}</span>
                    <button onClick={() => moveNpc(index, -1)} disabled={index === 0} className={`text-xs px-2 py-1 rounded shrink-0 disabled:opacity-30 ${BUTTON_STYLE.gray}`}>◀</button>
                    <button onClick={() => moveNpc(index, 1)} disabled={index === state.npc_ids.length - 1} className={`text-xs px-2 py-1 rounded shrink-0 disabled:opacity-30 ${BUTTON_STYLE.gray}`}>▶</button>
                    <button onClick={() => removeNpc(id)} className={`text-xs px-2 py-1 rounded shrink-0 ${BUTTON_STYLE.gray}`}>✕</button>
                  </div>
                )
              })
            )}
          </div>
          {state.npc_ids.length < MAX_FIGURES && (
            availableNpcs.length === 0 ? (
              <p className="text-ink-muted-2 text-xs italic">Aucun PNJ disponible — importez-en via Import CSV.</p>
            ) : (
              <div className="flex flex-wrap gap-1.5">
                {availableNpcs.map((npc) => (
                  <button
                    key={npc.id}
                    onClick={() => addNpc(npc.id)}
                    className={`flex items-center gap-1.5 pl-1.5 pr-2 py-1 rounded-full text-xs ${PIXEL_BORDER_SM} bg-cream hover:bg-cream-secondary transition-colors`}
                  >
                    {npc.image_url && <img src={npc.image_url} alt="" className="w-5 h-5 object-contain rounded-full" />}
                    {npc.nom}
                  </button>
                ))}
              </div>
            )
          )}
        </div>

        <div>
          <p className="text-ink-muted-2 text-sm mb-2">
            Pokémon affichés ({state.pokemon_ids.length}/{MAX_FIGURES})
          </p>
          <div className="flex flex-col gap-1.5 mb-2">
            {state.pokemon_ids.length === 0 ? (
              <p className="text-ink-muted-2 text-xs italic">Aucun Pokémon affiché.</p>
            ) : (
              state.pokemon_ids.map((id, index) => {
                const p = pokemon.find((x) => x.id === id)
                if (!p) return null
                return (
                  <div key={id} className={`flex items-center gap-2 px-3 py-2 rounded ${PIXEL_BORDER_SM} bg-cream-secondary`}>
                    <div className="w-6 h-6 shrink-0 flex items-center justify-center">
                      {p.image_miniature && <img src={p.image_miniature} alt="" className="pixelated w-full h-full object-contain" />}
                    </div>
                    <span className="flex-1 text-ink text-sm truncate">{p.nom}</span>
                    <button onClick={() => movePokemon(index, -1)} disabled={index === 0} className={`text-xs px-2 py-1 rounded shrink-0 disabled:opacity-30 ${BUTTON_STYLE.gray}`}>◀</button>
                    <button onClick={() => movePokemon(index, 1)} disabled={index === state.pokemon_ids.length - 1} className={`text-xs px-2 py-1 rounded shrink-0 disabled:opacity-30 ${BUTTON_STYLE.gray}`}>▶</button>
                    <button onClick={() => removePokemon(id)} className={`text-xs px-2 py-1 rounded shrink-0 ${BUTTON_STYLE.gray}`}>✕</button>
                  </div>
                )
              })
            )}
          </div>
          {state.pokemon_ids.length < MAX_FIGURES && (
            <PokemonSearchInput options={pokemon} onSelect={addPokemon} placeholder="Ajouter un Pokémon…" />
          )}
        </div>

        <div>
          <label className="text-ink-muted-2 text-sm block mb-1">Objet affiché</label>
          <select
            value={state.item_id ?? ''}
            onChange={(e) => updateDisplayState({ item_id: e.target.value ? Number(e.target.value) : null })}
            className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
          >
            <option value="">— Aucun —</option>
            {items.map((i) => (
              <option key={i.id} value={i.id}>{i.nom}</option>
            ))}
          </select>
        </div>
      </div>
    </div>
  )
}
