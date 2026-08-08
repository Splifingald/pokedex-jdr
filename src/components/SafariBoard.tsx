import type { SafariSessionPokemon, SafariGaugeArea, Pokemon, Player, Item } from '../types'
import { SafariPokemonCard } from './SafariPokemonCard'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import { PokedollarIcon } from './PokedollarIcon'

interface Props {
  sessionPokemon: SafariSessionPokemon[]
  pokemonByName: Map<string, Pokemon>
  areasByGroup: Map<number, SafariGaugeArea[]>
  playersById: Map<number, Player>
  selectedSlot: number | null
  onSelectSlot: (slot: number) => void
  berryItem: Item | undefined
  ballItem: Item | undefined
  berryCount: number
  ballCount: number
  hasAttempted: (sessionPokemonId: number) => boolean
  berryMinIncrease: number
  berryMaxIncrease: number
  pokedollarImageUrl?: string | null
  onThrowBerry: () => void
  onThrowBall: () => void
  onBuyBerry: () => void
  onBuyBall: () => void
}

export function SafariBoard({
  sessionPokemon, pokemonByName, areasByGroup, playersById,
  selectedSlot, onSelectSlot,
  berryItem, ballItem, berryCount, ballCount, hasAttempted,
  berryMinIncrease, berryMaxIncrease, pokedollarImageUrl,
  onThrowBerry, onThrowBall, onBuyBerry, onBuyBall,
}: Props) {
  const selected = sessionPokemon.find((sp) => sp.slot === selectedSlot) ?? null
  const selectedAreas = selected ? areasByGroup.get(selected.group_id) ?? [] : []
  const alreadyAttempted = selected ? hasAttempted(selected.id) : false
  const gaugeMaxed = selected ? selected.position_gauge >= 100 : false

  return (
    <div className="flex flex-col gap-4">
      {/* Rangée du haut : toujours les 3 pokémon en ordre naturel, gabarit
          compact — le pokémon sélectionné n'y est plus recentré/agrandi, il
          ne fait que se surligner (voir le panneau détaillé ci-dessous). */}
      <div className="flex flex-wrap justify-center items-start gap-4 py-2">
        {[0, 1, 2].map((slot) => {
          const sp = sessionPokemon.find((r) => r.slot === slot)
          if (!sp) return null
          return (
            <SafariPokemonCard
              key={sp.id}
              sessionPokemon={sp}
              pokemon={pokemonByName.get(sp.pokemon_nom)}
              areas={areasByGroup.get(sp.group_id) ?? []}
              capturedByPlayer={sp.captured_by_player_id ? playersById.get(sp.captured_by_player_id) : undefined}
              active={selectedSlot === slot}
              expanded={false}
              onSelect={() => onSelectSlot(slot)}
            />
          )
        })}
      </div>

      {!selected && (
        <p className="text-ink-muted-2 text-sm text-center italic">Sélectionne un pokémon pour commencer</p>
      )}

      {/* Panneau du pokémon sélectionné, en dessous de la rangée : carte
          agrandie + boutons d'action, qui n'apparaissent que là désormais. */}
      {selected && (
        <div className="flex flex-col items-center gap-4">
          <SafariPokemonCard
            sessionPokemon={selected}
            pokemon={pokemonByName.get(selected.pokemon_nom)}
            areas={selectedAreas}
            capturedByPlayer={selected.captured_by_player_id ? playersById.get(selected.captured_by_player_id) : undefined}
            active
            expanded
            onSelect={() => onSelectSlot(selected.slot)}
          />

          <div className="flex gap-8 justify-center items-start">
            <div className="flex flex-col items-center gap-1.5 w-36">
              {/* Une baie ne peut plus rien changer une fois la jauge au maximum
                  (100) — inutile de laisser le joueur en lancer (ou en acheter)
                  à ce stade, seule la Safari Ball reste pertinente. */}
              {gaugeMaxed ? (
                <div className="w-20 h-20 shrink-0 rounded-full border-[3px] border-ink bg-cream-secondary opacity-50 flex items-center justify-center">
                  {berryItem?.image_url ? (
                    <img src={berryItem.image_url} alt="" className="w-10 h-10 object-contain pixelated grayscale" />
                  ) : (
                    <span className="text-3xl grayscale">🍇</span>
                  )}
                </div>
              ) : berryCount > 0 ? (
                <button
                  onClick={onThrowBerry}
                  title={`Lancer une Baie (${berryCount})`}
                  className="w-20 h-20 shrink-0 rounded-full border-[3px] border-ink bg-yellow-300 flex items-center justify-center shadow-[var(--shadow-pixel)] active:shadow-none active:translate-x-[2px] active:translate-y-[2px] transition-all"
                >
                  {berryItem?.image_url ? (
                    <img src={berryItem.image_url} alt="" className="w-10 h-10 object-contain pixelated" />
                  ) : (
                    <span className="text-3xl">🍇</span>
                  )}
                </button>
              ) : (
                <button
                  onClick={onBuyBerry}
                  title="Acheter une Baie"
                  className={`w-20 h-20 shrink-0 rounded-full flex items-center justify-center text-xs font-bold text-center leading-tight ${BUTTON_STYLE.green}`}
                >
                  Acheter<br /><PokedollarIcon imageUrl={pokedollarImageUrl} size={13} className="align-[-2px]" />{berryItem?.achat ?? 0}
                </button>
              )}
              <p className="text-ink text-sm font-bold text-center">Lancer une Baie{berryCount > 0 ? ` (${berryCount})` : ''}</p>
              <p className="text-ink-muted-2 text-xs text-center">
                {gaugeMaxed ? 'jauge au maximum' : `les baies peuvent augmenter la jauge de ${berryMinIncrease} à ${berryMaxIncrease} points`}
              </p>
            </div>

            <div className="flex flex-col items-center gap-1.5 w-36">
              {ballCount > 0 ? (
                <button
                  onClick={onThrowBall}
                  disabled={alreadyAttempted}
                  title={`Tenter la capture (${ballCount})`}
                  className="w-20 h-20 shrink-0 rounded-full border-[3px] border-ink bg-orange-300 flex items-center justify-center disabled:opacity-40 disabled:cursor-not-allowed shadow-[var(--shadow-pixel)] active:shadow-none active:translate-x-[2px] active:translate-y-[2px] transition-all"
                >
                  {ballItem?.image_url ? (
                    <img src={ballItem.image_url} alt="" className="w-10 h-10 object-contain pixelated" />
                  ) : (
                    <span className="text-3xl">⚪</span>
                  )}
                </button>
              ) : (
                <button
                  onClick={onBuyBall}
                  title="Acheter une Safari Ball"
                  className={`w-20 h-20 shrink-0 rounded-full flex items-center justify-center text-xs font-bold text-center leading-tight ${BUTTON_STYLE.green}`}
                >
                  Acheter<br /><PokedollarIcon imageUrl={pokedollarImageUrl} size={13} className="align-[-2px]" />{ballItem?.achat ?? 0}
                </button>
              )}
              <p className="text-ink text-sm font-bold text-center">Tenter la capture{ballCount > 0 ? ` (${ballCount})` : ''}</p>
              <p className="text-ink-muted-2 text-xs text-center">
                {alreadyAttempted ? 'déjà tenté sur ce pokémon' : 'une seule tentative par pokémon'}
              </p>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
