import type { useOnlineState } from '../../hooks/useOnlineState'
import type { TurnOrderPosition } from '../../types'
import { useDisplayAssets } from '../../hooks/useDisplayAssets'
import { PANEL_LG, PIXEL_BORDER_SM } from '../../lib/panelStyles'
import { BUTTON_STYLE } from '../../lib/buttonStyles'
import { DisplayAssetSearchInput } from '../DisplayAssetSearchInput'
import { NumberInput } from '../NumberInput'
import { AdminDisplayPanel } from '../AdminDisplayPanel'
import { CloseIcon } from '../icons/CloseIcon'

interface Props {
  online: ReturnType<typeof useOnlineState>
  /** Tant qu'aucun décor de bataille n'est choisi, la fenêtre ne se ferme pas. */
  requireBattleBackground: boolean
  /** Le découpage change : l'appelant vide le plateau (les coordonnées changent de sens). */
  onColsChange: (cols: number) => void
  onReset: () => void
  onEndgame: () => void
  /** Une fin de partie n'a de sens qu'une fois le combat commencé. */
  canEndgame: boolean
  onClose: () => void
}

// Réglages du MJ, accessibles depuis l'écran partagé lui-même. Le contenu suit
// le mode : options d'affichage en mode « Affichage », options de plateau en
// mode « Bataille ». La bascule entre les deux vit ici, en tête.
export function OnlineSettingsModal({
  online, requireBattleBackground, onColsChange, onReset, onEndgame, canEndgame, onClose,
}: Props) {
  const { state, updateOnlineState } = online
  const { battleBackgrounds } = useDisplayAssets()
  const battle = state.mode === 'battle'
  const selected = battleBackgrounds.find((b) => b.nom === state.battle_background_nom) ?? null
  const canClose = !requireBattleBackground || !!state.battle_background_nom

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 p-4"
      onClick={(e) => { if (e.target === e.currentTarget && canClose) onClose() }}
    >
      <div className={`${PANEL_LG} w-full ${battle ? 'max-w-sm' : 'max-w-3xl'} max-h-[88vh] overflow-y-auto p-6 text-ink flex flex-col gap-4`}>
        <div className="flex items-center justify-between gap-2">
          <h3 className="text-ink text-lg">Réglages</h3>
          {canClose && (
            <button
              onClick={onClose}
              aria-label="Fermer"
              className="w-8 h-8 rounded-full border-2 border-ink bg-cream flex items-center justify-center shrink-0"
            >
              <CloseIcon className="w-4 h-4" />
            </button>
          )}
        </div>

        <div>
          <p className="text-ink-muted-2 text-sm mb-1">Mode de l'écran partagé</p>
          <div className="grid grid-cols-2 gap-2">
            <button
              onClick={() => void updateOnlineState({ mode: 'display' })}
              className={`py-2 rounded text-sm font-bold ${!battle ? BUTTON_STYLE.yellow : BUTTON_STYLE.gray}`}
            >
              🖼️ Affichage
            </button>
            <button
              onClick={() => void updateOnlineState({ mode: 'battle', battle_generation: state.battle_generation + 1 })}
              className={`py-2 rounded text-sm font-bold ${battle ? BUTTON_STYLE.yellow : BUTTON_STYLE.gray}`}
            >
              ⚔️ Bataille
            </button>
          </div>
        </div>

        {!battle && <AdminDisplayPanel />}

        {battle && (
          <>
            <div>
              <label className="text-ink-muted-2 text-sm block mb-1">Plateau</label>
              {selected && (
                <div className={`flex items-center gap-2 px-2 py-1.5 rounded mb-2 ${PIXEL_BORDER_SM} bg-cream-secondary`}>
                  <div className="w-12 h-9 shrink-0 overflow-hidden">
                    {selected.image_url && <img src={selected.image_url} alt="" className="w-full h-full object-cover" />}
                  </div>
                  <span className="flex-1 text-ink text-sm truncate">{selected.nom}</span>
                </div>
              )}
              {battleBackgrounds.length === 0 ? (
                <p className="text-ink-muted-2 text-xs italic">
                  Aucun plateau disponible — importe des lignes de type « Battle Background » via Admin → Import CSV.
                </p>
              ) : (
                <DisplayAssetSearchInput
                  options={battleBackgrounds.filter((b) => b.nom !== state.battle_background_nom)}
                  onSelect={(b) => void updateOnlineState({ battle_background_nom: b.nom })}
                  placeholder="Rechercher un plateau…"
                />
              )}
            </div>

            <div>
              <label className="text-ink-muted-2 text-sm block mb-1">Découpage</label>
              <div className="flex items-center gap-2 flex-wrap">
                <NumberInput
                  value={state.grid_cols}
                  onCommit={onColsChange}
                  min={1}
                  className="w-16 bg-white border-2 border-ink rounded px-2 py-1 text-ink text-sm text-center outline-none"
                />
                <span className="text-ink-muted-2 text-sm">cases de large</span>
                <span className="text-ink-muted-2 text-sm ml-auto">→ {state.grid_rows} lignes</span>
              </div>
              <p className="text-ink-muted-2 text-xs mt-1">
                Les cases sont carrées : la hauteur se déduit du format de l'image, et les bandes
                incomplètes du haut et du bas sont masquées.
              </p>
            </div>

            <div>
              <label className="text-ink-muted-2 text-sm block mb-1">Suivi des tours</label>
              <p className="text-ink-muted-2 text-xs mb-1">
                En compact, les Pokémon sont remplacés par leur initiale sur la couleur de leur type.
              </p>
              <select
                value={state.turn_order_position}
                onChange={(e) => void updateOnlineState({ turn_order_position: e.target.value as TurnOrderPosition })}
                className="w-full bg-white border-2 border-ink rounded px-2 py-1.5 text-ink text-sm outline-none"
              >
                <option value="top">Activé (en haut)</option>
                <option value="bottom">Activé (en bas)</option>
                <option value="compact_top">Compact (en haut)</option>
                <option value="compact_bottom">Compact (en bas)</option>
                <option value="hidden">Désactivé</option>
              </select>
            </div>

            <div className="flex flex-col gap-2">
              <label className="flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  checked={state.players_sidebar_enabled}
                  onChange={(e) => void updateOnlineState({ players_sidebar_enabled: e.target.checked })}
                  className="w-4 h-4"
                />
                <span className="text-ink text-sm">Barre latérale visible</span>
              </label>
              <label className="flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  checked={state.players_move_enabled}
                  onChange={(e) => void updateOnlineState({ players_move_enabled: e.target.checked })}
                  className="w-4 h-4"
                />
                <span className="text-ink text-sm">Déplacement autorisé</span>
              </label>
              <label className="flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  checked={state.hide_layout}
                  onChange={(e) => void updateOnlineState({ hide_layout: e.target.checked })}
                  className="w-4 h-4"
                />
                <span className="text-ink text-sm">Vue épurée (masque grille, cases bloquées et couleurs)</span>
              </label>
              <p className="text-ink-muted-2 text-xs">
                La vue épurée ne garde que le décor et les Pokémon — pratique pour une capture d'écran.
              </p>
            </div>

            <button
              onClick={onEndgame}
              disabled={!canEndgame}
              className={`py-2.5 rounded text-sm font-bold ${BUTTON_STYLE.green} disabled:opacity-50`}
            >
              🏁 Terminer la partie
            </button>

            <button onClick={onReset} className={`py-2.5 rounded text-sm font-bold ${BUTTON_STYLE.red}`}>
              Réinitialiser le plateau
            </button>
          </>
        )}

        {!canClose && (
          <p className="text-ink-muted text-xs text-center">Choisis un plateau pour continuer.</p>
        )}
      </div>
    </div>
  )
}
