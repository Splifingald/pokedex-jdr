import { useEffect, useMemo } from 'react'
import type { Item, Pokemon } from '../types'
import { useDisplayState } from '../hooks/useDisplayState'
import { useDisplayAssets } from '../hooks/useDisplayAssets'
import { usePokemon } from '../hooks/usePokemon'
import { useItems } from '../hooks/useItems'
import { usePlayers } from '../hooks/usePlayers'
import { resolveDisplayState, resolveNpcAsset } from '../lib/resolveDisplayState'
import { DisplayCanvas } from './display/DisplayCanvas'
import { PokemonSearchInput } from './PokemonSearchInput'
import { ItemSearchInput } from './ItemSearchInput'
import { DisplayAssetSearchInput } from './DisplayAssetSearchInput'
import { MAX_FIGURES, moveInArray, addToLayer, removeFromLayer } from '../lib/displayLayers'
import { setBackgroundAsset } from '../lib/displayActions'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { PANEL, PIXEL_BORDER_SM } from '../lib/panelStyles'
import { PixelIcon } from './icons/PixelIcon'
import { CloseIcon } from './icons/CloseIcon'
import { DISPLAY_ICON } from '../lib/icons'

export function AdminDisplayPanel() {
  const { state, loading, updateDisplayState } = useDisplayState()
  const { assets: displayAssets, npcs, backgrounds } = useDisplayAssets()
  const { pokemon } = usePokemon()
  const { items } = useItems()
  const { players } = usePlayers()

  const preview = useMemo(
    () => resolveDisplayState(state, displayAssets, pokemon, items, players),
    [state, displayAssets, pokemon, items, players]
  )

  const availableNpcs = npcs.filter((n) => !state.npc_ids.includes(n.id))
  const availableItems = items.filter((i) => !state.item_ids.includes(i.id))
  const availableBackgrounds = backgrounds.filter((b) => b.id !== state.background_id)
  const selectedBackground = backgrounds.find((b) => b.id === state.background_id) ?? null

  // Un fond doit toujours être défini : si aucun n'est choisi (première utilisation,
  // fond supprimé...), on retombe automatiquement sur le premier de la liste (ordre alphabétique).
  useEffect(() => {
    if (!loading && !state.background_id && !state.background_url && backgrounds.length > 0) {
      setBackgroundAsset(backgrounds[0].id, updateDisplayState)
    }
  }, [loading, state.background_id, state.background_url, backgrounds, updateDisplayState])

  const addNpc = (id: number) => updateDisplayState({ npc_ids: addToLayer(state.npc_ids, id) })
  const removeNpc = (id: number) => updateDisplayState({ npc_ids: removeFromLayer(state.npc_ids, id) })
  const moveNpc = (index: number, direction: -1 | 1) => updateDisplayState({ npc_ids: moveInArray(state.npc_ids, index, direction) })

  const addPokemon = (p: Pokemon) => updateDisplayState({ pokemon_ids: addToLayer(state.pokemon_ids, p.id) })
  const removePokemon = (id: number) => updateDisplayState({ pokemon_ids: removeFromLayer(state.pokemon_ids, id) })
  const movePokemon = (index: number, direction: -1 | 1) => updateDisplayState({ pokemon_ids: moveInArray(state.pokemon_ids, index, direction) })

  const addItem = (item: Item) => updateDisplayState({ item_ids: addToLayer(state.item_ids, item.id) })
  const removeItem = (id: number) => updateDisplayState({ item_ids: removeFromLayer(state.item_ids, id) })
  const moveItem = (index: number, direction: -1 | 1) => updateDisplayState({ item_ids: moveInArray(state.item_ids, index, direction) })

  if (loading) {
    return <p className="text-ink-muted-2 text-sm">Chargement…</p>
  }

  return (
    <div className={`${PANEL} w-full p-6`}>
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

      <div className="grid grid-cols-1 lg:grid-cols-[1fr_22rem] gap-5 items-start">
        <div className="order-2 lg:order-1 flex flex-col gap-5">
        <div>
          <label className="text-ink-muted-2 text-sm block mb-1">Fond d'écran</label>
          {selectedBackground && !state.background_url && (
            <div className={`flex items-center gap-2 px-3 py-2 rounded mb-2 ${PIXEL_BORDER_SM} bg-cream-secondary`}>
              <div className="w-6 h-6 shrink-0 flex items-center justify-center">
                {selectedBackground.image_url && (
                  <img src={selectedBackground.image_url} alt="" className="w-full h-full object-contain" />
                )}
              </div>
              <span className="flex-1 text-ink text-sm truncate">{selectedBackground.nom}</span>
            </div>
          )}
          <DisplayAssetSearchInput
            options={availableBackgrounds}
            onSelect={(b) => setBackgroundAsset(b.id, updateDisplayState)}
            placeholder="Rechercher un fond…"
          />
          {state.background_url && (
            <p className="text-ink-muted-2 text-xs mt-1">
              Fond personnalisé actif (bannière) — sélectionner un fond ci-dessus pour le remplacer.
            </p>
          )}
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
                const npc = resolveNpcAsset(id, displayAssets, players)
                if (!npc) return null
                return (
                  <div key={id} className={`flex items-center gap-2 px-3 py-2 rounded ${PIXEL_BORDER_SM} bg-cream-secondary`}>
                    <div className="w-6 h-6 shrink-0 flex items-center justify-center">
                      {npc.image_url && <img src={npc.image_url} alt="" className="w-full h-full object-contain" />}
                    </div>
                    <span className="flex-1 text-ink text-sm truncate">{npc.nom}</span>
                    <button onClick={() => moveNpc(index, -1)} disabled={index === 0} className={`text-xs px-2 py-1 rounded shrink-0 disabled:opacity-30 ${BUTTON_STYLE.gray}`}>◀</button>
                    <button onClick={() => moveNpc(index, 1)} disabled={index === state.npc_ids.length - 1} className={`text-xs px-2 py-1 rounded shrink-0 disabled:opacity-30 ${BUTTON_STYLE.gray}`}>▶</button>
                    <button onClick={() => removeNpc(id)} className={`text-xs px-2 py-1 rounded shrink-0 ${BUTTON_STYLE.gray}`}><CloseIcon className="w-3 h-3" /></button>
                  </div>
                )
              })
            )}
          </div>
          {state.npc_ids.length < MAX_FIGURES && (
            availableNpcs.length === 0 ? (
              <p className="text-ink-muted-2 text-xs italic">Aucun PNJ disponible — importez-en via Import CSV.</p>
            ) : (
              <DisplayAssetSearchInput
                options={availableNpcs}
                onSelect={(npc) => addNpc(npc.id)}
                placeholder="Ajouter un PNJ…"
              />
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
                    <button onClick={() => removePokemon(id)} className={`text-xs px-2 py-1 rounded shrink-0 ${BUTTON_STYLE.gray}`}><CloseIcon className="w-3 h-3" /></button>
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
          <p className="text-ink-muted-2 text-sm mb-2">
            Objets affichés ({state.item_ids.length}/{MAX_FIGURES})
          </p>
          <div className="flex flex-col gap-1.5 mb-2">
            {state.item_ids.length === 0 ? (
              <p className="text-ink-muted-2 text-xs italic">Aucun objet affiché.</p>
            ) : (
              state.item_ids.map((id, index) => {
                const item = items.find((x) => x.id === id)
                if (!item) return null
                return (
                  <div key={id} className={`flex items-center gap-2 px-3 py-2 rounded ${PIXEL_BORDER_SM} bg-cream-secondary`}>
                    <div className="w-6 h-6 shrink-0 flex items-center justify-center">
                      {item.image_url && <img src={item.image_url} alt="" className="w-full h-full object-contain" />}
                    </div>
                    <span className="flex-1 text-ink text-sm truncate">{item.nom}</span>
                    <button onClick={() => moveItem(index, -1)} disabled={index === 0} className={`text-xs px-2 py-1 rounded shrink-0 disabled:opacity-30 ${BUTTON_STYLE.gray}`}>◀</button>
                    <button onClick={() => moveItem(index, 1)} disabled={index === state.item_ids.length - 1} className={`text-xs px-2 py-1 rounded shrink-0 disabled:opacity-30 ${BUTTON_STYLE.gray}`}>▶</button>
                    <button onClick={() => removeItem(id)} className={`text-xs px-2 py-1 rounded shrink-0 ${BUTTON_STYLE.gray}`}><CloseIcon className="w-3 h-3" /></button>
                  </div>
                )
              })
            )}
          </div>
          {state.item_ids.length < MAX_FIGURES && (
            availableItems.length === 0 ? (
              <p className="text-ink-muted-2 text-xs italic">Aucun objet disponible.</p>
            ) : (
              <ItemSearchInput options={availableItems} onSelect={addItem} />
            )
          )}
        </div>
        </div>

        <div className="order-1 lg:order-2 lg:sticky lg:top-4">
          <div className="w-full aspect-video border-4 border-ink rounded-[var(--radius-pixel)] overflow-hidden shadow-[var(--shadow-pixel)]">
            <DisplayCanvas
              backgroundUrl={preview.backgroundUrl}
              npcs={preview.npcs}
              pokemons={preview.pokemons}
              items={preview.items}
              className="w-full h-full"
            />
          </div>
        </div>
      </div>
    </div>
  )
}
