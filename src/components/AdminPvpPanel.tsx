import { useMemo, useState } from 'react'
import { usePvpConfig } from '../hooks/usePvpConfig'
import { usePvpChallenges } from '../hooks/usePvpChallenges'
import { usePvpChallengeAttempts } from '../hooks/usePvpChallengeAttempts'
import { usePlayers } from '../hooks/usePlayers'
import { usePokemon } from '../hooks/usePokemon'
import { useAttacks } from '../hooks/useAttacks'
import { useToast } from '../context/ToastContext'
import { supabase } from '../lib/supabase'
import { NumberInput } from './NumberInput'
import { PokemonSearchInput } from './PokemonSearchInput'
import { MoveSearchInput } from './MoveSearchInput'
import { TypeBadge } from './TypeBadge'
import { CloseIcon } from './icons/CloseIcon'
import { ConfirmPopup } from './ConfirmPopup'
import { PvpChallengeBanner } from './PvpChallengeBanner'
import { BUTTON_STYLE } from '../lib/buttonStyles'
import type { PvpChallenge } from '../types'

export function AdminPvpPanel() {
  const { config, loading, updateConfig } = usePvpConfig()
  const { challenges, deleteChallenge } = usePvpChallenges()
  const { attemptsByChallenge, deleteAttempt } = usePvpChallengeAttempts()
  const { players } = usePlayers()
  const { pokemon } = usePokemon()
  const { attacks } = useAttacks()
  const { showToast } = useToast()
  const [deletingPast, setDeletingPast] = useState(false)
  const [confirmingDelete, setConfirmingDelete] = useState<PvpChallenge | null>(null)
  const playersById = useMemo(() => new Map(players.map((p) => [p.id, p])), [players])
  const pokemonByName = useMemo(() => new Map(pokemon.map((p) => [p.nom, p])), [pokemon])
  const dummySpecies = pokemon.find((p) => p.nom === config.trial_pokemon_nom)
  const dummyAbility = attacks.find((a) => a.nom === config.trial_ability_nom)

  const handleConfirmDelete = async () => {
    if (!confirmingDelete) return
    const ok = await deleteChallenge(confirmingDelete.id)
    setConfirmingDelete(null)
    showToast(ok ? 'Défi supprimé.' : 'Suppression impossible pour le moment.')
  }

  const handleDeletePast = async () => {
    if (deletingPast) return
    setDeletingPast(true)
    const { error } = await supabase.from('pvp_challenges').delete().eq('active', false)
    setDeletingPast(false)
    if (error) {
      console.error('Erreur lors de la suppression des défis passés :', error)
      showToast('Suppression impossible pour le moment.')
      return
    }
    showToast('Défis passés supprimés.')
  }

  if (loading) {
    return (
      <div className="bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
        <p className="text-ink-muted-2 text-sm">Chargement…</p>
      </div>
    )
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
        <div className="flex items-center gap-2 mb-5">
          <span className="text-2xl">🛡️</span>
          <h3 className="text-[#a3841a] text-lg font-bold">Défi PvP — Général</h3>
        </div>

        <div className="flex flex-col gap-3">
          <div>
            <label className="text-ink-muted-2 text-sm block mb-1">Nom affiché</label>
            <input
              type="text"
              value={config.nom}
              onChange={(e) => updateConfig({ nom: e.target.value })}
              className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
            />
          </div>
          <div>
            <label className="text-ink-muted-2 text-sm block mb-1">Icône (URL)</label>
            <input
              type="text"
              value={config.icon_url}
              onChange={(e) => updateConfig({ icon_url: e.target.value })}
              placeholder="/website_icons/icon_pvp_game.png"
              className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
            />
          </div>
          <div>
            <label className="text-ink-muted-2 text-sm block mb-1">Capacités max dans la boucle défensive</label>
            <NumberInput
              min={1}
              fallback={config.loadout_max}
              value={config.loadout_max}
              onCommit={(v) => updateConfig({ loadout_max: Math.min(8, Math.max(1, v)) })}
              className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
            />
            <p className="text-ink-muted-2 text-xs mt-1">Les doublons comptent (une même capacité peut occuper plusieurs positions). Plafond technique : 8.</p>
          </div>

          <div className="border-t-2 border-[#cfc7a8] pt-3">
            <label className="flex items-center gap-2 text-sm text-ink-muted">
              <input
                type="checkbox"
                checked={config.precision_enabled}
                onChange={(e) => updateConfig({ precision_enabled: e.target.checked })}
                className="w-4 h-4"
              />
              <span>Activer le système de précision (désactivé, toute capacité touche à coup sûr)</span>
            </label>
          </div>
        </div>
      </div>

      <div className="bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
        <div className="flex items-center gap-2 mb-2">
          <span className="text-2xl">🥊</span>
          <h3 className="text-[#a3841a] text-lg font-bold">Adversaire du mode "Tester"</h3>
        </div>
        <p className="text-ink-muted-2 text-xs mb-4">
          Pantin d'entraînement gratuit contre lequel un joueur peut tester sa boucle de capacités avant de poster un défi — pensé pour être "encaissant" (PV élevés) avec une capacité anodine.
        </p>

        <div className="flex flex-col gap-3">
          <div>
            <label className="text-ink-muted-2 text-sm block mb-1">Pokémon</label>
            {config.trial_pokemon_nom ? (
              <div className="flex items-center gap-2">
                <div className="w-8 h-8 shrink-0 rounded border-2 border-ink bg-cream-secondary flex items-center justify-center overflow-hidden">
                  {dummySpecies?.image_miniature ? (
                    <img src={dummySpecies.image_miniature} alt="" className="pixelated w-full h-full object-contain" />
                  ) : (
                    <span className="text-ink-muted-2 text-sm">?</span>
                  )}
                </div>
                <span className="text-ink text-sm flex-1">{config.trial_pokemon_nom}</span>
                <button onClick={() => updateConfig({ trial_pokemon_nom: '' })} className={`text-xs px-2 py-1 rounded ${BUTTON_STYLE.gray}`}>Changer</button>
              </div>
            ) : (
              <PokemonSearchInput options={pokemon} onSelect={(p) => updateConfig({ trial_pokemon_nom: p.nom })} />
            )}
          </div>

          <div>
            <label className="text-ink-muted-2 text-sm block mb-1">Capacité (toujours la même, en boucle)</label>
            {config.trial_ability_nom ? (
              <div className="flex items-center gap-2 flex-wrap">
                <TypeBadge type={dummyAbility?.type ?? '?'} small />
                <span className="text-ink text-sm flex-1">{config.trial_ability_nom}</span>
                <button onClick={() => updateConfig({ trial_ability_nom: '' })} className={`text-xs px-2 py-1 rounded ${BUTTON_STYLE.gray}`}>
                  <CloseIcon className="w-3 h-3" />
                </button>
              </div>
            ) : (
              <MoveSearchInput options={attacks} disabled={false} showDamage onSelect={(a) => updateConfig({ trial_ability_nom: a.nom })} />
            )}
          </div>

          <div>
            <label className="text-ink-muted-2 text-sm block mb-1">PV</label>
            <NumberInput
              min={1}
              fallback={config.trial_hp}
              value={config.trial_hp}
              onCommit={(v) => updateConfig({ trial_hp: Math.max(1, v) })}
              className="w-full bg-white border-2 border-ink rounded px-3 py-2 text-ink text-sm outline-none"
            />
          </div>

          {(!config.trial_pokemon_nom || !config.trial_ability_nom) && (
            <p className="text-hp-red text-xs font-bold">⚠ Configuration incomplète : le bouton "Tester" reste masqué côté joueurs.</p>
          )}
        </div>
      </div>

      <div className="bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
        <h3 className="text-[#a3841a] text-lg font-bold mb-4">Défis actifs ({challenges.length})</h3>
        {challenges.length === 0 ? (
          <p className="text-ink-muted-2 text-sm">Aucun défi actif pour le moment.</p>
        ) : (
          <div className="flex flex-col gap-4">
            {challenges.map((c) => (
              <PvpChallengeBanner
                key={c.id}
                challenge={c}
                defenderPlayer={playersById.get(c.defender_player_id)}
                pokemonByName={pokemonByName}
                attempts={attemptsByChallenge.get(c.id) ?? []}
                playersById={playersById}
                isOwn={false}
                isAdmin
                onPlay={() => {}}
                onWithdraw={() => {}}
                onDeleteChallenge={() => setConfirmingDelete(c)}
                onDeleteAttempt={(attemptId) => void deleteAttempt(attemptId)}
              />
            ))}
          </div>
        )}
      </div>

      <div className="bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
        <h3 className="text-[#a3841a] text-lg font-bold mb-2">Défis passés</h3>
        <p className="text-ink-muted-2 text-xs mb-4">
          Supprime définitivement de la base tous les défis retirés (et leur tableau des scores associé) — n'affecte jamais les défis actuellement actifs.
        </p>
        <button
          onClick={() => void handleDeletePast()}
          disabled={deletingPast}
          className={`px-4 py-2 rounded text-sm font-bold disabled:opacity-40 disabled:cursor-not-allowed ${BUTTON_STYLE.red}`}
        >
          Supprimer tous les défis passés
        </button>
      </div>

      {confirmingDelete && (
        <ConfirmPopup
          title={`Supprimer le défi de ${playersById.get(confirmingDelete.defender_player_id)?.name ?? 'ce joueur'} ?`}
          message="Le défi et tout son tableau des scores seront définitivement supprimés."
          confirmLabel="Supprimer"
          danger
          onConfirm={() => void handleConfirmDelete()}
          onCancel={() => setConfirmingDelete(null)}
        />
      )}
    </div>
  )
}
