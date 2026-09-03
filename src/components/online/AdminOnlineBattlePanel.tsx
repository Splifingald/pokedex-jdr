import { useState } from 'react'
import type { useOnlineState } from '../../hooks/useOnlineState'
import { useDisplayAssets } from '../../hooks/useDisplayAssets'
import { useOnlineTokens } from '../../hooks/useOnlineTokens'
import { PANEL, PIXEL_BORDER_SM } from '../../lib/panelStyles'
import { BUTTON_STYLE } from '../../lib/buttonStyles'
import { NumberInput } from '../NumberInput'
import { DisplayAssetSearchInput } from '../DisplayAssetSearchInput'
import { ConfirmPopup } from '../ConfirmPopup'

interface Props {
  online: ReturnType<typeof useOnlineState>
}

// Réglages du plateau de bataille : fond, taille de grille, droits des joueurs
// et réinitialisation. Le plateau lui-même se pilote depuis la pop-up plein
// écran, ouverte sur l'accueil — l'aperçu n'aurait pas de valeur ici.
export function AdminOnlineBattlePanel({ online }: Props) {
  const { state, updateOnlineState } = online
  const { battleBackgrounds } = useDisplayAssets()
  const { tokens, clearTokens, resetBoard } = useOnlineTokens()
  const [confirmingReset, setConfirmingReset] = useState(false)

  const selectedBackground = battleBackgrounds.find((b) => b.nom === state.battle_background_nom) ?? null

  const hasContent = tokens.length > 0 || state.blocked_cells.length > 0 || Object.keys(state.colored_cells).length > 0

  // Re-découper change le sens des coordonnées : une case (10,4) ne désigne
  // plus le même endroit du décor. On vide donc tout ce qui était posé plutôt
  // que de laisser des placements devenus faux.
  const setCols = async (cols: number) => {
    const next = Math.max(1, Math.min(60, cols))
    if (next === state.grid_cols) return
    if (hasContent && !window.confirm('Re-découper le terrain retire tous les Pokémon posés, les cases bloquées et les couleurs. Continuer ?')) return
    await updateOnlineState({ grid_cols: next, blocked_cells: [], colored_cells: {} })
    await clearTokens()
  }

  return (
    <div className={`${PANEL} p-6 flex flex-col gap-5 max-w-2xl`}>
      <div>
        <label className="text-ink-muted-2 text-sm block mb-1">Fond du plateau</label>
        {selectedBackground && (
          <div className={`flex items-center gap-2 px-3 py-2 rounded mb-2 ${PIXEL_BORDER_SM} bg-cream-secondary`}>
            <div className="w-10 h-10 shrink-0 flex items-center justify-center">
              {selectedBackground.image_url && (
                <img src={selectedBackground.image_url} alt="" className="w-full h-full object-contain" />
              )}
            </div>
            <span className="flex-1 text-ink text-sm truncate">{selectedBackground.nom}</span>
            <button
              onClick={() => void updateOnlineState({ battle_background_nom: '' })}
              className={`px-2 py-1 rounded text-xs font-bold ${BUTTON_STYLE.gray}`}
            >
              Retirer
            </button>
          </div>
        )}
        {battleBackgrounds.length === 0 ? (
          <p className="text-ink-muted-2 text-xs italic">
            Aucun fond de bataille — importez des lignes de type « Battle Background » via Import CSV.
          </p>
        ) : (
          <DisplayAssetSearchInput
            options={battleBackgrounds.filter((b) => b.nom !== state.battle_background_nom)}
            onSelect={(b) => void updateOnlineState({ battle_background_nom: b.nom })}
            placeholder="Rechercher un fond de bataille…"
          />
        )}
      </div>

      <div>
        <label className="text-ink-muted-2 text-sm block mb-1">Découpage</label>
        <div className="flex items-center gap-2 flex-wrap">
          <NumberInput
            value={state.grid_cols}
            onCommit={(v) => void setCols(v)}
            min={1}
            className="w-16 bg-white border-2 border-ink rounded px-2 py-1 text-ink text-sm text-center outline-none"
          />
          <span className="text-ink-muted-2 text-sm">cases de large</span>
          <span className="text-ink-muted-2 text-sm">→ {state.grid_rows} lignes</span>
        </div>
        <p className="text-ink-muted-2 text-xs mt-1">
          Les cases sont carrées : la hauteur se déduit du format de l'image, et les bandes incomplètes
          du haut et du bas sont masquées. Réduire le découpage retire les jetons et les couleurs qui dépassent.
        </p>
      </div>

      <div className="flex flex-col gap-2">
        <label className="flex items-center gap-2 cursor-pointer">
          <input
            type="checkbox"
            checked={state.players_sidebar_enabled}
            onChange={(e) => void updateOnlineState({ players_sidebar_enabled: e.target.checked })}
            className="w-4 h-4"
          />
          <span className="text-ink text-sm">Barre latérale visible (les joueurs consultent leur équipe)</span>
        </label>
        <label className="flex items-center gap-2 cursor-pointer">
          <input
            type="checkbox"
            checked={state.players_move_enabled}
            onChange={(e) => void updateOnlineState({ players_move_enabled: e.target.checked })}
            className="w-4 h-4"
          />
          <span className="text-ink text-sm">Déplacement autorisé (les joueurs posent et bougent leur Pokémon)</span>
        </label>
        <p className="text-ink-muted-2 text-xs">
          Les deux décochés, les joueurs peuvent encore pinger une case pour montrer quelque chose.
        </p>
      </div>

      <button
        onClick={() => setConfirmingReset(true)}
        className={`py-2.5 rounded text-sm font-bold ${BUTTON_STYLE.red}`}
      >
        Réinitialiser le plateau
      </button>

      {confirmingReset && (
        <ConfirmPopup
          title="Réinitialiser le plateau ?"
          message="Tous les jetons, les cases bloquées, les cases coloriées, le fond et la taille de grille reviennent à zéro."
          confirmLabel="Réinitialiser"
          danger
          onConfirm={() => { void resetBoard(); setConfirmingReset(false) }}
          onCancel={() => setConfirmingReset(false)}
        />
      )}
    </div>
  )
}
