import { useSafariForcedDraw } from '../hooks/useSafariForcedDraw'
import { useSafariGroups } from '../hooks/useSafariGroups'
import { usePokemon } from '../hooks/usePokemon'
import { BUTTON_STYLE } from '../lib/buttonStyles'

// Un slot du tirage forcé : sélection du groupe (qui fixe la jauge de
// capture utilisée) puis d'un pokémon parmi les membres de CE groupe — pas
// une recherche libre, pour garantir que le pokémon forcé hérite bien d'une
// jauge configurée (voir safari_ensure_active_session côté SQL, qui exige
// que le groupe choisi ait des zones de jauge).
function ForcedSlotEditor({
  slot, entry, groups, pokemonByGroup, pokemonByName, onSet, onClear,
}: {
  slot: number
  entry: { group_id: number; pokemon_nom: string } | undefined
  groups: { id: number; nom: string }[]
  pokemonByGroup: Map<number, { pokemon_nom: string }[]>
  pokemonByName: Map<string, { image_miniature: string }>
  onSet: (groupId: number, pokemonNom: string) => void
  onClear: () => void
}) {
  const selectedGroupId = entry?.group_id ?? groups[0]?.id ?? null
  const groupMembers = selectedGroupId ? pokemonByGroup.get(selectedGroupId) ?? [] : []
  const species = entry ? pokemonByName.get(entry.pokemon_nom) : undefined

  return (
    <div className="flex items-center gap-2 bg-cream-secondary border-2 border-ink rounded p-2">
      <span className="text-ink-muted-2 text-xs font-bold w-10 shrink-0">Slot {slot + 1}</span>
      <div className="w-8 h-8 shrink-0 flex items-center justify-center">
        {species?.image_miniature ? (
          <img src={species.image_miniature} alt="" className="pixelated w-full h-full object-contain" />
        ) : (
          <span className="text-lg">🦁</span>
        )}
      </div>
      <select
        value={selectedGroupId ?? ''}
        onChange={(e) => {
          const groupId = Number(e.target.value)
          const firstMember = pokemonByGroup.get(groupId)?.[0]?.pokemon_nom
          if (firstMember) onSet(groupId, firstMember)
        }}
        className="flex-1 min-w-0 bg-white border-2 border-ink rounded px-2 py-1.5 text-ink text-sm outline-none"
      >
        {groups.length === 0 && <option value="">Aucun groupe</option>}
        {groups.map((g) => (
          <option key={g.id} value={g.id}>{g.nom}</option>
        ))}
      </select>
      <select
        value={entry?.pokemon_nom ?? ''}
        disabled={!selectedGroupId || groupMembers.length === 0}
        onChange={(e) => { if (selectedGroupId) onSet(selectedGroupId, e.target.value) }}
        className="flex-1 min-w-0 bg-white border-2 border-ink rounded px-2 py-1.5 text-ink text-sm outline-none disabled:opacity-50"
      >
        {groupMembers.length === 0 && <option value="">Groupe vide</option>}
        {groupMembers.map((m) => (
          <option key={m.pokemon_nom} value={m.pokemon_nom}>{m.pokemon_nom}</option>
        ))}
      </select>
      {entry && (
        <button onClick={onClear} className={`text-xs px-2 py-1.5 rounded ${BUTTON_STYLE.gray}`}>Effacer</button>
      )}
    </div>
  )
}

export function AdminSafariForcedDrawPanel() {
  const { entries, loading: forcedLoading, setSlot, clearSlot, clearAll } = useSafariForcedDraw()
  const { groups, pokemonByGroup, loading: groupsLoading } = useSafariGroups()
  const { pokemon, loading: pokemonLoading } = usePokemon()

  if (forcedLoading || groupsLoading || pokemonLoading) {
    return (
      <div className="bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
        <p className="text-ink-muted-2 text-sm">Chargement…</p>
      </div>
    )
  }

  const pokemonByName = new Map(pokemon.map((p) => [p.nom, p]))
  const entryBySlot = new Map(entries.map((e) => [e.slot, e]))
  const complete = entries.length === 3

  return (
    <div className="bg-cream border-[3px] border-[#a3841a] rounded-[var(--radius-pixel)] shadow-[var(--shadow-pixel)] w-full p-6">
      <div className="flex items-center gap-2 mb-2">
        <span className="text-2xl">🎯</span>
        <h3 className="text-[#a3841a] text-lg font-bold">Tirage forcé (prochaine session)</h3>
      </div>
      <p className="text-ink-muted-2 text-xs mb-4">
        Choisis jusqu'à 3 pokémon (n'importe lequel existant dans le groupe choisi) pour remplacer le tirage aléatoire de la toute prochaine session Safari.
        La jauge de capture utilisée est automatiquement celle du groupe sélectionné pour chaque slot.
      </p>

      {groups.length === 0 ? (
        <p className="text-ink-muted-2 text-sm italic">Crée d'abord au moins un groupe (avec ses zones de jauge) dans l'onglet ci-dessous.</p>
      ) : (
        <>
          <div className="flex flex-col gap-2 mb-3">
            {[0, 1, 2].map((slot) => (
              <ForcedSlotEditor
                key={slot}
                slot={slot}
                entry={entryBySlot.get(slot)}
                groups={groups}
                pokemonByGroup={pokemonByGroup}
                pokemonByName={pokemonByName}
                onSet={(groupId, pokemonNom) => setSlot(slot, groupId, pokemonNom)}
                onClear={() => clearSlot(slot)}
              />
            ))}
          </div>

          <div className="flex items-center justify-between">
            <p className={`text-xs font-bold ${complete ? 'text-[#2f6b3f]' : 'text-ink-muted-2'}`}>
              {complete
                ? '✓ Tirage forcé prêt — utilisé dès la prochaine création de session, puis effacé automatiquement.'
                : `${entries.length}/3 slots définis — les 3 doivent être remplis pour que le tirage forcé s'applique.`}
            </p>
            {entries.length > 0 && (
              <button onClick={clearAll} className={`text-xs px-3 py-1.5 rounded font-bold ${BUTTON_STYLE.gray}`}>Tout effacer</button>
            )}
          </div>
        </>
      )}
    </div>
  )
}
