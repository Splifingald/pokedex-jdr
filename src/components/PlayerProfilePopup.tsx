import type { Player, AdminParameters } from '../types'
import { PLAYER_COLORS } from '../types'
import { EditableName } from './EditableName'
import { NumberInput } from './NumberInput'
import { PANEL_LG } from '../lib/panelStyles'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import {
  STAT_LABELS,
  playerStats,
  toStatPointConfig,
  remainingPoints,
  clampStatValue,
  formatStatModifier,
  statIconUrl,
  statDescription,
  type StatKey,
} from '../lib/statPoints'

interface Props {
  player: Player
  canEdit: boolean
  parameters: AdminParameters
  onUpdate: (id: number, data: Partial<Omit<Player, 'id' | 'created_at'>>) => void
  /** Meilleur score Magikarp (Mini-Jeux), lecture seule — absent si non chargé côté appelant */
  magikarpHighScore?: number
  /** Bouton "Se déconnecter" — fourni uniquement quand c'est le joueur qui consulte son propre profil */
  onLogout?: () => void
  onClose: () => void
}

export function PlayerProfilePopup({ player, canEdit, parameters, onUpdate, magikarpHighScore, onLogout, onClose }: Props) {
  const config = toStatPointConfig(parameters)
  const stats = playerStats(player)
  const remaining = remainingPoints(stats, player.level, config)

  const commitStat = (key: StatKey, requestedValue: number) => {
    const clamped = clampStatValue(stats, key, requestedValue, player.level, config)
    const column = ({
      charisme: 'stat_charisme',
      intelligence: 'stat_intelligence',
      sagesse: 'stat_sagesse',
      dexterite: 'stat_dexterite',
    } as const)[key]
    onUpdate(player.id, { [column]: clamped })
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/55 p-4"
      onClick={(e) => { if (e.target === e.currentTarget) onClose() }}
    >
      <div className={`${PANEL_LG} w-full max-w-sm max-h-[90%] overflow-y-auto p-5 text-ink`}>
        {/* En-tête : avatar, nom, niveau */}
        <div className="flex items-center gap-3 mb-3">
          <div
            className="w-16 h-16 rounded-full overflow-hidden shrink-0 border-[3px] border-ink"
            style={{ backgroundColor: player.color }}
          >
            {player.image_url && (
              <img src={player.image_url} alt={player.name} className="w-full h-full object-cover" />
            )}
          </div>
          <div className="flex-1 min-w-0">
            {canEdit ? (
              <EditableName
                value={player.name}
                onCommit={(v) => v && onUpdate(player.id, { name: v })}
                className="text-lg"
              />
            ) : (
              <p className="text-lg truncate">{player.name}</p>
            )}
            <div className="flex items-center gap-3 mt-1">
              <div className="flex items-center gap-1.5">
                <span className="text-xs text-ink-muted-2">Niveau</span>
                {canEdit ? (
                  <NumberInput
                    value={player.level}
                    min={1}
                    fallback={1}
                    onCommit={(v) => onUpdate(player.id, { level: Math.max(1, v) })}
                    className="w-12 bg-white border-2 border-ink rounded px-1 py-0.5 text-ink text-sm text-center outline-none"
                  />
                ) : (
                  <span className="text-sm font-bold">{player.level}</span>
                )}
              </div>
              <div className="flex items-center gap-1.5">
                <span className="text-xs text-ink-muted-2">Âge</span>
                {canEdit ? (
                  <NumberInput
                    value={player.age ?? 0}
                    min={0}
                    fallback={0}
                    onCommit={(v) => onUpdate(player.id, { age: v > 0 ? v : null })}
                    className="w-12 bg-white border-2 border-ink rounded px-1 py-0.5 text-ink text-sm text-center outline-none"
                  />
                ) : (
                  <span className="text-sm">{player.age ?? '—'}</span>
                )}
              </div>
            </div>
          </div>
        </div>

        {/* Avatar éditable : couleur + image */}
        {canEdit && (
          <div className="mb-4">
            <div className="flex gap-2 mb-2">
              {PLAYER_COLORS.map((c) => (
                <button
                  key={c}
                  type="button"
                  onClick={() => onUpdate(player.id, { color: c })}
                  className={`w-6 h-6 rounded-full ${player.color === c ? 'ring-2 ring-offset-2 ring-offset-cream ring-ink' : ''}`}
                  style={{ backgroundColor: c }}
                />
              ))}
            </div>
            <input
              type="text"
              defaultValue={player.image_url}
              onBlur={(e) => onUpdate(player.id, { image_url: e.target.value })}
              placeholder="Lien de l'image de profil (avatar)"
              className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
            />
          </div>
        )}

        {/* Stats */}
        <div className="border-t-2 border-[#cfc7a8] pt-3 mb-4">
          <div className="flex items-center justify-between mb-2">
            <span className="text-ink-muted-2 text-xs tracking-widest">STATS</span>
            <span className={`text-xs font-bold ${remaining < 0 ? 'text-hp-red' : 'text-ink-muted-2'}`}>
              Points restants : {remaining}
            </span>
          </div>
          <div className="flex flex-col gap-1.5">
            {(Object.keys(STAT_LABELS) as StatKey[]).map((key) => (
              <div key={key} className="flex items-center justify-between gap-2">
                <span className="text-sm flex items-center gap-1.5" title={statDescription(parameters, key) || undefined}>
                  {statIconUrl(parameters, key) && (
                    <img src={statIconUrl(parameters, key)} alt="" className="w-4 h-4 object-contain shrink-0" />
                  )}
                  {STAT_LABELS[key]}
                </span>
                {canEdit ? (
                  <div className="flex items-center gap-1.5">
                    <button
                      onClick={() => commitStat(key, stats[key] - 1)}
                      className={`w-6 h-6 rounded ${BUTTON_STYLE.gray} text-sm leading-none`}
                    >
                      −
                    </button>
                    <span className="w-6 text-center text-sm font-bold">{stats[key]}</span>
                    <button
                      onClick={() => commitStat(key, stats[key] + 1)}
                      className={`w-6 h-6 rounded ${BUTTON_STYLE.gray} text-sm leading-none`}
                    >
                      +
                    </button>
                    <span className="text-ink-muted-2 text-xs">({formatStatModifier(stats[key])})</span>
                  </div>
                ) : (
                  <span className="text-sm font-bold">
                    {stats[key]} <span className="text-ink-muted-2 text-xs">({formatStatModifier(stats[key])})</span>
                  </span>
                )}
              </div>
            ))}
          </div>
        </div>

        {/* Scores Mini-Jeux (lecture seule, jamais éditable ici) */}
        {magikarpHighScore !== undefined && (
          <div className="border-t-2 border-[#cfc7a8] pt-3 mb-4">
            <span className="text-ink-muted-2 text-xs tracking-widest block mb-1.5">SCORES MINI-JEUX</span>
            <div className="flex items-center justify-between">
              <span className="text-sm">Magikarp — meilleur score</span>
              <span className="text-sm font-bold">{magikarpHighScore} taps</span>
            </div>
          </div>
        )}

        {/* Histoire */}
        <div className="border-t-2 border-[#cfc7a8] pt-3 mb-4">
          <span className="text-ink-muted-2 text-xs tracking-widest block mb-1.5">HISTOIRE</span>
          {canEdit ? (
            <textarea
              defaultValue={player.background_story}
              onBlur={(e) => onUpdate(player.id, { background_story: e.target.value })}
              placeholder="Histoire du personnage…"
              rows={4}
              className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none resize-y"
            />
          ) : (
            <p className="text-sm whitespace-pre-wrap">{player.background_story || '—'}</p>
          )}
        </div>

        {/* Image plein pied */}
        <div className="border-t-2 border-[#cfc7a8] pt-3 mb-4">
          <span className="text-ink-muted-2 text-xs tracking-widest block mb-1.5">IMAGE (PLEIN PIED)</span>
          {canEdit && (
            <input
              type="text"
              defaultValue={player.full_body_image_url}
              onBlur={(e) => onUpdate(player.id, { full_body_image_url: e.target.value })}
              placeholder="Lien de l'image plein pied (portrait)"
              className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none mb-2"
            />
          )}
          {player.full_body_image_url ? (
            <img
              src={player.full_body_image_url}
              alt={player.name}
              className="w-full max-h-80 object-contain rounded border-2 border-ink"
            />
          ) : (
            !canEdit && <p className="text-ink-muted-2 text-sm">Aucune image.</p>
          )}
        </div>

        <div className="flex gap-2">
          {onLogout && (
            <button
              onClick={onLogout}
              className={`flex-1 py-2 rounded-lg text-sm font-bold ${BUTTON_STYLE.gray}`}
            >
              Se déconnecter
            </button>
          )}
          <button
            onClick={onClose}
            className={`flex-1 py-2 rounded-lg text-sm font-bold ${BUTTON_STYLE.gray}`}
          >
            Fermer
          </button>
        </div>
      </div>
    </div>
  )
}
